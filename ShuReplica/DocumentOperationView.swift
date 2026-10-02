import SwiftUI
import QuickLook

struct DocumentOperationRequest: Identifiable {
    enum Mode { case pdf, image }

    let id = UUID()
    let inputs: [URL]
    let mode: Mode
}

struct DocumentOperationView: View {
    let store: FileStore
    let request: DocumentOperationRequest
    let onFinish: () -> Void

    private enum Operation: String, CaseIterable {
        case merge = "合并 PDF", split = "分割 PDF", export = "按页导出", unlock = "移除密码"
        case convert = "转换图片", compress = "压缩 JPEG", extract = "提取全部帧", compose = "合成图片"
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var editing: String?
    @State private var inputs: [URL]
    @State private var operation: Operation
    @State private var destination: URL
    @State private var name: String
    @State private var passwords: [URL: String] = [:]
    @State private var pagesPerPart = "1"
    @State private var dpi = "72"
    @State private var jpeg = false
    @State private var format = ImageFormat.png
    @State private var quality = "0.9"
    @State private var frame = ""
    @State private var choosingFolder = false
    @State private var progress = Progress()
    @State private var running = false
    @State private var cancelling = false
    @State private var closeWhenFinished = false
    @State private var started = false
    @State private var cancelled = false
    @State private var result: URL?
    @State private var outputFiles: [URL] = []
    @State private var errorMessage: String?
    @State private var preview: URL?

    init(store: FileStore, request: DocumentOperationRequest, onFinish: @escaping () -> Void) {
        self.store = store
        self.request = request
        self.onFinish = onFinish
        _inputs = State(initialValue: request.inputs)
        _operation = State(initialValue: request.mode == .pdf
                           ? (request.inputs.count > 1 ? .merge : .split)
                           : (request.inputs.count > 1 ? .compose : .convert))
        _destination = State(initialValue: request.inputs.first?.deletingLastPathComponent() ?? store.root)
        _name = State(initialValue: (request.inputs.first?.deletingPathExtension().lastPathComponent ?? "文档") + "-处理结果")
    }

    private var operations: [Operation] {
        if request.mode == .pdf { return inputs.count > 1 ? [.merge] : [.split, .export, .unlock] }
        return inputs.count > 1 ? [.compose] : [.convert, .compress, .extract, .compose]
    }

