import Foundation

@main
struct FileStoreSmoke {
    static func main() throws {
        let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let root = base.appendingPathComponent("documents", isDirectory: true)
        let source = base.appendingPathComponent("source.txt")
        if FileManager.default.fileExists(atPath: base.path) {
            try FileManager.default.removeItem(at: base)
        }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try "hello".write(to: source, atomically: true, encoding: .utf8)

        let store = try FileStore(root: root)
        let initialDirectoryCount = try store.contents(of: root).count
        assert(initialDirectoryCount == 11)
        let folder = try store.createFolder(named: "Notes", in: root)
        let imported = try store.importFile(source, into: folder)
        let contents = try String(contentsOf: imported, encoding: .utf8)
        assert(contents == "hello")
        let renamed = try store.rename(imported, to: "renamed.txt")
        let unchangedName = try store.rename(renamed, to: "renamed.txt")
        assert(unchangedName == renamed)
        let copied = try store.copy(renamed, to: root)
        assert(copied.lastPathComponent == "renamed.txt")
        let moved = try store.move(renamed, to: root)
        assert(moved.lastPathComponent == "renamed 2.txt")
        let unchangedLocation = try store.move(moved, to: root)
        assert(unchangedLocation == moved)
        let beforeDelete = try store.contents(of: root)
        assert(beforeDelete.count == initialDirectoryCount + 3)
        try store.delete(copied)
        let afterDelete = try store.contents(of: root)
        assert(afterDelete.count == initialDirectoryCount + 2)
        let downloaded = try store.importFile(source, into: root, named: "download.txt")
        assert(downloaded.lastPathComponent == "download.txt")
        print("FileStore smoke passed")
    }
}
