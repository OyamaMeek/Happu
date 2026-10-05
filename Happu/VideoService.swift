import Foundation
import AVFoundation

enum VideoFormat: String, CaseIterable {
    case mp4, mov, m4v, threeGP = "3gp"
    var fileType: AVFileType {
        switch self { case .mp4: return .mp4; case .mov: return .mov; case .m4v: return .m4v; case .threeGP: return .mobile3GPP }
    }
}
enum VideoQuality: CaseIterable { case original, high, medium, low }
enum VideoOperation { case convert, removeAudio, trim(start: Double, end: Double) }
struct VideoInfo {
    let duration: Double
    let width: Int
    let height: Int
    let audioTracks: [AudioTrackInfo]
}
struct VideoService {
    let root: URL
    private var workspace: MediaWorkspace { MediaWorkspace(root: root) }

    func info(_ input: URL) async throws -> VideoInfo {
        try workspace.checkInput(input)
        let asset = AVURLAsset(url: input)
        let track = try await videoTrack(asset)
        let duration = try await asset.load(.duration).seconds
        let size = try await displayRect(track).size
        guard duration.isFinite, duration > 0, size.width.isFinite, size.height.isFinite, size.width >= 2, size.height >= 2 else { throw MediaError("视频时长或显示尺寸无效。") }
        let hasAudio = try await !asset.loadTracks(withMediaType: .audio).isEmpty
        let audios = hasAudio ? try await AudioService(root: root).tracks(input) : []
        return VideoInfo(duration: duration, width: Int(size.width.rounded()), height: Int(size.height.rounded()), audioTracks: audios)
    }

