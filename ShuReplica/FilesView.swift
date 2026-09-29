import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct FilesHomeView: View {
    let store: FileStore
    @State private var errorMessage: String?

    private struct Shortcut: Identifiable {
        let name: String
        let symbol: String
        var id: String { name }
    }

    private let categories = [
        Shortcut(name: "文稿", symbol: "doc.text"),
        Shortcut(name: "图片", symbol: "photo"),
        Shortcut(name: "视频", symbol: "film"),
        Shortcut(name: "音频", symbol: "waveform"),
        Shortcut(name: "电子书", symbol: "books.vertical"),
        Shortcut(name: "压缩文档", symbol: "archivebox"),
        Shortcut(name: "镜像文件", symbol: "opticaldisc"),
        Shortcut(name: "脚本配置", symbol: "chevron.left.forwardslash.chevron.right"),
        Shortcut(name: "工具配置", symbol: "wrench.and.screwdriver")
    ]

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
                ForEach(categories) { category in
                    NavigationLink {
                        FolderView(store: store, folder: store.root.appendingPathComponent(category.name))
                    } label: { Label(category.name, systemImage: category.symbol) }
                }
            }
        }
        .navigationTitle("文件")
        .onAppear {
            do {
                for name in categories.map(\.name) + ["共享"] {
                    try FileManager.default.createDirectory(
                        at: store.root.appendingPathComponent(name), withIntermediateDirectories: true
                    )
                }
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("无法创建工作区", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
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
    @State private var toDelete: URL?
    @State private var transfer: Transfer?
    @State private var errorMessage: String?

    private enum Edit { case folder, rename(URL) }
    private enum Transfer { case copy(URL), move(URL) }

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
                        Button("重命名", systemImage: "pencil") {
                            editName = url.lastPathComponent
                            edit = .rename(url)
                        }
                        Button("复制到…", systemImage: "doc.on.doc") { transfer = .copy(url) }
                        Button("移动到…", systemImage: "folder") { transfer = .move(url) }
                        ShareLink(item: url) { Label("分享", systemImage: "square.and.arrow.up") }
                        Button("删除", systemImage: "trash", role: .destructive) { toDelete = url }
                    }
            }
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("暂无文件", systemImage: "folder",
                                       description: Text("从“文件”App 导入，或新建文件夹"))
            }
        }
        .navigationTitle(folder == store.root ? "文件" : folder.lastPathComponent)
        .navigationBarTitleDisplayMode(folder == store.root ? .large : .inline)
        .searchable(text: $search, prompt: "搜索当前文件夹")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("导入文件", systemImage: "square.and.arrow.down") { importing = true }
                    Button("新建文件夹", systemImage: "folder.badge.plus") {
                        editName = ""
                        edit = .folder
                    }
                } label: { Image(systemName: "plus") }
            }
        }
        .onAppear(perform: reload)
        .quickLookPreview($preview)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            do {
                for url in try result.get() { _ = try store.importFile(url, into: folder) }
                reload()
            } catch { errorMessage = error.localizedDescription }
        }
        .alert(editTitle, isPresented: Binding(get: { edit != nil }, set: { if !$0 { edit = nil } })) {
            TextField("名称", text: $editName)
            Button("保存") { performEdit() }
            Button("取消", role: .cancel) { edit = nil }
        }
        .confirmationDialog("删除“\(toDelete?.lastPathComponent ?? "")”？", isPresented: Binding(
            get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let url = toDelete { perform { try store.delete(url) } }
                toDelete = nil
            }
        }
        .sheet(isPresented: Binding(get: { transfer != nil }, set: { if !$0 { transfer = nil } })) {
            FolderPicker(store: store) { destination in
                if let transfer {
                    perform {
                        switch transfer {
                        case .copy(let url): _ = try store.copy(url, to: destination)
                        case .move(let url): _ = try store.move(url, to: destination)
                        }
                    }
                }
                transfer = nil
            }
        }
        .alert("操作失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder
    private func itemView(_ url: URL) -> some View {
        if isFolder(url) {
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

    private func reload() {
        do { items = try store.contents(of: folder) }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct FolderPicker: View {
    let store: FileStore
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
            Button("移到这里 / 复制到这里") { onSelect(folder) }
                .fontWeight(.semibold)
            ForEach((try? store.contents(of: folder))?.filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            } ?? [], id: \.self) { child in
                NavigationLink(child.lastPathComponent) { folderList(child) }
            }
        }
        .navigationTitle(folder == store.root ? "文件" : folder.lastPathComponent))
    }
}
