import Foundation

@main
struct DownloadManagerSmoke {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
        let manager = try DownloadManager(store: FileStore(root: root))
        try manager.start(urlText: "http://127.0.0.1:8765/hello.txt", headersText: "")
        let success = try waitForResult(manager)
        assert(success.state == .completed)
        let text = try String(contentsOf: success.file!, encoding: .utf8)
        assert(text == "download test payload\n")
        let restoredCompleted = try DownloadManager(store: FileStore(root: root))
        assert(restoredCompleted.items.count == 1)
        assert(restoredCompleted.items[0].state == .completed)
        assert(restoredCompleted.items[0].file == success.file)

        try manager.start(urlText: "http://127.0.0.1:8765/hello.txt", headersText: "")
        let resumableID = manager.items[0].id
        manager.pause(resumableID)
        assert(manager.items[0].state == .paused)
        manager.resume(resumableID)
        let resumed = try waitForResult(manager)
        assert(resumed.state == .completed)

        try manager.start(urlText: "http://127.0.0.1:8765/missing.txt", headersText: "")
        let failure = try waitForResult(manager)
        assert(failure.state == .failed, "HTTP 404 was saved as a completed download")
        assert(failure.file == nil)

        try manager.start(urlText: "http://127.0.0.1:8765/hello.txt", headersText: "X-Test: restored")
        let pausedID = manager.items[0].id
        manager.pause(pausedID)
        let restoredPaused = try DownloadManager(store: FileStore(root: root))
        assert(restoredPaused.items[0].id == pausedID)
        assert(restoredPaused.items[0].state == .paused)
        assert(restoredPaused.items[0].request.value(forHTTPHeaderField: "X-Test") == "restored")
        restoredPaused.resume(pausedID)
        let resumedAfterRestore = try waitForResult(restoredPaused)
        assert(resumedAfterRestore.state == .completed)
        try restoredPaused.remove(pausedID)
        let afterRemoval = try DownloadManager(store: FileStore(root: root))
        assert(!afterRemoval.items.contains(where: { $0.id == pausedID }))
        print("DownloadManager smoke passed")
    }

    private static func waitForResult(_ manager: DownloadManager) throws -> DownloadItem {
        let end = Date().addingTimeInterval(10)
        while Date() < end {
            if let item = manager.items.first, item.state == .completed || item.state == .failed {
                return item
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        throw URLError(.timedOut)
    }
}
