import Foundation
import Darwin
import ShuNetwork
#if os(iOS)
import XCTest
@testable import ShuReplica
#else
@testable import ShuServices
#endif

enum NetworkChecks {
    final class Socket {
        let fd: Int32
        init(port: UInt16) throws {
            fd = socket(AF_INET, SOCK_STREAM, 0)
            guard fd >= 0 else { throw POSIXError(.EMFILE) }
            var timeout = timeval(tv_sec: 3, tv_usec: 0)
            var yes: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, 4)
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = port.bigEndian
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            let result = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
            if result != 0 { close(fd); throw POSIXError(.ECONNREFUSED) }
        }
        deinit { close(fd) }
        func send(_ string: String) throws {
            try send(Data(string.utf8))
        }
        func send(_ data: Data) throws {
            try data.withUnsafeBytes { bytes in
                var offset = 0
                while offset < bytes.count {
                    let count = Darwin.send(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset, 0)
                    guard count > 0 else { throw POSIXError(.EPIPE) }
                    offset += count
                }
            }
        }
        func response() -> String {
            var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = recv(fd, &buffer, buffer.count, 0)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            return String(decoding: data, as: UTF8.self)
        }
    }
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "NetworkChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "ASSERTION: " + message]) }
    }
    @MainActor static func moveBoundary(root: URL) async throws -> Int {
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let parent = root.appendingPathComponent("parent")
        try manager.createDirectory(at: parent, withIntermediateDirectories: false)
        let source = parent.appendingPathComponent("large")
        manager.createFile(atPath: source.path, contents: nil)
        let file = try FileHandle(forWritingTo: source)
        try file.truncate(atOffset: 268435456); try file.close()
        let access = try ShuFileAccess(workspaceURL: root, sharedDirectoryURL: root)
        let operation = Task.detached { () -> NSError? in
            do { try access.copyItem(atRelativePath: "parent/large", toRelativePath: "moved", move: true); return nil }
            catch { return error as NSError }
        }
        var copying = false
        for _ in 0..<1000 {
            let stages = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix(".shu-network-") }
            if let stage = stages.first, !(try manager.contentsOfDirectory(atPath: stage.path)).isEmpty { copying = true; break }
            try await Task.sleep(for: .milliseconds(1))
        }
        try require(copying, "real MOVE staging observed")
        let outside = root.deletingLastPathComponent().appendingPathComponent("moved-parent-" + UUID().uuidString)
        defer { try? manager.removeItem(at: outside) }
        try manager.moveItem(at: parent, to: outside)
        let error = await operation.value
        try require(error?.code == 403 || error?.code == 404, "MOVE rejects parent relocated outside root")
        try require(manager.fileExists(atPath: outside.appendingPathComponent("large").path) && !manager.fileExists(atPath: root.appendingPathComponent("moved").path), "outside MOVE source preserved and no target published")
        return 3
    }
    @MainActor static func stopDuringCopy(root: URL) async throws -> Int {
        _ = try FileStore(root: root)
        let manager = FileManager.default
        let source = root.appendingPathComponent("large")
        manager.createFile(atPath: source.path, contents: nil)
        let file = try FileHandle(forWritingTo: source)
        try file.truncate(atOffset: 536870912); try file.close()
        let service = NetworkSharingService(root: root)
        try await service.start(folder: root, mode: .webDAV)
        let base = "http://127.0.0.1:\(service.listeningPort!)"
        var request = URLRequest(url: URL(string: base + "/large")!)
        request.httpMethod = "COPY"; request.setValue(base + "/copied", forHTTPHeaderField: "Destination")
        let operation = Task { try await URLSession.shared.data(for: request) }
        var copying = false
        var stagedFile: URL?
        for _ in 0..<1000 {
            let stages = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix(".shu-network-") }
            if let stage = stages.first, let item = try manager.contentsOfDirectory(at: stage, includingPropertiesForKeys: nil).first { copying = true; stagedFile = item; break }
            try await Task.sleep(for: .milliseconds(1))
        }
        try require(copying, "real DAV COPY staging observed before stop")
        let stagedHandle = try FileHandle(forReadingFrom: stagedFile!)
        defer { try? stagedHandle.close() }
        let start = Date()
        let stopping = Task { try await service.stop() }
        await Task.yield()
        let responsiveness = Date().timeIntervalSince(start)
        try await stopping.value
        _ = await operation.result
        try require(try stagedHandle.seekToEnd() < 536870912, "stop cancels COPY before reading complete source")
        try require(responsiveness < 0.1, "main actor remains responsive while stopping copy: \(responsiveness)")
        try require(!manager.fileExists(atPath: root.appendingPathComponent("copied").path), "stopped COPY never publishes")
        try require(try manager.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".shu-network-") }, "COPY stop removes staging")
        return 5
    }
    @MainActor static func downloadSafety(root: URL) async throws -> Int {
        _ = try FileStore(root: root)
        let contents = Data("<script>fetch('/api/list')</script>".utf8)
        try contents.write(to: root.appendingPathComponent("activity.html"))
        let service = NetworkSharingService(root: root)
        try await service.start(folder: root, mode: .browser)
        let (data, response) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(service.listeningPort!)/files/activity.html")!)
        let headers = response as! HTTPURLResponse
        try require(headers.value(forHTTPHeaderField: "Content-Disposition")?.hasPrefix("attachment;") == true, "browser files force attachment")
        try require(headers.value(forHTTPHeaderField: "X-Content-Type-Options") == "nosniff" && headers.value(forHTTPHeaderField: "Content-Security-Policy")?.contains("sandbox") == true, "browser file content cannot execute with sharing origin")
        try require(data == contents, "attachment preserves exact file bytes")
        try await service.stop(); return 3
    }
    @MainActor static func assets(root: URL) async throws -> Int {
        let store = try FileStore(root: root)
        let service = NetworkSharingService(root: store.root)
        try await service.start(folder: store.root, mode: .browser)
        let base = URL(string: "http://127.0.0.1:\(service.listeningPort!)/")!
        let session = URLSession(configuration: .ephemeral)
        var passed = 0
        for (name, mime) in [("", "text/html"), ("sharing.js", "application/javascript"), ("sharing.css", "text/css")] {
            let url = base.appendingPathComponent(name)
            let (data, response) = try await session.data(from: url)
            try require((response as! HTTPURLResponse).statusCode == 200 && !data.isEmpty, "packaged browser asset \(name)")
            try require((response as! HTTPURLResponse).mimeType == mime, "browser asset MIME \(name)")
            #if os(iOS)
            let package = Bundle.main.bundleURL
            #else
            let package = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.deletingLastPathComponent()
            #endif
            let resourceBundle = Bundle(url: package.appendingPathComponent("ShuNetwork_ShuNetwork.bundle"))!
            let resource = resourceBundle.url(forResource: name.isEmpty ? "index.html" : name, withExtension: nil)!
            try require(data == Data(contentsOf: resource), "asset exact packaged bytes \(name)")
            var head = URLRequest(url: url); head.httpMethod = "HEAD"
            let (empty, headResponse) = try await session.data(for: head)
            try require(empty.isEmpty && (headResponse as! HTTPURLResponse).statusCode == 200, "asset HEAD \(name)")
            passed += 4
        }
        let (listing, _) = try await session.data(from: base.appendingPathComponent("api/list"))
        let entries = (try JSONSerialization.jsonObject(with: listing) as! [String: Any])["entries"] as! [[String: Any]]
        try require(Set(entries.compactMap { $0["name"] as? String }) == Set(WorkspaceCategory.allCases.map(\.rawValue) + ["Downloads", "共享"]), "browser root lists all homepage folders")
        try await service.stop(); session.invalidateAndCancel()
        return passed + 1
    }
    @MainActor static func dav(root: URL) async throws -> Int {
        let store = try FileStore(root: root)
        let service = NetworkSharingService(root: store.root)
        try await service.start(folder: store.root, mode: .webDAV)
        let base = "http://127.0.0.1:\(service.listeningPort!)"
        let session = URLSession(configuration: .ephemeral)
        var passed = 0
        func request(_ method: String, _ path: String, _ body: Data? = nil, _ headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
            var req = URLRequest(url: URL(string: base + path)!, cachePolicy: .reloadIgnoringLocalCacheData); req.httpMethod = method; req.httpBody = body
            for (name, value) in headers { req.setValue(value, forHTTPHeaderField: name) }
            let (data, response) = try await session.data(for: req)
            return (data, response as! HTTPURLResponse)
        }
        func check(_ condition: Bool, _ message: String) throws { try require(condition, message); passed += 1 }
        let bytes = Data("真实 DAV 中文内容".utf8)
        let encoded = "/" + "中文 & 空格.txt".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let options = try await request("OPTIONS", "/")
        try check(options.1.statusCode == 200 && options.1.value(forHTTPHeaderField: "Allow")?.contains("PROPFIND") == true, "DAV OPTIONS methods")
        try check(try await request("PUT", encoded, bytes).1.statusCode == 201, "DAV PUT")
        try check(try await request("GET", encoded).0 == bytes, "DAV exact GET")
        let head = try await request("HEAD", encoded)
        try check(head.0.isEmpty && head.1.value(forHTTPHeaderField: "Content-Length") == String(bytes.count), "DAV HEAD status=\(head.1.statusCode) headers=\(head.1.allHeaderFields) bytes=\(head.0.count)")
        let listing = try await request("PROPFIND", "/", nil, ["Depth": "1"])
        let xml = String(decoding: listing.0, as: UTF8.self)
        try check(listing.1.statusCode == 207 && XMLParser(data: listing.0).parse(), "DAV multistatus valid XML")
        try check(xml.contains("中文 &amp; 空格.txt") && xml.contains("/Downloads/"), "DAV escaped names and directory href")
        try check(!xml.contains("Thu, 01 Jan 1970"), "DAV root uses actual directory modification date")
        let zero = try await request("PROPFIND", encoded, nil, ["Depth": "0"])
        try check(zero.1.statusCode == 207 && String(decoding: zero.0, as: UTF8.self).components(separatedBy: "<D:response>").count == 2, "DAV Depth zero single response")
        try check(try await request("PROPFIND", "/", nil, ["Depth": "infinity"]).1.statusCode == 403, "DAV refuses unlimited depth")
        try check(try await request("PROPFIND", "/", Data("<bad".utf8), ["Depth": "0"]).1.statusCode == 400, "DAV malformed XML")
        let unknown = try await request("PROPFIND", "/", Data("<D:propfind xmlns:D='DAV:' xmlns:X='urn:custom'><D:prop><X:unknown/></D:prop></D:propfind>".utf8), ["Depth": "0"])
        try check(unknown.1.statusCode == 207 && String(decoding: unknown.0, as: UTF8.self).contains("404 Not Found"), "DAV unknown property 404")
        let external = Data("<!DOCTYPE p [<!ENTITY secret SYSTEM 'file:///etc/passwd'>]><D:propfind xmlns:D='DAV:'><D:prop>&secret;</D:prop></D:propfind>".utf8)
        try check(try await request("PROPFIND", "/", external, ["Depth": "0"]).1.statusCode == 400, "DAV rejects DTD before entity resolution")
        try check(try await request("MKCOL", "/Folder").1.statusCode == 201, "DAV MKCOL")
        try check(try await request("PUT", "/Folder/inner", bytes).1.statusCode == 201, "DAV child PUT")
        try check(try await request("COPY", "/Folder", nil, ["Destination": base + "/shallow", "Depth": "0"]).1.statusCode == 201, "DAV shallow collection COPY")
        let shallow = try await request("PROPFIND", "/shallow", nil, ["Depth": "1"])
        try check(String(decoding: shallow.0, as: UTF8.self).components(separatedBy: "<D:response>").count == 2, "DAV Depth zero COPY excludes children")
        try check(try await request("DELETE", "/shallow").1.statusCode == 204, "DAV shallow directory DELETE")
        try check(try await request("COPY", encoded, nil, ["Destination": base + "/invalid-depth", "Depth": "1"]).1.statusCode == 400, "DAV COPY rejects invalid Depth")
        try check(try await request("MOVE", encoded, nil, ["Destination": base + "/invalid-depth", "Depth": "0"]).1.statusCode == 400, "DAV MOVE rejects invalid Depth")
        try check(try await request("COPY", encoded, nil, ["Destination": base + "/copy"]).1.statusCode == 201, "DAV COPY")
        try check(try Data(contentsOf: store.root.appendingPathComponent("copy")) == bytes, "DAV COPY exact bytes")
        let noOverwrite = try await request("COPY", encoded, nil, ["Destination": base + "/copy", "Overwrite": "F"])
        let overwrite = try await request("COPY", encoded, nil, ["Destination": base + "/copy", "Overwrite": "T"])
        try check(noOverwrite.1.statusCode == 412 && overwrite.1.statusCode == 409, "DAV no-overwrite policy")
        try check(try Data(contentsOf: store.root.appendingPathComponent("copy")) == bytes, "DAV conflict preserves bytes")
        try check(try await request("MOVE", "/copy", nil, ["Destination": base + "/Folder/moved"]).1.statusCode == 201, "DAV MOVE")
        try check(!FileManager.default.fileExists(atPath: store.root.appendingPathComponent("copy").path), "DAV MOVE source absent")
        for destination in ["http://evil.invalid/x", "http://127.0.0.1:1/x", base + "/.hidden", base + "/%2e%2e/outside"] {
            try check(try await request("COPY", encoded, nil, ["Destination": destination]).1.statusCode == 403, "DAV invalid Destination \(destination)")
        }
        try check(try await request("MOVE", "/Folder", nil, ["Destination": base + "/Folder/child"]).1.statusCode == 403, "DAV rejects descendant move")
        try check(try await request("COPY", encoded, nil, ["Destination": base + encoded]).1.statusCode == 409, "DAV rejects identical destination")
        for method in ["LOCK", "UNLOCK", "PROPPATCH"] { try check(try await request(method, "/").1.statusCode == 501, "DAV unsupported \(method)") }
        try check(try await request("DELETE", "/").1.statusCode == 403, "DAV protects root")
        try check(try await request("DELETE", "/Folder").1.statusCode == 204, "DAV recursive DELETE")
        try check(try await request("PUT", "/empty", Data()).1.statusCode == 201, "DAV empty PUT")
        try await service.stop(); session.invalidateAndCancel()
        return passed
    }
    static func components(root: URL, sourceBytes: Data, sentinel: URL) throws -> Int {
        let manager = FileManager.default
        var passed = 0
        func check(_ condition: Bool, _ message: String) throws { try require(condition, message); passed += 1 }
        let componentRoot = root.appendingPathComponent("components")
        try manager.createDirectory(at: componentRoot, withIntermediateDirectories: false)
        var access: ShuFileAccess? = try ShuFileAccess(workspaceURL: root, sharedDirectoryURL: componentRoot)
        try sourceBytes.write(to: componentRoot.appendingPathComponent("source"))
        try access!.copyItem(atRelativePath: "source", toRelativePath: "copy", move: false)
        try check(try Data(contentsOf: componentRoot.appendingPathComponent("copy")) == sourceBytes, "component COPY exact bytes")
        try access!.copyItem(atRelativePath: "copy", toRelativePath: "moved", move: true)
        try check(!manager.fileExists(atPath: componentRoot.appendingPathComponent("copy").path) && (try Data(contentsOf: componentRoot.appendingPathComponent("moved"))) == sourceBytes, "component MOVE exact bytes")
        var collision = false
        do { try access!.copyItem(atRelativePath: "source", toRelativePath: "moved", move: true) } catch { collision = (error as NSError).code == 409 }
        try check(collision && manager.fileExists(atPath: componentRoot.appendingPathComponent("source").path), "component MOVE conflict preserves source")
        try manager.createDirectory(at: componentRoot.appendingPathComponent("tree"), withIntermediateDirectories: false)
        try sourceBytes.write(to: componentRoot.appendingPathComponent("tree/visible"))
        try sourceBytes.write(to: componentRoot.appendingPathComponent("tree/.hidden"))
        var deniedTree = false
        do { try access!.copyItem(atRelativePath: "tree", toRelativePath: "tree-copy", move: false) } catch { deniedTree = (error as NSError).code == 403 }
        try check(deniedTree && !manager.fileExists(atPath: componentRoot.appendingPathComponent("tree-copy").path), "COPY hidden descendant rejects whole target")
        try manager.removeItem(at: componentRoot.appendingPathComponent("tree/.hidden"))
        try manager.createSymbolicLink(at: componentRoot.appendingPathComponent("tree/link"), withDestinationURL: sentinel)
        deniedTree = false
        do { try access!.copyItem(atRelativePath: "tree", toRelativePath: "tree-copy", move: false) } catch { deniedTree = (error as NSError).code == 403 }
        try check(deniedTree && !manager.fileExists(atPath: componentRoot.appendingPathComponent("tree-copy").path), "COPY link descendant rejects whole target")
        try manager.removeItem(at: componentRoot.appendingPathComponent("tree/link"))
        try access!.copyItem(atRelativePath: "tree", toRelativePath: "tree-copy", move: false)
        try check(try Data(contentsOf: componentRoot.appendingPathComponent("tree-copy/visible")) == sourceBytes, "component directory COPY")
        try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: componentRoot.appendingPathComponent("tree").path)
        var moveDenied = false
        do { try access!.copyItem(atRelativePath: "tree/visible", toRelativePath: "denied-move", move: true) } catch { moveDenied = (error as NSError).code == 500 }
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: componentRoot.appendingPathComponent("tree").path)
        try check(moveDenied && !manager.fileExists(atPath: componentRoot.appendingPathComponent("denied-move").path) && manager.fileExists(atPath: componentRoot.appendingPathComponent("tree/visible").path), "MOVE permission failure leaves target absent and source intact")
        try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: componentRoot.path)
        var ioFailure = false
        do { try access!.createDirectory(atRelativePath: "denied") } catch { ioFailure = (error as NSError).code == 500 }
        try check(ioFailure, "real component mkdir permission error")
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: componentRoot.path)
        access = nil
        try check(try manager.contentsOfDirectory(atPath: componentRoot.path).allSatisfy { !$0.hasPrefix(".shu-network-") }, "component release cleans session")
        return passed
    }
    @MainActor static func http(root: URL) async throws -> Int {
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let shared = root.appendingPathComponent("共享 空间")
        try manager.createDirectory(at: shared, withIntermediateDirectories: true)
        let service = NetworkSharingService(root: root)
        try await service.start(folder: shared, mode: .browser)
        guard let port = service.listeningPort else { throw NSError(domain: "NetworkChecks", code: 2) }
        var passed = 0
        let sourceBytes = Data("中文文件内容\nhello world".utf8)
        let url = URL(string: "http://127.0.0.1:\(port)/files/")!.appendingPathComponent("中文 文件.txt")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        @Sendable func request(_ method: String, _ path: String, _ body: Data? = nil, headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
            var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)" + path)!)
            req.httpMethod = method; req.httpBody = body
            for (key, value) in headers { req.setValue(value, forHTTPHeaderField: key) }
            let (data, response) = try await session.data(for: req)
            return (data, response as! HTTPURLResponse)
        }
        func check(_ value: Bool, _ message: String) throws { try require(value, message); passed += 1 }
        var upload = URLRequest(url: url)
        upload.httpMethod = "PUT"
        upload.httpBody = sourceBytes
        let (_, result) = try await session.data(for: upload)
        try require((result as? HTTPURLResponse)?.statusCode == 201, "PUT returns 201")
        passed += 1
        let (downloadedBytes, _) = try await session.data(from: url)
        #if os(iOS)
        XCTAssertEqual(downloadedBytes, sourceBytes)
        #endif
        try require(downloadedBytes == sourceBytes, "GET preserves exact bytes")
        passed += 1
        try check(try await request("PUT", "/files/empty", Data()).1.statusCode == 201, "empty upload")
        try check(try await request("GET", "/files/empty").0.isEmpty, "empty download")
        try check(try await request("PUT", "/files/second", Data([1, 2, 3])).1.statusCode == 201, "multiple upload")
        try check(try await request("PUT", "/files/second", Data([9])).1.statusCode == 409, "collision")
        try check(try Data(contentsOf: shared.appendingPathComponent("second")) == Data([1, 2, 3]), "collision preserves original")
        let concurrentStatuses: [Int]
        do {
            async let first = request("PUT", "/files/concurrent", Data([4]))
            async let second = request("PUT", "/files/concurrent", Data([5]))
            concurrentStatuses = try await [first.1.statusCode, second.1.statusCode]
        }
        #if os(iOS)
        XCTAssertEqual(concurrentStatuses.sorted(), [201, 409])
        #endif
        try check(concurrentStatuses.sorted() == [201, 409], "concurrent exclusive publication")
        let listing = try await request("GET", "/api/list?path=")
        let entries = (try JSONSerialization.jsonObject(with: listing.0) as! [String: Any])["entries"] as! [[String: Any]]
        try check(entries.count == 4 && entries.contains { $0["name"] as? String == "中文 文件.txt" }, "listing names and count")
        let head = try await request("HEAD", "/files/second")
        try check(head.0.isEmpty && head.1.value(forHTTPHeaderField: "Content-Length") == "3", "HEAD byte count without body")
        let partial = try await request("GET", "/files/second", headers: ["Range": "bytes=1-2"])
        try check(partial.1.statusCode == 206 && partial.0 == Data([2, 3]), "range bytes")
        for range in ["bytes=99-100", "bytes=abc", "bytes=2-1", "bytes=0-1,2-3"] {
            try check(try await request("GET", "/files/second", headers: ["Range": range]).1.statusCode == 416, "invalid range \(range)")
        }
        try check(try await request("POST", "/api/directories", Data("{\"path\":\"子目录 空格\"}".utf8)).1.statusCode == 201, "create directory")
        try check(try await request("DELETE", "/files/" + "子目录 空格".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!).1.statusCode == 204, "delete directory")
        try check(try await request("DELETE", "/files/").1.statusCode == 403, "delete root forbidden")
        try check(try await request("POST", "/api/directories", Data("{}".utf8)).1.statusCode == 400, "invalid JSON path")
        let sentinel = root.appendingPathComponent("sentinel")
        let sentinelBefore = Data("outside unchanged".utf8)
        try sentinelBefore.write(to: sentinel)
        try manager.createSymbolicLink(at: shared.appendingPathComponent("link"), withDestinationURL: sentinel)
        try manager.createSymbolicLink(at: shared.appendingPathComponent("ancestor"), withDestinationURL: root)
        try Data([7]).write(to: shared.appendingPathComponent(".hidden"))
        for path in [".hidden", "link", "ancestor/sentinel", "%2e%2e/sentinel", "../sentinel", "a%2Fb", "a%5Cb", "a%00b", "%2ehidden", "a//b"] {
            let socket = try Socket(port: port)
            try socket.send("GET /files/\(path) HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\n\r\n")
            let response = socket.response()
            try check(response.hasPrefix("HTTP/1.1 403") || response.hasPrefix("HTTP/1.1 400"), "reject raw path \(path): \(response.prefix(80))")
        }
        for headers in [["Origin": "http://evil.example"], ["Host": "evil.example:\(port)"], ["Origin": "null"]] {
            try check(try await request("PUT", "/files/cross-origin", Data([1]), headers: headers).1.statusCode == 403, "reject changed Host/Origin")
        }
        for (name, framing, body) in [("truncated", "Content-Length: 100", "abc"), ("chunk-truncated", "Transfer-Encoding: chunked", "3\r\nabc\r\n"), ("conflict", "Content-Length: 3\r\nTransfer-Encoding: chunked", "0\r\n\r\n"), ("overflow", "Content-Length: 18446744073709551616", "abc"), ("extra", "Content-Length: 1", "abc")] {
            let socket = try Socket(port: port)
            try socket.send("PUT /files/\(name) HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\n\(framing)\r\n\r\n\(body)")
            shutdown(socket.fd, SHUT_WR)
            let response = socket.response()
            try check(!response.hasPrefix("HTTP/1.1 201") && !manager.fileExists(atPath: shared.appendingPathComponent(name).path), "incomplete/framing rejected \(name)")
        }
        let replaced = shared.appendingPathComponent("replaced")
        try manager.createDirectory(at: replaced, withIntermediateDirectories: false)
        let held = try Socket(port: port)
        try held.send("PUT /files/replaced/sentinel HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nContent-Length: 6\r\n\r\nabc")
        try await Task.sleep(nanoseconds: 100_000_000)
        try manager.moveItem(at: replaced, to: shared.appendingPathComponent("old"))
        try manager.createSymbolicLink(at: replaced, withDestinationURL: root)
        try held.send("def")
        try check(!held.response().hasPrefix("HTTP/1.1 201"), "ancestor replacement prevents publish")
        let sentinelAfter = try Data(contentsOf: sentinel)
        #if os(iOS)
        XCTAssertEqual(sentinelAfter, sentinelBefore)
        #endif
        try check(sentinelAfter == sentinelBefore, "outside sentinel unchanged")
        let readonly = shared.appendingPathComponent("readonly")
        try manager.createDirectory(at: readonly, withIntermediateDirectories: false)
        try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readonly.path)
        let denied = try await request("PUT", "/files/readonly/denied", Data([1]))
        try check(denied.1.statusCode == 500 && !manager.fileExists(atPath: readonly.appendingPathComponent("denied").path), "real HTTP publication permission error")
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readonly.path)
        passed += try components(root: root, sourceBytes: sourceBytes, sentinel: sentinel)
        passed += try await lifecycle(port: port, shared: shared, service: service)
        passed += try await chunkEndings(root: root.appendingPathComponent("chunk-endings"))
        passed += try await contentEncoding(root: root.appendingPathComponent("content-encoding"))
        return passed
    }

    @MainActor static func stopWithinDeadline(_ service: NetworkSharingService) async throws {
        let stopping = Task { try await service.stop() }
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if service.status == .stopped { break }
        }
        try require(service.status == .stopped && service.canStart, "stop finishes within two seconds")
        try await stopping.value
    }

    @MainActor static func chunkEndings(root: URL) async throws -> Int {
        let manager = FileManager.default
        var passed = 0
        for scenario in ["split", "disconnect", "stop"] {
            let shared = root.appendingPathComponent(scenario)
            try manager.createDirectory(at: shared, withIntermediateDirectories: true)
            let service = NetworkSharingService(root: root)
            try await service.start(folder: shared, mode: .browser)
            let port = service.listeningPort!
            let socket = try Socket(port: port)
            try socket.send("PUT /files/result HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n0\r\n")
            try await Task.sleep(nanoseconds: 100_000_000)
            let target = shared.appendingPathComponent("result")
            try require(!manager.fileExists(atPath: target.path), "zero chunk without final CRLF is not published: \(scenario)")
            passed += 1
            if scenario == "split" {
                try socket.send("\r\n")
                try require(socket.response().hasPrefix("HTTP/1.1 201"), "split zero chunk completes after final CRLF")
                try require(try Data(contentsOf: target) == Data("abc".utf8), "split chunk exact published bytes")
                passed += 2
            } else if scenario == "disconnect" {
                shutdown(socket.fd, SHUT_WR)
                try require(socket.response().hasPrefix("HTTP/1.1 400"), "zero chunk disconnect rejects missing final CRLF")
                passed += 1
            }
            try await stopWithinDeadline(service)
            passed += 1
            try require(try manager.contentsOfDirectory(atPath: shared.path).allSatisfy { !$0.hasPrefix(".shu-network-") }, "zero chunk stop clears staging: \(scenario)")
            passed += 1
            if scenario != "split" {
                try require(!manager.fileExists(atPath: target.path), "incomplete zero chunk never publishes: \(scenario)")
                passed += 1
            }
            if scenario == "stop" {
                try require(!socket.response().hasPrefix("HTTP/1.1 201"), "stopped zero chunk cannot succeed")
                passed += 1
            }
        }
        return passed
    }

    @MainActor static func contentEncoding(root: URL) async throws -> Int {
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let service = NetworkSharingService(root: root)
        try await service.start(folder: root, mode: .browser)
        let port = service.listeningPort!
        let truncatedGzip = Data(base64Encoded: "H4sIAAAAAAAC/ytILCrJTMxRSElNzk9JTVFIzs8rSc0rKQYA")!
        var passed = 0
        for (name, encoding, body) in [("empty", "gzip", Data()), ("truncated", "gzip", truncatedGzip), ("mixed", "GZip", truncatedGzip), ("unknown", "br", Data([1]))] {
            let socket = try Socket(port: port)
            var wire = Data("PUT /files/\(name) HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nContent-Encoding: \(encoding)\r\nContent-Length: \(body.count)\r\n\r\n".utf8)
            wire.append(body)
            try socket.send(wire)
            try require(socket.response().hasPrefix("HTTP/1.1 415"), "unsupported encoding rejected before decoding: \(name)")
            let stage = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix(".shu-network-") }!
            try require(!manager.fileExists(atPath: root.appendingPathComponent(name).path) && (try manager.contentsOfDirectory(atPath: stage.path)).isEmpty, "encoding failure leaves no published or staged bytes: \(name)")
            let probe = try Socket(port: port)
            try probe.send("GET /api/list HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\n\r\n")
            try require(probe.response().hasPrefix("HTTP/1.1 200"), "service survives rejected encoding: \(name)")
            passed += 3
        }
        let identity = try Socket(port: port)
        try identity.send("PUT /files/identity HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nContent-Encoding: IdEnTiTy\r\nContent-Length: 3\r\n\r\nabc")
        try require(identity.response().hasPrefix("HTTP/1.1 201") && (try Data(contentsOf: root.appendingPathComponent("identity"))) == Data("abc".utf8), "identity encoding preserves bytes")
        passed += 1
        try await stopWithinDeadline(service)
        try require(try manager.contentsOfDirectory(atPath: root.path) == ["identity"], "encoding failure stop removes session")
        return passed + 2
    }

    @MainActor static func lifecycle(port: UInt16, shared: URL, service: NetworkSharingService) async throws -> Int {
        let manager = FileManager.default
        var passed = 0
        func check(_ condition: Bool, _ message: String) throws { try require(condition, message); passed += 1 }
        let chunked = try Socket(port: port)
        try chunked.send("PUT /files/chunked HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n2\r\nde\r\n0\r\n\r\n")
        try check(chunked.response().hasPrefix("HTTP/1.1 201") && (try Data(contentsOf: shared.appendingPathComponent("chunked"))) == Data("abcde".utf8), "complete chunked exact bytes")
        let streaming = try Socket(port: port)
        try streaming.send("PUT /files/streaming HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nTransfer-Encoding: chunked\r\n\r\n100000\r\n" + String(repeating: "x", count: 65536))
        try await Task.sleep(nanoseconds: 100_000_000)
        let stageDirectories = try manager.contentsOfDirectory(at: shared, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix(".shu-network-") }
        let partialFiles = try manager.contentsOfDirectory(at: stageDirectories[0], includingPropertiesForKeys: [.fileSizeKey])
        try check(try partialFiles.contains { (try $0.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 }, "chunk bytes stream to disk before entire chunk arrives")
        shutdown(streaming.fd, SHUT_RDWR)
        let cancelled = try Socket(port: port)
        try cancelled.send("PUT /files/cancelled HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nContent-Length: 999999\r\n\r\npartial")
        shutdown(cancelled.fd, SHUT_RDWR)
        try await Task.sleep(nanoseconds: 100_000_000)
        try check(!manager.fileExists(atPath: shared.appendingPathComponent("cancelled").path), "client upload cancellation")
        let large = shared.appendingPathComponent("large")
        let largeFD = open(large.path, O_CREAT | O_WRONLY | O_EXCL, 0o600)
        try require(largeFD >= 0 && ftruncate(largeFD, 32 * 1024 * 1024) == 0, "large download setup")
        close(largeFD)
        let download = try Socket(port: port)
        try download.send("GET /files/large HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\n\r\n")
        var received = [UInt8](repeating: 0, count: 1024)
        try check(recv(download.fd, &received, received.count, 0) > 0, "download starts before interruption")
        shutdown(download.fd, SHUT_RDWR)
        let active = try Socket(port: port)
        try active.send("PUT /files/interrupted HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nContent-Length: 1000000\r\n\r\npartial")
        try await Task.sleep(nanoseconds: 100_000_000)
        let stages = try manager.contentsOfDirectory(at: shared, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix(".shu-network-") }
        try check(stages.count == 1 && !(try manager.contentsOfDirectory(atPath: stages[0].path)).isEmpty, "real staging exists before stop")
        do {
            async let stop1: Void = service.stop()
            async let stop2: Void = service.stop()
            try await stop1; try await stop2
        }
        try check(!manager.fileExists(atPath: shared.appendingPathComponent("interrupted").path), "stop does not publish partial file")
        try check(try manager.contentsOfDirectory(atPath: shared.path).allSatisfy { !$0.hasPrefix(".shu-network-") }, "stop removes staging")
        var refused = false
        do { _ = try Socket(port: port) } catch { refused = true }
        try check(refused, "new connections refused after stop")
        try? active.send("late bytes")
        try check(!active.response().hasPrefix("HTTP/1.1 201"), "old request cannot publish")
        for _ in 0..<3 {
            try await service.start(folder: shared, mode: .browser)
            try check(service.status == .running && !service.canStart, "restart independent session")
            try await service.stop()
            try check(service.status == .stopped && service.canStart, "restart fully stopped")
        }
        try await service.start(folder: shared, mode: .browser)
        try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: shared.path)
        var cleanupFailed = false
        do { try await service.stop() } catch { cleanupFailed = true }
        try check(cleanupFailed && !service.canStart, "cleanup permission failure retains failed session")
        if case .failed(let reason) = service.status { try check(!reason.isEmpty, "cleanup failure reason") }
        else { try require(false, "cleanup reports failed state") }
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: shared.path)
        try await service.stop()
        try check(service.canStart && service.status == .stopped, "cleanup retry releases session")
        try await service.stop()
        try require(service.status == .stopped && service.canStart, "stop releases session")
        return passed + 1
    }
}

