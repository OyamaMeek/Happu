import Foundation

@main
struct ArchiveSmoke {
    static func check(_ condition: Bool, _ message: String = "Archive behavior mismatch") {
        precondition(condition, message)
    }
    static func run(_ executable: String, _ arguments: [String], in folder: URL? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = folder
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        precondition(process.terminationStatus == 0, "Command failed: \(executable)")
        return String(decoding: data, as: UTF8.self)
    }

    static func main() throws {
        let manager = FileManager.default
        let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).standardizedFileURL
        try manager.createDirectory(at: base, withIntermediateDirectories: true)
        let runRoot = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = runRoot.appendingPathComponent("workspace", isDirectory: true)
        let store = try FileStore(root: root)
        let service = ArchiveService(root: store.root)
        let folder = root.appendingPathComponent("文稿", isDirectory: true)
        let source = folder.appendingPathComponent("中文", isDirectory: true)
        try manager.createDirectory(at: source.appendingPathComponent("子目录"), withIntermediateDirectories: true)
        try manager.createDirectory(at: source.appendingPathComponent("空目录"), withIntermediateDirectories: true)
        let bytes = Data("真实内容\nhello ZIP\n".utf8)
        try bytes.write(to: source.appendingPathComponent("子目录/文本.txt"))
        try Data("hidden".utf8).write(to: source.appendingPathComponent(".隐藏"))
        let sentinel = runRoot.appendingPathComponent("sentinel.txt")
        try Data("original".utf8).write(to: sentinel)

