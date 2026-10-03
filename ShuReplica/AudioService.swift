import Foundation
import AVFoundation
import AudioToolbox
import LAME

enum AudioFormat: String, CaseIterable { case m4a, wav, mp3, caf, flac }
struct AudioTrackInfo {
    let id: Int32
    let language: String?
    let channels: Int
    let sampleRate: Double
}
struct AudioService {
    let root: URL
    private var workspace: MediaWorkspace { MediaWorkspace(root: root) }

    func tracks(_ input: URL) async throws -> [AudioTrackInfo] {
        try workspace.checkInput(input)
        let asset = AVURLAsset(url: input)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw MediaError("输入没有音频轨道。") }
        return try await tracks.asyncInfos()
    }

    func convert(_ input: URL, to format: AudioFormat, bitRate: Int = 192000, trackID: Int32?, downmixToStereo: Bool, in folder: URL, named name: String, progress: Progress) async throws -> URL {
        try MediaWorkspace.checkCancellation(progress)
        try workspace.checkInput(input)
        try workspace.checkOutput(folder: folder, name: name)
        guard [64000, 128000, 192000, 256000, 320000].contains(bitRate) else { throw MediaError("音频码率必须为 64/128/192/256/320 kbps。") }
        let asset = AVURLAsset(url: input)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw MediaError("输入没有音频轨道。") }
        let selected: AVAssetTrack
        if let trackID {
            guard let track = tracks.first(where: { $0.trackID == trackID }) else { throw MediaError("指定音频轨道不存在。") }
            selected = track
        } else {
            guard tracks.count == 1 else { throw MediaError("输入包含多个音频轨道，请明确选择轨道。") }
            selected = tracks[0]
        }
        let info = try await [selected].asyncInfos()[0]
        let duration = try await selected.load(.timeRange).duration.seconds
        guard duration.isFinite, duration > 0, info.sampleRate.isFinite, info.sampleRate > 0, info.channels > 0 else { throw MediaError("音频轨道长度或格式无效。") }
        let channels = downmixToStereo && info.channels > 2 ? 2 : info.channels
        if format == .mp3 {
            guard channels <= 2 else { throw MediaError("多声道 MP3 需要明确选择下混至双声道。") }
            let rate = Int(info.sampleRate)
            guard [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000].contains(rate), Double(rate) == info.sampleRate,
                  rate >= 32000 || (rate >= 16000 && bitRate <= 128000) || (rate < 16000 && bitRate == 64000) else { throw MediaError("MP3 无法保持该采样率与码率组合。") }
        }
        let description = try await selected.load(.formatDescriptions)[0]
        if format == .flac, let source = CMAudioFormatDescriptionGetStreamBasicDescription(description), source.pointee.mFormatID == kAudioFormatLinearPCM {
            guard source.pointee.mFormatFlags & kAudioFormatFlagIsFloat == 0 else { throw MediaError("FLAC 无法无损保留原始浮点 PCM 精度。") }
            guard source.pointee.mBitsPerChannel <= 24 else { throw MediaError("当前 FLAC 转换无法无损保留超过 24 位的整数 PCM。") }
        }
        let layout: AVAudioChannelLayout
        if channels == info.channels, let original = CMAudioFormatDescriptionGetChannelLayout(description, sizeOut: nil) {
            layout = AVAudioChannelLayout(layout: original)
        } else {
            guard let fallback = AVAudioChannelLayout(layoutTag: channels == 1 ? kAudioChannelLayoutTag_Mono : (channels == 2 ? kAudioChannelLayoutTag_Stereo : kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channels))) else { throw MediaError("声道布局无法表达。") }
            layout = fallback
        }
        let pcm = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: info.sampleRate, interleaved: true, channelLayout: layout)
        let nativeInput = try await asset.loadTracks(withMediaType: .video).isEmpty && tracks.count == 1 && channels == info.channels
        let nativeFile = nativeInput ? try AVAudioFile(forReading: input, commonFormat: .pcmFormatFloat32, interleaved: true) : nil
        progress.totalUnitCount = nativeFile?.length ?? max(1, Int64((duration * info.sampleRate).rounded()))
        guard progress.totalUnitCount > 0 else { throw MediaError("音频轨道没有可解码样本。") }
        progress.completedUnitCount = 0
        let ext = (name as NSString).pathExtension
        let outputName = ext.lowercased() == format.rawValue ? name : name + "." + format.rawValue
        try workspace.checkOutput(folder: folder, name: outputName)
        return try await workspace.withStaging(progress: progress) { staging in
            let output = staging.appendingPathComponent("output." + format.rawValue)
            let encoder = try AudioEncoder(url: output, format: format, pcm: pcm, bitRate: bitRate)
            let consume: (AVAudioPCMBuffer) throws -> Void = { buffer in
                try MediaWorkspace.checkCancellation(progress)
                try encoder.write(buffer)
                progress.completedUnitCount = min(progress.totalUnitCount, progress.completedUnitCount + Int64(buffer.frameLength))
            }
            let expected = try nativeFile.map { try read(file: $0, pcm: pcm, progress: progress, consume: consume) }
                ?? read(asset: asset, track: selected, pcm: pcm, progress: progress, consume: consume)
            try MediaWorkspace.checkCancellation(progress)
            try encoder.finish()
            try MediaWorkspace.checkCancellation(progress)
            let checkAsset = AVURLAsset(url: output)
            let checkTracks = try await checkAsset.loadTracks(withMediaType: .audio)
            guard checkTracks.count == 1 else { throw MediaError("输出音频轨道验证失败。") }
            let checkInfo = try await checkTracks.asyncInfos()[0]
            guard checkInfo.channels == channels, checkInfo.sampleRate == info.sampleRate else { throw MediaError("输出采样率或声道数发生变化。") }
            let decoded = try AVAudioFile(forReading: output, commonFormat: .pcmFormatFloat32, interleaved: true)
            let actual = try read(file: decoded, pcm: pcm, progress: progress) { _ in }
            try expected.validate(actual, rate: info.sampleRate, lossy: [.mp3, .m4a].contains(format))
            progress.completedUnitCount = progress.totalUnitCount
            try MediaWorkspace.checkCancellation(progress)
            return try workspace.publish(output, in: folder, named: outputName, progress: progress)
        }
    }

    private func read(file: AVAudioFile, pcm: AVAudioFormat, progress: Progress, consume: (AVAudioPCMBuffer) throws -> Void) throws -> AudioSignal {
        guard file.processingFormat.sampleRate == pcm.sampleRate, file.processingFormat.channelCount == pcm.channelCount, file.processingFormat.isInterleaved, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 8192) else { throw MediaError("原生 PCM 采样率或声道格式不匹配。") }
        let converter: AVAudioConverter?
        if file.processingFormat != pcm {
            guard let conversion = AVAudioConverter(from: file.processingFormat, to: pcm) else { throw MediaError("PCM 声道布局无法转换。") }
            converter = conversion
        } else { converter = nil }
        guard let converted = AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: 8192) else { throw MediaError("PCM 缓冲区无法分配。") }
        var signal = AudioSignal(channels: Int(pcm.channelCount))
        while file.framePosition < file.length {
            try MediaWorkspace.checkCancellation(progress)
            try file.read(into: buffer)
            guard buffer.frameLength > 0 else { throw MediaError("音频数据在预期结束前中断。") }
            if let converter { try converter.convert(to: converted, from: buffer) }
            let samples = converter == nil ? buffer : converted
            try signal.append(samples)
            try MediaWorkspace.checkCancellation(progress)
            try consume(samples)
            try MediaWorkspace.checkCancellation(progress)
        }
        guard signal.frames > 0 else { throw MediaError("音频轨道没有可解码样本。") }
        return signal
    }

    private func read(asset: AVAsset, track: AVAssetTrack, pcm: AVAudioFormat, progress: Progress, consume: (AVAudioPCMBuffer) throws -> Void) throws -> AudioSignal {
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: pcm.sampleRate, AVNumberOfChannelsKey: pcm.channelCount, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false]
        let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw MediaError("无法解码所选音频轨道。") }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? MediaError("无法开始音频解码。") }
        defer { if reader.status == .reading { reader.cancelReading() } }
        var signal = AudioSignal(channels: Int(pcm.channelCount))
        while reader.status == .reading {
            try MediaWorkspace.checkCancellation(progress)
            let hasBuffer: Bool = try autoreleasepool {
                guard let sample = output.copyNextSampleBuffer() else { return false }
                guard let data = CMSampleBufferGetDataBuffer(sample) else { throw MediaError("PCM 数据缺失。") }
                let frames = CMSampleBufferGetNumSamples(sample)
                let frameBytes = Int(pcm.streamDescription.pointee.mBytesPerFrame)
                for start in stride(from: 0, to: frames, by: 8192) {
                    try MediaWorkspace.checkCancellation(progress)
                    let count = min(8192, frames - start)
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: AVAudioFrameCount(count)) else { throw MediaError("无法分配 PCM 缓冲区。") }
                    buffer.frameLength = AVAudioFrameCount(count)
                    let status = CMBlockBufferCopyDataBytes(data, atOffset: start * frameBytes, dataLength: count * frameBytes, destination: buffer.mutableAudioBufferList.pointee.mBuffers.mData!)
                    guard status == noErr else { throw MediaError("PCM 数据读取失败：\(status)") }
                    try signal.append(buffer)
                    try consume(buffer)
                    try MediaWorkspace.checkCancellation(progress)
                }
                return true
            }
            if !hasBuffer { break }
        }
        guard reader.status == .completed else { throw reader.error ?? MediaError("音频解码未完整结束。") }
        guard signal.frames > 0 else { throw MediaError("音频轨道没有可解码样本。") }
        return signal
    }
}

