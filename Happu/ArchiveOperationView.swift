import SwiftUI
import QuickLook

struct ArchiveRequest: Identifiable {
    enum Action {
        case create([URL])
        case extract(URL)
    }

    let id = UUID()
    let action: Action
    let folder: URL
    var chooseDestination = false
}

struct ArchiveOperationView: View {
    let store: FileStore
    let request: ArchiveRequest
    let onStart: () -> Void
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var destination: URL
    @State private var name: String
    @State private var password = ""
    @State private var choosingFolder: Bool
    @State private var progress = Progress()
    @State private var running = false
    @State private var cancelling = false
    @State private var closeWhenFinished = false
    @State private var started = false
    @State private var result: URL?
    @State private var errorMessage: String?
    @State private var cancelled = false
    @State private var preview: URL?

    init(store: FileStore, request: ArchiveRequest, onStart: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.store = store
        self.request = request
        self.onStart = onStart
        self.onFinish = onFinish
        _destination = State(initialValue: request.folder)
        _choosingFolder = State(initialValue: request.chooseDestination)
        if case .create(let items) = request.action {
            _name = State(initialValue: items.count == 1 ? items[0].lastPathComponent : "归档")
        } else {
            _name = State(initialValue: "")
        }
    }

    private var creating: Bool {
        if case .create = request.action { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                if !started {
                    Section("归档设置") {
                        if creating {
                            TextField("ZIP 名称", text: $name)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("密码（普通 ZIP 可留空）", text: $password)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                        }
                        Text("目的目录：\(destination.path)")
                            .font(.caption)
                        Button("选择目的目录…") { choosingFolder = true }
                        Button(creating ? "开始打包" : "开始解压", action: start)
                            .disabled(creating && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                if started {
                    Section("归档进度") {
                        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                            ProgressView(value: progress.fractionCompleted)
                            Text("已处理 \(progress.completedUnitCount) / \(progress.totalUnitCount) 项")
                        }
                        if running {
                            Text(cancelling ? "正在取消" : "正在处理")
                            Text("取消在条目边界生效，大文件可能需要等待。")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("取消处理", role: .destructive) { cancel() }
                                .disabled(cancelling)
                        }
                    }
                }
                if let result {
                    Section("处理完成") {
                        Text(result.path).textSelection(.enabled)
                        ShareLink(item: result) { Label("分享结果", systemImage: "square.and.arrow.up") }
                        if creating {
                            Button("预览 ZIP", systemImage: "eye") { preview = result }
                        } else {
                            Text("关闭后可在文件列表打开解压目录。")
                        }
                    }
                }
                if let errorMessage {
                    Section("处理失败") {
                        Text(errorMessage)
                        Button("返回输入重试") { resetInput() }
                    }
                }
                if cancelled {
                    Section("已取消") {
                        Text("未发布结果，原文件已保留。")
                        Button("返回输入") { resetInput() }
                    }
                }
            }
            .navigationTitle(creating ? "打包为 ZIP" : "解压 ZIP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        if running {
                            closeWhenFinished = true
                            cancel()
                        } else { dismiss() }
                    }
                    .disabled(closeWhenFinished)
                }
            }
        }
        .interactiveDismissDisabled(running)
        .onDisappear { if running { cancel() } }
        .quickLookPreview($preview)
        .sheet(isPresented: $choosingFolder) {
            FolderPicker(store: store, selectionTitle: creating ? "打包到这里" : "解压到这里") { folder in
                destination = folder
                choosingFolder = false
            }
        }
    }

    @MainActor
    private func start() {
        guard !running else { return }
        let operationProgress = Progress()
        progress = operationProgress
        running = true
        started = true
        cancelling = false
        cancelled = false
        errorMessage = nil
        result = nil
        onStart()
        let service = ArchiveService(root: store.root)
        let action = request.action
        let folder = destination
        let archiveName = name
        let archivePassword = password.isEmpty ? nil : password
        password = ""
        Task { @MainActor in
            let outcome = await Task.detached(priority: .userInitiated) {
                Result {
                    switch action {
                    case .create(let items):
                        return try service.create(items: items, in: folder, named: archiveName, progress: operationProgress)
                    case .extract(let archive):
                        return try service.extract(archive, in: folder, password: archivePassword, progress: operationProgress)
                    }
                }
            }.value
            running = false
            cancelling = false
            switch outcome {
            case .success(let url): result = url
            case .failure(let error):
                if error is CancellationError { cancelled = true }
                else { errorMessage = error.localizedDescription }
            }
            onFinish()
            if closeWhenFinished { dismiss() }
        }
    }

    private func cancel() {
        cancelling = true
        progress.cancel()
    }

    private func resetInput() {
        started = false
        cancelled = false
        errorMessage = nil
        password = ""
    }
}