        func checkClean() throws {
            check(try manager.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".archive-") }, "Staging leaked")
        }
        func reject(_ action: () throws -> URL, cancellation: Bool = false) throws {
            let before = try manager.contentsOfDirectory(atPath: folder.path).sorted()
            do {
                _ = try action()
                preconditionFailure("Invalid operation published a result")
            } catch {
                if cancellation { precondition(error is CancellationError, "Cancellation must throw CancellationError") }
            }
            check(try manager.contentsOfDirectory(atPath: folder.path).sorted() == before, "Failed operation changed destination")
            try checkClean()
        }

        let creation = Progress(totalUnitCount: 0)
        let zip = try service.create(items: [source], in: folder, named: "归档", progress: creation)
        precondition(zip.lastPathComponent == "归档.zip")
        precondition(creation.totalUnitCount > 0 && creation.completedUnitCount == creation.totalUnitCount)
        let listed = try run("/usr/bin/unzip", ["-Z1", zip.path])
        precondition(listed.split(separator: "\n").count == 5 && listed.contains(".txt"), "System unzip must list all entries")
        let extraction = Progress(totalUnitCount: 0)
        let restored = try service.extract(zip, in: folder, password: nil, progress: extraction)
        check(try Data(contentsOf: restored.appendingPathComponent("中文/子目录/文本.txt")) == bytes)
        precondition(manager.fileExists(atPath: restored.appendingPathComponent("中文/空目录").path))
        check(try Data(contentsOf: restored.appendingPathComponent("中文/.隐藏")) == Data("hidden".utf8))
        precondition(extraction.totalUnitCount > 0 && extraction.completedUnitCount == extraction.totalUnitCount)
        let originalZip = try Data(contentsOf: zip)
        let numbered = try service.create(items: [source], in: folder, named: "归档.zip", progress: Progress())
        precondition(numbered.lastPathComponent == "归档 2.zip")
        check(try Data(contentsOf: zip) == originalZip)
        let another = try service.extract(zip, in: folder, password: nil, progress: Progress())
        precondition(another.lastPathComponent == "归档 2")
        check(try Data(contentsOf: restored.appendingPathComponent("中文/子目录/文本.txt")) == bytes)

        let fixtures = folder.appendingPathComponent("fixtures", isDirectory: true)
        _ = try run("/usr/bin/python3", ["Tests/make_archive_fixtures.py", fixtures.path, zip.path])
        let independent = try service.extract(fixtures.appendingPathComponent("ordinary.zip"), in: folder, password: nil, progress: Progress())
        check(try Data(contentsOf: independent.appendingPathComponent("independent.txt")) == Data("independent bytes".utf8))
        func macOSXRoundtrip(empty: Bool) throws {
            let directory = folder.appendingPathComponent("__MACOSX", isDirectory: true)
            try manager.createDirectory(at: directory.appendingPathComponent("empty"), withIntermediateDirectories: true)
            if !empty { try Data("ordinary bytes".utf8).write(to: directory.appendingPathComponent("file.txt")) }
            let result = try service.create(items: [directory], in: folder, named: empty ? "macEmpty" : "macContent", progress: Progress())
            let restored = try service.extract(result, in: folder, password: nil, progress: Progress())
            precondition(manager.fileExists(atPath: restored.appendingPathComponent("__MACOSX/empty").path), "Ordinary __MACOSX empty directory was dropped")
            if !empty { check(try Data(contentsOf: restored.appendingPathComponent("__MACOSX/file.txt")) == Data("ordinary bytes".utf8)) }
            try manager.removeItem(at: directory)
        }
        if CommandLine.arguments.contains("macosx") { try macOSXRoundtrip(empty: false) }
        if CommandLine.arguments.contains("macosx-empty") { try macOSXRoundtrip(empty: true) }
        for fixture in ["duplicate.zip", "normalized-collision.zip", "file-directory-conflict.zip", "directory-file-conflict.zip"] {
            try reject { try service.extract(fixtures.appendingPathComponent(fixture), in: folder, password: nil, progress: Progress()) }
        }
        try macOSXRoundtrip(empty: false)
        try macOSXRoundtrip(empty: true)
        let independentMac = try service.extract(fixtures.appendingPathComponent("macosx.zip"), in: folder, password: nil, progress: Progress())
        check(try Data(contentsOf: independentMac.appendingPathComponent("__MACOSX/file.txt")) == Data("ordinary bytes".utf8))
        precondition(manager.fileExists(atPath: independentMac.appendingPathComponent("__MACOSX/empty").path))
        _ = try run("/usr/bin/zip", ["-q", "-P", "secret", fixtures.appendingPathComponent("password.zip").path, "子目录/文本.txt"], in: source)
        try reject { try service.extract(fixtures.appendingPathComponent("password.zip"), in: folder, password: "wrong", progress: Progress()) }
        let passwordResult = try service.extract(fixtures.appendingPathComponent("password.zip"), in: folder, password: "secret", progress: Progress())
        check(try Data(contentsOf: passwordResult.appendingPathComponent("子目录/文本.txt")) == bytes)
        try Data("broken ZIP".utf8).write(to: fixtures.appendingPathComponent("broken.zip"))
        try reject { try service.extract(fixtures.appendingPathComponent("broken.zip"), in: folder, password: nil, progress: Progress()) }
        try reject { try service.extract(fixtures.appendingPathComponent("crc-corrupt.zip"), in: folder, password: nil, progress: Progress()) }

        for fixture in ["traversal.zip", "outside-traversal.zip", "absolute.zip", "symlink.zip"] {
            precondition(root.appendingPathComponent(".archive-placeholder/output/../../../sentinel.txt").standardizedFileURL == sentinel)
            try reject { try service.extract(fixtures.appendingPathComponent(fixture), in: folder, password: nil, progress: Progress()) }
            precondition(!manager.fileExists(atPath: root.appendingPathComponent("escaped.txt").path))
            precondition(!manager.fileExists(atPath: folder.appendingPathComponent("absolute-escaped.txt").path))
            check(try Data(contentsOf: sentinel) == Data("original".utf8))
            try checkClean()
        }
        precondition(!manager.fileExists(atPath: folder.appendingPathComponent("symlink").path), "Symlink archive published")
        let nestedDestination = source.appendingPathComponent("子目录")
        let nestedZip = try service.create(items: [source], in: nestedDestination, named: "内部", progress: Progress())
        let nestedListing = try run("/usr/bin/unzip", ["-Z1", nestedZip.path])
        precondition(!nestedListing.contains(".archive-") && !nestedListing.contains("内部.zip"))
        let nestedRestored = try service.extract(nestedZip, in: folder, password: nil, progress: Progress())
        check(try Data(contentsOf: nestedRestored.appendingPathComponent("中文/子目录/文本.txt")) == bytes)
        let link = folder.appendingPathComponent("link")
        try manager.createSymbolicLink(at: link, withDestinationURL: sentinel)
        try reject { try service.create(items: [link], in: folder, named: "link", progress: Progress()) }
        try manager.removeItem(at: link)
        try manager.createSymbolicLink(at: source.appendingPathComponent("link"), withDestinationURL: sentinel)
        try reject { try service.create(items: [source], in: folder, named: "link", progress: Progress()) }
        try manager.removeItem(at: source.appendingPathComponent("link"))
        try reject { try service.create(items: [root], in: folder, named: "root", progress: Progress()) }
        try reject { try service.create(items: [sentinel], in: folder, named: "outside", progress: Progress()) }
        try reject { try service.create(items: [source, source], in: folder, named: "duplicate", progress: Progress()) }
        try reject { try service.create(items: [source, source.appendingPathComponent("子目录/文本.txt")], in: folder, named: "overlap", progress: Progress()) }
        let otherSource = fixtures.appendingPathComponent("中文")
        try manager.createDirectory(at: otherSource, withIntermediateDirectories: false)
        try reject { try service.create(items: [source, otherSource], in: folder, named: "duplicateName", progress: Progress()) }
        try reject { try service.create(items: [], in: folder, named: "empty", progress: Progress()) }
        for name in ["", "..", "../bad", "bad\0name"] {
            try reject { try service.create(items: [source], in: folder, named: name, progress: Progress()) }
        }
        for target in [runRoot, folder.appendingPathComponent("missing"), zip] {
            try reject { try service.create(items: [source], in: target, named: "badTarget", progress: Progress()) }
            try reject { try service.extract(zip, in: target, password: nil, progress: Progress()) }
        }
        for extracting in [false, true] {
            let cancelled = Progress()
            cancelled.cancel()
            try reject({
                try extracting ? service.extract(zip, in: folder, password: nil, progress: cancelled) : service.create(items: [source], in: folder, named: "cancel", progress: cancelled)
            }, cancellation: true)
            let during = Progress()
            let observation = during.observe(\.completedUnitCount) { progress, _ in
                if progress.completedUnitCount >= 1 { progress.cancel() }
            }
            try reject({
                try extracting ? service.extract(zip, in: folder, password: nil, progress: during) : service.create(items: [source], in: folder, named: "cancel", progress: during)
            }, cancellation: true)
            withExtendedLifetime(observation) {}
            precondition(during.completedUnitCount >= 1, "Mid-operation cancellation never started")
            let last = Progress()
            let lastObservation = last.observe(\.completedUnitCount) { progress, _ in
                if progress.totalUnitCount > 0 && progress.completedUnitCount == progress.totalUnitCount { progress.cancel() }
            }
            try reject({
                try extracting ? service.extract(zip, in: folder, password: nil, progress: last) : service.create(items: [source], in: folder, named: "lastCancel", progress: last)
            }, cancellation: true)
            withExtendedLifetime(lastObservation) {}
            precondition(last.completedUnitCount == last.totalUnitCount, "Last-entry cancellation never reached final entry")
        }
        try checkClean()
        print("ArchiveSmoke passed: roundtrip, interoperability, password, collisions, __MACOSX, CRC, boundaries, malicious paths, cancellation, cleanup")
    }
}
