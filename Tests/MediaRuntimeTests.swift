import XCTest
@testable import ShuReplica

final class MediaRuntimeTests: XCTestCase {
    func testVideoContainersAndEdits() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("video-runtime-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let passed = try await VideoChecks.codecs(root: root)
        XCTAssertEqual(passed, 13)
        let incompatible = try XCTUnwrap(Bundle(for: MediaRuntimeTests.self).url(forResource: "video-mjpeg", withExtension: "mov"))
        try await VideoChecks.extended(root: root, incompatibleFixture: incompatible)
        try await VideoChecks.boundaries(root: root)
        print("VIDEO_RUNTIME_RESULT {\"total\":13,\"passed\":\(passed),\"failed\":0,\"skipped\":0}")
    }

    func testAudioCodecs() async throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("audio-runtime-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let passed = try await AudioChecks.codecs(root: root)
        XCTAssertEqual(passed, 33)
        print("AUDIO_RUNTIME_RESULT {\"total\":33,\"passed\":\(passed),\"failed\":0,\"skipped\":0}")
    }
}
