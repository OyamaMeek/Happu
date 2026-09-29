import SwiftUI
import QuickLook

struct DownloadsView: View {
    @ObservedObject var manager: DownloadManager
    @State private var adding = false
    @State private var urlText = ""
    @State private var headersText = ""
    @State private var preview: URL?
    @State private var formError: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let storageError = manager.storageError {
                Section { Text(storageError).foregroundStyle(.red) }
            }
            if !manager.items.filter({ $0.state != .completed }).isEmpty {
                Section("活动任务") {
                    ForEach(manager.items.filter { $0.state != .completed }) { item in row(item) }
                }
            }
            if !manager.items.filter({ $0.state == .completed }).isEmpty {
                Section("下载完成") {
                    ForEach(manager.items.filter { $0.state == .completed }) { item in row(item) }
                }
            }
        }
        .overlay {
            if manager.items.isEmpty {
                ContentUnavailableView("暂无下载任务", systemImage: "arrow.down.circle",
                                       description: Text("点击右上角添加 HTTP 链接"))
            }
        }
        .navigationTitle("下载")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("新建下载", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $adding) {
            NavigationStack {
                Form {
                    Section("链接") {
                        TextField("https://example.com/file.zip", text: $urlText)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                    }
                    Section("请求头（可选）") {
                        TextEditor(text: $headersText)
                            .frame(minHeight: 90)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Text("每行一项，如 User-Agent: Shu")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("新建下载")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { adding = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("开始") {
                            do {
                                try manager.start(urlText: urlText, headersText: headersText)
                                urlText = ""
                                headersText = ""
                                adding = false
                            } catch { formError = error.localizedDescription }
                        }
                    }
                }
            }
            .alert("链接无效", isPresented: Binding(get: { formError != nil }, set: { if !$0 { formError = nil } })) {
                Button("好") { formError = nil }
            } message: { Text(formError ?? "") }
        }
        .quickLookPreview($preview)
        .alert("下载失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func row(_ item: DownloadItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.state == .completed ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.title2)
                .foregroundStyle(item.state == .completed ? Color.green : Color.blue)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name).lineLimit(1)
                if item.state == .running {
                    ProgressView(value: item.progress)
                    Text(item.progress > 0 ? "\(Int(item.progress * 100))%" : "下载中…")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(status(item)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if item.state == .running {
                Button { manager.pause(item.id) } label: { Image(systemName: "pause.circle") }
                    .accessibilityLabel("暂停")
            } else if item.state == .paused || item.state == .failed {
                Button { manager.resume(item.id) } label: { Image(systemName: "play.circle") }
                    .accessibilityLabel("继续")
            } else if let file = item.file {
                Button { preview = file } label: { Image(systemName: "eye") }
                    .accessibilityLabel("预览")
            }
        }
        .buttonStyle(.borderless)
        .contextMenu {
            if let file = item.file {
                ShareLink(item: file) { Label("分享", systemImage: "square.and.arrow.up") }
            }
            Button("删除任务与文件", systemImage: "trash", role: .destructive) {
                do { try manager.remove(item.id) }
                catch { errorMessage = error.localizedDescription }
            }
        }
    }

    private func status(_ item: DownloadItem) -> String {
        switch item.state {
        case .running: "下载中"
        case .paused: "已暂停"
        case .completed: "已保存到文件 / Downloads"
        case .failed: item.error ?? "下载失败"
        }
    }
}