private extension Array where Element == AVAssetTrack {
    func asyncInfos() async throws -> [AudioTrackInfo] {
        var infos: [AudioTrackInfo] = []
        for track in self {
            let descriptions = try await track.load(.formatDescriptions)
            guard let description = descriptions.first, let format = CMAudioFormatDescriptionGetStreamBasicDescription(description) else { throw MediaError("音频轨道格式无法读取。") }
            infos.append(AudioTrackInfo(id: track.trackID, language: try await track.load(.languageCode), channels: Int(format.pointee.mChannelsPerFrame), sampleRate: format.pointee.mSampleRate))
        }
        return infos
    }
}

private struct AudioSignal {
    var frames: Int64 = 0
    var energy: [Double]
    init(channels: Int) { energy = Array(repeating: 0, count: channels) }
    mutating func append(_ buffer: AVAudioPCMBuffer) throws {
        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(buffer.frameLength) {
            for channel in energy.indices {
                let sample = Double(samples[frame * energy.count + channel])
                guard sample.isFinite else { throw MediaError("音频包含无效 PCM 样本。") }
                energy[channel] += sample * sample
            }
        }
        frames += Int64(buffer.frameLength)
    }
    func validate(_ actual: AudioSignal, rate: Double, lossy: Bool) throws {
        guard abs(Double(frames - actual.frames)) / rate <= (lossy ? 0.15 : 0.001) else { throw MediaError("输出音频时长验证失败：输入 \(frames) 样本，输出 \(actual.frames) 样本，采样率 \(rate)。") }
        for channel in energy.indices {
            let reference = energy[channel] / Double(frames), value = actual.energy[channel] / Double(actual.frames)
            guard abs(reference - value) <= max(0.00001, reference * (lossy ? 0.25 : 0.001)) else { throw MediaError("输出音频信号验证失败。") }
        }
    }
}

