import Foundation
import AVFoundation
import CryptoKit
#if os(iOS)
@testable import Happu
#else
@testable import ShuServices
#endif

enum VideoChecks {
    static let manager = FileManager.default
    static func require(_ value: Bool, _ message: String) throws {
        guard value else { throw MediaError("ASSERTION: " + message) }
    }

    static func audio(_ url: URL, rate: Double = 48000, seconds: Double = 3, scale: Double = 1) throws {
        let pcm = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false], commonFormat: .pcmFormatFloat32, interleaved: false)
        let count = Int(seconds * rate)
        for start in stride(from: 0, to: count, by: 4096) {
            let n = min(4096, count - start), buffer = AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: AVAudioFrameCount(n))!
            buffer.frameLength = AVAudioFrameCount(n)
            for i in 0..<n {
                let time = Double(start + i) / rate
                buffer.floatChannelData![0][i] = Float(0.3 * sin(2 * .pi * 440 * scale * (time < seconds / 2 ? 1 : 1.5) * time))
            }
            try file.write(from: buffer)
        }
        if #available(macOS 15, iOS 18, *) { file.close() }
    }

    static func verifyAudio(_ url: URL, rate: Double, seconds: Double, offset: Double = 0, sourceSeconds: Double = 3, scale: Double = 1, silence: Double = 0) throws {
        let file = try AVAudioFile(forReading: url)
        try require(file.processingFormat.sampleRate == rate && file.processingFormat.channelCount == 1, "audio format")
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096)!
        var samples: [Float] = []
        while file.framePosition < file.length { try file.read(into: buffer); samples.append(contentsOf: UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))) }
        try require(abs(Double(samples.count) / rate - seconds) < 0.15, "audio duration")
        if silence > 0 { try require(samples.prefix(Int((silence - 0.03) * rate)).allSatisfy { abs($0) < 0.001 }, "leading silence lost") }
        let window = min(0.1, (seconds - silence) / 8)
        var checked = 0
        for time in [window + silence, seconds - window * 2] where time >= silence && time + window < seconds {
            let hz = 440 * scale * (time + offset - silence < sourceSeconds / 2 ? 1 : 1.5)
            let start = Int(time * rate), count = Int(rate * window)
            try require(count > 0 && start + count <= samples.count, "signal window must be present")
            var re = 0.0, im = 0.0, energy = 0.0
            for i in 0..<count {
                let value = Double(samples[start + i]), phase = 2 * .pi * hz * Double(i) / rate
                re += value * cos(phase); im += value * sin(phase); energy += value * value
            }
            try require(sqrt(2 * (re * re + im * im) / (Double(count) * max(energy, 1e-12))) > 0.9, "audio segment signal changed")
            checked += 1
        }
        try require(checked > 0, "audio signal must actually be checked")
    }

    static func fixture(_ url: URL, width: Int = 96, height: Int = 64, rotated: Bool = false, frames: Int = 30, offset: Double = 0, codec: AVVideoCodecType = .h264) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: codec, AVVideoWidthKey: width, AVVideoHeightKey: height])
        if rotated { input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: CGFloat(height), ty: 0) }
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
        writer.add(input)
        try require(writer.startWriting(), "fixture start")
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData {
                try require(writer.status == .writing, "fixture writer failed")
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            var pixel: CVPixelBuffer?
            try require(CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &pixel) == kCVReturnSuccess, "fixture pixel")
            CVPixelBufferLockBaseAddress(pixel!, [])
            let rowBytes = CVPixelBufferGetBytesPerRow(pixel!)
            let bytes = CVPixelBufferGetBaseAddress(pixel!)!.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    let i = y * rowBytes + x * 4
                    bytes[i] = frame < frames / 2 ? 20 : 220
                    bytes[i + 1] = x < width / 2 ? 35 : 180
                    bytes[i + 2] = frame < frames / 2 ? 220 : 20
                    bytes[i + 3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(pixel!, [])
            try require(adapter.append(pixel!, withPresentationTime: CMTime(seconds: offset + Double(frame) / 10, preferredTimescale: 600)), "fixture append")
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: offset + Double(frames) / 10, preferredTimescale: 600))
        await writer.finishWriting()
        try require(writer.status == .completed, "fixture finish \(String(describing: writer.error))")
    }

    static func mux(_ video: URL, audios: [URL], offsets: [Double], at url: URL) async throws {
        let composition = AVMutableComposition()
        let asset = AVURLAsset(url: video)
        let source = try await asset.loadTracks(withMediaType: .video)[0]
        let target = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        try target.insertTimeRange(try await source.load(.timeRange), of: source, at: .zero)
        target.preferredTransform = try await source.load(.preferredTransform)
        for (i, url) in audios.enumerated() {
            let audioAsset = AVURLAsset(url: url)
            let track = try await audioAsset.loadTracks(withMediaType: .audio)[0]
            let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
            try audio.insertTimeRange(try await track.load(.timeRange), of: track, at: CMTime(seconds: offsets[i], preferredTimescale: 600))
            withExtendedLifetime(audioAsset) { }
        }
        let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)!
        export.outputURL = url; export.outputFileType = .mov
        await export.export()
        try require(export.status == .completed, "fixture mux \(String(describing: export.error))")
    }

    static func frame(_ url: URL, time: Double) throws -> (Int, Int, Double, Double, Double, Double) {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.11, preferredTimescale: 600)
        let image = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let a = (image.height / 4 * image.width + image.width / 4) * 4
        let b = (image.height * 3 / 4 * image.width + image.width * 3 / 4) * 4
        return (image.width, image.height, Double(bytes[a]), Double(bytes[a + 2]), Double(bytes[a + 1]), Double(bytes[b + 1]))
    }

    static func verify(_ url: URL, width: Int, height: Int, seconds: Double, audioCount: Int, late: Bool = false) async throws {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        try require(abs(duration - seconds) <= 0.12, "duration \(duration) expected \(seconds)")
        let audios = try await asset.loadTracks(withMediaType: .audio)
        try require(audios.count == audioCount, "audio count \(audios.count) expected \(audioCount)")
        let first = try frame(url, time: min(0.2, seconds / 4))
        try require(first.0 == width && first.1 == height, "display size \(first.0)x\(first.1) expected \(width)x\(height)")
        try require(late ? first.3 > first.2 + 100 : first.2 > first.3 + 100, "video time/color changed")
        try require(abs(first.4 - first.5) > 80, "spatial orientation marker lost")
        if seconds > 2 {
            let last = try frame(url, time: seconds - 0.3)
            try require(last.3 > last.2 + 100, "last frame content")
        }
    }

    static func compressedVideo(_ url: URL) async throws -> SHA256.Digest {
        let asset = AVURLAsset(url: url)
        let reader = try AVAssetReader(asset: asset), track = try await asset.loadTracks(withMediaType: .video)[0]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output); try require(reader.startReading(), "compressed reader start")
        var hash = SHA256(), count = 0
        while let sample = output.copyNextSampleBuffer() {
            if CMSampleBufferGetNumSamples(sample) == 0 { continue }
            guard let block = CMSampleBufferGetDataBuffer(sample) else { throw MediaError("ASSERTION: compressed frame missing data") }
            var bytes = Data(count: CMBlockBufferGetDataLength(block))
            let status = bytes.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!) }
            try require(status == noErr, "compressed sample bytes")
            hash.update(data: bytes)
            count += 1
        }
        try require(reader.status == .completed && count > 0, "compressed reader complete with video frames")
        return hash.finalize()
    }

    static func codecs(root: URL) async throws -> Int {
        try manager.createDirectory(at: root.appendingPathComponent("outputs"), withIntermediateDirectories: true)
        let folder = root.appendingPathComponent("outputs"), service = VideoService(root: root)
        let silent = root.appendingPathComponent("silent.mov")
        try await fixture(silent, rotated: true)
        let audio = root.appendingPathComponent("audio.wav")
        try self.audio(audio)
        let input = root.appendingPathComponent("input.mov")
        try await mux(silent, audios: [audio], offsets: [0], at: input)
        var passed = 0
        for format in VideoFormat.allCases {
            let output = try await service.process(input, operation: .convert, to: format, quality: .high, audioTrackIDs: nil, in: folder, named: "container-" + format.rawValue, progress: Progress())
            try require(output.pathExtension == format.rawValue, "container extension")
            try await verify(output, width: 64, height: 96, seconds: 3, audioCount: 1)
            let audioOutput = try await AudioService(root: root).convert(output, to: .wav, trackID: nil, downmixToStereo: false, in: folder, named: "decode-" + format.rawValue, progress: Progress())
            try verifyAudio(audioOutput, rate: 48000, seconds: 3)
            passed += 1; print("VIDEO_CONTAINER_PASS \(format.rawValue)")
        }
        for quality in VideoQuality.allCases {
            let output = try await service.process(silent, operation: .convert, to: .mov, quality: quality, audioTrackIDs: nil, in: folder, named: "silent-\(passed)", progress: Progress())
            try await verify(output, width: 64, height: 96, seconds: 3, audioCount: 0)
            if quality == .original { try require(try await compressedVideo(output) == compressedVideo(silent), "compatible original re-encoded") }
            passed += 1
        }
        let mute = try await service.process(input, operation: .removeAudio, to: .mp4, quality: .original, audioTrackIDs: [999], in: folder, named: "mute", progress: Progress())
        try await verify(mute, width: 64, height: 96, seconds: 3, audioCount: 0)
        try require(try await compressedVideo(mute) == compressedVideo(input), "original mute re-encoded compatible retained video")
        passed += 1
        for (start, end) in [(0.0, 1.1), (1.8, 3.0), (0.13, 0.38), (1.4, 1.7)] {
            let trimmed = try await service.process(input, operation: .trim(start: start, end: end), to: .mp4, quality: .medium, audioTrackIDs: nil, in: folder, named: "trim-\(passed)", progress: Progress())
            try await verify(trimmed, width: 64, height: 96, seconds: end - start, audioCount: 1, late: start > 1.5)
            let trimmedAsset = AVURLAsset(url: trimmed)
            let track = try await trimmedAsset.loadTracks(withMediaType: .video)[0]
            try require(abs(try await track.load(.timeRange).start.seconds) < 0.11, "trim starts at zero")
            withExtendedLifetime(trimmedAsset) { }
            let decoded = try await AudioService(root: root).convert(trimmed, to: .wav, trackID: nil, downmixToStereo: false, in: folder, named: "trim-audio-\(passed)", progress: Progress())
            try verifyAudio(decoded, rate: 48000, seconds: end - start, offset: start)
            passed += 1
        }
        print("VIDEO_CODECS_RESULT \(passed)")
        return passed
    }

    static func extended(root: URL, incompatibleFixture: URL? = nil) async throws {
        let folder = root.appendingPathComponent("outputs"), service = VideoService(root: root)
        let large = root.appendingPathComponent("large.mov")
        try await fixture(large, width: 2002, height: 1002, frames: 10)
        for (quality, width, height) in [(VideoQuality.high, 1920, 960), (.medium, 1280, 640), (.low, 640, 320)] {
            let output = try await service.process(large, operation: .convert, to: .mp4, quality: quality, audioTrackIDs: nil, in: folder, named: "large-\(width)", progress: Progress())
            try await verify(output, width: width, height: height, seconds: 1, audioCount: 0)
        }
        let sound = root.appendingPathComponent("short.wav")
        try audio(sound, rate: 44100, seconds: 1)
        let delayed = root.appendingPathComponent("delayed.mov")
        try await mux(root.appendingPathComponent("silent.mov"), audios: [sound], offsets: [1], at: delayed)
        let output = try await service.process(delayed, operation: .convert, to: .mov, quality: .high, audioTrackIDs: nil, in: folder, named: "delayed", progress: Progress())
        let outputAsset = AVURLAsset(url: output)
        let track = try await outputAsset.loadTracks(withMediaType: .audio)[0]
        let range = try await track.load(.timeRange)
        try require(abs(range.end.seconds - 2) < 0.05, "short/delayed audio extended to video duration \(range)")
        withExtendedLifetime(outputAsset) { }
        let delayedPCM = try await AudioService(root: root).convert(output, to: .wav, trackID: nil, downmixToStereo: false, in: folder, named: "delayed-pcm", progress: Progress())
        try verifyAudio(delayedPCM, rate: 44100, seconds: 2, sourceSeconds: 1, silence: 1)
        let other = root.appendingPathComponent("other.wav")
        try audio(other, rate: 44100, seconds: 1, scale: 2)
        let multi = root.appendingPathComponent("multi.mov")
        try await mux(root.appendingPathComponent("silent.mov"), audios: [sound, other], offsets: [0, 0.5], at: multi)
        let infos = try await service.info(multi)
        try require(infos.audioTracks.count == 2 && infos.width == 64 && infos.height == 96, "info tracks/rotation")
        let kept = try await service.process(multi, operation: .convert, to: .mov, quality: .high, audioTrackIDs: nil, in: folder, named: "multi", progress: Progress())
        try await verify(kept, width: 64, height: 96, seconds: 3, audioCount: 2)
        let chosen = try await service.process(multi, operation: .convert, to: .threeGP, quality: .medium, audioTrackIDs: [infos.audioTracks[1].id], in: folder, named: "chosen", progress: Progress())
        try await verify(chosen, width: 64, height: 96, seconds: 3, audioCount: 1)
        let chosenPCM = try await AudioService(root: root).convert(chosen, to: .wav, trackID: nil, downmixToStereo: false, in: folder, named: "chosen-pcm", progress: Progress())
        try verifyAudio(chosenPCM, rate: 44100, seconds: 1.5, sourceSeconds: 1, scale: 2, silence: 0.5)
        let offsetVideo = root.appendingPathComponent("video-offset.mov")
        try await fixture(offsetVideo, offset: 1)
        let offsetOutput = try await service.process(offsetVideo, operation: .convert, to: .mp4, quality: .medium, audioTrackIDs: nil, in: folder, named: "video-offset", progress: Progress())
        let offsetAsset = AVURLAsset(url: offsetOutput)
        try require(abs(try await offsetAsset.load(.duration).seconds - 4) < 0.12, "nonzero video timeline changed")
        let early = try frame(offsetOutput, time: 1.2), late = try frame(offsetOutput, time: 3.2)
        try require(early.2 > early.3 + 100 && late.3 > late.2 + 100, "nonzero video content shifted")
        try await incompatibleOriginal(root: root, fixture: incompatibleFixture)
        print("VIDEO_EXTENDED_PASS scaling/delayed/multiple-track-selection")
    }

    static func incompatibleOriginal(root: URL, fixture incompatibleFixture: URL?) async throws {
        let service = VideoService(root: root), folder = root.appendingPathComponent("outputs")
        let incompatible = root.appendingPathComponent(incompatibleFixture == nil ? "prores.mov" : "mjpeg.mov")
        let format: VideoFormat, sourceCodec: CMVideoCodecType
        if let incompatibleFixture {
            try manager.copyItem(at: incompatibleFixture, to: incompatible)
            format = .threeGP; sourceCodec = kCMVideoCodecType_JPEG
        } else {
            try await fixture(incompatible, width: 128, height: 128, codec: .proRes422)
            format = .mp4; sourceCodec = kCMVideoCodecType_AppleProRes422
        }
        let incompatibleAsset = AVURLAsset(url: incompatible)
        let incompatibleTrack = try await incompatibleAsset.loadTracks(withMediaType: .video)[0]
        let incompatibleDescription = try await incompatibleTrack.load(.formatDescriptions)[0]
        try require(CMFormatDescriptionGetMediaSubType(incompatibleDescription) == sourceCodec, "fixture must contain actual incompatible codec")
        let compatible = await AVAssetExportSession.compatibility(ofExportPreset: AVAssetExportPresetPassthrough, with: incompatibleAsset, outputFileType: format.fileType)
        try require(!compatible, "fixture must actually be incompatible with target passthrough")
        let recoded = try await service.process(incompatible, operation: .convert, to: format, quality: .original, audioTrackIDs: nil, in: folder, named: "incompatible-original", progress: Progress())
        let recodedAsset = AVURLAsset(url: recoded), recodedTrack = try await recodedAsset.loadTracks(withMediaType: .video)[0]
        let description = try await recodedTrack.load(.formatDescriptions)[0]
        try require(CMFormatDescriptionGetMediaSubType(description) == kCMVideoCodecType_H264, "incompatible original must encode H.264")
        withExtendedLifetime(recodedAsset) { }
        try await verify(recoded, width: 128, height: 128, seconds: 3, audioCount: 0)
        print("VIDEO_INCOMPATIBLE_PASS \(format.rawValue)")
    }

    static func boundaries(root: URL) async throws {
        let folder = root.appendingPathComponent("outputs"), service = VideoService(root: root), input = root.appendingPathComponent("input.mov")
        let sentinel = try Data(contentsOf: input)
        func reject(_ label: String, input source: URL? = nil, operation: VideoOperation = .convert, ids: [Int32]? = nil, name: String? = nil, destination: URL? = nil, progress: Progress = Progress()) async throws {
            do {
                _ = try await service.process(source ?? input, operation: operation, to: .mp4, quality: .medium, audioTrackIDs: ids, in: destination ?? folder, named: name ?? label, progress: progress)
            } catch {
                try require(try Data(contentsOf: input) == sentinel, "input changed after \(label)")
                try require(try manager.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".media-") }, "staging leaked after \(label)")
                print("VIDEO_REJECT_PASS \(label): \(error.localizedDescription)")
                return
            }
            throw MediaError("ASSERTION: accepted \(label)")
        }
        for (i, bounds) in [(-1.0, 1.0), (1, 1), (0, 4), (.nan, 1), (0, .infinity)].enumerated() { try await reject("range-\(i)", operation: .trim(start: bounds.0, end: bounds.1)) }
        try await reject("no-audio", input: root.appendingPathComponent("silent.mov"), operation: .removeAudio)
        try await reject("no-video", input: root.appendingPathComponent("audio.wav"))
        try await reject("missing", input: root.appendingPathComponent("missing.mov"))
        let bad = root.appendingPathComponent("bad.mov"); try Data("broken".utf8).write(to: bad)
        try await reject("broken", input: bad)
        try await reject("id", ids: [999])
        let id = try await service.info(input).audioTracks[0].id
        try await reject("duplicate", ids: [id, id])
        try await reject("bad-name", name: "../escape")
        try await reject("bad-folder", destination: input)
        let existing = folder.appendingPathComponent("existing.mp4"); try Data("sentinel".utf8).write(to: existing)
        let collision = try await service.process(input, operation: .convert, to: .mp4, quality: .medium, audioTrackIDs: nil, in: folder, named: "existing", progress: Progress())
        try require(collision != existing, "collision did not produce a separate file")
        try await verify(collision, width: 64, height: 96, seconds: 3, audioCount: 1)
        try require(try Data(contentsOf: existing) == Data("sentinel".utf8), "collision overwritten")
        let link = root.appendingPathComponent("link.mov"); try manager.createSymbolicLink(at: link, withDestinationURL: input)
        try await reject("symlink", input: link)
        try await reject("point", input: URL(fileURLWithPath: root.path + "/outputs/../input.mov"))
        let denied = root.appendingPathComponent("denied")
        try manager.createDirectory(at: denied, withIntermediateDirectories: false)
        try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: denied.path)
        try await reject("write-permission", destination: denied)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: denied.path)
        let cancelled = Progress(); cancelled.cancel()
        try await reject("cancelled", progress: cancelled)
        let progress = Progress()
        let task = Task { try await service.process(input, operation: .convert, to: .mp4, quality: .high, audioTrackIDs: nil, in: folder, named: "during-cancel", progress: progress) }
        let deadline = Date().addingTimeInterval(10)
        while progress.completedUnitCount == 0 && Date() < deadline { try await Task.sleep(nanoseconds: 100_000) }
        try require(progress.completedUnitCount > 0 && progress.completedUnitCount < progress.totalUnitCount, "cancellation must occur during actual processing")
        progress.cancel()
        do { _ = try await task.value; throw MediaError("ASSERTION: mid-operation cancellation published") }
        catch is CancellationError { }
        try require(!manager.fileExists(atPath: folder.appendingPathComponent("during-cancel.mp4").path), "cancel output leaked")
        try require(try manager.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".media-") }, "cancel staging leaked")
        let completionProgress = Progress()
        let observation = completionProgress.observe(\.completedUnitCount) { p, _ in
            if p.totalUnitCount > 0 && p.completedUnitCount == p.totalUnitCount { p.cancel() }
        }
        defer { observation.invalidate() }
        do {
            _ = try await service.process(input, operation: .convert, to: .mp4, quality: .medium, audioTrackIDs: nil, in: folder, named: "before-publish", progress: completionProgress)
            throw MediaError("ASSERTION: completion-boundary cancellation published")
        } catch is CancellationError { }
        try require(!manager.fileExists(atPath: folder.appendingPathComponent("before-publish.mp4").path), "completion cancel output leaked")
        print("VIDEO_BOUNDARIES_PASS")
    }
}

#if !os(iOS)
@main struct VideoSmoke {
    static func main() async {
        setbuf(stdout, nil)
        do {
            let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).standardizedFileURL
            try VideoChecks.require(!FileManager.default.fileExists(atPath: root.path), "fresh test root required")
            if CommandLine.arguments.count == 3 && CommandLine.arguments[2] == "--mjpeg-fixture" {
                try await VideoChecks.fixture(root, width: 128, height: 128, codec: .jpeg)
                print("MotionJPEG fixture generated")
                return
            }
            _ = try await VideoChecks.codecs(root: root)
            try await VideoChecks.extended(root: root)
            try await VideoChecks.incompatibleOriginal(root: root, fixture: URL(fileURLWithPath: "Tests/fixtures/video-mjpeg.mov"))
            try await VideoChecks.boundaries(root: root)
            print("VideoSmoke passed")
        } catch { FileHandle.standardError.write(Data("VideoSmoke FAILED: \(error)\n".utf8)); exit(1) }
    }
}
#endif
