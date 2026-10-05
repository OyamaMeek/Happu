import Foundation
import Darwin

struct MediaWorkspace {
    let root: URL
    private let manager = FileManager.default

    func checkInput(_ input: URL) throws {
        try checkPath(input)
        guard try input.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { throw MediaError("媒体输入必须是普通文件。") }
    }

    func checkOutput(folder: URL, name: String) throws {
        try checkPath(folder)
        guard try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw MediaError("输出目标必须是目录。") }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"), !name.contains("\0"), name == name.trimmingCharacters(in: .whitespacesAndNewlines) else { throw CocoaError(.fileWriteInvalidFileName) }
        var rootStat = stat(), folderStat = stat()
        guard stat(root.path, &rootStat) == 0, stat(folder.path, &folderStat) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard rootStat.st_dev == folderStat.st_dev else { throw MediaError("输出目标必须与工作区处于同一卷。") }
    }

    func withStaging(progress: Progress, operation: (URL) async throws -> URL) async throws -> URL {
        try Self.checkCancellation(progress)
        try checkPath(root)
        let staging = root.appendingPathComponent(".media-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        let result: Result<URL, Error>
        do { result = .success(try await operation(staging)) }
        catch { result = .failure(error) }
        do { try manager.removeItem(at: staging) }
        catch { throw MediaError("媒体暂存清理失败：\(error.localizedDescription)；暂存目录：\(staging.path)") }
        return try result.get()
    }

    func publish(_ output: URL, in folder: URL, named name: String, progress: Progress) throws -> URL {
        try Self.checkCancellation(progress)
        try checkInput(output)
        try checkOutput(folder: folder, name: name)
        let store = try FileStore(root: root)
        let renamed = try store.rename(output, to: name)
        try Self.checkCancellation(progress)
        return try store.move(renamed, to: folder)
    }

    static func checkCancellation(_ progress: Progress) throws {
        try Task.checkCancellation()
        if progress.isCancelled { throw CancellationError() }
    }

    private func checkPath(_ url: URL) throws {
        guard url.isFileURL, root.isFileURL else { throw CocoaError(.fileReadNoPermission) }
        let raw = url.path.split(separator: "/", omittingEmptySubsequences: false)
        guard !raw.contains("."), !raw.contains("..") else { throw MediaError("媒体路径不得包含点路径。") }
        let path = url.standardizedFileURL.path, rootPath = root.standardizedFileURL.path
        guard path == rootPath || path.hasPrefix(rootPath + "/") else { throw CocoaError(.fileReadNoPermission) }
        var ancestor = URL(fileURLWithPath: "/", isDirectory: true)
        for part in url.pathComponents.dropFirst() {
            ancestor.appendPathComponent(part)
            guard try ancestor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw MediaError("媒体路径不得包含符号链接。") }
        }
    }
}

struct MediaError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
