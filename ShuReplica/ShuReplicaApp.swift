import SwiftUI

@main
struct ShuReplicaApp: App {
    private let startup: Result<Runtime, Error>

    init() {
        startup = Result {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let store = try FileStore(root: documents)
            return Runtime(store: store, downloads: try DownloadManager(store: store))
        }
    }

    var body: some Scene {
        WindowGroup {
            switch startup {
            case .success(let runtime):
                TabView {
                    NavigationStack {
                        FilesHomeView(store: runtime.store)
                    }
                    .tabItem { Label("文件", systemImage: "folder") }

                    NavigationStack {
                        DownloadsView(manager: runtime.downloads)
                    }
                    .tabItem { Label("下载", systemImage: "arrow.down.circle") }

                    NavigationStack {
                        MoreView()
                    }
                    .tabItem { Label("更多", systemImage: "ellipsis.circle") }
                }
                .tint(.blue)
            case .failure(let error):
                ContentUnavailableView("无法打开工作区", systemImage: "folder.badge.questionmark",
                                       description: Text(error.localizedDescription))
            }
        }
    }
}

private struct Runtime {
    let store: FileStore
    let downloads: DownloadManager
}
