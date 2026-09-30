import Foundation
import ZipArchive
#if SWIFT_PACKAGE
import ArchiveBridge
#endif

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
                let restoredValues = try restored.resourceValues(forKeys: [.isDirectoryKey])
                guard entry.directory ? restoredValues.isDirectory == true : manager.contentsEqual(atPath: entry.url.path, andPath: restored.path) else {
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
        guard let reader = archive.withUnsafeFileSystemRepresentation({ unzOpen($0) }) else {
            throw ArchiveError("无法打开 ZIP 归档。")
        }
        do { try readEntries(reader, to: output, password: password, progress: progress, updateProgress: updateProgress) }
        catch {
            guard unzClose(reader) == 0 else { throw ArchiveError("关闭 ZIP 归档失败。") }
            throw error
        }
        guard unzClose(reader) == 0 else { throw ArchiveError("关闭 ZIP 归档失败。") }
        try checkCancellation(progress)
    }

    private func readEntries(_ reader: UnsafeMutableRawPointer, to output: URL, password: String?, progress: Progress, updateProgress: Bool) throws {
        var global = unz_global_info64()
        guard unzGetGlobalInfo64(reader, &global) == 0, global.number_entry <= UInt64(Int64.max) else {
            throw ArchiveError("无法读取 ZIP 条目数量。")
        }
        if updateProgress { progress.totalUnitCount = Int64(global.number_entry) }
        var status = unzGoToFirstFile(reader)
        var processed: UInt64 = 0
        var destinations = Set<String>()
        while status == 0 {
            try checkCancellation(progress)
            var info = unz_file_info64()
            guard unzGetCurrentFileInfo64(reader, &info, nil, 0, nil, 0, nil, 0) == 0 else { throw ArchiveError("无法读取 ZIP 条目信息。") }
            var filename = [CChar](repeating: 0, count: Int(info.size_filename) + 1)
            guard unzGetCurrentFileInfo64(reader, &info, &filename, UInt(filename.count), nil, 0, nil, 0) == 0 else { throw ArchiveError("无法读取 ZIP 条目名称。") }
            let data = Data(filename.dropLast().map { UInt8(bitPattern: $0) })
            let legacy = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosLatinUS.rawValue)))
            let utf8 = String(data: data, encoding: .utf8)
            let decoded = info.flag & (1 << 11) != 0 ? utf8 : ((info.version >> 8) == 0 ? String(data: data, encoding: legacy) : utf8 ?? String(data: data, encoding: legacy))
            guard !data.contains(0), let name = decoded else {
                throw ArchiveError("ZIP 条目名称编码无效。")
            }
            let components = name.split(separator: "/", omittingEmptySubsequences: false)
            guard !name.isEmpty, !name.hasPrefix("/"), !components.contains(".."), !components.contains(".") else {
                throw ArchiveError("ZIP 包含不安全的条目路径。")
            }
            let target = output.appendingPathComponent(name).standardizedFileURL
            guard target.path.hasPrefix(output.path + "/"), destinations.insert(target.path).inserted else {
                throw ArchiveError("ZIP 条目路径重复或越界。")
            }
            let kind = (info.external_fa >> 16) & 0o170000
            guard kind == 0 || kind == 0o100000 || kind == 0o040000 else { throw ArchiveError("ZIP 包含符号链接或特殊文件。") }
            let directory = name.hasSuffix("/") || kind == 0o040000
            if directory {
                try manager.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                guard !manager.fileExists(atPath: target.path), manager.createFile(atPath: target.path, contents: nil) else {
                    throw ArchiveError("ZIP 条目与已有文件或目录冲突。")
                }
            }
            let opened = password.map { value in value.withCString { unzOpenCurrentFilePassword(reader, $0) } } ?? unzOpenCurrentFilePassword(reader, nil)
            guard opened == 0 else { throw ArchiveError("无法读取 ZIP 条目，请检查密码。") }
            do { try readEntry(reader, to: directory ? nil : target, expectedSize: info.uncompressed_size) }
            catch {
                _ = unzCloseCurrentFile(reader)
                throw error
            }
            guard unzCloseCurrentFile(reader) == 0 else { throw ArchiveError("ZIP 条目 CRC 或关闭校验失败。") }
            processed += 1
            if updateProgress { progress.completedUnitCount = Int64(processed) }
            status = unzGoToNextFile(reader)
        }
        guard status == -100, processed == global.number_entry else { throw ArchiveError("ZIP 条目读取不完整。") }
    }

    private func readEntry(_ reader: UnsafeMutableRawPointer, to target: URL?, expectedSize: UInt64) throws {
        let file = try target.map { try FileHandle(forWritingTo: $0) }
        do {
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            var size: UInt64 = 0
            while true {
                let count = buffer.withUnsafeMutableBytes { unzReadCurrentFile(reader, $0.baseAddress, UInt32($0.count)) }
                guard count >= 0 else { throw ArchiveError("ZIP 条目数据损坏或密码错误。") }
                if count == 0 { break }
                size += UInt64(count)
                guard size <= expectedSize else { throw ArchiveError("ZIP 条目大小与声明不符。") }
                try file?.write(contentsOf: Data(buffer.prefix(Int(count))))
            }
            guard size == expectedSize, target != nil || size == 0 else { throw ArchiveError("ZIP 条目内容不完整。") }
        } catch {
            try file?.close()
            throw error
        }
        try file?.close()
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
