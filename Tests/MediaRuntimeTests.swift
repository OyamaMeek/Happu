import XCTest
@testable import ShuReplica

final class MediaRuntimeTests: XCTestCase {
    func testAudioCodecs() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("audio-runtime-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let passed = try await AudioChecks.codecs(root: root)
        XCTAssertEqual(passed, 33)
        print("AUDIO_RUNTIME_RESULT {\"total\":33,\"passed\":\(passed),\"failed\":0,\"skipped\":0}")
    }
}
