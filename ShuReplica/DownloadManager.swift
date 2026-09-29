import Foundation
import Combine

struct DownloadItem: Identifiable {
    enum State: String, Codable { case running, paused, completed, failed }

    let id: UUID
    let request: URLRequest
    var name: String
    var progress: Double = 0
    var state: State = .running
    var file: URL?
    var resumeData: Data?
    var error: String?
}

final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    // ponytail: 重启后中断任务从头重新下载；需要字节级续传时改用后台会话与持久化续传数据。
    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var storageError: String?
    private var session: URLSession!
    private var active: [UUID: URLSessionDownloadTask] = [:]
    private let store: FileStore
    private let downloadsFolder: URL
    private let recordFile: URL

    private struct Record: Codable {
        let id: UUID
        let url: URL
        let headers: [String: String]
        let name: String
        let state: DownloadItem.State
        let fileName: String?
        let error: String?

        init(_ item: DownloadItem) {
            id = item.id
            url = item.request.url!
            headers = item.request.allHTTPHeaderFields ?? [:]
            name = item.name
            state = item.state
            fileName = item.file?.lastPathComponent
            error = item.error
        }

        func item(in folder: URL) throws -> DownloadItem {
            var request = URLRequest(url: url)
            for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
            var file: URL?
            if let fileName {
                guard !fileName.isEmpty, fileName != ".", fileName != "..",
                      !fileName.contains("/"), !fileName.contains("\\") else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                file = folder.appendingPathComponent(fileName)
            }
            let exists = file.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            let restoredState: DownloadItem.State = state == .running ? .paused
                : state == .completed && !exists ? .failed : state
            return DownloadItem(id: id, request: request, name: name,
                                progress: restoredState == .completed ? 1 : 0,
                                state: restoredState, file: exists ? file : nil,
                                error: state == .completed && !exists ? "文件已移动或删除" : error)
        }
    }

    init(store: FileStore) throws {
        self.store = store
        downloadsFolder = store.root.appendingPathComponent("Downloads", isDirectory: true)
        recordFile = store.root.appendingPathComponent(".shu-downloads.json")
        try FileManager.default.createDirectory(at: downloadsFolder, withIntermediateDirectories: true)
        super.init()
        if FileManager.default.fileExists(atPath: recordFile.path) {
            let records = try JSONDecoder().decode([Record].self, from: Data(contentsOf: recordFile))
            items = try records.map { try $0.item(in: downloadsFolder) }
        }
        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    }

    func start(urlText: String, headersText: String) throws {
        let request = try DownloadRequest.make(urlText: urlText, headersText: headersText)
        let id = UUID()
        let pathName = request.url?.lastPathComponent ?? ""
        let name = pathName.isEmpty ? "download" : pathName
        items.insert(DownloadItem(id: id, request: request, name: name), at: 0)
        save()
        launch(id: id, request: request, resumeData: nil)
    }

    func pause(_ id: UUID) {
        guard let task = active.removeValue(forKey: id), let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .paused
        save()
        task.cancel { [weak self] data in
            DispatchQueue.main.async {
                guard let self, let index = self.items.firstIndex(where: { $0.id == id }),
                      self.items[index].state == .paused else { return }
                self.items[index].resumeData = data
            }
        }
    }

    func resume(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].state == .paused || items[index].state == .failed else { return }
        let item = items[index]
        items[index].state = .running
        items[index].error = nil
        items[index].resumeData = nil
        save()
        launch(id: id, request: item.request, resumeData: item.resumeData)
    }

    func remove(_ id: UUID) throws {
        active.removeValue(forKey: id)?.cancel()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let file = items[index].file { try store.delete(file) }
        items.remove(at: index)
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items.map(Record.init))
            try data.write(to: recordFile, options: .atomic)
            storageError = nil
        } catch {
            storageError = "下载记录保存失败：\(error.localizedDescription)"
        }
    }

    private func launch(id: UUID, request: URLRequest, resumeData: Data?) {
        let task = resumeData.map { session.downloadTask(withResumeData: $0) }
            ?? session.downloadTask(with: request)
        task.taskDescription = id.uuidString
        active[id] = task
        task.resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)) else { return }
        DispatchQueue.main.async {
            guard let index = self.items.firstIndex(where: { $0.id == id }),
                  self.active[id] === downloadTask,
                  self.items[index].state == .running else { return }
            if totalBytesExpectedToWrite > 0 {
                self.items[index].progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)) else { return }
        let name = downloadTask.response?.suggestedFilename
            ?? downloadTask.originalRequest?.url?.lastPathComponent ?? "download"
        let result = Result {
            guard let response = downloadTask.response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return try store.importFile(location, into: downloadsFolder, named: name)
        }
        DispatchQueue.main.async {
            guard let index = self.items.firstIndex(where: { $0.id == id }),
                  self.active[id] === downloadTask else {
                if case .success(let file) = result { try? self.store.delete(file) }
                return
            }
            self.active.removeValue(forKey: id)
            switch result {
            case .success(let file):
                self.items[index].file = file
                self.items[index].name = file.lastPathComponent
                self.items[index].progress = 1
                self.items[index].state = .completed
            case .failure(let error):
                self.items[index].state = .failed
                self.items[index].error = error.localizedDescription
            }
            self.save()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error, let id = task.taskDescription.flatMap(UUID.init(uuidString:)) else { return }
        DispatchQueue.main.async {
            guard let index = self.items.firstIndex(where: { $0.id == id }),
                  self.active[id] === task else { return }
            self.active.removeValue(forKey: id)
            if self.items[index].state == .paused { return }
            self.items[index].state = .failed
            self.items[index].error = error.localizedDescription
            self.items[index].resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            self.save()
        }
    }
}
