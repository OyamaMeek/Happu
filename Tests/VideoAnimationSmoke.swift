import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import libwebp
#if os(iOS)
@testable import Happu
#else
@testable import ShuServices
#endif

enum AnimationChecks {
    static let manager = FileManager.default
    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw MediaError("ASSERTION: " + message) }
    }

    static func fixture(_ url: URL, width: Int = 96, height: Int = 64, rotated: Bool = true, frames: Int = 30) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
        if rotated { input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: CGFloat(height), ty: 0) }
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        writer.add(input)
        try require(writer.startWriting(), "fixture start")
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData {
                try require(writer.status == .writing, "fixture encoder")
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            var buffer: CVPixelBuffer?
            try require(CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer) == kCVReturnSuccess, "fixture allocation")
            CVPixelBufferLockBaseAddress(buffer!, [])
            let bytes = CVPixelBufferGetBaseAddress(buffer!)!.assumingMemoryBound(to: UInt8.self), row = CVPixelBufferGetBytesPerRow(buffer!)
            for y in 0..<height {
                for x in 0..<width {
                    let i = y * row + x * 4
                    bytes[i] = frame < 15 ? 20 : 220
                    bytes[i + 1] = x < width / 2 ? 35 : 180
                    bytes[i + 2] = frame < 15 ? 220 : 20
                    bytes[i + 3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer!, [])
            try require(adapter.append(buffer!, withPresentationTime: CMTime(value: Int64(frame), timescale: 10)), "fixture append")
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: Int64(frames), timescale: 10))
        await writer.finishWriting()
        try require(writer.status == .completed, "fixture finish \(String(describing: writer.error))")
    }

    static func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self).advanced(by: (y * image.width + x) * 4), count: 4))
    }

    struct Decoded {
        let frames: [CGImage]
        let durations: [Double]
        let loop: Int
    }

    static func decode(_ url: URL) throws -> Decoded {
        if url.pathExtension == "webp" {
            let bytes = try Data(contentsOf: url)
            return try bytes.withUnsafeBytes { buffer in
                var data = WebPData(bytes: buffer.bindMemory(to: UInt8.self).baseAddress, size: bytes.count)
                guard let decoder = WebPAnimDecoderNewInternal(&data, nil, WEBP_DEMUX_ABI_VERSION) else { throw MediaError("WebP test decoder") }
                defer { WebPAnimDecoderDelete(decoder) }
                var info = WebPAnimInfo()
                try require(WebPAnimDecoderGetInfo(decoder, &info) != 0, "WebP info")
                var frames: [CGImage] = [], durations: [Double] = [], previous: Int32 = 0
                while WebPAnimDecoderHasMoreFrames(decoder) != 0 {
                    var rgba: UnsafeMutablePointer<UInt8>?, time: Int32 = 0
                    try require(WebPAnimDecoderGetNext(decoder, &rgba, &time) != 0 && rgba != nil, "WebP decode")
                    let pixels = Data(bytes: rgba!, count: Int(info.canvas_width * info.canvas_height * 4))
                    frames.append(CGImage(width: Int(info.canvas_width), height: Int(info.canvas_height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Int(info.canvas_width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: CGDataProvider(data: pixels as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!)
                    durations.append(Double(time - previous) / 1000)
                    previous = time
                }
                return Decoded(frames: frames, durations: durations, loop: Int(info.loop_count))
            }
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw MediaError("GIF test decoder") }
        let properties = CGImageSourceCopyProperties(source, nil)! as NSDictionary
        let loop = ((properties[kCGImagePropertyGIFDictionary] as? NSDictionary)?[kCGImagePropertyGIFLoopCount] as? NSNumber)?.intValue ?? 1
        var frames: [CGImage] = [], durations: [Double] = []
        for index in 0..<CGImageSourceGetCount(source) {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)! as NSDictionary
            let gif = properties[kCGImagePropertyGIFDictionary] as! NSDictionary
            durations.append((gif[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber ?? gif[kCGImagePropertyGIFDelayTime] as! NSNumber).doubleValue)
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { throw MediaError("GIF frame decode") }
            frames.append(frame)
        }
        return Decoded(frames: frames, durations: durations, loop: loop)
    }

    static func verify(_ url: URL, start: Double, end: Double, fps: Int, loop: Int, width: Int, height: Int, color: AnimationColor = .full, reference: CGImage? = nil) throws {
        let actual = try decode(url), count = Int(ceil((end - start) * Double(fps)))
        try require(actual.frames.count == count && actual.durations.count == count && actual.loop == loop, "frame count/loop \(url.lastPathComponent)")
        let tick = url.pathExtension == "gif" ? 0.01 : 0.001
        try require(abs(actual.durations.reduce(0, +) - (end - start)) <= tick + 1e-8 && actual.durations.allSatisfy { $0 > 0 }, "duration/positive tail")
        var elapsed = 0.0
        for (index, frame) in actual.frames.enumerated() {
            try require(frame.width == width && frame.height == height, "display size")
            elapsed += actual.durations[index]
            try require(abs(elapsed - min(end - start, Double(index + 1) / Double(fps))) <= tick + 1e-8, "cumulative timestamp drift")
            let p = pixel(frame, x: frame.width / 4, y: frame.height / 4)
            switch color {
            case .full, .webSafe:
                let red = start + Double(index) / Double(fps) < 1.45
                let blue = start + Double(index) / Double(fps) >= 1.55
                if red { try require(Int(p[0]) - Int(p[2]) > 100, "red temporal marker") }
                if blue { try require(Int(p[2]) - Int(p[0]) > 100, "blue temporal marker") }
                if color == .webSafe {
                    try require(p.prefix(3).allSatisfy { value in min(Int(value) % 51, 51 - Int(value) % 51) <= 8 }, "web-safe palette")
                }
            case .grayscale: try require(abs(Int(p[0]) - Int(p[1])) < 5 && abs(Int(p[1]) - Int(p[2])) < 5, "grayscale")
            case .blackWhite: try require(p.prefix(3).allSatisfy { $0 <= 5 || $0 >= 250 }, "black/white palette")
            }
        }
        if let reference {
            for (x, y) in [(width / 4, height / 4), (width / 4, height * 3 / 4)] {
                let source = pixel(reference, x: x, y: y)
                let expected = source[1], observed = pixel(actual.frames[0], x: x, y: y)[1]
                try require((expected > 100) == (observed > 100), "signed spatial direction")
                let gray = 0.2126 * Double(source[0]) + 0.7152 * Double(source[1]) + 0.0722 * Double(source[2])
                if color == .grayscale { try require(abs(Double(observed) - gray) <= 5, "grayscale luma") }
                if color == .blackWhite { try require(abs(Int(observed) - (gray >= 127.5 ? 255 : 0)) <= 5, "binary luma threshold") }
            }
            try require(abs(Int(pixel(actual.frames[0], x: width / 4, y: height / 4)[1]) - Int(pixel(actual.frames[0], x: width / 4, y: height * 3 / 4)[1])) > 70, "spatial marker retained")
        }
    }

    static func rejected(_ expected: String? = nil, cancellation: Bool = false, _ operation: () async throws -> URL) async throws {
        do { _ = try await operation() }
        catch {
            if cancellation { try require(error is CancellationError, "must be cancellation: \(error)") }
            if let expected { try require(error.localizedDescription.contains(expected), "expected \(expected): \(error)") }
            return
        }
        throw MediaError("ASSERTION: expected rejection")
    }

    static func run(root: URL) async throws -> Int {
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let output = root.appendingPathComponent("outputs", isDirectory: true)
        try manager.createDirectory(at: output, withIntermediateDirectories: false)
        let workspace = MediaWorkspace(root: root)
        let publicationSentinel = output.appendingPathComponent("published.txt")
        try Data("existing".utf8).write(to: publicationSentinel)
        for cleanupFailure in [false, true] {
            let progress = Progress()
            let before = Set(try manager.contentsOfDirectory(atPath: output.path))
            try await rejected(cleanupFailure ? "清理失败" : nil, cancellation: !cleanupFailure) {
                try await workspace.withStaging(progress: progress) { staging in
                    let input = staging.appendingPathComponent("new.txt")
                    try Data("new".utf8).write(to: input)
                    let result = try workspace.publish(input, in: output, named: "published.txt", progress: progress)
                    if cleanupFailure { try manager.removeItem(at: staging) }
                    else { progress.cancel() }
                    return result
                }
            }
            try require(Set(manager.contentsOfDirectory(atPath: output.path)) == before, "late cancellation or cleanup failure published output")
            try require(Data(contentsOf: publicationSentinel) == Data("existing".utf8), "existing output changed")
            try require(!manager.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".media-") }, "late cleanup leaked staging")
        }
        let taskBefore = Set(try manager.contentsOfDirectory(atPath: output.path))
        let cancelledTask = Task {
            try await workspace.withStaging(progress: Progress()) { staging in
                let input = staging.appendingPathComponent("task.txt")
                try Data("task".utf8).write(to: input)
                let result = try workspace.publish(input, in: output, named: "published.txt", progress: Progress())
                withUnsafeCurrentTask { $0?.cancel() }
                return result
            }
        }
        try await rejected(cancellation: true) { try await cancelledTask.value }
        try require(Set(manager.contentsOfDirectory(atPath: output.path)) == taskBefore, "late Task cancellation published output")
        let video = root.appendingPathComponent("marker.mov")
        try await fixture(video)
        let original = try Data(contentsOf: video), service = VideoAnimationService(root: root)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let reference = try await generator.image(at: CMTime(value: 0, timescale: 10)).image
        var passed = 0
        for format in [ImageFormat.gif, .webp] {
            for fps in [1, 10, 29, 30] {
                for loop in [0, 1, 4] {
                    let progress = Progress()
                    let result = try await service.convert(video, start: 0, end: 2, fps: fps, to: format, quality: .original, color: .full, loop: loop, in: output, named: "matrix-\(format)-\(fps)-\(loop)", progress: progress)
                    try verify(result, start: 0, end: 2, fps: fps, loop: loop, width: 64, height: 96, reference: reference)
                    try require(progress.completedUnitCount == progress.totalUnitCount && progress.totalUnitCount > 0, "complete progress")
                    passed += 1
                }
            }
            for color in AnimationColor.allCases {
                let result = try await service.convert(video, start: 0.2, end: 2.03, fps: 10, to: format, quality: .low, color: color, loop: 4, in: output, named: "color-\(format)-\(color)", progress: Progress())
                try verify(result, start: 0.2, end: 2.03, fps: 10, loop: 4, width: 64, height: 96, color: color, reference: reference)
                passed += 1
            }
            for (start, end, fps) in [(0.13, 1.88, 10), (0.2, 0.25, 10)] {
                let result = try await service.convert(video, start: start, end: end, fps: fps, to: format, quality: .original, color: .full, loop: 1, in: output, named: "range-\(format)-\(start)", progress: Progress())
                try verify(result, start: start, end: end, fps: fps, loop: 1, width: 64, height: 96)
                passed += 1
            }
        }
        let large = root.appendingPathComponent("large.mov")
        try await fixture(large, width: 1400, height: 700, rotated: false)
        for format in [ImageFormat.gif, .webp] {
            for (quality, width) in zip(AnimationQuality.allCases, [1400, 1280, 960, 720, 480, 320]) {
                let result = try await service.convert(large, start: 0, end: 0.2, fps: 10, to: format, quality: quality, color: .full, loop: 0, in: output, named: "size-\(format)-\(quality)", progress: Progress())
                try verify(result, start: 0, end: 0.2, fps: 10, loop: 0, width: width, height: width / 2)
                passed += 1
            }
        }
        let before = Set(try manager.contentsOfDirectory(atPath: output.path))
        for (start, end, fps, loop, format) in [(-0.1, 1.0, 10, 0, ImageFormat.gif), (0.0, 3.1, 10, 0, .gif), (0.0, 0.0, 10, 0, .gif), (Double.nan, 1.0, 10, 0, .gif), (0.0, Double.infinity, 10, 0, .gif), (0.0, 1.0, 0, 0, .gif), (0.0, 1.0, 31, 0, .webp), (0.0, 1.0, 10, -1, .gif), (0.0, 1.0, 10, 65536, .webp), (0.0, 1.0, 10, 0, .png)] {
            try await rejected { try await service.convert(video, start: start, end: end, fps: fps, to: format, quality: .original, color: .full, loop: loop, in: output, named: "invalid", progress: Progress()) }
        }
        for format in [ImageFormat.gif, .webp] {
            try await rejected("时长") { try await service.convert(video, start: 0, end: 1.0001, fps: 10, to: format, quality: .original, color: .full, loop: 0, in: output, named: "zero-tail", progress: Progress()) }
            for boundary in [0, 1, 60, 120, 180] {
                let progress = Progress()
                if boundary == 0 { progress.cancel() }
                let observation = progress.observe(\.completedUnitCount) { value, _ in
                    if value.completedUnitCount >= boundary && boundary > 0 { value.cancel() }
                }
                try await rejected(cancellation: true) { try await service.convert(video, start: 0, end: 2, fps: 30, to: format, quality: .original, color: .full, loop: 0, in: output, named: "cancel", progress: progress) }
                observation.invalidate()
                try require(Set(manager.contentsOfDirectory(atPath: output.path)) == before, "cancel unpublished")
                try require(!manager.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".media-") || $0.hasPrefix(".image-") }, "cancel cleanup")
            }
        }
        try await rejected("8000 万") { try await service.convert(large, start: 0, end: 3, fps: 30, to: .webp, quality: .original, color: .full, loop: 0, in: output, named: "too-large", progress: Progress()) }
        let long = root.appendingPathComponent("long.mov")
        try await fixture(long, rotated: false, frames: 340)
        try await rejected("1000") { try await service.convert(long, start: 0, end: 34, fps: 30, to: .gif, quality: .low, color: .full, loop: 0, in: output, named: "too-many", progress: Progress()) }
        for name in ["", ".", "..", "a/b", "a\\b", " a", "a\0b"] {
            try await rejected { try await service.convert(video, start: 0, end: 1, fps: 10, to: .gif, quality: .low, color: .full, loop: 0, in: output, named: name, progress: Progress()) }
        }
        let link = root.appendingPathComponent("link")
        try manager.createSymbolicLink(at: link, withDestinationURL: root)
        for input in [link.appendingPathComponent("marker.mov"), URL(fileURLWithPath: root.path + "/./marker.mov"), output] {
            try await rejected { try await service.convert(input, start: 0, end: 1, fps: 10, to: .gif, quality: .low, color: .full, loop: 0, in: output, named: "invalid-input", progress: Progress()) }
        }
        try await rejected { try await service.convert(video, start: 0, end: 1, fps: 10, to: .gif, quality: .low, color: .full, loop: 0, in: link, named: "invalid-folder", progress: Progress()) }
        let sentinel = output.appendingPathComponent("collision.gif"), bytes = Data("preserve".utf8)
        try bytes.write(to: sentinel)
        let collision = try await service.convert(video, start: 0, end: 1, fps: 10, to: .gif, quality: .low, color: .full, loop: 0, in: output, named: "collision", progress: Progress())
        try require(collision.lastPathComponent == "collision 2.gif" && Data(contentsOf: sentinel) == bytes && Data(contentsOf: video) == original, "collision/input preservation")
        print("AnimationSmoke passed: \(passed) outputs, timing, signed orientation, colors, scaling, loops, limits, cancellation and cleanup")
        return passed
    }
}

#if !os(iOS)
@main
struct VideoAnimationSmoke {
    static func main() async {
        do { _ = try await AnimationChecks.run(root: URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)) }
        catch { print("ANIMATION_FAILED: \(error.localizedDescription)"); exit(1) }
    }
}
#endif
