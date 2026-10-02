// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShuArchiveChecks",
    platforms: [.macOS(.v13), .iOS("18.0")],
    dependencies: [.package(url: "https://github.com/ZipArchive/ZipArchive.git", exact: "2.6.0"), .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", exact: "1.6.0")],
    targets: [.target(
        name: "ArchiveBridge",
        dependencies: [.product(name: "ZipArchive", package: "ZipArchive")],
        path: "ArchiveBridge",
        publicHeadersPath: "."
    ), .target(
        name: "ShuServices",
        dependencies: ["ArchiveBridge", .product(name: "ZipArchive", package: "ZipArchive"), .product(name: "libwebp", package: "libwebp-Xcode")],
        path: "ShuReplica",
        exclude: ["PDFService.swift", "Info.plist", "ShuReplicaApp.swift", "FilesView.swift", "ArchiveOperationView.swift", "DocumentOperationView.swift", "DownloadRequest.swift", "DownloadManager.swift", "DownloadsView.swift", "MoreView.swift"],
        sources: ["ArchiveService.swift", "FileStore.swift", "WorkspaceCategory.swift", "ImageService.swift"]
    ), .executableTarget(
        name: "ArchiveSmoke",
        dependencies: ["ShuServices"],
        path: "Tests",
        exclude: ["make_archive_fixtures.py", "prepare_document_ui_fixtures.swift", "fixtures", "FileBatchSmoke.swift", "FileStoreSmoke.swift", "WorkspaceCategorySmoke.swift", "DownloadRequestSmoke.swift", "DownloadManagerSmoke.swift", "ShuReplicaUITests.swift", "PDFSmoke.swift", "ImageSmoke.swift"],
        sources: ["ArchiveSmoke.swift"]
    ), .executableTarget(
        name: "ImageSmoke",
        dependencies: ["ShuServices", .product(name: "libwebp", package: "libwebp-Xcode")],
        path: "Tests",
        exclude: ["make_archive_fixtures.py", "prepare_document_ui_fixtures.swift", "fixtures", "FileBatchSmoke.swift", "FileStoreSmoke.swift", "WorkspaceCategorySmoke.swift", "DownloadRequestSmoke.swift", "DownloadManagerSmoke.swift", "ShuReplicaUITests.swift", "PDFSmoke.swift", "ArchiveSmoke.swift"],
        sources: ["ImageSmoke.swift"]
    )]
)
