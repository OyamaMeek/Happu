import Foundation
import Combine
import ShuNetwork

enum NetworkSharingMode: String, CaseIterable { case browser, webDAV }
enum NetworkSharingStatus: Equatable { case stopped, starting, running, stopping, failed(String) }

@MainActor final class NetworkSharingService: ObservableObject {
    @Published private(set) var status: NetworkSharingStatus = .stopped
    @Published private(set) var sharedDirectory: URL?
    @Published private(set) var mode: NetworkSharingMode?
    @Published private(set) var listeningPort: UInt16?
    @Published private(set) var canStart = true
    private let root: URL
    private var server: ShuHTTPServer?
    private var stopping: Task<Void, Error>?
    init(root: URL) { self.root = root }
    func start(folder: URL, mode: NetworkSharingMode) async throws {
        guard canStart else { throw NSError(domain: "ShuNetwork", code: 409, userInfo: [NSLocalizedDescriptionKey: "请等待当前共享会话完成停止。"] ) }
        canStart = false; status = .starting
        do {
            let candidate = try ShuHTTPServer(workspaceURL: root, sharedDirectoryURL: folder)
            server = candidate
            try candidate.start(with: mode == .browser ? .browser : .webDAV)
            sharedDirectory = folder; self.mode = mode
            listeningPort = candidate.port; status = .running
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
