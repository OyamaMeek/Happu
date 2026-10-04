import XCTest
@testable import ShuReplica

final class NetworkRuntimeTests: XCTestCase {
    func testHTTPFilesAndStop() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("network-http-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let passed = try await NetworkChecks.http(root: root)
        XCTAssertGreaterThan(passed, 0)
        print("NETWORK_HTTP_RESULT {\"passed\":\(passed),\"failed\":0,\"skipped\":0}")
    }
}