private final class AudioEncoder {
    private var file: ExtAudioFileRef?
    private var lame: OpaquePointer?
    private var handle: FileHandle?
    private let channels: Int
    init(url: URL, format: AudioFormat, pcm: AVAudioFormat, bitRate: Int) throws {
        channels = Int(pcm.channelCount)
        if format == .mp3 {
            guard let state = lame_init() else { throw MediaError("LAME 初始化失败。") }
            lame = state
            guard lame_set_in_samplerate(state, Int32(pcm.sampleRate)) == 0, lame_set_out_samplerate(state, Int32(pcm.sampleRate)) == 0, lame_set_num_channels(state, Int32(channels)) == 0, lame_set_brate(state, Int32(bitRate / 1000)) == 0, lame_set_bWriteVbrTag(state, 1) == 0, lame_set_quality(state, 2) == 0, lame_init_params(state) == 0 else { throw MediaError("MP3 编码参数不受支持。") }
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            handle = try FileHandle(forUpdating: url)
        } else {
            var description = AudioStreamBasicDescription()
            description.mSampleRate = pcm.sampleRate
            description.mChannelsPerFrame = UInt32(channels)
            var type: AudioFileTypeID
            switch format {
            case .m4a: description.mFormatID = kAudioFormatMPEG4AAC; description.mFormatFlags = UInt32(MPEG4ObjectID.AAC_LC.rawValue); type = kAudioFileM4AType
            case .flac: description.mFormatID = kAudioFormatFLAC; type = kAudioFileFLACType
            default:
                description.mFormatID = kAudioFormatLinearPCM
                description.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
                description.mBitsPerChannel = 16
                description.mBytesPerFrame = UInt32(channels * 2)
                description.mFramesPerPacket = 1
                description.mBytesPerPacket = description.mBytesPerFrame
                type = format == .wav ? kAudioFileWAVEType : kAudioFileCAFType
            }
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try Self.check(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &size, &description), "编码格式")
            let outputLayout = format == .m4a && channels == 6 ? AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AAC_5_1) : pcm.channelLayout
            try Self.check(ExtAudioFileCreateWithURL(url as CFURL, type, &description, outputLayout?.layout, 0, &file), "创建音频文件")
            do {
                // Apple 软件 codec 的 'appl' 值；SDK 仅在 iOS 导出对应常量。
                var manufacturer: UInt32 = 0x6170706c
                try Self.check(ExtAudioFileSetProperty(file!, kExtAudioFileProperty_CodecManufacturer, UInt32(MemoryLayout<UInt32>.size), &manufacturer), "选择系统软件编码器")
                var client = pcm.streamDescription.pointee
                try Self.check(ExtAudioFileSetProperty(file!, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &client), "设置 PCM 格式")
                if let layout = pcm.channelLayout {
                    let bytes = MemoryLayout<AudioChannelLayout>.size + max(0, Int(layout.layout.pointee.mNumberChannelDescriptions) - 1) * MemoryLayout<AudioChannelDescription>.size
                    try Self.check(ExtAudioFileSetProperty(file!, kExtAudioFileProperty_ClientChannelLayout, UInt32(bytes), layout.layout), "设置 PCM 声道布局")
                }
                if format == .m4a {
                    var converter: AudioConverterRef?
                    var bytes = UInt32(MemoryLayout<AudioConverterRef?>.size)
                    try Self.check(ExtAudioFileGetProperty(file!, kExtAudioFileProperty_AudioConverter, &bytes, &converter), "读取 AAC 编码器")
                    guard let converter else { throw MediaError("AAC 编码器不存在。") }
                    var rate = UInt32(bitRate)
                    try Self.check(AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, UInt32(MemoryLayout<UInt32>.size), &rate), "设置 AAC 码率")
                    var actual: UInt32 = 0
                    bytes = UInt32(MemoryLayout<UInt32>.size)
                    try Self.check(AudioConverterGetProperty(converter, kAudioConverterEncodeBitRate, &bytes, &actual), "验证 AAC 码率")
                    guard actual == rate else { throw MediaError("AAC 无法表达所选码率与音频格式组合。") }
                    var config: UnsafeRawPointer?
                    try Self.check(ExtAudioFileSetProperty(file!, kExtAudioFileProperty_ConverterConfig, UInt32(MemoryLayout<UnsafeRawPointer?>.size), &config), "更新 AAC 文件格式")
                }
                var encoded = AudioStreamBasicDescription()
                var encodedSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                try Self.check(ExtAudioFileGetProperty(file!, kExtAudioFileProperty_FileDataFormat, &encodedSize, &encoded), "验证编码格式")
                guard encoded.mSampleRate == pcm.sampleRate, encoded.mChannelsPerFrame == pcm.channelCount else { throw MediaError("原生编码器无法保持所选采样率或声道数。") }
            } catch {
                let result = ExtAudioFileDispose(file!)
                file = nil
                if result != noErr { throw MediaError("编码器初始化与关闭失败：\(error.localizedDescription)；\(result)") }
                throw error
            }
        }
    }
    deinit {
        if let file { ExtAudioFileDispose(file) }
        if let lame { lame_close(lame) }
        try? handle?.close()
    }
    func write(_ buffer: AVAudioPCMBuffer) throws {
        if let lame, let handle {
            var bytes = [UInt8](repeating: 0, count: Int(Double(buffer.frameLength) * 1.25) + 7200)
            let count: Int32 = channels == 1
                ? lame_encode_buffer_ieee_float(lame, buffer.floatChannelData![0], buffer.floatChannelData![0], Int32(buffer.frameLength), &bytes, Int32(bytes.count))
                : lame_encode_buffer_interleaved_ieee_float(lame, buffer.floatChannelData![0], Int32(buffer.frameLength), &bytes, Int32(bytes.count))
            guard count >= 0 else { throw MediaError("MP3 分块编码失败：\(count)") }
            try handle.write(contentsOf: Data(bytes.prefix(Int(count))))
        } else { try Self.check(ExtAudioFileWrite(file!, buffer.frameLength, buffer.audioBufferList), "写入 PCM") }
    }
    func finish() throws {
        if let file {
            let status = ExtAudioFileDispose(file)
            self.file = nil
            try Self.check(status, "结束原生音频编码")
        }
        if let lame, let handle {
            var bytes = [UInt8](repeating: 0, count: 7200)
            let count = lame_encode_flush(lame, &bytes, Int32(bytes.count))
            guard count >= 0 else { throw MediaError("MP3 flush 失败：\(count)") }
            try handle.write(contentsOf: Data(bytes.prefix(Int(count))))
            let tagCount = lame_get_lametag_frame(lame, &bytes, bytes.count)
            guard tagCount > 0, tagCount <= bytes.count else { throw MediaError("MP3 gapless 标签生成失败。") }
            try handle.seek(toOffset: 0)
            try handle.write(contentsOf: Data(bytes.prefix(tagCount)))
            try handle.synchronize()
            try handle.close()
            self.handle = nil
            guard lame_close(lame) == 0 else { throw MediaError("LAME 关闭失败。") }
            self.lame = nil
        }
    }
    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw MediaError("\(operation)失败：OSStatus \(status)。") }
    }
}
