import Foundation

@main
struct FileBatchSmoke {
    static func main() throws {
        let manager = FileManager.default
        let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        if manager.fileExists(atPath: base.path) {
            try manager.removeItem(at: base)
        }
        try manager.createDirectory(at: base, withIntermediateDirectories: true)

        let root = base.appendingPathComponent("documents", isDirectory: true)
        let store = try FileStore(root: root)
        let photo = root.appendingPathComponent("photo.PNG")
        let book = root.appendingPathComponent("book.EPUB")
        let unknown = root.appendingPathComponent("unknown")
        let shared = root.appendingPathComponent("共享/shared.PNG")
        let outside = base.appendingPathComponent("outside.PNG")
        let outsideLink = root.appendingPathComponent("outside-link.PNG")
        let existing = root.appendingPathComponent("图片/photo.PNG")
        try Data("new photo".utf8).write(to: photo)
        try Data("book".utf8).write(to: book)
        try Data("unknown".utf8).write(to: unknown)
        try Data("shared".utf8).write(to: shared)
        try Data("outside".utf8).write(to: outside)
        try Data("existing photo".utf8).write(to: existing)
        try manager.createSymbolicLink(at: outsideLink, withDestinationURL: outside)

        let grouped = store.perform(.group, on: [photo, book, unknown, outsideLink, shared])
        assert(grouped.succeeded.count == 2)
        assert(grouped.skipped.count == 2)
        assert(grouped.failures.count == 1)
        assert(grouped.skipped == [unknown, shared])
        assert(grouped.failures[0].url == outsideLink)
        assert(grouped.succeeded[0].lastPathComponent == "photo 2.PNG")
        assert(grouped.succeeded[1].path == root.appendingPathComponent("电子书/book.EPUB").path)
        try assertBytes("new photo", at: grouped.succeeded[0])
        try assertBytes("book", at: grouped.succeeded[1])
        try assertBytes("existing photo", at: existing)
        try assertBytes("unknown", at: unknown)
        try assertBytes("shared", at: shared)
        try assertBytes("outside", at: outside)
        assert(manager.fileExists(atPath: outsideLink.path))

        let missing = root.appendingPathComponent("missing.txt")
        let copied = store.perform(.copy(to: root.appendingPathComponent("文稿")), on: [unknown, missing])
        assert(copied.succeeded.count == 1)
        assert(copied.skipped.isEmpty)
        assert(copied.failures.count == 1 && copied.failures[0].url == missing)
        try assertBytes("unknown", at: copied.succeeded[0])
        try assertBytes("unknown", at: unknown)

        let folder = try store.createFolder(named: "parent", in: root)
        let child = try store.createFolder(named: "child", in: folder)
        let nested = folder.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: nested)
        let invalidMove = store.perform(.move(to: child), on: [folder])
        assert(invalidMove.succeeded.isEmpty && invalidMove.skipped.isEmpty)
        assert(invalidMove.failures.count == 1 && invalidMove.failures[0].url == folder)
        try assertBytes("keep", at: nested)
        assert(manager.fileExists(atPath: child.path))

        let keep = root.appendingPathComponent("keep.txt")
        let remove = root.appendingPathComponent("remove.txt")
        try Data("keep".utf8).write(to: keep)
        try Data("remove".utf8).write(to: remove)
        let deleted = store.perform(.delete, on: [remove])
        assert(deleted.succeeded == [remove])
        assert(deleted.skipped.isEmpty && deleted.failures.isEmpty)
        assert(!manager.fileExists(atPath: remove.path))
        try assertBytes("keep", at: keep)

        print("FileBatch smoke passed")
    }

    private static func assertBytes(_ expected: String, at url: URL) throws {
        let bytes = try Data(contentsOf: url)
        assert(bytes == Data(expected.utf8))
    }
}
