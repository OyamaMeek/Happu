// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ShuNetwork", platforms: [.macOS(.v13), .iOS("18.0")],
    products: [.library(name: "ShuNetwork", targets: ["ShuNetwork"])], targets: [
        .target(name: "GCDWebServer", path: "Upstream", exclude: ["LICENSE"], publicHeadersPath: ".",
            cSettings: [.headerSearchPath("GCDWebServer/Core"), .headerSearchPath("GCDWebServer/Requests"), .headerSearchPath("GCDWebServer/Responses"), .unsafeFlags(["-fobjc-arc", "-fmodules"])],
            linkerSettings: [.linkedFramework("CFNetwork"), .linkedLibrary("z"), .linkedLibrary("xml2")]),
        .target(name: "ShuNetwork", dependencies: ["GCDWebServer"], path: "Sources", resources: [.process("Resources")], publicHeadersPath: "include", cSettings: [.headerSearchPath("../Upstream/GCDWebServer/Core"), .headerSearchPath("../Upstream/GCDWebServer/Requests"), .headerSearchPath("../Upstream/GCDWebServer/Responses"), .unsafeFlags(["-fobjc-arc", "-fmodules"])])
    ])
