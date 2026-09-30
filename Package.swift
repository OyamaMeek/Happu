// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShuArchiveChecks",
    platforms: [.macOS(.v13), .iOS("18.0")],
    dependencies: [.package(url: "https://github.com/ZipArchive/ZipArchive.git", exact: "2.6.0")],
    targets: [.executableTarget(
        name: "ArchiveSmoke",
        dependencies: [.product(name: "ZipArchive", package: "ZipArchive")],
        path: ".",
        exclude: ["Payload", "DerivedData", "reverse-skill", "work", "context", "docs", "memory", "HANDOFF", "ShuReplica.xcodeproj", "AGENTS.md", "Tests/make_archive_fixtures.py", "Tests/fixtures", "Tests/FileBatchSmoke.swift", "Tests/FileStoreSmoke.swift", "Tests/WorkspaceCategorySmoke.swift", "Tests/DownloadRequestSmoke.swift", "Tests/DownloadManagerSmoke.swift", "Tests/ShuReplicaUITests.swift", "ShuReplica/Info.plist", "ShuReplica/ShuReplicaApp.swift", "ShuReplica/FilesView.swift", "ShuReplica/DownloadRequest.swift", "ShuReplica/DownloadManager.swift", "ShuReplica/DownloadsView.swift", "ShuReplica/MoreView.swift"],
        sources: ["ShuReplica/ArchiveService.swift", "ShuReplica/FileStore.swift", "ShuReplica/WorkspaceCategory.swift", "Tests/ArchiveSmoke.swift"]
    )]
)
