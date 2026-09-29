import Foundation

@main
struct WorkspaceCategorySmoke {
    static func main() throws {
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "A.EPUB")) == .ebook)
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "B.JPG")) == .picture)
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "C.PDF")) == .document)
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "D.MP4")) == .video)
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "E.MP3")) == .audio)
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "F.ZIP")) == .archive)
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "G.DMG")) == .diskImage)
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "H.SH")) == .script)
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "I.JSON")) == .utility)
        assert(WorkspaceCategory.forFile(URL(fileURLWithPath: "unknown.blob")) == nil)

        let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let root = base.appendingPathComponent("documents", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let collision = root.appendingPathComponent("文稿")
        let original = Data([0, 1, 2, 255])
        try original.write(to: collision)
        do {
            _ = try FileStore(root: root)
            assertionFailure("FileStore should reject a file occupying a category directory")
        } catch {
            let preserved = try Data(contentsOf: collision)
            assert(preserved == original)
        }

        print("WorkspaceCategory smoke passed")
    }
}
