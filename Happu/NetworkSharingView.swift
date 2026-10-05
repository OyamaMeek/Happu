import SwiftUI
import UIKit

struct NetworkSharingRequest: Identifiable {
    let id = UUID()
    let initialFolder: URL
}

struct NetworkSharingView: View {
    let store: FileStore
    let request: NetworkSharingRequest
    var onFinish: (() -> Void)?
    @EnvironmentObject private var sharing: NetworkSharingService
    @State private var folder: URL?
    @State private var mode = NetworkSharingMode.browser
    @State private var choosingFolder = false
    @State private var errorMessage: String?
    @State private var copiedURL: URL?

    private var selectedFolder: URL { folder ?? request.initialFolder }
    private var active: Bool { !sharing.canStart }
    private var relativeFolder: String {
        if selectedFolder == store.root { return "首页全部文件夹" }
        return selectedFolder.pathComponents.dropFirst(store.root.pathComponents.count).joined(separator: "/")
    }
    var body: some View {
        Form {
            Section("共享内容") {
                LabeledContent("文件夹", value: relativeFolder)
                    .accessibilityIdentifier("network-shared-folder")
                Button("更换文件夹", systemImage: "folder") { choosingFolder = true }.disabled(active)
                Picker("连接方式", selection: $mode) {
                    Text("浏览器").tag(NetworkSharingMode.browser)
                    Text("WebDAV").tag(NetworkSharingMode.webDAV)
                }.disabled(active)
                Text(mode == .browser ? "在同一 Wi-Fi 或热点的设备上，用浏览器打开共享地址，即可查看文件夹、上传和下载文件。" : "在支持 WebDAV 的客户端中输入共享地址。支持浏览、新建、上传、下载、复制、移动和删除；同名文件不会覆盖。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("连接状态") {
                switch sharing.status {
                case .stopped: Text("共享已停止")
                case .starting: ProgressView("正在启动共享")
                case .running: Label("共享已启动", systemImage: "checkmark.circle")
                case .stopping: ProgressView("正在停止并清理传输")
                case .failed(let message): Text(message).foregroundStyle(.red)
                }
                if sharing.canStart {
                    Button("启动共享", systemImage: "network") {
                        Task { do { try await sharing.start(folder: selectedFolder, mode: mode) } catch { errorMessage = error.localizedDescription } }
                    }
                } else {
                    Button("停止共享", systemImage: "stop.circle", role: .destructive) {
                        Task { do { try await sharing.stop() } catch { errorMessage = error.localizedDescription } }
                    }.disabled(sharing.status == .starting || sharing.status == .stopping)
                }
            }
            if sharing.status == .running {
                Section("共享地址") {
                    if sharing.accessURLs.isEmpty { Text(sharing.addressError ?? "没有可用的 Wi-Fi、热点或有线局域网地址，请连接本地网络。") }
                    ForEach(sharing.accessURLs, id: \.self) { url in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(url.absoluteString).textSelection(.enabled).font(.callout.monospaced()).accessibilityIdentifier("network-access-url")
                            Button(copiedURL == url ? "地址已复制" : "复制地址", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = url.absoluteString
                                copiedURL = url
                            }
                            switch Result(catching: { try NetworkSharingQRCode.image(for: url) }) {
                            case .success(let image):
                                Image(decorative: image, scale: 1).interpolation(.none).resizable().scaledToFit().frame(width: 180, height: 180)
                                    .accessibilityLabel("共享地址二维码")
                            case .failure(let error): Text(error.localizedDescription).foregroundStyle(.red)
                            }
                        }
                    }
                    if let error = sharing.discoveryError { Text(error).foregroundStyle(.orange) }
                    Text("共享期间请保持应用在前台。关闭页面、进入后台或锁屏会停止共享，回到前台后需要手动启动。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("本地网络共享")
        .toolbar {
            if let onFinish {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { Task { do { try await sharing.stop(); onFinish() } catch { errorMessage = error.localizedDescription } } }
                        .disabled(sharing.status == .starting || sharing.status == .stopping)
                }
            }
        }
        .interactiveDismissDisabled(active)
        .sheet(isPresented: $choosingFolder) {
            FolderPicker(store: store, selectionTitle: "共享这个文件夹") { folder = $0; choosingFolder = false }
        }
        .alert("共享操作失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onDisappear { Task { do { try await sharing.stop() } catch { errorMessage = error.localizedDescription } } }
    }
}
