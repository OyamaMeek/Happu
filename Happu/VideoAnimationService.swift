import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum AnimationQuality: String, CaseIterable { case original, best, higher, high, medium, low }
enum AnimationColor: String, CaseIterable { case full, webSafe, grayscale, blackWhite }

struct VideoAnimationService {
    let root: URL

    func convert(_ input: URL, start: Double, end: Double, fps: Int, to format: ImageFormat, quality: AnimationQuality, color: AnimationColor, loop: Int, in folder: URL, named name: String, progress: Progress) async throws -> URL {
        let workspace = MediaWorkspace(root: root)
        try MediaWorkspace.checkCancellation(progress)
        try workspace.checkInput(input)
        try workspace.checkOutput(folder: folder, name: name)
        guard format == .gif || format == .webp else { throw MediaError("动图输出仅支持 GIF 和 WebP。") }
        guard (1...30).contains(fps), (0...65535).contains(loop) else { throw MediaError("动图帧率必须为 1–30，循环数必须为 0–65535。") }
        let metadata = try await VideoService(root: root).info(input)
        guard start.isFinite, end.isFinite, start >= 0, start < end, end <= metadata.duration else { throw MediaError("动图区间必须满足 0 ≤ 开始 < 结束 ≤ 视频时长。") }
        let seconds = end - start, rawCount = ceil(seconds * Double(fps))
        guard rawCount.isFinite, (1...1000).contains(rawCount) else { throw MediaError("动图帧数必须为 1–1000，请调整区间或帧率。") }
        let count = Int(rawCount), unit = format == .gif ? 100.0 : 1000.0
        var previous = 0.0
        let durations = try (1...count).map { index -> Double in
            let edge = (min(seconds, Double(index) / Double(fps)) * unit).rounded()
            let duration = (edge - previous) / unit
            guard duration > 0 else { throw MediaError("末帧时长无法用该动图格式表示，请调整区间或帧率。") }
            previous = edge
            return duration
        }
        let maximum: Int
        switch quality {
        case .original: maximum = max(metadata.width, metadata.height)
        case .best: maximum = 1280
        case .higher: maximum = 960
        case .high: maximum = 720
        case .medium: maximum = 480
        case .low: maximum = 320
        }
        let scale = min(1, Double(maximum) / Double(max(metadata.width, metadata.height)))
        let width = max(1, Int((Double(metadata.width) * scale).rounded())), height = max(1, Int((Double(metadata.height) * scale).rounded()))
        guard width <= 40_000_000 / height else { throw MediaError("动图单帧不得超过 4000 万像素，请降低质量。") }
        guard width * height <= 80_000_000 / count else { throw MediaError("动图所有帧合计不得超过 8000 万像素，请调整质量、区间或帧率。") }
        guard format != .webp || width <= 16383 && height <= 16383 else { throw MediaError("WebP 宽高均不得超过 16383 像素，请降低质量。") }
        let asset = AVURLAsset(url: input), generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: width, height: height)
        let track = try await asset.loadTracks(withMediaType: .video)[0]
        let rate = try await track.load(.nominalFrameRate)
        guard rate.isFinite, rate > 0 else { throw MediaError("无法读取视频帧率。") }
        let frameDuration = 1 / Double(rate)
        progress.totalUnitCount = Int64(count * 3)
        progress.completedUnitCount = 0
        let encoding = Progress(totalUnitCount: Int64(count * 2))
        progress.addChild(encoding, withPendingUnitCount: Int64(count * 2))
        return try await workspace.withStaging(progress: progress) { staging in
            defer { generator.cancelAllCGImageGeneration() }
            for index in 0..<count {
                try MediaWorkspace.checkCancellation(progress)
                let seconds = start + Double(index) / Double(fps)
                generator.requestedTimeToleranceBefore = CMTime(seconds: min(frameDuration, seconds - start), preferredTimescale: 1_000_000_000)
                generator.requestedTimeToleranceAfter = CMTime(seconds: min(frameDuration, max(0, end - seconds - 1e-9)), preferredTimescale: 1_000_000_000)
                var result = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 1_000_000_000))
                if result.actualTime.seconds < start, start + frameDuration < end {
                    try MediaWorkspace.checkCancellation(progress)
                    generator.requestedTimeToleranceBefore = .zero
                    generator.requestedTimeToleranceAfter = .zero
                    result = try await generator.image(at: CMTime(seconds: start + frameDuration, preferredTimescale: 1_000_000_000))
                }
                try MediaWorkspace.checkCancellation(progress)
                guard result.actualTime.seconds.isFinite, result.actualTime.seconds >= start - 1e-9, result.actualTime.seconds < end, abs(result.actualTime.seconds - seconds) <= frameDuration + 1e-8 else { throw MediaError("无法在指定区间内取得第 \(index + 1) 帧（请求 \(seconds)，实际 \(result.actualTime.seconds)，区间 \(start)–\(end)），请调整区间或帧率。") }
                try autoreleasepool {
                    let image = try processed(result.image, width: width, height: height, color: color)
                    let url = staging.appendingPathComponent("frame-\(index).png")
                    guard let writer = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw MediaError("无法暂存动图帧。") }
                    CGImageDestinationAddImage(writer, image, nil)
                    guard CGImageDestinationFinalize(writer) else { throw MediaError("动图帧暂存失败。") }
                }
                progress.completedUnitCount += 1
            }
            try MediaWorkspace.checkCancellation(progress)
            let encoded = try ImageService(root: root).encodeAnimation(frameCount: count, frameAt: { index in
                try MediaWorkspace.checkCancellation(progress)
                let url = staging.appendingPathComponent("frame-\(index).png")
                guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary), let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw MediaError("无法读取动图暂存帧。") }
                return image
            }, durations: durations, loop: loop, to: format, quality: 1, in: staging, named: "animation", progress: encoding)
            try MediaWorkspace.checkCancellation(progress)
            let outputName = name.lowercased().hasSuffix("." + format.rawValue) ? name : name + "." + format.rawValue
            return try workspace.publish(encoded, in: folder, named: outputName, progress: progress)
        }
    }

    private func processed(_ image: CGImage, width: Int, height: Int, color: AnimationColor) throws -> CGImage {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { throw MediaError("无法分配动图帧内存。") }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        if color != .full {
            for offset in stride(from: 0, to: width * height * 4, by: 4) {
                switch color {
                case .full: break
                case .webSafe:
                    for channel in 0..<3 { pixels[offset + channel] = UInt8((Double(pixels[offset + channel]) / 51).rounded() * 51) }
                case .grayscale, .blackWhite:
                    let gray = 0.2126 * Double(pixels[offset]) + 0.7152 * Double(pixels[offset + 1]) + 0.0722 * Double(pixels[offset + 2])
                    let value = color == .blackWhite ? UInt8(gray >= 127.5 ? 255 : 0) : UInt8(gray.rounded())
                    for channel in 0..<3 { pixels[offset + channel] = value }
                }
            }
        }
        guard let result = context.makeImage() else { throw MediaError("无法生成动图帧。") }
        return result
    }
}
