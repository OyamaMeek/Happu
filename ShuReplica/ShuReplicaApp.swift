import SwiftUI

@main
struct ShuReplicaApp: App {
    private let startup: Result<Runtime, Error>

    init() {
        startup = Result {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let store = try FileStore(root: documents)
            return Runtime(store: store, downloads: try DownloadManager(store: store), sharing: NetworkSharingService(root: store.root))
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
                        NetworkSharingView(store: runtime.store, request: NetworkSharingRequest(initialFolder: runtime.store.root))
                    }
                    .tabItem { Label("网络共享", systemImage: "network") }

                    NavigationStack {
                        MoreView(store: runtime.store, downloads: runtime.downloads)
                    }
                    .tabItem { Label("更多", systemImage: "ellipsis.circle") }
                }
                .tint(.blue)
                .environmentObject(runtime.sharing)
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
    let sharing: NetworkSharingService
}
