import SwiftUI
import QuickLook
import UIKit
import UniformTypeIdentifiers

struct FilesHomeView: View {
    let store: FileStore
    @State private var errorMessage: String?
    @State private var result: FileBatchResult?

    var body: some View {
        List {
            Section("工作区") {
                NavigationLink {
                    FolderView(store: store, folder: store.root)
                } label: { Label("所有文件", systemImage: "folder") }
                NavigationLink {
                    FolderView(store: store, folder: store.root.appendingPathComponent("Downloads"))
                } label: { Label("下载", systemImage: "arrow.down.circle") }
                NavigationLink {
                    FolderView(store: store, folder: store.root.appendingPathComponent("共享"))
                } label: { Label("共享", systemImage: "square.and.arrow.up") }
            }
            Section("文件分类") {
                ForEach(WorkspaceCategory.allCases, id: \.self) { category in
                    NavigationLink {
                        FolderView(store: store, folder: store.root.appendingPathComponent(category.rawValue))
                    } label: { Label(category.rawValue, systemImage: category.systemImage) }
                }
            }
        }
        .navigationTitle("文件")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("一键归组", systemImage: "square.grid.2x2") {
                    do {
                        let files = try store.contents(of: store.root).filter {
                            (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true
                        }
                        result = store.perform(.group, on: files)
                    }
                    catch { errorMessage = error.localizedDescription }
                }
                .accessibilityLabel("一键归组")
            }
        }
        .alert("操作失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert("归组结果", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
            Button("好") { result = nil }
        } message: { Text(result?.message ?? "") }
    }
}

struct FolderView: View {
    let store: FileStore
    let folder: URL

    @AppStorage("sortByDate") private var sortByDate = false
    @State private var items: [URL] = []
    @State private var search = ""
    @State private var preview: URL?
    @State private var importing = false
    @State private var edit: Edit?
    @State private var editName = ""
    @State private var toDelete: [URL] = []
    @State private var transfer: Transfer?
    @State private var errorMessage: String?
    @State private var result: FileBatchResult?
    @State private var selecting = false
    @State private var selection: Set<URL> = []
    @State private var shareRequest: FileShareRequest?
    @State private var archiveRequest: ArchiveRequest?
    @State private var archiveRunning = false
    @State private var documentRequest: DocumentOperationRequest?

    private enum Edit { case folder, rename(URL) }
    private enum Transfer { case copy([URL]), move([URL]) }

    private var selectedItems: [URL] { items.filter { selection.contains($0) } }

    private var visibleItems: [URL] {
        let filtered = items.filter { search.isEmpty || $0.lastPathComponent.localizedCaseInsensitiveContains(search) }
        guard sortByDate else { return filtered }
        return filtered.sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
    }

