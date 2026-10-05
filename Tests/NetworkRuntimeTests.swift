import XCTest
import WebKit
import CoreImage
@testable import ShuReplica

@MainActor private final class BrowserConfirmation: NSObject, WKUIDelegate {
    var confirmations = 0
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        confirmations += 1; completionHandler(true)
    }
}

final class NetworkRuntimeTests: XCTestCase {
    @MainActor func testAddressesAndQRCode() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("network-addresses-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try FileStore(root: root)
        let service = NetworkSharingService(root: root)
        try await service.start(folder: root, mode: .browser)
        let addresses = try NetworkSharingAddresses.urls(port: service.listeningPort!)
        XCTAssertEqual(Set(addresses), Set(service.accessURLs))
        let urls = addresses + [URL(string: "http://127.0.0.1:\(service.listeningPort!)/")!]
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        for url in urls {
            XCTAssertEqual(url.port, Int(service.listeningPort!))
            let image = try NetworkSharingQRCode.image(for: url)
            let features = detector.features(in: CIImage(cgImage: image)).compactMap { $0 as? CIQRCodeFeature }
            XCTAssertEqual(features.first?.messageString, url.absoluteString)
            let (data, response) = try await URLSession.shared.data(from: url)
            XCTAssertEqual((response as! HTTPURLResponse).statusCode, 200, "\(url.absoluteString)：\(String(decoding: data, as: UTF8.self))")
        }
        let previousPort = service.listeningPort!
        try await service.stop()
        XCTAssertTrue(service.accessURLs.isEmpty); XCTAssertTrue(service.canStart)
        XCTAssertThrowsError(try NetworkChecks.Socket(port: previousPort))
        print("NETWORK_ADDRESSES_RESULT {\"passed\":\(urls.count),\"failed\":0,\"skipped\":0}")
    }
    func testDAVAndBrowserAssets() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("network-dav-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let dav = try await NetworkChecks.dav(root: root)
        let assets = try await NetworkChecks.assets(root: root.appendingPathComponent("assets"))
        XCTAssertGreaterThan(dav, 20); XCTAssertEqual(assets, 13)
        print("NETWORK_DAV_RESULT {\"passed\":\(dav + assets),\"failed\":0,\"skipped\":0}")
    }
    func testCopyCancellation() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("network-cancel-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let passed = try await NetworkChecks.stopDuringCopy(root: root)
        XCTAssertEqual(passed, 5)
    }
    @MainActor func testBrowserJavaScriptAndActualUploads() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("network-browser-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try FileStore(root: root)
        let special = "<b>& 中文" + String(repeating: "长", count: 50) + ".txt"
        try Data("特殊名称内容".utf8).write(to: root.appendingPathComponent(special))
        let service = NetworkSharingService(root: root)
        try await service.start(folder: root, mode: .browser)
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let confirmation = BrowserConfirmation(); web.uiDelegate = confirmation
        let base = URL(string: "http://127.0.0.1:\(service.listeningPort!)/")!
        web.load(URLRequest(url: base))
        func js(_ script: String) async throws -> Any? {
            try await withCheckedThrowingContinuation { continuation in
                web.evaluateJavaScript(script) { value, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: value) }
                }
            }
        }
        func wait(_ expression: String) async throws {
            for _ in 0..<200 {
                if (try? await js(expression)) as? Bool == true { return }
                try await Task.sleep(for: .milliseconds(100))
            }
            let state = try await js("JSON.stringify({status:document.querySelector('#status')?.textContent, files:document.querySelector('#files')?.files.length, uploads:document.querySelector('#uploads')?.textContent, results:Array.from(document.querySelectorAll('#uploads [data-result]')).map(row=>row.dataset.result)})")
            print("BROWSER_FAILURE_STATE \(String(describing: state))")
            XCTFail("浏览器行为超时：\(expression)")
            throw NSError(domain: "BrowserChecks", code: 1)
        }
        try await wait("document.querySelectorAll('#entries li').length === 12")
        let pickerReady = try await js("!document.querySelector('#files').disabled") as? Bool
        let folderTitle = try await js("document.querySelector('#folder-title')?.textContent") as? String
        let icons = try await js("document.querySelectorAll('#entries svg').length") as? Int
        let fitsPhone = try await js("document.documentElement.scrollWidth <= innerWidth") as? Bool
        let touchTarget = try await js("document.querySelector('#refresh').getBoundingClientRect().height >= 44") as? Bool
        XCTAssertEqual(pickerReady, true)
        XCTAssertEqual(folderTitle, "首页")
        XCTAssertEqual(icons, 24)
        XCTAssertEqual(fitsPhone, true)
        XCTAssertEqual(touchTarget, true)
        let injectedElements = try await js("document.querySelector('#entries').querySelectorAll('b').length") as? Int
        XCTAssertEqual(injectedElements, 0)
        let names = try await js("Array.from(document.querySelectorAll('#entries li')).map(row => row.dataset.name)") as! [String]
        XCTAssertEqual(Set(names), Set(WorkspaceCategory.allCases.map(\.rawValue) + ["Downloads", "共享", special]))
        let downloadLink = try await js("Array.from(document.querySelectorAll('#entries a')).find(a=>a.textContent==='下载').getAttribute('href')") as? String
        XCTAssertEqual(downloadLink, "#Downloads")
        _ = try await js("document.querySelector('#new-folder summary').click(); document.querySelector('#folder-name').focus(); document.querySelector('#folder-name').value='网页目录'; document.querySelector('#create').requestSubmit()")
        try await wait("Array.from(document.querySelectorAll('#entries li')).some(row=>row.dataset.name==='网页目录')")
        let focusRestored = try await js("document.activeElement === document.querySelector('#new-folder summary') && !document.querySelector('#new-folder').open") as? Bool
        XCTAssertEqual(focusRestored, true)
        _ = try await js("location.hash=encodeURIComponent('网页目录')")
        try await wait("document.querySelector('#breadcrumbs').textContent.includes('网页目录') && document.querySelector('#entries').children.length===0")
        _ = try await js("const transfer=new DataTransfer(); transfer.items.add(new File(['真实页面上传'], '中文 空格.txt')); transfer.items.add(new File([], 'empty.txt')); transfer.items.add(new File([new Uint8Array(4194304).fill(37)], 'progress.bin')); document.querySelector('#files').files=transfer.files; document.querySelector('#files').dispatchEvent(new Event('change', {bubbles:true}))")
        try await wait("document.querySelectorAll('#uploads [data-result=success]').length===3")
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("网页目录/中文 空格.txt")), Data("真实页面上传".utf8))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("网页目录/empty.txt")).count, 0)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("网页目录/progress.bin")), Data(repeating: 37, count: 4194304))
        let progressEvent = try await js("document.querySelectorAll('#uploads progress[data-event=progress]').length > 0") as? Bool
        XCTAssertEqual(progressEvent, true)
        try await wait("!document.querySelector('#files').disabled && document.querySelector('#files').files.length===0")
        _ = try await js("const retry=new DataTransfer(); retry.items.add(new File(['真实页面上传'], '中文 空格.txt')); retry.items.add(new File([], 'empty.txt')); retry.items.add(new File([new Uint8Array(4194304).fill(37)], 'progress.bin')); document.querySelector('#files').files=retry.files; document.querySelector('#files').dispatchEvent(new Event('change', {bubbles:true}))")
        try await wait("document.querySelectorAll('#uploads [data-result=error]').length===3")
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("网页目录/中文 空格.txt")), Data("真实页面上传".utf8))
        _ = try await js("Array.from(document.querySelectorAll('#entries li')).find(row=>row.dataset.name==='empty.txt').querySelector('button').click()")
        try await wait("!Array.from(document.querySelectorAll('#entries li')).some(row=>row.dataset.name==='empty.txt')")
        XCTAssertEqual(confirmation.confirmations, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("网页目录/empty.txt").path))
        web.frame = CGRect(x: 0, y: 0, width: 1100, height: 800)
        try await wait("innerWidth === 1100")
        let fitsDesktop = try await js("document.documentElement.scrollWidth <= innerWidth") as? Bool
        XCTAssertEqual(fitsDesktop, true)
        _ = try await js("document.querySelector('#skip-files').click()")
        let sameFolder = try await js("location.hash === '#' + encodeURIComponent('网页目录') && document.activeElement.id === 'entries'") as? Bool
        XCTAssertEqual(sameFolder, true)
        try await service.stop()
        print("NETWORK_BROWSER_RESULT {\"result\":\"passed\",\"scenario\":\"automatic-upload\"}")
    }
    func testHTTPFilesAndStop() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("network-http-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let passed = try await NetworkChecks.http(root: root)
        XCTAssertGreaterThan(passed, 0)
        print("NETWORK_HTTP_RESULT {\"passed\":\(passed),\"failed\":0,\"skipped\":0}")
    }
}