#if !os(iOS)
@main struct NetworkSmoke {
    @MainActor static func main() async {
        do {
            let root = URL(fileURLWithPath: CommandLine.arguments[1])
            let passed: Int
            switch CommandLine.arguments[2] {
            case "serve-dav":
                _ = try FileStore(root: root)
                let service = NetworkSharingService(root: root)
                try await service.start(folder: root, mode: .webDAV)
                FileHandle.standardOutput.write(Data("NETWORK_CURL_URL http://127.0.0.1:\(service.listeningPort!)/\n".utf8))
                try await Task.sleep(for: .seconds(60))
                try await service.stop(); return
            case "assets": passed = try await NetworkChecks.assets(root: root)
            case "dav": passed = try await NetworkChecks.dav(root: root)
            case "move-boundary": passed = try await NetworkChecks.moveBoundary(root: root)
            case "stop-copy": passed = try await NetworkChecks.stopDuringCopy(root: root)
            case "download-safety": passed = try await NetworkChecks.downloadSafety(root: root)
            case "chunk-endings": passed = try await NetworkChecks.chunkEndings(root: root)
            case "content-encoding": passed = try await NetworkChecks.contentEncoding(root: root)
            case "http": passed = try await NetworkChecks.http(root: root)
            default: throw NSError(domain: "NetworkChecks", code: 3)
            }
            print("NETWORK_HTTP_RESULT {\"passed\":\(passed),\"failed\":0,\"skipped\":0}")
        } catch {
            print("NETWORK_HTTP_FAILED: \(error.localizedDescription)")
            exit(1)
        }
    }
}
#endif
