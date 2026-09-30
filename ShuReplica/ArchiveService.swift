import Foundation
import ZipArchive

struct ArchiveService {
    let root: URL
    private let manager = FileManager.default

    func create(items: [URL], in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkCancellation(progress)
        try checkFolder(folder)
        let value = try validName(name)
        let outputName = value.lowercased().hasSuffix(".zip") ? value : value + ".zip"
        guard !items.isEmpty else { throw ArchiveError("请选择需要打包的文件。") }
        var paths: [URL] = []
        var names = Set<String>()
        for item in items {
            try checkItem(item)
            guard names.insert(item.lastPathComponent).inserted else { throw ArchiveError("所选文件的顶层名称重复。") }
            let path = item.resolvingSymlinksInPath()
            guard !paths.contains(where: { path.path == $0.path || path.path.hasPrefix($0.path + "/") || $0.path.hasPrefix(path.path + "/") }) else {
                throw ArchiveError("所选文件重复或包含父子目录。")
            }
            paths.append(path)
        }
        var entries: [(url: URL, name: String, directory: Bool)] = []
        func collect(_ item: URL, name: String) throws {
            try checkCancellation(progress)
            guard !item.pathComponents.contains(where: { $0.hasPrefix(".archive-") }) else { throw ArchiveError("不能打包暂存目录。") }
            let values = try checkItem(item)
            entries.append((item, name, values.isDirectory == true))
            if values.isDirectory == true {
                for child in try manager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    try collect(child, name: name + "/" + child.lastPathComponent)
                }
            }
        }
        for item in items { try collect(item, name: item.lastPathComponent) }
        progress.totalUnitCount = Int64(entries.count)
        progress.completedUnitCount = 0
        return try withStaging { staging in
            let output = staging.appendingPathComponent("output.zip")
            let archive = SSZipArchive(path: output.path)
            guard archive.open() else { throw ArchiveError("无法创建 ZIP 归档。") }
            do {
                for entry in entries {
                    try checkCancellation(progress)
                    try checkItem(entry.url)
                    let written = entry.directory
                        ? archive.writeFolder(atPath: entry.url.path, withFolderName: entry.name, withPassword: nil)
                        : archive.writeFile(atPath: entry.url.path, withFileName: entry.name, withPassword: nil)
                    guard written else { throw ArchiveError("无法写入归档条目：\(entry.name)") }
                    progress.completedUnitCount += 1
                }
            } catch {
                let closed = archive.close()
                if !closed { throw ArchiveError("关闭 ZIP 归档失败。") }
                throw error
            }
            guard archive.close() else { throw ArchiveError("关闭 ZIP 归档失败。") }
            try checkCancellation(progress)
            // SSZipArchive 写入函数未检查每次底层写入的结果，发布前解压核对实际内容。
            let verification = staging.appendingPathComponent("verification", isDirectory: true)
            try manager.createDirectory(at: verification, withIntermediateDirectories: false)
            try unzip(output, to: verification, password: nil, progress: progress, updateProgress: false)
            for entry in entries {
                try checkCancellation(progress)
                let restored = verification.appendingPathComponent(entry.name)
                guard entry.directory || manager.contentsEqual(atPath: entry.url.path, andPath: restored.path) else {
                    throw ArchiveError("归档内容核对失败：\(entry.name)")
                }
            }
            try manager.removeItem(at: verification)
            return try publish(output, in: folder, named: outputName, progress: progress)
        }
    }

    func extract(_ archive: URL, in folder: URL, password: String?, progress: Progress) throws -> URL {
        try checkCancellation(progress)
        try checkFolder(folder)
        let values = try checkItem(archive)
        guard values.isRegularFile == true, archive.pathExtension.lowercased() == "zip" else { throw ArchiveError("请选择 ZIP 文件。") }
        let name = try validName(archive.deletingPathExtension().lastPathComponent)
        progress.completedUnitCount = 0
        progress.totalUnitCount = 0
        return try withStaging { staging in
            let output = staging.appendingPathComponent("output", isDirectory: true)
            try manager.createDirectory(at: output, withIntermediateDirectories: false)
            try unzip(archive, to: output, password: password, progress: progress, updateProgress: true)
            return try publish(output, in: folder, named: name, progress: progress)
        }
    }

    private func unzip(_ archive: URL, to output: URL, password: String?, progress: Progress, updateProgress: Bool) throws {
        let delegate = ArchiveExtractionDelegate(progress: progress)
        var libraryError: NSError?
        let succeeded = SSZipArchive.unzipFile(atPath: archive.path, toDestination: output.path, preserveAttributes: false, overwrite: false, nestedZipLevel: 0, password: password, error: &libraryError, delegate: delegate, progressHandler: { entry, info, index, total in
            do {
                let target = output.appendingPathComponent(entry)
                let values = try target.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey])
                guard values.isSymbolicLink != true,
                      target.resolvingSymlinksInPath().path.hasPrefix(output.path + "/"),
                      values.isDirectory == true || (values.isRegularFile == true && values.fileSize.map { $0 >= 0 && UInt64($0) == UInt64(info.uncompressed_size) } == true) else {
                    throw ArchiveError("解压条目写入不完整或包含不安全路径：\(entry)")
                }
            } catch { delegate.failure = error }
            if updateProgress {
                progress.totalUnitCount = Int64(total)
                progress.completedUnitCount = Int64(index + 1)
            }
        }, completionHandler: nil)
        try checkCancellation(progress)
        if let failure = delegate.failure { throw failure }
        guard succeeded else { throw ArchiveError("解压失败，请检查密码及归档完整性。\(libraryError.map { " " + $0.localizedDescription } ?? "")") }
        guard let enumerator = manager.enumerator(at: output, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [], errorHandler: { _, error in delegate.failure = error; return false }) else {
            throw ArchiveError("无法验证解压目录。")
        }
        for case let item as URL in enumerator {
            try checkCancellation(progress)
            try checkItem(item)
        }
        if let failure = delegate.failure { throw failure }
    }

    private func checkFolder(_ folder: URL) throws {
        try checkInside(folder)
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw ArchiveError("目的位置必须是已有文件夹。") }
    }

    @discardableResult
    private func checkItem(_ item: URL) throws -> URLResourceValues {
        try checkInside(item)
        guard item.resolvingSymlinksInPath().path != root.resolvingSymlinksInPath().path else { throw ArchiveError("不能打包工作区根目录。") }
        let values = try item.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey])
        guard values.isSymbolicLink != true, values.isDirectory == true || values.isRegularFile == true else { throw ArchiveError("不支持符号链接或特殊文件。") }
        var ancestor = item.standardizedFileURL.deletingLastPathComponent()
        let rootPath = root.resolvingSymlinksInPath().path
        while ancestor.path.hasPrefix(rootPath + "/") {
            guard try ancestor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ArchiveError("不支持通过符号链接访问输入文件。") }
            ancestor.deleteLastPathComponent()
        }
        return values
    }

    private func checkInside(_ url: URL) throws {
        let rootPath = root.resolvingSymlinksInPath().path
        let path = url.resolvingSymlinksInPath().path
        guard url.isFileURL, path == rootPath || path.hasPrefix(rootPath + "/") else { throw ArchiveError("文件必须位于工作区内。") }
    }

    private func validName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != ".", value != "..", !value.contains("/"), !value.contains("\0") else { throw ArchiveError("文件名称无效。") }
        return value
    }

    private func stagingDirectory() throws -> URL {
        let staging = root.resolvingSymlinksInPath().appendingPathComponent(".archive-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        return staging
    }

    private func withStaging(_ operation: (URL) throws -> URL) throws -> URL {
        let staging = try stagingDirectory()
        let result: URL
        do { result = try operation(staging) }
        catch {
            do { try manager.removeItem(at: staging) }
            catch { throw ArchiveError("ZIP 暂存清理失败：\(error.localizedDescription)") }
            throw error
        }
        do { try manager.removeItem(at: staging) }
        catch {
            let cleanupError = error
            do { try manager.removeItem(at: result) }
            catch { throw ArchiveError("ZIP 暂存清理及结果撤回失败：\(error.localizedDescription)") }
            throw ArchiveError("ZIP 暂存清理失败：\(cleanupError.localizedDescription)")
        }
        return result
    }

    private func publish(_ output: URL, in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkFolder(folder)
        try checkCancellation(progress)
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        var index = 1
        while true {
            let numbered = index == 1 ? name : (ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)")
            let destination = folder.appendingPathComponent(numbered)
            if (try? manager.attributesOfItem(atPath: destination.path)) == nil {
                try checkCancellation(progress)
                try manager.moveItem(at: output, to: destination)
                return destination
            }
            index += 1
        }
    }

    private func checkCancellation(_ progress: Progress) throws {
        if progress.isCancelled { throw CancellationError() }
    }
}

private struct ArchiveError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

private final class ArchiveExtractionDelegate: NSObject, SSZipArchiveDelegate {
    let progress: Progress
    var failure: Error?

    init(progress: Progress) { self.progress = progress }

    func zipArchiveShouldUnzipFile(at fileIndex: Int, totalFiles: Int, archivePath: String, fileInfo: unz_file_info) -> Bool {
        if (fileInfo.version >> 8) == 3 && ((fileInfo.external_fa >> 16) & 0o170000) == 0o120000 {
            failure = ArchiveError("归档包含符号链接，无法解压。")
        }
        return !progress.isCancelled && failure == nil
    }
}
