import SwiftUI
import UniformTypeIdentifiers

struct MoreView: View {
    let store: FileStore
    @ObservedObject var downloads: DownloadManager
    @AppStorage("sortByDate") private var sortByDate = false
    @State private var importing = false
    @State private var copying = false
    @State private var importMode = DocumentOperationRequest.Mode.pdf
    @State private var request: DocumentOperationRequest?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("传输") {
                NavigationLink { DownloadsView(manager: downloads) } label: { Label("下载", systemImage: "arrow.down.circle") }
            }
            Section("文件") {
                Button("PDF 处理", systemImage: "doc.text") { importMode = .pdf; importing = true }
                    .disabled(copying)
                Button("图片转换", systemImage: "photo") { importMode = .image; importing = true }
                    .disabled(copying)
                if copying { ProgressView("正在导入文件") }
                Picker("文件排序", selection: $sortByDate) {
                    Text("名称").tag(false)
                    Text("最近修改").tag(true)
                }
            }
            Section("关于") {
                LabeledContent("应用", value: "Shu Replica")
                LabeledContent("原版参考", value: "Shu 1.2.4")
            }
        }
        .navigationTitle("更多")
        .fileImporter(isPresented: $importing, allowedContentTypes: importMode == .pdf ? [.pdf] : [.image], allowsMultipleSelection: true) { result in
            do {
                let urls = try result.get()
                let mode = importMode
                let fileStore = store
                copying = true
                Task { @MainActor in
                    let imported = await Task.detached(priority: .userInitiated) {
                        fileStore.importFiles(urls, into: fileStore.root)
                    }.value
                    copying = false
                    guard imported.failures.isEmpty else {
                        errorMessage = imported.failures.map { "\($0.url.lastPathComponent)：\($0.message)" }.joined(separator: "\n")
                        return
                    }
                    guard !imported.succeeded.isEmpty else { return }
                    request = DocumentOperationRequest(inputs: imported.succeeded, mode: mode)
                }
            } catch {
                if (error as? CocoaError)?.code != .userCancelled { errorMessage = error.localizedDescription }
            }
        }
        .sheet(item: $request) { request in
            DocumentOperationView(store: store, request: request, onFinish: {}).id(request.id)
        }
        .alert("导入失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}
