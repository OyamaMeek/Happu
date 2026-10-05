// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShuArchiveChecks",
    platforms: [.macOS(.v13), .iOS("18.0")],
    dependencies: [.package(path: "Vendor/ShuNetwork"), .package(url: "https://github.com/ZipArchive/ZipArchive.git", exact: "2.6.0"), .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", exact: "1.6.0"), .package(url: "https://github.com/BB9z/LAME-xcframework.git", exact: "3.100.3")],
    targets: [.target(
        name: "ArchiveBridge",
        dependencies: [.product(name: "ZipArchive", package: "ZipArchive")],
        path: "ArchiveBridge",
        publicHeadersPath: "."
    ), .target(
        name: "ShuServices",
        dependencies: ["ArchiveBridge", .product(name: "ShuNetwork", package: "ShuNetwork"), .product(name: "ZipArchive", package: "ZipArchive"), .product(name: "libwebp", package: "libwebp-Xcode"), .product(name: "LAME", package: "LAME-xcframework")],
        path: "ShuReplica",
        exclude: ["PDFService.swift", "Info.plist", "ShuReplicaApp.swift", "FilesView.swift", "ArchiveOperationView.swift", "DocumentOperationView.swift", "DownloadRequest.swift", "DownloadManager.swift", "DownloadsView.swift", "MoreView.swift", "NetworkSharingView.swift"],
        sources: ["ArchiveService.swift", "FileStore.swift", "WorkspaceCategory.swift", "ImageService.swift", "MediaWorkspace.swift", "AudioService.swift", "VideoService.swift", "NetworkSharingService.swift", "NetworkSharingAddresses.swift", "NetworkSharingQRCode.swift"],
        linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path"], .when(platforms: [.macOS]))]
    ), .executableTarget(
        name: "ArchiveSmoke",
        dependencies: ["ShuServices"],
        path: "Tests",
        exclude: ["make_archive_fixtures.py", "prepare_document_ui_fixtures.swift", "fixtures", "FileBatchSmoke.swift", "FileStoreSmoke.swift", "WorkspaceCategorySmoke.swift", "DownloadRequestSmoke.swift", "DownloadManagerSmoke.swift", "ShuReplicaUITests.swift", "PDFSmoke.swift", "ImageSmoke.swift", "AudioSmoke.swift", "MediaRuntimeTests.swift", "NetworkSmoke.swift", "NetworkRuntimeTests.swift", "VideoSmoke.swift"],
        sources: ["ArchiveSmoke.swift"]
    ), .executableTarget(
        name: "ImageSmoke",
        dependencies: ["ShuServices", .product(name: "libwebp", package: "libwebp-Xcode")],
        path: "Tests",
        exclude: ["make_archive_fixtures.py", "prepare_document_ui_fixtures.swift", "fixtures", "FileBatchSmoke.swift", "FileStoreSmoke.swift", "WorkspaceCategorySmoke.swift", "DownloadRequestSmoke.swift", "DownloadManagerSmoke.swift", "ShuReplicaUITests.swift", "PDFSmoke.swift", "ArchiveSmoke.swift", "AudioSmoke.swift", "MediaRuntimeTests.swift", "NetworkSmoke.swift", "NetworkRuntimeTests.swift", "VideoSmoke.swift"],
        sources: ["ImageSmoke.swift"]
    ), .executableTarget(
        name: "AudioSmoke", dependencies: ["ShuServices"], path: "Tests",
        exclude: ["make_archive_fixtures.py", "prepare_document_ui_fixtures.swift", "fixtures", "FileBatchSmoke.swift", "FileStoreSmoke.swift", "WorkspaceCategorySmoke.swift", "DownloadRequestSmoke.swift", "DownloadManagerSmoke.swift", "ShuReplicaUITests.swift", "PDFSmoke.swift", "ArchiveSmoke.swift", "ImageSmoke.swift", "MediaRuntimeTests.swift", "NetworkSmoke.swift", "NetworkRuntimeTests.swift", "VideoSmoke.swift"],
        sources: ["AudioSmoke.swift"]
    ), .executableTarget(
        name: "NetworkSmoke", dependencies: ["ShuServices", .product(name: "ShuNetwork", package: "ShuNetwork")], path: "Tests",
        exclude: ["make_archive_fixtures.py", "prepare_document_ui_fixtures.swift", "fixtures", "FileBatchSmoke.swift", "FileStoreSmoke.swift", "WorkspaceCategorySmoke.swift", "DownloadRequestSmoke.swift", "DownloadManagerSmoke.swift", "ShuReplicaUITests.swift", "PDFSmoke.swift", "ArchiveSmoke.swift", "ImageSmoke.swift", "AudioSmoke.swift", "MediaRuntimeTests.swift", "NetworkRuntimeTests.swift", "VideoSmoke.swift"],
        sources: ["NetworkSmoke.swift"]
    ), .executableTarget(
        name: "VideoSmoke", dependencies: ["ShuServices"], path: "Tests",
        exclude: ["make_archive_fixtures.py", "prepare_document_ui_fixtures.swift", "fixtures", "FileBatchSmoke.swift", "FileStoreSmoke.swift", "WorkspaceCategorySmoke.swift", "DownloadRequestSmoke.swift", "DownloadManagerSmoke.swift", "ShuReplicaUITests.swift", "PDFSmoke.swift", "ArchiveSmoke.swift", "ImageSmoke.swift", "AudioSmoke.swift", "MediaRuntimeTests.swift", "NetworkSmoke.swift", "NetworkRuntimeTests.swift"],
        sources: ["VideoSmoke.swift"]
    )]
)