    func process(_ input: URL, operation: VideoOperation, to format: VideoFormat, quality: VideoQuality, audioTrackIDs: [Int32]?, in folder: URL, named name: String, progress: Progress) async throws -> URL {
        try MediaWorkspace.checkCancellation(progress)
        try workspace.checkInput(input)
        try workspace.checkOutput(folder: folder, name: name)
        let metadata = try await info(input), asset = AVURLAsset(url: input)
        let video = try await videoTrack(asset)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let selected: [AVAssetTrack]
        var start = 0.0, end = metadata.duration, trimming = false
        switch operation {
        case .removeAudio:
            guard !audioTracks.isEmpty else { throw MediaError("视频没有可移除的音频轨道。") }
            selected = []
        case .convert, .trim:
            if let ids = audioTrackIDs {
                guard Set(ids).count == ids.count, ids.allSatisfy({ id in audioTracks.contains { $0.trackID == id } }) else { throw MediaError("音轨选择包含重复或不存在的编号。") }
                selected = ids.map { id in audioTracks.first { $0.trackID == id }! }
            } else { selected = audioTracks }
        }
        if case let .trim(a, b) = operation {
            guard a.isFinite, b.isFinite, a >= 0, a < b, b <= metadata.duration else { throw MediaError("剪辑区间必须满足 0 ≤ 开始 < 结束 ≤ 视频时长。") }
            start = a; end = b; trimming = true
        }
        guard format != .threeGP || selected.count <= 1 else { throw MediaError("3GP 无法保留多个音轨，请明确选择一个音轨。") }
        let interval = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600000), end: CMTime(seconds: end, preferredTimescale: 600000))
        let sourceRect = try await displayRect(video)
        let limit: Double
        let bitRate: Int
        switch quality {
        case .original: limit = Double(max(metadata.width, metadata.height)); bitRate = 8000000
        case .high: limit = 1920; bitRate = 8000000
        case .medium: limit = 1280; bitRate = 4000000
        case .low: limit = 640; bitRate = 1000000
        }
        let scale = min(1, limit / Double(max(metadata.width, metadata.height)))
        let size = CGSize(width: max(2, (sourceRect.width * scale / 2).rounded(.down) * 2), height: max(2, (sourceRect.height * scale / 2).rounded(.down) * 2))
        let descriptions = try await video.load(.formatDescriptions)
        guard let hint = descriptions.first else { throw MediaError("视频格式描述缺失。") }
        var passthrough = false
        if quality == .original && !trimming {
            let retained = AVMutableComposition()
            for track in [video] + selected {
                guard let copy = retained.addMutableTrack(withMediaType: track.mediaType, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw MediaError("无法检查所选媒体轨道的兼容性。") }
                let range = try await track.load(.timeRange)
                try copy.insertTimeRange(range, of: track, at: range.start)
            }
            passthrough = await AVAssetExportSession.compatibility(ofExportPreset: AVAssetExportPresetPassthrough, with: retained, outputFileType: format.fileType)
        }
        let outputName = (name as NSString).pathExtension.lowercased() == format.rawValue ? name : name + "." + format.rawValue
        try workspace.checkOutput(folder: folder, name: outputName)
        progress.totalUnitCount = max(1, Int64(((end - start) * 1000000).rounded()))
        progress.completedUnitCount = 0
        return try await workspace.withStaging(progress: progress) { staging in
            let output = staging.appendingPathComponent("output." + format.rawValue)
            let reader = try AVAssetReader(asset: asset), writer = try AVAssetWriter(outputURL: output, fileType: format.fileType)
            reader.timeRange = interval
            defer { if reader.status == .reading { reader.cancelReading() }; if writer.status == .writing { writer.cancelWriting() } }
            let videoOutput: AVAssetReaderOutput
            let videoInput: AVAssetWriterInput
            if passthrough {
                videoOutput = AVAssetReaderTrackOutput(track: video, outputSettings: nil)
                videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: hint)
                videoInput.transform = try await video.load(.preferredTransform)
            } else {
                let composition = AVMutableVideoComposition()
                composition.renderSize = size
                let fps = try await video.load(.nominalFrameRate)
                guard fps.isFinite, fps > 0 else { throw MediaError("视频帧率无法读取。") }
                composition.frameDuration = CMTime(seconds: 1 / Double(fps), preferredTimescale: 600000)
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: metadata.duration, preferredTimescale: 600000))
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: video)
                let transform = try await video.load(.preferredTransform)
                    .concatenating(CGAffineTransform(translationX: -sourceRect.minX, y: -sourceRect.minY))
                    .concatenating(CGAffineTransform(scaleX: size.width / sourceRect.width, y: size.height / sourceRect.height))
                layer.setTransform(transform, at: .zero)
                instruction.layerInstructions = [layer]; composition.instructions = [instruction]
                let composed = AVAssetReaderVideoCompositionOutput(videoTracks: [video], videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
                composed.videoComposition = composition
                videoOutput = composed
                let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height), AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitRate, AVVideoAllowFrameReorderingKey: false]]
                guard writer.canApply(outputSettings: settings, forMediaType: .video) else { throw MediaError("目标容器无法使用 H.264 视频编码。") }
                videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            }
            var pairs: [(AVAssetReaderOutput, AVAssetWriterInput)] = [(videoOutput, videoInput)]
            var expectedAudio: [AudioTrackInfo] = []
            var audioRanges: [CMTimeRange] = []
            for track in selected {
                let description = try await track.load(.formatDescriptions)
                guard let audioHint = description.first, let basic = CMAudioFormatDescriptionGetStreamBasicDescription(audioHint) else { throw MediaError("音频格式描述缺失。") }
                let source = basic.pointee
                guard source.mSampleRate.isFinite, source.mSampleRate > 0, source.mChannelsPerFrame > 0 else { throw MediaError("音频采样率或声道数无效。") }
                let audioRange = CMTimeRangeGetIntersection(try await track.load(.timeRange), otherRange: interval)
                if audioRange.isEmpty { continue }
                let audioPassthrough = passthrough
                let readSettings: [String: Any]? = audioPassthrough ? nil : [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: source.mSampleRate, AVNumberOfChannelsKey: Int(source.mChannelsPerFrame), AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false]
                var writeSettings: [String: Any]? = audioPassthrough ? nil : [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: source.mSampleRate, AVNumberOfChannelsKey: Int(source.mChannelsPerFrame), AVEncoderBitRateKey: 192000]
                if !audioPassthrough, let layout = CMAudioFormatDescriptionGetChannelLayout(audioHint, sizeOut: nil) {
                    var layoutSize = 0
                    _ = CMAudioFormatDescriptionGetChannelLayout(audioHint, sizeOut: &layoutSize)
                    writeSettings?[AVChannelLayoutKey] = Data(bytes: layout, count: layoutSize)
                }
                if let settings = writeSettings, !writer.canApply(outputSettings: settings, forMediaType: .audio) { throw MediaError("目标无法保持该音轨的采样率与声道数，请选择其他容器或音轨。") }
                let read = AVAssetReaderTrackOutput(track: track, outputSettings: readSettings)
                let write = AVAssetWriterInput(mediaType: .audio, outputSettings: writeSettings, sourceFormatHint: audioPassthrough ? audioHint : nil)
                write.languageCode = try await track.load(.languageCode)
                pairs.append((read, write))
                expectedAudio.append(AudioTrackInfo(id: track.trackID, language: write.languageCode, channels: Int(source.mChannelsPerFrame), sampleRate: source.mSampleRate))
                audioRanges.append(CMTimeRange(start: audioRange.start - interval.start, duration: audioRange.duration))
            }
            for (read, write) in pairs {
                guard reader.canAdd(read), writer.canAdd(write) else { throw MediaError("目标容器无法表达所选轨道，请明确调整音轨选择。") }
                read.alwaysCopiesSampleData = false
                reader.add(read); writer.add(write)
            }
            guard writer.startWriting() else { throw writer.error ?? MediaError("视频输出无法开始。") }
            writer.startSession(atSourceTime: interval.start)
            guard reader.startReading() else { throw reader.error ?? MediaError("视频输入无法开始读取。") }
            var finished = Set<Int>()
            while finished.count < pairs.count {
                try MediaWorkspace.checkCancellation(progress)
                guard writer.status == .writing else { throw writer.error ?? MediaError("视频写入终止。") }
                guard reader.status != .failed && reader.status != .cancelled else { throw reader.error ?? MediaError("视频读取终止。") }
                var wrote = false
                for (index, pair) in pairs.enumerated() where !finished.contains(index) && pair.1.isReadyForMoreMediaData {
                    try autoreleasepool {
                        guard let sample = pair.0.copyNextSampleBuffer() else { pair.1.markAsFinished(); finished.insert(index); return }
                        try MediaWorkspace.checkCancellation(progress)
                        guard pair.1.append(sample) else { throw writer.error ?? MediaError("媒体样本写入失败。") }
                        let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds - start
                        if time.isFinite { progress.completedUnitCount = max(progress.completedUnitCount, min(progress.totalUnitCount - 1, Int64(max(0, time) * 1000000))) }
                        wrote = true
                    }
                }
                if !wrote && finished.count < pairs.count { try await Task.sleep(nanoseconds: 1_000_000) }
            }
            guard reader.status == .completed else { throw reader.error ?? MediaError("视频读取未完整结束。") }
            writer.endSession(atSourceTime: interval.end)
            await writer.finishWriting()
            try MediaWorkspace.checkCancellation(progress)
            guard writer.status == .completed else { throw writer.error ?? MediaError("视频输出未完整结束。") }
            let check = try await info(output)
            let expectedSize = passthrough ? sourceRect.size : size
            let frameRate = try await video.load(.nominalFrameRate)
            guard abs(check.duration - interval.duration.seconds) <= 1 / Double(max(1, frameRate)) + 0.02,
                  check.width == Int(expectedSize.width.rounded()), check.height == Int(expectedSize.height.rounded()),
                  check.audioTracks.count == expectedAudio.count else { throw MediaError("输出视频时间、尺寸或轨道验证失败。") }
            for (actual, expected) in zip(check.audioTracks, expectedAudio) {
                guard actual.channels == expected.channels, actual.sampleRate == expected.sampleRate else { throw MediaError("输出音轨的采样率或声道数发生变化。") }
            }
            let outputAsset = AVURLAsset(url: output)
            for (track, range) in zip(try await outputAsset.loadTracks(withMediaType: .audio), audioRanges) {
                try await validateAudioTimeline(outputAsset, track: track, expected: range, progress: progress)
            }
            let sourceRange = CMTimeRangeGetIntersection(try await video.load(.timeRange), otherRange: interval)
            guard !sourceRange.isEmpty else { throw MediaError("剪辑区间没有可解码视频帧。") }
            let frameDuration = 1 / Double(max(1, frameRate))
            let firstTime = max(0, sourceRange.start.seconds - start)
            let lastTime = max(firstTime, sourceRange.end.seconds - start - frameDuration)
            let generator = AVAssetImageGenerator(asset: outputAsset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: frameDuration, preferredTimescale: 600000)
            generator.requestedTimeToleranceAfter = generator.requestedTimeToleranceBefore
            for time in [firstTime, lastTime] {
                try MediaWorkspace.checkCancellation(progress)
                var actualTime = CMTime.invalid
                _ = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600000), actualTime: &actualTime)
                guard actualTime.seconds.isFinite, abs(actualTime.seconds - time) <= frameDuration + 0.02 else { throw MediaError("输出视频帧时间范围验证失败。") }
            }
            progress.completedUnitCount = progress.totalUnitCount
            try MediaWorkspace.checkCancellation(progress)
            return try workspace.publish(output, in: folder, named: outputName, progress: progress)
        }
    }

    private func videoTrack(_ asset: AVAsset) async throws -> AVAssetTrack {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard tracks.count == 1 else { throw MediaError(tracks.isEmpty ? "输入没有视频轨道。" : "输入包含多个视频轨道，当前无法完整保留。") }
        return tracks[0]
    }

    private func displayRect(_ track: AVAssetTrack) async throws -> CGRect {
        let size = try await track.load(.naturalSize), transform = try await track.load(.preferredTransform)
        return CGRect(origin: .zero, size: size).applying(transform).standardized
    }

    private func validateAudioTimeline(_ asset: AVAsset, track: AVAssetTrack, expected: CMTimeRange, progress: Progress) async throws {
        let actual = try await track.load(.timeRange)
        let descriptions = try await track.load(.formatDescriptions)
        guard let description = descriptions.first, let format = CMAudioFormatDescriptionGetStreamBasicDescription(description) else { throw MediaError("输出音频格式描述缺失。") }
        let source = format.pointee
        let rate = source.mSampleRate
        let tolerance = 0.15
        guard abs(actual.end.seconds - expected.end.seconds) <= tolerance, actual.start.seconds >= -0.02, actual.start.seconds <= expected.start.seconds + tolerance else { throw MediaError("输出音频轨道时间范围发生变化。") }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: Int(source.mChannelsPerFrame), AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false])
        guard reader.canAdd(output) else { throw MediaError("输出音频无法重新解码。") }
        reader.add(output)
        defer { if reader.status == .reading { reader.cancelReading() } }
        guard reader.startReading() else { throw reader.error ?? MediaError("输出音频重读失败。") }
        var first: Double?, last = -Double.infinity
        while let sample = output.copyNextSampleBuffer() {
            try MediaWorkspace.checkCancellation(progress)
            let count = CMSampleBufferGetNumSamples(sample)
            if count == 0 { continue }
            let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard time.isFinite else { throw MediaError("输出音频样本时间无效。") }
            if first == nil { first = time }
            last = max(last, time + Double(count) / rate)
            if expected.start.seconds > 0, time < expected.start.seconds - 0.03 {
                guard let block = CMSampleBufferGetDataBuffer(sample) else { throw MediaError("输出音频样本数据缺失。") }
                var bytes = Data(count: CMBlockBufferGetDataLength(block))
                let status = bytes.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!) }
                guard status == noErr else { throw MediaError("输出音频样本重读失败。") }
                let silentFrames = min(count, Int((expected.start.seconds - 0.03 - time) * rate))
                let silent = bytes.withUnsafeBytes { buffer in buffer.bindMemory(to: Float.self).prefix(silentFrames * Int(source.mChannelsPerFrame)).allSatisfy { $0.isFinite && abs($0) <= 0.001 } }
                guard silent else { throw MediaError("输出音频没有保留原时间线的前导静音。") }
            }
        }
        guard reader.status == .completed, let first, first >= -0.02, first <= expected.start.seconds + tolerance, abs(last - expected.end.seconds) <= tolerance else { throw reader.error ?? MediaError("输出音频有效样本范围验证失败。") }
    }
}