    var body: some View {
        NavigationStack {
            Form {
                if !started {
                    Section("输入文件（按处理顺序）") {
                        ForEach(Array(inputs.enumerated()), id: \.element) { index, input in
                            VStack(alignment: .leading) {
                                Text("\(index + 1). \(input.lastPathComponent)")
                                if inputs.count > 1 {
                                    HStack {
                                        Button("上移", systemImage: "arrow.up") { inputs.swapAt(index, index - 1) }
                                            .disabled(index == 0)
                                            .accessibilityLabel("上移 \(input.lastPathComponent)")
                                        Button("下移", systemImage: "arrow.down") { inputs.swapAt(index, index + 1) }
                                            .disabled(index == inputs.count - 1)
                                            .accessibilityLabel("下移 \(input.lastPathComponent)")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                if request.mode == .pdf {
                                    SecureField("密码 \(input.lastPathComponent)", text: Binding(
                                        get: { passwords[input] ?? "" }, set: { passwords[input] = $0 }
                                    ))
                                    .accessibilityIdentifier("密码 \(input.lastPathComponent)")
                                    .textContentType(.password)
                                    .focused($editing, equals: input.absoluteString)
                                    .submitLabel(.done)
                                }
                            }
                        }
                        if request.mode == .pdf { Text("未加密 PDF 的密码可留空；移除密码需要已知原密码。") .font(.caption) }
                    }
                    Section("处理设置") {
                        Picker("操作类型", selection: $operation) {
                            ForEach(operations, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("操作类型")
                        if operation == .split { inputField("每份页数", text: $pagesPerPart) }
                        if operation == .export {
                            inputField("分辨率 dpi", text: $dpi)
                            Text("分辨率范围：36–300 dpi。") .font(.caption)
                            Picker("页面格式", selection: $jpeg) {
                                Text("PNG").tag(false)
                                Text("JPEG").tag(true)
                            }
                            .pickerStyle(.menu)
                        }
                        if operation == .convert {
                            Picker("图片格式", selection: $format) {
                                ForEach(ImageFormat.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("图片格式")
                        }
                        if operation == .convert || operation == .compress {
                            inputField("图片质量", text: $quality)
                            Text("质量范围：0.1–1.0；影响 JPEG 和 WebP 编码。") .font(.caption)
                            inputField("帧序号（从零开始，可留空）", text: $frame)
                            Text("多帧转 PNG、JPEG、BMP 必须选择帧；转 GIF、WebP、TIFF 留空保留全部帧。JPEG 和 BMP 使用白色背景。")
                                .font(.caption)
                        }
                        if operation == .compose { Text("按输入顺序纵向合成单帧图片，白色背景，输出 PNG。") .font(.caption) }
                        inputField("输出名称", text: $name)
                        Text("目的目录：\(destination.path)") .font(.caption)
                        Button("选择目的目录…") { editing = nil; choosingFolder = true }
                        Button("开始处理", action: start)
                            .disabled(inputs.isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                if started {
                    Section("文档进度") {
                        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                            ProgressView(value: progress.fractionCompleted)
                            Text("已处理 \(progress.completedUnitCount) / \(progress.totalUnitCount) 项")
                        }
                        if running {
                            Text(cancelling ? "正在取消" : "正在处理")
                            Text("取消在页、帧或文件边界生效；单次编码完成前需要等待。") .font(.caption)
                            Button("取消处理", role: .destructive, action: cancel).disabled(cancelling)
                        }
                    }
                }
                if let result {
                    Section("处理完成") {
                        Text(result.path).textSelection(.enabled).accessibilityIdentifier("document-output")
                        ShareLink(item: result) { Label("分享结果", systemImage: "square.and.arrow.up") }
                        Button("预览结果", systemImage: "eye") { preview = outputFiles.first }
                            .disabled(outputFiles.isEmpty)
                        if outputFiles.count > 1 {
                            ForEach(outputFiles, id: \.self) { file in
                                Button(file.lastPathComponent) { preview = file }
                            }
                        }
                    }
                }
                if let errorMessage {
                    Section("处理失败") {
                        Text(errorMessage)
                        Button("返回输入重试", action: resetInput)
                    }
                }
                if cancelled {
                    Section("已取消") {
                        Text("未发布结果，原文件已保留。")
                        Button("返回输入", action: resetInput)
                    }
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit { editing = nil }
            .navigationTitle(request.mode == .pdf ? "PDF 处理" : "图片处理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        passwords.removeAll()
                        if running { closeWhenFinished = true; cancel() }
                        else { dismiss() }
                    }
                    .disabled(closeWhenFinished)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成输入") { editing = nil }
                }
            }
        }
        .interactiveDismissDisabled(running)
        .onDisappear { passwords.removeAll(); if running { cancel() } }
        .quickLookPreview($preview)
        .sheet(isPresented: $choosingFolder) {
            FolderPicker(store: store, selectionTitle: "保存到这里") { destination = $0; choosingFolder = false }
        }
    }

    private func inputField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text).accessibilityIdentifier(title).focused($editing, equals: title).submitLabel(.done)
    }

    @MainActor
    private func start() {
        guard !running else { return }
        editing = nil
        let operationProgress = Progress()
        progress = operationProgress
        running = true
        started = true
        cancelling = false
        cancelled = false
        errorMessage = nil
        result = nil
        outputFiles = []
        let action = operation
        let urls = inputs
        let inputPasswords = passwords
        passwords.removeAll()
        let root = store.root
        let folder = destination
        let outputName = name
        let splitPages = pagesPerPart
        let resolution = dpi
        let exportJPEG = jpeg
        let imageFormat = operation == .compress ? ImageFormat.jpeg : format
        let imageQuality = quality
        let imageFrame = frame.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            let outcome = await Task.detached(priority: .userInitiated) {
                Result {
                    guard let input = urls.first else { throw DocumentInputError("请选择输入文件。") }
                    let pdf = PDFService(root: root)
                    let image = ImageService(root: root)
                    switch action {
                    case .merge:
                        return try pdf.merge(urls, passwords: inputPasswords, in: folder, named: outputName, progress: operationProgress)
                    case .split:
                        guard let count = Int(splitPages) else { throw DocumentInputError("每份页数必须是正整数。") }
                        return try pdf.split(input, password: inputPasswords[input], pagesPerPart: count, in: folder, named: outputName, progress: operationProgress)
                    case .export:
                        guard let dpi = Double(resolution) else { throw DocumentInputError("分辨率必须为 36–300 dpi。") }
                        return try pdf.exportPages(input, password: inputPasswords[input], dpi: dpi, jpeg: exportJPEG, in: folder, named: outputName, progress: operationProgress)
                    case .unlock:
                        return try pdf.removePassword(input, password: inputPasswords[input] ?? "", in: folder, named: outputName, progress: operationProgress)
                    case .convert, .compress:
                        guard let quality = Double(imageQuality) else { throw DocumentInputError("图片质量必须为 0.1–1.0。") }
                        let frame: Int?
                        if imageFrame.isEmpty { frame = nil }
                        else {
                            guard let index = Int(imageFrame), index >= 0 else { throw DocumentInputError("帧序号必须是从零开始的整数。") }
                            frame = index
                        }
                        return try image.convert(input, to: imageFormat, quality: quality, frame: frame, in: folder, named: outputName, progress: operationProgress)
                    case .extract:
                        return try image.extractFrames(input, in: folder, named: outputName, progress: operationProgress)
                    case .compose:
                        return try image.compose(urls, in: folder, named: outputName, progress: operationProgress)
                    }
                }
            }.value
            running = false
            cancelling = false
            switch outcome {
            case .success(let url):
                result = url
                do {
                    outputFiles = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                        ? store.contents(of: url) : [url]
                } catch { errorMessage = "结果已保存，但无法列出预览文件：\(error.localizedDescription)" }
            case .failure(let error):
                if error is CancellationError { cancelled = true }
                else { errorMessage = error.localizedDescription }
            }
            onFinish()
            if closeWhenFinished { dismiss() }
        }
    }

    private func cancel() { cancelling = true; progress.cancel() }

    private func resetInput() {
        started = false
        cancelled = false
        errorMessage = nil
        passwords.removeAll()
    }
}

private struct DocumentInputError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
