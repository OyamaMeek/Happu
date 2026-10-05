import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import libwebp
@testable import ShuServices

@main
struct ImageSmoke {
    static let manager = FileManager.default
    static func check(_ condition: Bool) { precondition(condition) }

    static func image(_ width: Int, _ height: Int, color: CGColor) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    static func pattern() -> CGImage {
        let context = CGContext(data: nil, width: 6, height: 4, bitsPerComponent: 8, bytesPerRow: 24, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for (rect, color) in [(CGRect(x: 0, y: 2, width: 3, height: 2), CGColor(red: 1, green: 0, blue: 0, alpha: 1)), (CGRect(x: 3, y: 2, width: 3, height: 2), CGColor(red: 0, green: 0, blue: 1, alpha: 1)), (CGRect(x: 0, y: 0, width: 3, height: 2), CGColor(red: 0, green: 1, blue: 0, alpha: 1)), (CGRect(x: 3, y: 0, width: 3, height: 2), CGColor(red: 1, green: 1, blue: 0, alpha: 1))] {
            context.setFillColor(color)
            context.fill(rect)
        }
        return context.makeImage()!
    }

    static func corners(_ image: CGImage) -> [String] {
        [(0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)].map { x, y in
            let value = pixel(image, x: x, y: y)
            if value[2] > 200 && value[0] < 100 { return "B" }
            if value[0] > 200 && value[1] > 200 && value[2] < 100 { return "Y" }
            if value[1] > 200 && value[0] < 100 && value[2] < 100 { return "G" }
            if value[0] > 200 && value[1] < 100 && value[2] < 100 { return "R" }
            preconditionFailure("Unexpected corner \(value)")
        }
    }

    static func write(_ images: [CGImage], to url: URL, type: UTType, orientation: Int = 1, loop: Int = 3) {
        let writer = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, images.count, nil)!
        CGImageDestinationSetProperties(writer, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loop]] as CFDictionary)
        for (index, image) in images.enumerated() {
            CGImageDestinationAddImage(writer, image, [kCGImagePropertyOrientation: orientation, kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCompression: 5], kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: index == 0 ? 0.1 : 0.3]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(writer))
    }

    static func pixel(_ image: CGImage, x: Int = 0, y: Int = 0) -> [UInt8] {
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pointer = context.data!.assumingMemoryBound(to: UInt8.self).advanced(by: (y * image.width + x) * 4)
        return Array(UnsafeBufferPointer(start: pointer, count: 4))
    }

    static func read(_ url: URL) -> [CGImage] {
        if url.pathExtension == "webp" {
            let data = try! Data(contentsOf: url)
            return data.withUnsafeBytes { bytes in
                var input = WebPData(bytes: bytes.bindMemory(to: UInt8.self).baseAddress, size: data.count)
                var options = WebPAnimDecoderOptions()
                precondition(WebPAnimDecoderOptionsInitInternal(&options, WEBP_DEMUX_ABI_VERSION) != 0)
                options.color_mode = MODE_RGBA
                let decoder = WebPAnimDecoderNewInternal(&input, &options, WEBP_DEMUX_ABI_VERSION)!
                defer { WebPAnimDecoderDelete(decoder) }
                var info = WebPAnimInfo()
                precondition(WebPAnimDecoderGetInfo(decoder, &info) != 0)
                var images: [CGImage] = []
                while WebPAnimDecoderHasMoreFrames(decoder) != 0 {
                    var rgba: UnsafeMutablePointer<UInt8>?
                    var timestamp: Int32 = 0
                    precondition(WebPAnimDecoderGetNext(decoder, &rgba, &timestamp) != 0)
                    let pixels = Data(bytes: rgba!, count: Int(info.canvas_width * info.canvas_height * 4))
                    images.append(CGImage(width: Int(info.canvas_width), height: Int(info.canvas_height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Int(info.canvas_width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: CGDataProvider(data: pixels as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!)
                }
                return images
            }
        }
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        return (0..<CGImageSourceGetCount(source)).map { CGImageSourceCreateImageAtIndex(source, $0, nil)! }
    }

    static func animation(_ url: URL) -> ([Double], Int?) {
        if url.pathExtension == "webp" {
            let data = try! Data(contentsOf: url)
            return data.withUnsafeBytes { bytes in
                var input = WebPData(bytes: bytes.bindMemory(to: UInt8.self).baseAddress, size: data.count)
                var state = WEBP_DEMUX_PARSING_HEADER
                let demux = WebPDemuxInternal(&input, 0, &state, WEBP_DEMUX_ABI_VERSION)!
                defer { WebPDemuxDelete(demux) }
                var durations: [Double] = []
                var iterator = WebPIterator()
                precondition(WebPDemuxGetFrame(demux, 1, &iterator) != 0)
                repeat { durations.append(Double(iterator.duration) / 1000) } while WebPDemuxNextFrame(&iterator) != 0
                WebPDemuxReleaseIterator(&iterator)
                return (durations, Int(WebPDemuxGetI(demux, WEBP_FF_LOOP_COUNT)))
            }
        }
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let props = CGImageSourceCopyProperties(source, nil)! as NSDictionary
        let gif = props[kCGImagePropertyGIFDictionary] as? NSDictionary
        let durations = (0..<CGImageSourceGetCount(source)).map { index -> Double in
            let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil)! as NSDictionary
            let gif = props[kCGImagePropertyGIFDictionary] as! NSDictionary
            return (gif[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber ?? gif[kCGImagePropertyGIFDelayTime] as! NSNumber).doubleValue
        }
        return (durations, (gif?[kCGImagePropertyGIFLoopCount] as? NSNumber)?.intValue)
    }

    static func rejects(_ expected: String? = nil, cancellation: Bool = false, _ operation: () throws -> Void) {
        do { try operation(); preconditionFailure("Expected rejection") }
        catch {
            precondition(!error.localizedDescription.isEmpty)
            if let expected { precondition(error.localizedDescription.contains(expected), "Unexpected error: \(error)") }
            if cancellation { precondition(error is CancellationError) }
        }
    }

    static func attachEXIF(_ tiff: URL, to webp: URL, output: URL) throws {
        let data = try Data(contentsOf: webp)
        let exif = try Data(contentsOf: tiff)
        try data.withUnsafeBytes { bytes in
            var input = WebPData(bytes: bytes.bindMemory(to: UInt8.self).baseAddress, size: data.count)
            let mux = WebPMuxCreateInternal(&input, 1, WEBP_MUX_ABI_VERSION)!
            defer { WebPMuxDelete(mux) }
            exif.withUnsafeBytes { bytes in
                var chunk = WebPData(bytes: bytes.bindMemory(to: UInt8.self).baseAddress, size: exif.count)
                precondition(WebPMuxSetChunk(mux, "EXIF", &chunk, 1) == WEBP_MUX_OK)
            }
            var result = WebPData()
            defer { WebPFree(UnsafeMutableRawPointer(mutating: result.bytes)) }
            precondition(WebPMuxAssemble(mux, &result) == WEBP_MUX_OK)
            try Data(bytes: result.bytes!, count: result.size).write(to: output)
        }
    }

    static func setWebPLoop(_ loop: Int, in webp: URL, output: URL) throws {
        let data = try Data(contentsOf: webp)
        try data.withUnsafeBytes { bytes in
            var input = WebPData(bytes: bytes.bindMemory(to: UInt8.self).baseAddress, size: data.count)
            let mux = WebPMuxCreateInternal(&input, 1, WEBP_MUX_ABI_VERSION)!
            defer { WebPMuxDelete(mux) }
            var params = WebPMuxAnimParams()
            precondition(WebPMuxGetAnimationParams(mux, &params) == WEBP_MUX_OK)
            params.loop_count = Int32(loop)
            precondition(WebPMuxSetAnimationParams(mux, &params) == WEBP_MUX_OK)
            var result = WebPData()
            defer { WebPFree(UnsafeMutableRawPointer(mutating: result.bytes)) }
            precondition(WebPMuxAssemble(mux, &result) == WEBP_MUX_OK)
            try Data(bytes: result.bytes!, count: result.size).write(to: output)
        }
    }

    static func checkAnimation(_ url: URL, loop: Int?) {
        let images = read(url)
        precondition(images.count == 2 && pixel(images[0])[0] > 230 && pixel(images[1])[2] > 230)
        let (times, actual) = animation(url)
        precondition(times.count == 2 && abs(times[0] - 0.1) < 0.011 && abs(times[1] - 0.3) < 0.011)
        precondition(actual == loop, "Loop metadata changed for \(url.lastPathComponent): expected \(String(describing: loop)), got \(String(describing: actual))")
    }

    static func checkLoops(_ service: ImageService, root: URL, output: URL, red: CGImage, blue: CGImage) throws {
        for loop in [1, 0, 2, 4] {
            let label = loop == 1 ? "absent" : String(loop)
            let input = root.appendingPathComponent("loop-\(label).gif")
            if loop == 1 {
                // Pillow 编码的两帧 GIF：省略 loop 参数，未写入循环扩展。
                let fixture = Data(base64Encoded: "R0lGODlhBgAEAIEAAP8AAAAAAAAAAAAAACH5BAAKAAAALAAAAAAGAAQAAAgLAAEIHEiwoMGBAQEAIfkEAR4AAQAsAAAAAAYABACBAAD/AAAAAAAAAAAACAsAAQgcSLCgwYEBAQA7")!
                try fixture.write(to: input)
            } else { write([red, blue], to: input, type: .gif, loop: loop) }
            checkAnimation(input, loop: loop)
            let gif = try service.convert(input, to: .gif, quality: 1, frame: nil, in: output, named: "loop-gif-\(label)", progress: Progress())
            checkAnimation(gif, loop: loop)
            let webp = try service.convert(input, to: .webp, quality: 1, frame: nil, in: output, named: "loop-webp-\(label)", progress: Progress())
            checkAnimation(webp, loop: loop)
            let back = try service.convert(webp, to: .gif, quality: 1, frame: nil, in: output, named: "loop-back-\(label)", progress: Progress())
            checkAnimation(back, loop: loop)
            let again = try service.convert(back, to: .webp, quality: 1, frame: nil, in: output, named: "loop-again-\(label)", progress: Progress())
            checkAnimation(again, loop: loop)
            let fixture = root.appendingPathComponent("native-webp-\(loop).webp")
            try setWebPLoop(loop, in: webp, output: fixture)
            checkAnimation(fixture, loop: loop)
            let reverse = try service.convert(fixture, to: .gif, quality: 1, frame: nil, in: output, named: "reverse-gif-\(label)", progress: Progress())
            checkAnimation(reverse, loop: loop)
            let reverseWebP = try service.convert(reverse, to: .webp, quality: 1, frame: nil, in: output, named: "reverse-webp-\(label)", progress: Progress())
            checkAnimation(reverseWebP, loop: loop)
        }
    }

    static func streaming(_ service: ImageService, root: URL, output: URL) throws {
        let red = image(32, 24, color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        let blue = image(32, 24, color: CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        for format in [ImageFormat.gif, .webp] {
            let contentBefore = Set(try manager.contentsOfDirectory(atPath: output.path))
            var contentCalls = 0
            rejects("内容") {
                _ = try service.encodeAnimation(frameCount: 1, frameAt: { _ in
                    contentCalls += 1
                    return contentCalls == 1 ? red : blue
                }, durations: [0.1], loop: 0, to: format, quality: 1, in: output, named: "changed-content", progress: Progress())
            }
            precondition(contentCalls == 2)
            check(Set(try manager.contentsOfDirectory(atPath: output.path)) == contentBefore)
            var sequenceCalls = 0
            rejects("内容") {
                _ = try service.encodeAnimation(frameCount: 3, frameAt: { index in
                    sequenceCalls += 1
                    return (sequenceCalls <= 3 ? index : 2 - index) == 0 ? red : blue
                }, durations: [0.1, 0.1, 0.1], loop: 0, to: format, quality: 1, in: output, named: "changed-sequence", progress: Progress())
            }
            precondition(sequenceCalls == 4)
            check(Set(try manager.contentsOfDirectory(atPath: output.path)) == contentBefore)
            let lowQuality = try service.encodeAnimation(frameCount: 1, frameAt: { _ in red }, durations: [0.1], loop: 0, to: format, quality: 0.1, in: output, named: "low-quality-content", progress: Progress())
            precondition(pixel(read(lowQuality)[0])[0] > 200)
            let fractional = try service.encodeAnimation(frameCount: 29, frameAt: { _ in red }, durations: Array(repeating: 1.0 / 29, count: 29), loop: 0, to: format, quality: 1, in: output, named: "stream-fractional-\(format)", progress: Progress())
            let times = animation(fractional).0
            precondition(times.count == 29 && abs(times.reduce(0, +) - 1) <= (format == .gif ? 0.01 : 0.001) + 1e-8, "Cumulative duration drift")
            for loop in [0, 1, 4] {
                var calls: [Int] = []
                let progress = Progress()
                let result = try service.encodeAnimation(frameCount: 3, frameAt: { index in
                    calls.append(index)
                    return index == 2 ? blue : red
                }, durations: [0.03, 0.04, 0.03], loop: loop, to: format, quality: 1, in: output, named: "stream-\(format)-\(loop)", progress: progress)
                precondition(calls == [0, 1, 2, 0, 1, 2], "Every frame must be encoded and validated on demand")
                let frames = read(result), metadata = animation(result)
                precondition(frames.count == 3 && pixel(frames[0])[0] > 230 && pixel(frames[1])[0] > 230 && pixel(frames[2])[2] > 230)
                precondition(metadata.1 == loop && zip(metadata.0, [0.03, 0.04, 0.03]).allSatisfy { abs($0 - $1) < 0.0011 })
                precondition(progress.completedUnitCount == 6 && progress.totalUnitCount == 6)
                let single = try service.encodeAnimation(frameCount: 1, frameAt: { _ in red }, durations: [0.25], loop: loop, to: format, quality: 1, in: output, named: "stream-single-\(format)-\(loop)", progress: Progress())
                precondition(animation(single).1 == loop && abs(animation(single).0[0] - 0.25) < 0.0011)
            }
            let before = Set(try manager.contentsOfDirectory(atPath: output.path))
            for boundary in [1, 3, 6] {
                let progress = Progress()
                let observation = progress.observe(\.completedUnitCount) { value, _ in
                    if value.completedUnitCount >= boundary { value.cancel() }
                }
                rejects(cancellation: true) {
                    _ = try service.encodeAnimation(frameCount: 3, frameAt: { _ in red }, durations: [0.1, 0.1, 0.1], loop: 0, to: format, quality: 1, in: output, named: "stream-cancel", progress: progress)
                }
                observation.invalidate()
                check(Set(try manager.contentsOfDirectory(atPath: output.path)) == before)
                check(!(try manager.contentsOfDirectory(atPath: root.path)).contains { $0.hasPrefix(".image-") })
            }
            rejects("尺寸") {
                _ = try service.encodeAnimation(frameCount: 2, frameAt: { $0 == 0 ? red : image(2, 2, color: CGColor(gray: 0, alpha: 1)) }, durations: [0.1, 0.1], loop: 0, to: format, quality: 1, in: output, named: "invalid-size", progress: Progress())
            }
            for times in [[0.0], [0.0001], [-0.1], [Double.nan], [Double.infinity], []] {
                var calls = 0
                rejects {
                    _ = try service.encodeAnimation(frameCount: 1, frameAt: { _ in calls += 1; return red }, durations: times, loop: 0, to: format, quality: 1, in: output, named: "invalid-time", progress: Progress())
                }
                precondition(calls == 0)
            }
            for (count, quality, loop, outputFormat) in [(0, 1.0, 0, format), (1001, 1.0, 0, format), (1, 0.0, 0, format), (1, Double.nan, 0, format), (1, 1.0, -1, format), (1, 1.0, 65536, format), (1, 1.0, 0, ImageFormat.png)] {
                var calls = 0
                rejects {
                    _ = try service.encodeAnimation(frameCount: count, frameAt: { _ in calls += 1; return red }, durations: Array(repeating: 0.1, count: max(0, count)), loop: loop, to: outputFormat, quality: quality, in: output, named: "invalid-params", progress: Progress())
                }
                precondition(calls == 0)
            }
            for failureAt in [2, 4] {
                var calls = 0
                rejects("provider failed") {
                    _ = try service.encodeAnimation(frameCount: 3, frameAt: { _ in
                        calls += 1
                        if calls == failureAt { throw NSError(domain: "provider failed", code: 1, userInfo: [NSLocalizedDescriptionKey: "provider failed"]) }
                        return red
                    }, durations: [0.1, 0.1, 0.1], loop: 0, to: format, quality: 1, in: output, named: "invalid-provider", progress: Progress())
                }
                precondition(calls == failureAt)
            }
            check(Set(try manager.contentsOfDirectory(atPath: output.path)) == before)
            check(!(try manager.contentsOfDirectory(atPath: root.path)).contains { $0.hasPrefix(".image-") })
        }
        autoreleasepool {
            let wide = image(16384, 1, color: CGColor(gray: 0, alpha: 1))
            rejects("16383") { _ = try service.encodeAnimation(frameCount: 1, frameAt: { _ in wide }, durations: [0.1], loop: 0, to: .webp, quality: 1, in: output, named: "invalid-wide", progress: Progress()) }
            let large = image(6000, 5000, color: CGColor(gray: 0, alpha: 1))
            var calls = 0
            rejects("8000 万") { _ = try service.encodeAnimation(frameCount: 3, frameAt: { _ in calls += 1; return large }, durations: [0.1, 0.1, 0.1], loop: 0, to: .gif, quality: 1, in: output, named: "invalid-total", progress: Progress()) }
            precondition(calls == 1)
        }
        let half = image(32, 24, color: CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        let singleAlpha = try service.encodeAnimation(frameCount: 1, frameAt: { _ in half }, durations: [0.25], loop: 4, to: .webp, quality: 1, in: output, named: "stream-single-alpha", progress: Progress())
        let decoded = pixel(read(singleAlpha)[0])
        precondition((126...130).contains(decoded[3]) && decoded[0] >= 120 && animation(singleAlpha).1 == 4 && abs(animation(singleAlpha).0[0] - 0.25) < 0.0011)
        print("ImageSmoke streaming passed: lazy callbacks, duplicate and single frames, timing, loops, validation and cancellation")
    }

    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).standardizedFileURL
        precondition(!manager.fileExists(atPath: root.path), "Use a fresh test directory")
        let store = try FileStore(root: root)
        let service = ImageService(root: store.root)
        let output = try store.createFolder(named: "outputs", in: root)
        let red = image(6, 4, color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        let blue = image(6, 4, color: CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        let input = root.appendingPathComponent("input.png")
        write([red], to: input, type: .png)
        let original = try Data(contentsOf: input)
        for format in ImageFormat.allCases {
            let progress = Progress(totalUnitCount: 0)
            let result = try service.convert(input, to: format, quality: 0.8, frame: nil, in: output, named: format.rawValue, progress: progress)
            let decoded = read(result)
            if format != .webp {
                let types: [ImageFormat: UTType] = [.tiff: .tiff, .gif: .gif, .png: .png, .jpeg: .jpeg, .bmp: .bmp]
                precondition(CGImageSourceGetType(CGImageSourceCreateWithURL(result as CFURL, nil)!) as String? == types[format]!.identifier)
            }
            precondition(decoded.count == 1 && decoded[0].width == 6 && decoded[0].height == 4)
            precondition(pixel(decoded[0])[0] > 230 && pixel(decoded[0])[2] < 25)
            precondition(progress.completedUnitCount == progress.totalUnitCount && progress.totalUnitCount > 0)
        }
        let gif = root.appendingPathComponent("animated.gif")
        write([red, blue], to: gif, type: .gif)
        check(try service.frameCount(gif) == 2)
        try checkLoops(service, root: root, output: output, red: red, blue: blue)
        for format in [ImageFormat.gif, .webp, .tiff] {
            let result = try service.convert(gif, to: format, quality: 1, frame: nil, in: output, named: "animation-" + format.rawValue, progress: Progress())
            let decoded = read(result)
            precondition(decoded.count == 2 && pixel(decoded[0])[0] > 230 && pixel(decoded[1])[2] > 230)
            if format != .tiff {
                let (times, loop) = animation(result)
                precondition(times.count == 2 && abs(times[0] - 0.1) < 0.011 && abs(times[1] - 0.3) < 0.011 && loop == 3)
                let back = try service.convert(result, to: .gif, quality: 1, frame: nil, in: output, named: "back-" + format.rawValue, progress: Progress())
                precondition(read(back).count == 2 && animation(back).1 == 3 && abs(animation(back).0[1] - 0.3) < 0.011)
            } else {
                let back = try service.convert(result, to: .gif, quality: 1, frame: nil, in: output, named: "back-tiff", progress: Progress())
                precondition(read(back).count == 2 && pixel(read(back)[1])[2] > 230)
            }
        }
        for format in [ImageFormat.png, .jpeg, .bmp] {
            rejects { _ = try service.convert(gif, to: format, quality: 1, frame: nil, in: output, named: "missing-frame", progress: Progress()) }
            let result = try service.convert(gif, to: format, quality: 1, frame: 1, in: output, named: "selected-" + format.rawValue, progress: Progress())
            precondition(read(result).count == 1 && pixel(read(result)[0])[2] > 230)
        }
        let frames = try service.extractFrames(gif, in: output, named: "frames", progress: Progress())
        let extracted = try manager.contentsOfDirectory(at: frames, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent < $1.lastPathComponent }
        precondition(extracted.map(\.lastPathComponent) == ["frame-000001.png", "frame-000002.png"])
        precondition(pixel(read(extracted[0])[0])[0] > 230 && pixel(read(extracted[1])[0])[2] > 230)
        let framesAgain = try service.extractFrames(gif, in: output, named: "frames", progress: Progress())
        precondition(framesAgain.lastPathComponent == "frames 2" && read(extracted[0]).count == 1)
        let duplicateGIF = root.appendingPathComponent("duplicate.gif")
        write([red, red], to: duplicateGIF, type: .gif)
        let duplicateWebP = try service.convert(duplicateGIF, to: .webp, quality: 1, frame: nil, in: output, named: "duplicate", progress: Progress())
        precondition(read(duplicateWebP).count == 2 && animation(duplicateWebP).0 == [0.1, 0.3] && animation(duplicateWebP).1 == 3)
        let transparent = root.appendingPathComponent("transparent.png")
        write([image(3, 2, color: CGColor(gray: 0, alpha: 0))], to: transparent, type: .png)
        for format in [ImageFormat.jpeg, .bmp] {
            let result = try service.convert(transparent, to: format, quality: 1, frame: nil, in: output, named: "white-" + format.rawValue, progress: Progress())
            precondition(pixel(read(result)[0]).allSatisfy { $0 >= 250 })
        }
        let expected = [["R", "B", "G", "Y"], ["B", "R", "Y", "G"], ["Y", "G", "B", "R"], ["G", "Y", "R", "B"], ["R", "G", "B", "Y"], ["G", "R", "Y", "B"], ["Y", "B", "G", "R"], ["B", "Y", "R", "G"]]
        for orientation in 1...8 {
            let oriented = root.appendingPathComponent("oriented-\(orientation).tiff")
            write([pattern()], to: oriented, type: .tiff, orientation: orientation)
            let result = try service.convert(oriented, to: .png, quality: 1, frame: nil, in: output, named: "oriented-\(orientation)", progress: Progress())
            let image = read(result)[0]
            precondition(image.width == (orientation >= 5 ? 4 : 6) && image.height == (orientation >= 5 ? 6 : 4))
            precondition(corners(image) == expected[orientation - 1], "EXIF \(orientation): \(corners(image))")
        }
        let half = root.appendingPathComponent("half.png")
        write([image(6, 4, color: CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))], to: half, type: .png)
        let halfWebP = try service.convert(half, to: .webp, quality: 1, frame: nil, in: output, named: "half", progress: Progress())
        let halfPNG = try service.convert(halfWebP, to: .png, quality: 1, frame: nil, in: output, named: "half-back", progress: Progress())
        precondition((126...130).contains(pixel(read(halfPNG)[0])[3]) && pixel(read(halfPNG)[0])[0] >= 120)
        let patternPNG = root.appendingPathComponent("pattern.png")
        write([pattern()], to: patternPNG, type: .png)
        let patternWebP = try service.convert(patternPNG, to: .webp, quality: 1, frame: nil, in: output, named: "pattern", progress: Progress())
        let exifWebP = root.appendingPathComponent("exif.webp")
        try attachEXIF(root.appendingPathComponent("oriented-6.tiff"), to: patternWebP, output: exifWebP)
        let exifPNG = try service.convert(exifWebP, to: .png, quality: 1, frame: nil, in: output, named: "exif-webp", progress: Progress())
        precondition(read(exifPNG)[0].width == 4 && read(exifPNG)[0].height == 6 && corners(read(exifPNG)[0]) == expected[5])
        let composition = try service.compose([input, transparent], in: output, named: "composed", progress: Progress())
        let composed = read(composition)[0]
        precondition(composed.width == 6 && composed.height == 6)
        precondition(pixel(composed, y: 0)[0] > 230 && pixel(composed, y: 0)[2] < 25 && pixel(composed, y: 5)[0] > 250 && pixel(composed, y: 5)[2] > 250)
        precondition(pixel(composed, x: 5, y: 5)[0] > 250 && pixel(composed, x: 5, y: 5)[2] > 250)
        let sentinel = output.appendingPathComponent("sentinel.png")
        try original.write(to: sentinel)
        let collision = try service.convert(input, to: .png, quality: 1, frame: nil, in: output, named: "sentinel", progress: Progress())
        check(try collision.lastPathComponent == "sentinel 2.png" && Data(contentsOf: sentinel) == original)
        let bad = root.appendingPathComponent("bad.png")
        try Data("bad".utf8).write(to: bad)
        let before = Set(try manager.contentsOfDirectory(atPath: output.path))
        for quality in [0.0, 1.1, .nan, .infinity] { rejects { _ = try service.convert(input, to: .png, quality: quality, frame: nil, in: output, named: "invalid", progress: Progress()) } }
        for frame in [-1, 2] { rejects { _ = try service.convert(gif, to: .png, quality: 1, frame: frame, in: output, named: "invalid", progress: Progress()) } }
        rejects { _ = try service.convert(bad, to: .png, quality: 1, frame: nil, in: output, named: "invalid", progress: Progress()) }
        rejects { _ = try service.compose([], in: output, named: "invalid", progress: Progress()) }
        rejects { _ = try service.compose([gif], in: output, named: "invalid", progress: Progress()) }
        for name in ["", ".", "..", "a/b", "a\0b"] { rejects { _ = try service.extractFrames(input, in: output, named: name, progress: Progress()) } }
        let link = root.appendingPathComponent("link")
        try manager.createSymbolicLink(at: link, withDestinationURL: root)
        let outside = root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent + "-outside", isDirectory: true)
        try manager.createDirectory(at: outside, withIntermediateDirectories: false)
        let outsideSentinel = outside.appendingPathComponent("sentinel.png")
        try original.write(to: outsideSentinel)
        let externalLink = root.appendingPathComponent("external-link")
        try manager.createSymbolicLink(at: externalLink, withDestinationURL: outside)
        for invalid in [link.appendingPathComponent("input.png"), URL(fileURLWithPath: root.path + "/link/../input.png"), URL(fileURLWithPath: root.path + "/./input.png"), outsideSentinel, externalLink.appendingPathComponent("sentinel.png")] {
            rejects { _ = try service.frameCount(invalid) }
            rejects { _ = try service.convert(invalid, to: .png, quality: 1, frame: nil, in: output, named: "invalid", progress: Progress()) }
            rejects { _ = try service.extractFrames(invalid, in: output, named: "invalid", progress: Progress()) }
            rejects { _ = try service.compose([input, invalid], in: output, named: "invalid", progress: Progress()) }
        }
        for invalidFolder in [link, externalLink, URL(fileURLWithPath: root.path + "/link/../outputs"), input, outside] {
            rejects { _ = try service.convert(input, to: .png, quality: 1, frame: nil, in: invalidFolder, named: "invalid", progress: Progress()) }
            rejects { _ = try service.extractFrames(input, in: invalidFolder, named: "invalid", progress: Progress()) }
            rejects { _ = try service.compose([input], in: invalidFolder, named: "invalid", progress: Progress()) }
        }
        let cancelled = Progress()
        cancelled.cancel()
        rejects { _ = try service.convert(input, to: .png, quality: 1, frame: nil, in: output, named: "invalid", progress: cancelled) }
        rejects { _ = try service.extractFrames(gif, in: output, named: "invalid", progress: cancelled) }
        rejects { _ = try service.compose([input], in: output, named: "invalid", progress: cancelled) }
        for boundary in [1, 2] {
            for operation in 0..<4 {
                let progress = Progress()
                let observation = progress.observe(\.completedUnitCount) { value, _ in
                    if boundary == 1 && value.completedUnitCount >= 1 || boundary == 2 && value.completedUnitCount == value.totalUnitCount && value.completedUnitCount > 0 { value.cancel() }
                }
                rejects(cancellation: true) {
                    switch operation {
                    case 0: _ = try service.convert(gif, to: .gif, quality: 1, frame: nil, in: output, named: "mid-cancel", progress: progress)
                    case 1: _ = try service.convert(gif, to: .webp, quality: 1, frame: nil, in: output, named: "mid-cancel", progress: progress)
                    case 2: _ = try service.extractFrames(gif, in: output, named: "mid-cancel", progress: progress)
                    default: _ = try service.compose([input, transparent], in: output, named: "mid-cancel", progress: progress)
                    }
                }
                observation.invalidate()
                precondition(progress.completedUnitCount == Int64(boundary == 1 ? 1 : 2))
                check(Set(try manager.contentsOfDirectory(atPath: output.path)) == before)
                check(!(try manager.contentsOfDirectory(atPath: root.path)).contains { $0.hasPrefix(".image-") })
            }
        }
        let denied = try store.createFolder(named: "denied", in: root)
        try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: denied.path)
        defer { try! manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: denied.path) }
        rejects { _ = try service.convert(input, to: .png, quality: 1, frame: nil, in: denied, named: "denied", progress: Progress()) }
        rejects { _ = try service.extractFrames(gif, in: denied, named: "denied", progress: Progress()) }
        rejects { _ = try service.compose([input], in: denied, named: "denied", progress: Progress()) }
        check(try manager.contentsOfDirectory(atPath: denied.path).isEmpty)
        autoreleasepool {
            let huge = root.appendingPathComponent("huge.tiff")
            write([image(8001, 5000, color: CGColor(gray: 0, alpha: 1))], to: huge, type: .tiff)
            rejects("4000 万") { _ = try service.frameCount(huge) }
            rejects("4000 万") { _ = try service.convert(huge, to: .png, quality: 1, frame: nil, in: output, named: "huge", progress: Progress()) }
            let total = root.appendingPathComponent("total.tiff")
            let large = image(6000, 5000, color: CGColor(gray: 0, alpha: 1))
            write([large, large, large], to: total, type: .tiff)
            rejects("8000 万") { _ = try service.frameCount(total) }
            rejects("8000 万") { _ = try service.extractFrames(total, in: output, named: "huge", progress: Progress()) }
            let wide = root.appendingPathComponent("wide.png")
            write([image(5000, 4001, color: CGColor(gray: 0, alpha: 1))], to: wide, type: .png)
            rejects("4000 万") { _ = try service.compose([wide, wide], in: output, named: "huge", progress: Progress()) }
            let many = root.appendingPathComponent("many.tiff")
            write(Array(repeating: red, count: 1001), to: many, type: .tiff)
            rejects("1–1000") { _ = try service.frameCount(many) }
        }
        let cleanupProgress = Progress()
        var blocked: URL?
        let cleanupObservation = cleanupProgress.observe(\.completedUnitCount) { value, _ in
            if value.completedUnitCount == 2 {
                let staging = try! manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix(".image-") }
                precondition(staging.count == 1)
                blocked = staging[0].appendingPathComponent("frames", isDirectory: true)
                precondition(manager.fileExists(atPath: blocked!.appendingPathComponent("frame-000001.png").path))
                try! manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: blocked!.path)
                value.cancel()
            }
        }
        rejects("暂存清理失败") { _ = try service.extractFrames(gif, in: output, named: "cleanup-failure", progress: cleanupProgress) }
        cleanupObservation.invalidate()
        precondition(blocked != nil)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: blocked!.path)
        try manager.removeItem(at: blocked!.deletingLastPathComponent())
        check(Set(try manager.contentsOfDirectory(atPath: output.path)) == before)
        check(try Data(contentsOf: input) == original && Data(contentsOf: sentinel) == original)
        check(try Data(contentsOf: outsideSentinel) == original && manager.contentsOfDirectory(atPath: outside.path) == ["sentinel.png"])
        check(!(try manager.contentsOfDirectory(atPath: root.path)).contains { $0.hasPrefix(".image-") })
        try streaming(service, root: root, output: output)
        print("ImageSmoke passed: six codecs, frame content/timing/loop, selection, extraction, orientation, white background, composition, collisions, validation, boundaries, cancellation, cleanup")
    }
}