    var body: some View {
        List {
            ForEach(visibleItems, id: \.self) { url in
                itemView(url)
                    .contextMenu {
                        if !selecting {
                            Button("重命名", systemImage: "pencil") {
                                editName = url.lastPathComponent
                                edit = .rename(url)
                            }
                            Button("复制到…", systemImage: "doc.on.doc") { transfer = .copy([url]) }
                            Button("移动到…", systemImage: "folder") { transfer = .move([url]) }
                            if let mode = documentMode(url) {
                                Button(mode == .pdf ? "PDF 处理" : "图片处理", systemImage: "doc.badge.gearshape") {
                                    documentRequest = DocumentOperationRequest(inputs: [url], mode: mode)
                                }
                                .disabled(archiveRunning)
                            }
                            Button("打包为 ZIP", systemImage: "archivebox") { openArchive(.create([url])) }
                                .disabled(archiveRunning)
                            if !isFolder(url), url.pathExtension.lowercased() == "zip" {
                                Button("解压", systemImage: "archivebox") { openArchive(.extract(url)) }
                                    .disabled(archiveRunning)
                                Button("解压到…", systemImage: "folder") { openArchive(.extract(url), chooseDestination: true) }
                                    .disabled(archiveRunning)
                            } else if !isFolder(url), let category = WorkspaceCategory.forFile(url),
                                      [.archive, .diskImage].contains(category) {
                                Button("解压（当前格式不支持）", systemImage: "archivebox") {
                                    errorMessage = "当前格式不支持解压，仅支持 ZIP。"
                                }
                            }
                            if store.canGroup(url) {
                                Button("归组", systemImage: "square.grid.2x2") { perform(.group, on: [url]) }
                            }
                            ShareLink(item: url) { Label("分享", systemImage: "square.and.arrow.up") }
                            Button("删除", systemImage: "trash", role: .destructive) { toDelete = [url] }
                        }
                    }
            }
        }
        .accessibilityIdentifier("workspace-files")
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("暂无文件", systemImage: "folder",
                                       description: Text("从“文件”App 导入，或新建文件夹"))
            }
        }
        .navigationTitle(folder == store.root ? "文件" : folder.lastPathComponent)
        .navigationBarTitleDisplayMode(folder == store.root ? .large : .inline)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索当前文件夹")
        .toolbar(selecting ? .hidden : .automatic, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(selecting ? "完成" : "编辑") {
                    selecting.toggle()
                    selection.removeAll()
                }
                .accessibilityLabel(selecting ? "完成" : "编辑")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("导入文件", systemImage: "square.and.arrow.down") { importing = true }
                    Button("新建文件夹", systemImage: "folder.badge.plus") {
                        editName = ""
                        edit = .folder
                    }
                } label: { Image(systemName: "plus").accessibilityLabel("新增") }
            }
            if selecting {
                ToolbarItemGroup(placement: .bottomBar) {
                    Text("已选 \(selectedItems.count) 项")
                    Spacer()
                    Menu {
                        Button("全选") { selection.formUnion(visibleItems) }
                        Button("反选") { selection.formSymmetricDifference(visibleItems) }
                        Button("取消选择") { selection.removeAll() }
                    } label: { Label("选择", systemImage: "checkmark.circle") }
                    .accessibilityLabel("选择")
                    Menu {
                        Button("复制到…", systemImage: "doc.on.doc") { transfer = .copy(selectedItems) }
                        Button("移动到…", systemImage: "folder") { transfer = .move(selectedItems) }
                        if selectedItems.count >= 2, selectedItems.allSatisfy({ documentMode($0) == .pdf }) {
                            Button("合并 PDF", systemImage: "doc.on.doc") {
                                documentRequest = DocumentOperationRequest(inputs: selectedItems, mode: .pdf)
                            }
                            .disabled(archiveRunning)
                        }
                        if selectedItems.count >= 2, selectedItems.allSatisfy({ documentMode($0) == .image }) {
                            Button("合成图片", systemImage: "photo.on.rectangle") {
                                documentRequest = DocumentOperationRequest(inputs: selectedItems, mode: .image)
                            }
                            .disabled(archiveRunning)
                        }
                        Button("打包为 ZIP", systemImage: "archivebox") { openArchive(.create(selectedItems)) }
                            .disabled(archiveRunning)
                        Button("归组", systemImage: "square.grid.2x2") { perform(.group, on: selectedItems) }
                            .disabled(selectedItems.isEmpty || !selectedItems.allSatisfy { store.canGroup($0) })
                        Button("分享", systemImage: "square.and.arrow.up") {
                            shareRequest = FileShareRequest(items: selectedItems)
                        }
                        Button("删除", systemImage: "trash", role: .destructive) { toDelete = selectedItems }
                    } label: { Label("操作", systemImage: "ellipsis.circle") }
                    .disabled(selectedItems.isEmpty)
                    .accessibilityLabel("批量操作")
                }
            }
        }
        .onAppear(perform: reload)
        .quickLookPreview($preview)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            do {
                self.result = store.importFiles(try result.get(), into: folder)
                reload()
            } catch { errorMessage = error.localizedDescription }
        }
        .alert(editTitle, isPresented: Binding(get: { edit != nil }, set: { if !$0 { edit = nil } })) {
            TextField("名称", text: $editName)
            Button("保存") { performEdit() }
            Button("取消", role: .cancel) { edit = nil }
        }
        .confirmationDialog("删除所选 \(toDelete.count) 项？", isPresented: Binding(
            get: { !toDelete.isEmpty }, set: { if !$0 { toDelete = [] } }
        )) {
            Button("删除", role: .destructive) {
                perform(.delete, on: toDelete)
                toDelete = []
            }
        }
        .sheet(isPresented: Binding(get: { transfer != nil }, set: { if !$0 { transfer = nil } })) {
            FolderPicker(store: store) { destination in
                if let transfer {
                    switch transfer {
                    case .copy(let urls): perform(.copy(to: destination), on: urls)
                    case .move(let urls): perform(.move(to: destination), on: urls)
                    }
                }
                transfer = nil
            }
        }
        .sheet(item: $shareRequest, onDismiss: finishSharing) { request in
            FileShareSheet(items: request.items) { shareRequest = nil }
        }
        .sheet(item: $archiveRequest) { request in
            ArchiveOperationView(store: store, request: request, onStart: { archiveRunning = true }) {
                archiveRunning = false
                selection.removeAll()
                reload()
            }
            .id(request.id)
        }
        .sheet(item: $documentRequest, onDismiss: reload) { request in
            DocumentOperationView(store: store, request: request) {
                selection.removeAll()
                reload()
            }
            .id(request.id)
        }
        .alert("操作失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert("操作结果", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
            Button("好") { result = nil }
        } message: { Text(result?.message ?? "") }
    }

    @ViewBuilder
    private func itemView(_ url: URL) -> some View {
        if selecting {
            Button {
                if !selection.insert(url).inserted { selection.remove(url) }
            } label: {
                HStack {
                    Image(systemName: selection.contains(url) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(.blue)
                    row(url)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(url.lastPathComponent)
            .accessibilityValue(selection.contains(url) ? "已选择" : "未选择")
        } else if isFolder(url) {
            NavigationLink { FolderView(store: store, folder: url) } label: { row(url) }
        } else {
            Button { preview = url } label: { row(url) }
                .buttonStyle(.plain)
        }
    }

    private func row(_ url: URL) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(url.lastPathComponent).foregroundStyle(.primary)
                if !isFolder(url),
                   let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: isFolder(url) ? "folder.fill" : "doc.fill")
                .foregroundStyle(isFolder(url) ? Color.blue : Color.secondary)
        }
    }

    private func isFolder(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    private func documentMode(_ url: URL) -> DocumentOperationRequest.Mode? {
        guard !isFolder(url) else { return nil }
        if url.pathExtension.lowercased() == "pdf" { return .pdf }
        if WorkspaceCategory.forFile(url) == .picture { return .image }
        return nil
    }

    private var editTitle: String {
        switch edit {
        case .folder: "新建文件夹"
        case .rename: "重命名"
        case nil: ""
        }
    }

    private func performEdit() {
        guard let edit else { return }
        perform {
            switch edit {
            case .folder: _ = try store.createFolder(named: editName, in: folder)
            case .rename(let url): _ = try store.rename(url, to: editName)
            }
        }
        self.edit = nil
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation(); reload() }
        catch { errorMessage = error.localizedDescription }
    }

    private func perform(_ action: FileBatchAction, on urls: [URL]) {
        result = store.perform(action, on: urls)
        selection.removeAll()
        reload()
    }

    private func finishSharing() {
        selection.removeAll()
        reload()
    }

    private func openArchive(_ action: ArchiveRequest.Action, chooseDestination: Bool = false) {
        guard !archiveRunning, archiveRequest == nil else { return }
        archiveRequest = ArchiveRequest(action: action, folder: folder, chooseDestination: chooseDestination)
    }

    private func reload() {
        do {
            items = try store.contents(of: folder)
            selection.formIntersection(items)
        }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct FileShareRequest: Identifiable {
    let id = UUID()
    let items: [URL]
}

private struct FileShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async(execute: onComplete)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private extension FileBatchResult {
    var message: String {
        var lines = ["成功 \(succeeded.count) 项，跳过 \(skipped.count) 项，失败 \(failures.count) 项。"]
        lines += failures.map { "\($0.url.lastPathComponent)：\($0.message)" }
        return lines.joined(separator: "\n")
    }
}

struct FolderPicker: View {
    let store: FileStore
    var selectionTitle = "移到这里 / 复制到这里"
    let onSelect: (URL) -> Void

    var body: some View {
        NavigationStack {
            folderList(store.root)
                .navigationTitle("选择文件夹")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func folderList(_ folder: URL) -> AnyView {
        AnyView(List {
            Button(selectionTitle) { onSelect(folder) }
                .fontWeight(.semibold)
            ForEach((try? store.contents(of: folder))?.filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            } ?? [], id: \.self) { child in
                NavigationLink(child.lastPathComponent) { folderList(child) }
            }
        }
        .accessibilityIdentifier("destination-folders")
        .navigationTitle(folder == store.root ? "文件" : folder.lastPathComponent))
    }
}
