import Foundation
import Combine
import ShuNetwork
import Network
#if os(iOS)
import UIKit
#endif

enum NetworkSharingMode: String, CaseIterable { case browser, webDAV }
enum NetworkSharingStatus: Equatable { case stopped, starting, running, stopping, failed(String) }

@MainActor final class NetworkSharingService: NSObject, ObservableObject, NetServiceDelegate {
    @Published private(set) var status: NetworkSharingStatus = .stopped
    @Published private(set) var sharedDirectory: URL?
    @Published private(set) var mode: NetworkSharingMode?
    @Published private(set) var listeningPort: UInt16?
    @Published private(set) var canStart = true
    @Published private(set) var accessURLs: [URL] = []
    @Published private(set) var discoveryError: String?
    @Published private(set) var addressError: String?
    private let root: URL
    private var server: ShuHTTPServer?
    private var stopping: Task<Void, Error>?
    private var monitor: NWPathMonitor?
    private var discovery: NetService?
    private var observers: [NSObjectProtocol] = []
    init(root: URL) {
        self.root = root
        super.init()
        #if os(iOS)
        for name in [UIApplication.didEnterBackgroundNotification, UIApplication.protectedDataWillBecomeUnavailableNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    let token = UIApplication.shared.beginBackgroundTask(withName: "停止网络共享")
                    do { try await self.stop() } catch { self.status = .failed(error.localizedDescription) }
                    if token != .invalid { UIApplication.shared.endBackgroundTask(token) }
                }
            })
        }
        #endif
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) }; monitor?.cancel() }
    private func refreshAddresses() {
        guard let port = listeningPort, status == .running else { return }
        do { accessURLs = try NetworkSharingAddresses.urls(port: port); addressError = nil }
        catch { accessURLs = []; addressError = error.localizedDescription }
    }
    nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        Task { @MainActor in
            guard sender === discovery else { return }
            discoveryError = "局域网服务发现失败（\(errorDict[NetService.errorCode]?.intValue ?? 0)）。请通过显示的地址连接，并检查本地网络权限。"
        }
    }
    func start(folder: URL, mode: NetworkSharingMode) async throws {
        guard canStart else { throw NSError(domain: "ShuNetwork", code: 409, userInfo: [NSLocalizedDescriptionKey: "请等待当前共享会话完成停止。"] ) }
        canStart = false; status = .starting
        do {
            let candidate = try ShuHTTPServer(workspaceURL: root, sharedDirectoryURL: folder)
            server = candidate
            try candidate.start(with: mode == .browser ? .browser : .webDAV)
            sharedDirectory = folder; self.mode = mode
            listeningPort = candidate.port; status = .running
            refreshAddresses(); discoveryError = nil
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] _ in Task { @MainActor in self?.refreshAddresses() } }
            self.monitor = monitor; monitor.start(queue: DispatchQueue(label: "ShuNetwork.interfaces"))
            let discovery = NetService(domain: "local.", type: "_http._tcp.", name: "Shu 网络共享", port: Int32(candidate.port))
            discovery.delegate = self; self.discovery = discovery; discovery.publish()
        } catch {
            status = .failed(error.localizedDescription)
            if server == nil { canStart = true }
            else { try await stop(); status = .failed(error.localizedDescription) }
            throw error
        }
    }
    func stop() async throws {
        if let stopping { return try await stopping.value }
        guard let server else { return }
        status = .stopping; canStart = false
        monitor?.cancel(); monitor = nil; discovery?.stop(); discovery = nil
        accessURLs = []; discoveryError = nil; addressError = nil
        let task = Task { @MainActor in
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                server.stop { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        }
        stopping = task
        do {
            try await task.value
            self.server = nil; sharedDirectory = nil; mode = nil; listeningPort = nil
            status = .stopped; canStart = true; stopping = nil
        } catch {
            status = .failed(error.localizedDescription); stopping = nil
            throw error
        }
    }
}
