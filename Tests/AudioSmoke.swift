import Foundation
import AVFoundation
#if os(iOS)
@testable import ShuReplica
#else
@testable import ShuServices
#endif

enum AudioChecks {
    static let manager = FileManager.default
    static func require(_ value: Bool, _ message: String) throws {
        guard value else { throw MediaError("ASSERTION: " + message) }
    }
    static func fixture(_ url: URL, rate: Double = 44100, channels: Int = 2, seconds: Double = 2, scale: Double = 1, bits: Int = 16, floating: Bool = false) throws {
        let layout = AVAudioChannelLayout(layoutTag: channels == 6 ? kAudioChannelLayoutTag_MPEG_5_1_A : (channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo))!
        let common: AVAudioCommonFormat = bits == 32 && !floating ? .pcmFormatInt32 : .pcmFormatFloat32
        let format = AVAudioFormat(commonFormat: common, sampleRate: rate, interleaved: false, channelLayout: layout)
        let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: channels, AVLinearPCMBitDepthKey: bits, AVLinearPCMIsFloatKey: floating, AVChannelLayoutKey: Data(bytes: layout.layout, count: MemoryLayout<AudioChannelLayout>.size)], commonFormat: common, interleaved: false)
        let count = Int(rate * seconds)
        for start in stride(from: 0, to: count, by: 4096) {
            let n = min(4096, count - start)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
            buffer.frameLength = AVAudioFrameCount(n)
            for c in 0..<channels {
                for i in 0..<n {
                    let t = Double(start + i) / rate
                    let hz = (channels == 6 ? [440.0, 880, 660, 60, 1100, 1320][c] : Double(c % 2 == 0 ? 440 : 880)) * scale * (t >= seconds / 2 ? 1.5 : 1)
                    let value = 0.3 * sin(2 * .pi * hz * t)
                    if common == .pcmFormatInt32 { buffer.int32ChannelData![c][i] = (Int32(value * 2147483648) & ~255) | 91 }
                    else { buffer.floatChannelData![c][i] = bits == 24 && start + i < 8 ? Float(Double(start + i + 1) / 8388608) : Float(value) }
                }
            }
            try file.write(from: buffer)
        }
        if #available(macOS 15, iOS 18, *) { file.close() }
    }
    static func decode(_ url: URL) throws -> (Double, [[Float]]) {
        let file = try AVAudioFile(forReading: url)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096)!
        let canonical = file.processingFormat.channelCount == 6 ? AVAudioFormat(standardFormatWithSampleRate: file.processingFormat.sampleRate, channelLayout: AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_MPEG_5_1_A)!) : file.processingFormat
        let converter = file.processingFormat == canonical ? nil : AVAudioConverter(from: file.processingFormat, to: canonical)
        let converted = AVAudioPCMBuffer(pcmFormat: canonical, frameCapacity: 4096)!
        var samples = Array(repeating: [Float](), count: Int(file.processingFormat.channelCount))
        while file.framePosition < file.length {
            try file.read(into: buffer)
            if let converter { try converter.convert(to: converted, from: buffer) }
            let pcm = converter == nil ? buffer : converted
            for c in samples.indices { samples[c].append(contentsOf: UnsafeBufferPointer(start: pcm.floatChannelData![c], count: Int(pcm.frameLength))) }
        }
        return (file.processingFormat.sampleRate, samples)
    }
    static func verify(_ url: URL, rate: Double, channels: Int, seconds: Double = 2, lossy: Bool, scale: Double = 1, timeOffset: Double = 0) throws {
        let (actualRate, samples) = try decode(url)
        if url.pathExtension == "wav" {
            let file = try AVAudioFile(forReading: url)
            let format = file.fileFormat
            try withExtendedLifetime(format) {
                let encoded = format.streamDescription.pointee
                try require(encoded.mFormatID == kAudioFormatLinearPCM && encoded.mBitsPerChannel == 16, "WAV must contain 16-bit PCM: \(encoded)")
            }
        }
        try require(actualRate == rate && samples.count == channels, "rate/channels changed for \(url.lastPathComponent): \(actualRate)/\(samples.count)")
        try require(abs(Double(samples[0].count) / rate - seconds) <= (lossy ? 0.15 : 0.001), "duration changed")
        for c in samples.indices {
            if timeOffset > 0 { try require(samples[c].prefix(Int(timeOffset * rate)).allSatisfy { abs($0) < 0.00001 }, "leading audio edit lost silence") }
            for (time, multiplier) in [(0.3 + timeOffset, 1.0), (1.3 + timeOffset, 1.5)] where time + 0.2 < seconds {
                let start = Int(time * rate), count = Int(0.2 * rate)
                let block = Array(samples[c][start..<(start + count)])
                let expected = (channels == 6 ? [440.0, 880, 660, 60, 1100, 1320][c] : Double(c % 2 == 0 ? 440 : 880)) * multiplier * scale
                var best = (frequency: 0.0, power: 0.0)
                for hz in stride(from: expected - 10, through: expected + 10, by: 1) {
                    var re = 0.0, im = 0.0, energy = 0.0
                    for i in block.indices {
                        let v = Double(block[i]), phase = 2 * .pi * hz * Double(i) / rate
                        re += v * cos(phase); im += v * sin(phase); energy += v * v
                    }
                    let correlation = sqrt(2 * (re * re + im * im) / (Double(count) * max(energy, 1e-12)))
                    if correlation > best.power { best = (hz, correlation) }
                }
                try require(abs(best.frequency - expected) <= 5 && best.power > 0.9, "signal \(url.lastPathComponent) c\(c) t\(time): \(best)")
            }
        }
    }
    static func verifyMix(_ url: URL, lossy: Bool) throws {
        let (rate, samples) = try decode(url)
        try require(rate == 44100 && samples.count == 2 && abs(Double(samples[0].count) / rate - 2) <= (lossy ? 0.15 : 0.001), "downmix rate/channel/duration")
        for channel in samples {
            for (time, multiplier) in [(0.3, 1.0), (1.3, 1.5)] {
                let count = 8820, start = Int(time * rate)
                let block = Array(channel[start..<(start + count)])
                let energy = block.reduce(0.0) { $0 + Double($1 * $1) }
                var power = 0.0
                for frequency in [440.0, 880.0, 660.0, 1100.0, 1320.0] {
                    var re = 0.0, im = 0.0
                    for i in block.indices {
                        let phase = 2 * .pi * frequency * multiplier * Double(i) / rate
                        re += Double(block[i]) * cos(phase); im += Double(block[i]) * sin(phase)
                    }
                    power += 2 * (re * re + im * im) / Double(count)
                }
                try require(energy > 1 && sqrt(power / energy) > 0.9, "downmix lost known segment content")
            }
        }
    }
    static func codecs(root: URL) async throws -> Int {
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let service = AudioService(root: root)
        let folder = root.appendingPathComponent("outputs")
        try manager.createDirectory(at: folder, withIntermediateDirectories: false)
        var passed = 0
        for rate in [44100.0, 48000.0] {
            for channels in [1, 2] {
                let input = root.appendingPathComponent("input-\(Int(rate))-\(channels).wav")
                try fixture(input, rate: rate, channels: channels)
                let original = try Data(contentsOf: input)
                for format in AudioFormat.allCases {
                    let progress = Progress()
                    let result = try await service.convert(input, to: format, bitRate: 192000, trackID: nil, downmixToStereo: false, in: folder, named: "\(Int(rate))-\(channels)-\(format.rawValue)", progress: progress)
                    try verify(result, rate: rate, channels: channels, lossy: [.m4a, .mp3].contains(format))
                    try require(progress.completedUnitCount == progress.totalUnitCount && progress.totalUnitCount > 0, "progress incomplete")
                    let back = try await service.convert(result, to: .wav, bitRate: 192000, trackID: nil, downmixToStereo: false, in: folder, named: "back-\(Int(rate))-\(channels)-\(format.rawValue)", progress: Progress())
                    try verify(back, rate: rate, channels: channels, lossy: true)
                    passed += 1
                    print("CODEC_PASS \(format.rawValue) \(Int(rate))Hz \(channels)ch roundtrip")
                }
                try require(Data(contentsOf: input) == original, "input changed")
            }
        }
        for format in [AudioFormat.m4a, .mp3] {
            for rate in [64000, 128000, 192000, 256000, 320000] {
                let result = try await service.convert(root.appendingPathComponent("input-44100-2.wav"), to: format, bitRate: rate, trackID: nil, downmixToStereo: false, in: folder, named: "bitrate-\(format)-\(rate)", progress: Progress())
                try verify(result, rate: 44100, channels: 2, lossy: true)
                passed += 1
                print("BITRATE_PASS \(format) \(rate)")
            }
        }
        let precise = root.appendingPathComponent("input-24bit.wav")
        try fixture(precise, channels: 1, bits: 24)
        let preciseFile = try AVAudioFile(forReading: precise)
        let preciseFormat = preciseFile.fileFormat
        try require(preciseFormat.streamDescription.pointee.mBitsPerChannel == 24, "precision fixture is not native 24-bit PCM")
        let encoded = try await service.convert(precise, to: .flac, trackID: nil, downmixToStereo: false, in: folder, named: "24bit-lossless", progress: Progress())
        let sourcePCM = try decode(precise), resultPCM = try decode(encoded)
        let below16 = sourcePCM.1[0].filter { abs($0) > 0 && abs($0) < 1 / 32768 }
        try require(below16.count >= 8, "24-bit fixture contains no nonzero samples below 16-bit LSB")
        print("PRECISION_INPUT \(preciseFormat) frames=\(sourcePCM.1[0].count) below16LSB=\(below16.count) first8=\(Array(sourcePCM.1[0].prefix(8)))")
        try require(sourcePCM.0 == resultPCM.0 && sourcePCM.1 == resultPCM.1, "FLAC changed 24-bit PCM samples")
        passed += 1
        print("PRECISION_PASS FLAC 24-bit complete PCM equality")
        for source in [AudioFormat.m4a, .mp3] {
            let input = folder.appendingPathComponent("44100-2-\(source.rawValue).\(source.rawValue)")
            let output = try await service.convert(input, to: .flac, trackID: nil, downmixToStereo: false, in: folder, named: "\(source.rawValue)-to-flac", progress: Progress())
            try verify(output, rate: 44100, channels: 2, lossy: true)
            passed += 1
            print("INPUT_FORMAT_PASS \(source.rawValue) to FLAC decoded signal")
        }
        for floating in [false, true] {
            let unsupported = root.appendingPathComponent(floating ? "float-PCM.wav" : "32bit-PCM.wav")
            try fixture(unsupported, channels: 1, bits: 32, floating: floating)
            let originalFile = try AVAudioFile(forReading: unsupported)
            let originalFormat = originalFile.fileFormat
            let originalDescription = originalFormat.streamDescription.pointee
            try require(originalDescription.mFormatID == kAudioFormatLinearPCM && originalDescription.mBitsPerChannel == 32 && (originalDescription.mFormatFlags & kAudioFormatFlagIsFloat != 0) == floating, "unsupported precision fixture metadata")
            let before = Set(try manager.contentsOfDirectory(atPath: folder.path))
            try await reject(floating ? "FLAC raw float PCM precision" : "FLAC native unsupported 32-bit PCM precision") {
                _ = try await service.convert(unsupported, to: .flac, trackID: nil, downmixToStereo: false, in: folder, named: "unsupported-precision", progress: Progress())
            }
            try require(Set(manager.contentsOfDirectory(atPath: folder.path)) == before && !manager.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".media-") }, "precision rejection published output or leaked staging")
        }
        return passed
    }
    static func video(_ url: URL, audios: [URL] = [], audioOffset: Double = 0, videoFrames: Int = 20) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 32, AVVideoHeightKey: 32])
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 32, kCVPixelBufferHeightKey as String: 32])
        writer.add(input)
        var audioInputs: [(AVAssetReader, AVAssetReaderTrackOutput, AVAssetWriterInput, Double)] = []
        for url in audios {
            let asset = AVURLAsset(url: url)
            let track = try await asset.loadTracks(withMediaType: .audio)[0]
            let hint = try await track.load(.formatDescriptions)[0]
            let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: hint)
            writer.add(audio)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            reader.add(output)
            audioInputs.append((reader, output, audio, try AVAudioFile(forReading: url).processingFormat.sampleRate))
        }
        try require(writer.startWriting(), "video fixture start")
        writer.startSession(atSourceTime: .zero)
        var pixel: CVPixelBuffer?
        try require(CVPixelBufferCreate(nil, 32, 32, kCVPixelFormatType_32BGRA, nil, &pixel) == kCVReturnSuccess, "video pixel allocation")
        CVPixelBufferLockBaseAddress(pixel!, [])
        memset(CVPixelBufferGetBaseAddress(pixel!), 127, CVPixelBufferGetDataSize(pixel!))
        CVPixelBufferUnlockBaseAddress(pixel!, [])
        for (reader, output, audio, rate) in audioInputs {
            try require(reader.startReading(), "fixture audio reader start")
            while let sample = output.copyNextSampleBuffer() {
                while !audio.isReadyForMoreMediaData {
                    try require(writer.status == .writing, "fixture audio writer failed")
                    await Task.yield()
                }
                var appended = sample
                if audioOffset != 0 {
                    if CMSampleBufferGetNumSamples(sample) == 0 { continue }
                    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: Int32(rate)), presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sample) + CMTime(seconds: audioOffset, preferredTimescale: Int32(rate)), decodeTimeStamp: .invalid)
                    var shifted: CMSampleBuffer?
                    try require(CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sample, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleBufferOut: &shifted) == noErr, "fixture audio offset")
                    appended = shifted!
                }
                try require(audio.append(appended), "fixture audio append \(String(describing: writer.error))")
            }
            try require(reader.status == .completed, "fixture audio reader completion")
            audio.markAsFinished()
        }
        for frame in 0..<videoFrames {
            while !input.isReadyForMoreMediaData {
                try require(writer.status == .writing, "video fixture writer failed")
                await Task.yield()
            }
            try require(adapter.append(pixel!, withPresentationTime: CMTime(value: Int64(frame), timescale: 10)), "video fixture append")
        }
        input.markAsFinished()
        await writer.finishWriting()
        try require(writer.status == .completed, "video fixture finish: \(String(describing: writer.error))")
    }
    static func selection(root: URL) async throws {
        let service = AudioService(root: root), folder = root.appendingPathComponent("outputs")
        let silent = root.appendingPathComponent("silent.mov")
        try await video(silent)
        try await reject("no audio video") { _ = try await service.tracks(silent) }
        let other = root.appendingPathComponent("other.wav")
        try fixture(other, channels: 1, scale: 2)
        for count in [1, 2] {
            let url = root.appendingPathComponent("video-\(count).mov")
            try await video(url, audios: Array([root.appendingPathComponent("input-44100-1.wav"), other].prefix(count)))
            let tracks = try await service.tracks(url)
            try require(tracks.count == count && tracks.allSatisfy { $0.channels == 1 && $0.sampleRate == 44100 }, "video track metadata")
            if count == 2 {
                try await reject("multiple tracks require ID") { _ = try await service.convert(url, to: .wav, trackID: nil, downmixToStereo: false, in: folder, named: "ambiguous", progress: Progress()) }
            }
            try await reject("missing track ID") { _ = try await service.convert(url, to: .wav, trackID: -999, downmixToStereo: false, in: folder, named: "missing-id", progress: Progress()) }
            for (index, track) in tracks.enumerated() {
                let result = try await service.convert(url, to: .wav, trackID: count == 1 ? nil : track.id, downmixToStereo: false, in: folder, named: "video-\(count)-track-\(index)", progress: Progress())
                try verify(result, rate: 44100, channels: 1, lossy: false, scale: Double(index + 1))
            }
        }
        let offset = root.appendingPathComponent("offset.mov")
        try await video(offset, audios: [root.appendingPathComponent("input-44100-1.wav")], audioOffset: 1, videoFrames: 40)
        let offsetTrack = try await AVURLAsset(url: offset).loadTracks(withMediaType: .audio)[0]
        let offsetRange = try await offsetTrack.load(.timeRange)
        print("OFFSET_FIXTURE start=\(offsetRange.start.seconds) duration=\(offsetRange.duration.seconds)")
        let offsetAssetDuration = try await AVURLAsset(url: offset).load(.duration).seconds
        try require(offsetRange.start.seconds == 0 && abs(offsetRange.duration.seconds - 3) < 0.001 && abs(offsetAssetDuration - 4) < 0.001, "fixture selected track/edit range")
        let offsetResult = try await service.convert(offset, to: .wav, trackID: nil, downmixToStereo: false, in: folder, named: "offset-track", progress: Progress())
        try verify(offsetResult, rate: 44100, channels: 1, seconds: 3, lossy: false, timeOffset: 1)
        let six = root.appendingPathComponent("six.wav")
        try fixture(six, channels: 6)
        for format in [AudioFormat.wav, .caf, .flac, .m4a] {
            let result = try await service.convert(six, to: format, trackID: nil, downmixToStereo: false, in: folder, named: "six-\(format)", progress: Progress())
            try verify(result, rate: 44100, channels: 6, lossy: format == .m4a)
        }
        try await reject("six MP3 needs explicit downmix") { _ = try await service.convert(six, to: .mp3, trackID: nil, downmixToStereo: false, in: folder, named: "six-mp3", progress: Progress()) }
        let downmixed = try await service.convert(six, to: .mp3, trackID: nil, downmixToStereo: true, in: folder, named: "six-stereo", progress: Progress())
        try verifyMix(downmixed, lossy: true)
        let downmixedFLAC = try await service.convert(folder.appendingPathComponent("six-flac.flac"), to: .wav, trackID: nil, downmixToStereo: true, in: folder, named: "flac-stereo", progress: Progress())
        try verifyMix(downmixedFLAC, lossy: false)
        let low = root.appendingPathComponent("low.wav")
        try fixture(low, rate: 8000, channels: 1)
        for format in [AudioFormat.wav, .caf, .flac, .mp3] {
            let result = try await service.convert(low, to: format, bitRate: 64000, trackID: nil, downmixToStereo: false, in: folder, named: "8k-\(format)", progress: Progress())
            try verify(result, rate: 8000, channels: 1, lossy: format == .mp3)
        }
        try await reject("8k MP3 192k unsupported") { _ = try await service.convert(low, to: .mp3, bitRate: 192000, trackID: nil, downmixToStereo: false, in: folder, named: "unsupported", progress: Progress()) }
        try await reject("8k AAC 192k unsupported") { _ = try await service.convert(low, to: .m4a, bitRate: 192000, trackID: nil, downmixToStereo: false, in: folder, named: "unsupported-aac", progress: Progress()) }
        let unusual = root.appendingPathComponent("50k.wav")
        try fixture(unusual, rate: 50000, channels: 1)
        try await reject("50k MP3 unsupported") { _ = try await service.convert(unusual, to: .mp3, trackID: nil, downmixToStereo: false, in: folder, named: "unsupported-rate", progress: Progress()) }
        print("SELECTION_PASS video single/multiple IDs; six channels and explicit system downmix; 8k and unsupported combinations")
    }
    static func reject(_ label: String, cancellation: Bool = false, _ operation: () async throws -> Void) async throws {
        do { try await operation() }
        catch {
            if cancellation { try require(error is CancellationError, "expected cancellation for \(label): \(error)") }
            print("REJECTION_PASS \(label): \(error.localizedDescription)")
            return
        }
        throw MediaError("ASSERTION: expected rejection \(label)")
    }
    static func boundaries(root: URL) async throws {
        let service = AudioService(root: root), workspace = MediaWorkspace(root: root)
        let input = root.appendingPathComponent("input-44100-2.wav"), folder = root.appendingPathComponent("outputs")
        func convert(_ url: URL = input, to format: AudioFormat = .wav, bits: Int = 192000, in destination: URL = folder, name: String = "invalid", progress: Progress = Progress()) async throws {
            _ = try await service.convert(url, to: format, bitRate: bits, trackID: nil, downmixToStereo: false, in: destination, named: name, progress: progress)
        }
        let sentinel = folder.appendingPathComponent("sentinel.wav"), bytes = try Data(contentsOf: input)
        try bytes.write(to: sentinel)
        let collision = try await service.convert(input, to: .wav, bitRate: 192000, trackID: nil, downmixToStereo: false, in: folder, named: "sentinel", progress: Progress())
        try require(collision.lastPathComponent == "sentinel 2.wav" && Data(contentsOf: sentinel) == bytes, "collision overwrote output")
        for name in ["", ".", "..", "a/b", "a\0b", "a\\b"] { try await reject("name \(name)") { try await convert(name: name) } }
        for bits in [0, 64001, -1] { try await reject("bitrate \(bits)") { try await convert(to: .mp3, bits: bits) } }
        let bad = root.appendingPathComponent("bad.wav")
        try Data("broken".utf8).write(to: bad)
        let empty = root.appendingPathComponent("empty.wav")
        try fixture(empty, seconds: 0)
        for url in [bad, empty, root, root.appendingPathComponent("missing.wav")] { try await reject("invalid input") { try await convert(url) } }
        let outside = root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent + "-outside")
        try manager.createDirectory(at: outside, withIntermediateDirectories: false)
        try bytes.write(to: outside.appendingPathComponent("input.wav"))
        let link = root.appendingPathComponent("link"), external = root.appendingPathComponent("external")
        try manager.createSymbolicLink(at: link, withDestinationURL: root)
        try manager.createSymbolicLink(at: external, withDestinationURL: outside)
        for url in [link.appendingPathComponent(input.lastPathComponent), external.appendingPathComponent("input.wav"), URL(fileURLWithPath: root.path + "/./" + input.lastPathComponent), URL(fileURLWithPath: root.path + "/link/../" + input.lastPathComponent), outside.appendingPathComponent("input.wav")] {
            try await reject("path input") { try await convert(url) }
            try await reject("track path") { _ = try await service.tracks(url) }
        }
        for destination in [link, external, outside, input, URL(fileURLWithPath: root.path + "/./outputs")] { try await reject("path output") { try await convert(in: destination) } }
        let before = Set(try manager.contentsOfDirectory(atPath: folder.path))
        for format in AudioFormat.allCases {
            for boundary in [0, 1, 2] {
                let progress = Progress()
                if boundary == 0 { progress.cancel() }
                let observation = progress.observe(\.completedUnitCount) { p, _ in
                    if boundary == 1 && p.completedUnitCount > 0 || boundary == 2 && p.completedUnitCount == p.totalUnitCount && p.totalUnitCount > 0 { p.cancel() }
                }
                try await reject("cancel \(format) \(boundary)", cancellation: true) { try await convert(to: format, progress: progress) }
                observation.invalidate()
                try require(Set(manager.contentsOfDirectory(atPath: folder.path)) == before, "cancel published output")
                try require(!manager.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".media-") }, "staging leaked")
            }
        }
        let denied = root.appendingPathComponent("denied")
        try manager.createDirectory(at: denied, withIntermediateDirectories: false)
        try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: denied.path)
        try await reject("write permission") { try await convert(in: denied) }
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: denied.path)
        try manager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: input.path)
        try await reject("read permission") { try await convert() }
        try manager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: input.path)
        var blocked: URL?
        try await reject("cleanup failure") {
            _ = try await workspace.withStaging(progress: Progress()) { staging in
                blocked = staging
                try Data("retained".utf8).write(to: staging.appendingPathComponent("sentinel"))
                try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: staging.path)
                throw MediaError("intentional real operation failure")
            }
        }
        try require(blocked != nil && manager.fileExists(atPath: blocked!.path), "cleanup failure hidden")
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: blocked!.path)
        try manager.removeItem(at: blocked!)
        try require(Data(contentsOf: input) == bytes && Set(manager.contentsOfDirectory(atPath: folder.path)) == before, "input/output changed")
    }
}

#if !os(iOS)
@main
struct AudioSmoke {
    static func main() async {
        setbuf(stdout, nil)
        do {
            let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).standardizedFileURL
            try AudioChecks.require(!AudioChecks.manager.fileExists(atPath: root.path), "fresh directory required")
            let passed: Int
            if CommandLine.arguments.count > 2 {
                try AudioChecks.manager.createDirectory(at: root.appendingPathComponent("outputs"), withIntermediateDirectories: true)
                try AudioChecks.fixture(root.appendingPathComponent("input-44100-1.wav"), channels: 1)
                try AudioChecks.fixture(root.appendingPathComponent("input-44100-2.wav"))
                passed = 0
            } else { passed = try await AudioChecks.codecs(root: root) }
            try await AudioChecks.selection(root: root)
            try await AudioChecks.boundaries(root: root)
            print("AudioSmoke passed: \(passed) codec/bitrate content checks; selection, boundaries, cancellation, cleanup")
        } catch {
            FileHandle.standardError.write(Data("AudioSmoke FAILED: \(error)\n".utf8))
            exit(1)
        }
    }
}
#endif
