import Foundation

enum FileBatchAction {
    case copy(to: URL)
    case move(to: URL)
    case delete
    case group
}

struct FileBatchResult {
    let succeeded: [URL]
    let skipped: [URL]
    let failures: [(url: URL, message: String)]
}

struct FileStore {
    let root: URL
    private let manager = FileManager.default

    init(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        self.root = root.resolvingSymlinksInPath()
        for name in WorkspaceCategory.allCases.map(\.rawValue) + ["Downloads", "共享"] {
            try FileManager.default.createDirectory(
                at: self.root.appendingPathComponent(name, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    func contents(of folder: URL) throws -> [URL] {
        try checkInside(folder)
        return try manager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).sorted {
            let leftFolder = (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let rightFolder = (try? $1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return leftFolder == rightFolder
                ? $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                : leftFolder
        }
    }

    func createFolder(named name: String, in folder: URL) throws -> URL {
        try checkInside(folder)
        let destination = folder.appendingPathComponent(try validName(name), isDirectory: true)
        try manager.createDirectory(at: destination, withIntermediateDirectories: false)
        return destination
    }

    func importFile(_ source: URL, into folder: URL, named name: String? = nil) throws -> URL {
        try checkInside(folder)
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        let destination = uniqueDestination(for: try validName(name ?? source.lastPathComponent), in: folder)
        try manager.copyItem(at: source, to: destination)
        return destination
    }

    func rename(_ item: URL, to name: String) throws -> URL {
        try checkItem(item)
        let destination = item.deletingLastPathComponent().appendingPathComponent(try validName(name))
        if destination == item { return item }
        guard !manager.fileExists(atPath: destination.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        try manager.moveItem(at: item, to: destination)
        return destination
    }

    func copy(_ item: URL, to folder: URL) throws -> URL {
        try checkItem(item)
        try checkInside(folder)
        try checkNotDescendant(folder, of: item)
        let destination = uniqueDestination(for: item.lastPathComponent, in: folder)
        try manager.copyItem(at: item, to: destination)
        return destination
    }

    func move(_ item: URL, to folder: URL) throws -> URL {
        try checkItem(item)
        try checkInside(folder)
        if folder.resolvingSymlinksInPath() == item.deletingLastPathComponent().resolvingSymlinksInPath() {
            return item
        }
        try checkNotDescendant(folder, of: item)
        let destination = uniqueDestination(for: item.lastPathComponent, in: folder)
        try manager.moveItem(at: item, to: destination)
        return destination
    }

    func delete(_ item: URL) throws {
        try checkItem(item)
        try manager.removeItem(at: item)
    }

    func perform(_ action: FileBatchAction, on items: [URL]) -> FileBatchResult {
        var succeeded: [URL] = []
        var skipped: [URL] = []
        var failures: [(url: URL, message: String)] = []

        for item in items {
            do {
                switch action {
                case .copy(let folder):
                    succeeded.append(try copy(item, to: folder))
                case .move(let folder):
                    succeeded.append(try move(item, to: folder))
                case .delete:
                    try delete(item)
                    succeeded.append(item)
                case .group:
                    try checkItem(item)
                    let parent = item.deletingLastPathComponent().resolvingSymlinksInPath().path
                    let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard parent == root.path, values.isRegularFile == true, values.isSymbolicLink != true,
                          let category = WorkspaceCategory.forFile(item) else {
                        skipped.append(item)
                        continue
                    }
                    succeeded.append(try move(item, to: root.appendingPathComponent(category.rawValue, isDirectory: true)))
                }
            } catch {
                failures.append((url: item, message: error.localizedDescription))
            }
        }

        return FileBatchResult(succeeded: succeeded, skipped: skipped, failures: failures)
    }

    private func validName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != ".", value != "..", !value.contains("/"), !value.contains("\0") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        return value
    }

    private func checkInside(_ url: URL) throws {
        let path = url.resolvingSymlinksInPath().path
        guard path == root.path || path.hasPrefix(root.path + "/") else {
            throw CocoaError(.fileReadNoPermission)
        }
    }

    private func checkItem(_ url: URL) throws {
        try checkInside(url)
        guard url.resolvingSymlinksInPath().path != root.path else {
            throw CocoaError(.fileWriteNoPermission)
        }
    }

    private func checkNotDescendant(_ folder: URL, of item: URL) throws {
        let path = folder.resolvingSymlinksInPath().path
        let source = item.resolvingSymlinksInPath().path
        guard path != source, !path.hasPrefix(source + "/") else {
            throw CocoaError(.fileWriteNoPermission)
        }
    }

    private func uniqueDestination(for name: String, in folder: URL) -> URL {
        let proposed = folder.appendingPathComponent(name)
        guard manager.fileExists(atPath: proposed.path) else { return proposed }
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        var index = 2
        while true {
            let numbered = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            let candidate = folder.appendingPathComponent(numbered)
            if !manager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}
