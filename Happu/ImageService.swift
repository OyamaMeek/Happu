import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import libwebp

enum ImageFormat: String, CaseIterable { case tiff, gif, webp, png, jpeg, bmp }

struct ImageService {
    let root: URL
    private let manager = FileManager.default

    func convert(_ input: URL, to format: ImageFormat, quality: Double, frame: Int?, in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkCancellation(progress)
        try checkFolder(folder)
        let outputName = try fileName(name, format: format)
        guard quality.isFinite, (0.1...1).contains(quality) else { throw ImageServiceError("图片质量必须为 0.1–1.0。") }
        let source = try open(input)
        if let frame {
            guard source.sizes.indices.contains(frame) else { throw ImageServiceError("帧序号超出范围；帧序号从零开始。") }
        } else if source.sizes.count > 1, ![ImageFormat.gif, .webp, .tiff].contains(format) {
            throw ImageServiceError("多帧图片转换为静态格式时必须选择帧序号。")
        }
        let indices = frame.map { [$0] } ?? Array(source.sizes.indices)
        progress.totalUnitCount = Int64(indices.count)
        progress.completedUnitCount = 0
        let images = try decode(source, indices: indices, progress: progress)
        let durations = indices.map { source.durations[$0] }
        return try withStaging { staging in
            let output = staging.appendingPathComponent("output." + format.rawValue)
            try write(images, durations: durations, loop: source.loop, format: format, quality: quality, to: output, progress: progress)
            return try publish(output, in: folder, named: outputName, progress: progress)
        }
    }

    func extractFrames(_ input: URL, in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkCancellation(progress)
        try checkFolder(folder)
        let outputName = try validName(name)
        let source = try open(input)
        progress.totalUnitCount = Int64(source.sizes.count)
        progress.completedUnitCount = 0
        let images = try decode(source, indices: Array(source.sizes.indices), progress: progress)
        return try withStaging { staging in
            let output = staging.appendingPathComponent("frames", isDirectory: true)
            try manager.createDirectory(at: output, withIntermediateDirectories: false)
            for (index, image) in images.enumerated() {
                try checkCancellation(progress)
                let file = output.appendingPathComponent(String(format: "frame-%06d.png", index + 1))
                try write([image], durations: [0.1], loop: 0, format: .png, quality: 1, to: file, progress: progress)
            }
            return try publish(output, in: folder, named: outputName, progress: progress)
        }
    }

    func compose(_ inputs: [URL], in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkCancellation(progress)
        try checkFolder(folder)
        let outputName = try fileName(name, format: .png)
        guard !inputs.isEmpty else { throw ImageServiceError("图片合成至少需要一个输入文件。") }
        var sources: [Source] = []
        var width = 0
        var height = 0
        var inputPixels = 0
        for input in inputs {
            try checkCancellation(progress)
            let source = try open(input)
            guard source.sizes.count == 1 else { throw ImageServiceError("合成仅接受单帧图片；请先提取所需帧。") }
            let size = source.sizes[0]
            width = max(width, size.width)
            height += size.height
            inputPixels += size.width * size.height
            guard inputPixels <= 80_000_000 else { throw ImageServiceError("合成输入合计不得超过 8000 万像素。") }
            sources.append(source)
        }
        try checkSize(width, height)
        progress.totalUnitCount = Int64(inputs.count)
        progress.completedUnitCount = 0
        let context = try context(width, height, white: true)
        var y = height
        for source in sources {
            try checkCancellation(progress)
            let image = try decode(source, indices: [0], progress: progress)[0]
            y -= image.height
            context.draw(image, in: CGRect(x: 0, y: y, width: image.width, height: image.height))
            progress.completedUnitCount += 1
        }
        guard let image = context.makeImage() else { throw ImageServiceError("无法合成图片。") }
        return try withStaging { staging in
            let output = staging.appendingPathComponent("output.png")
            try write([image], durations: [0.1], loop: 0, format: .png, quality: 1, to: output, progress: progress, advance: false)
            return try publish(output, in: folder, named: outputName, progress: progress)
        }
    }

    func frameCount(_ input: URL) throws -> Int { try open(input).sizes.count }

    private struct Source {
        let data: Data
        let native: CGImageSource?
        let webp: Bool
        let sizes: [(width: Int, height: Int)]
        let orientations: [Int32]
        let durations: [Double]
        let loop: Int
    }

    private func open(_ input: URL) throws -> Source {
        try checkPath(input)
        guard try input.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { throw ImageServiceError("图片输入必须是普通文件。") }
        let data = try Data(contentsOf: input, options: .mappedIfSafe)
        let native = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        let webp: Source? = try data.withUnsafeBytes { bytes in
            var input = WebPData(bytes: bytes.bindMemory(to: UInt8.self).baseAddress, size: data.count)
            var state = WEBP_DEMUX_PARSING_HEADER
            guard let demux = WebPDemuxInternal(&input, 0, &state, WEBP_DEMUX_ABI_VERSION) else { return nil }
            defer { WebPDemuxDelete(demux) }
            guard state == WEBP_DEMUX_DONE else { throw ImageServiceError("WebP 文件不完整。") }
            let count = Int(WebPDemuxGetI(demux, WEBP_FF_FRAME_COUNT))
            let width = Int(WebPDemuxGetI(demux, WEBP_FF_CANVAS_WIDTH))
            let height = Int(WebPDemuxGetI(demux, WEBP_FF_CANVAS_HEIGHT))
            try checkCount(count)
            try checkSize(width, height)
            guard width * height <= 80_000_000 / count else { throw ImageServiceError("图片所有帧合计不得超过 8000 万像素。") }
            let properties = native.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as NSDictionary? }
            let orientation = try orientation(properties)
            let size = (orientation >= 5 ? height : width, orientation >= 5 ? width : height)
            var durations: [Double] = []
            var iterator = WebPIterator()
            guard WebPDemuxGetFrame(demux, 1, &iterator) != 0 else { throw ImageServiceError("无法读取 WebP 帧信息。") }
            defer { WebPDemuxReleaseIterator(&iterator) }
            repeat {
                guard iterator.complete != 0 else { throw ImageServiceError("WebP 包含不完整帧。") }
                durations.append(Double(iterator.duration) / 1000)
            } while WebPDemuxNextFrame(&iterator) != 0
            guard durations.count == count else { throw ImageServiceError("WebP 帧数不完整。") }
            return Source(data: data, native: native, webp: true, sizes: Array(repeating: size, count: count), orientations: Array(repeating: orientation, count: count), durations: durations, loop: Int(WebPDemuxGetI(demux, WEBP_FF_LOOP_COUNT)))
        }
        if let webp { return webp }
        guard let native else { throw ImageServiceError("无法打开图片，文件可能已损坏或格式不受支持。") }
        let count = CGImageSourceGetCount(native)
        try checkCount(count)
        var sizes: [(width: Int, height: Int)] = []
        var orientations: [Int32] = []
        var durations: [Double] = []
        var pixels = 0
        for index in 0..<count {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(native, index, nil) as NSDictionary?, let width = properties[kCGImagePropertyPixelWidth] as? NSNumber, let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else { throw ImageServiceError("图片帧尺寸无法读取。") }
            try checkSize(width.intValue, height.intValue)
            pixels += width.intValue * height.intValue
            guard pixels <= 80_000_000 else { throw ImageServiceError("图片所有帧合计不得超过 8000 万像素。") }
            let orientation = try orientation(properties)
            sizes.append(orientation >= 5 ? (height.intValue, width.intValue) : (width.intValue, height.intValue))
            orientations.append(orientation)
            let gif = properties[kCGImagePropertyGIFDictionary] as? NSDictionary
            let png = properties[kCGImagePropertyPNGDictionary] as? NSDictionary
            let duration = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber ?? gif?[kCGImagePropertyGIFDelayTime] as? NSNumber ?? png?[kCGImagePropertyAPNGUnclampedDelayTime] as? NSNumber ?? png?[kCGImagePropertyAPNGDelayTime] as? NSNumber)?.doubleValue ?? 0.1
            guard duration.isFinite, duration >= 0 else { throw ImageServiceError("图片帧时长无效。") }
            durations.append(duration)
        }
        let properties = CGImageSourceCopyProperties(native, nil) as NSDictionary?
        let gif = properties?[kCGImagePropertyGIFDictionary] as? NSDictionary
        let png = properties?[kCGImagePropertyPNGDictionary] as? NSDictionary
        let loop = (gif?[kCGImagePropertyGIFLoopCount] as? NSNumber ?? png?[kCGImagePropertyAPNGLoopCount] as? NSNumber)?.intValue ?? 1
        return Source(data: data, native: native, webp: false, sizes: sizes, orientations: orientations, durations: durations, loop: loop)
    }

    private func orientation(_ properties: NSDictionary?) throws -> Int32 {
        let value = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.int32Value ?? 1
        guard (1...8).contains(value) else { throw ImageServiceError("图片 EXIF 方向无效。") }
        return value
    }

    private func decode(_ source: Source, indices: [Int], progress: Progress) throws -> [CGImage] {
        if source.webp {
            return try source.data.withUnsafeBytes { bytes in
                var data = WebPData(bytes: bytes.bindMemory(to: UInt8.self).baseAddress, size: source.data.count)
                guard let decoder = WebPAnimDecoderNewInternal(&data, nil, WEBP_DEMUX_ABI_VERSION) else { throw ImageServiceError("无法创建 WebP 解码器。") }
                defer { WebPAnimDecoderDelete(decoder) }
                var info = WebPAnimInfo()
                guard WebPAnimDecoderGetInfo(decoder, &info) != 0 else { throw ImageServiceError("无法读取 WebP 信息。") }
                var images: [CGImage] = []
                for index in source.sizes.indices {
                    try checkCancellation(progress)
                    var buffer: UnsafeMutablePointer<UInt8>?
                    var timestamp: Int32 = 0
                    guard WebPAnimDecoderGetNext(decoder, &buffer, &timestamp) != 0, let buffer else { throw ImageServiceError("WebP 帧解码失败。") }
                    if indices.contains(index) {
                        let pixels = Data(bytes: buffer, count: Int(info.canvas_width) * Int(info.canvas_height) * 4)
                        guard let provider = CGDataProvider(data: pixels as CFData), let image = CGImage(width: Int(info.canvas_width), height: Int(info.canvas_height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Int(info.canvas_width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { throw ImageServiceError("无法分配 WebP 帧图像。") }
                        images.append(try normalize(image, orientation: source.orientations[index]))
                    }
                }
                return images
            }
        }
        guard let native = source.native else { throw ImageServiceError("图片解码器缺失。") }
        return try indices.map { index in
            try checkCancellation(progress)
            guard let image = CGImageSourceCreateImageAtIndex(native, index, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { throw ImageServiceError("图片第 \(index + 1) 帧解码失败。") }
            let result = try normalize(image, orientation: source.orientations[index])
            guard result.width == source.sizes[index].width, result.height == source.sizes[index].height else { throw ImageServiceError("图片帧尺寸与元数据不符。") }
            return result
        }
    }

    private func normalize(_ image: CGImage, orientation: Int32) throws -> CGImage {
        if orientation == 1 { return image }
        let oriented = CIImage(cgImage: image).oriented(forExifOrientation: orientation)
        guard let normalized = CIContext(options: [.cacheIntermediates: false]).createCGImage(oriented, from: oriented.extent) else { throw ImageServiceError("无法正常化图片 EXIF 方向。") }
        return normalized
    }

    private func write(_ images: [CGImage], durations: [Double], loop: Int, format: ImageFormat, quality: Double, to output: URL, progress: Progress, advance: Bool = true) throws {
        try checkCancellation(progress)
        var frames = images
        if format == .gif || format == .webp {
            let width = images.map(\.width).max()!
            let height = images.map(\.height).max()!
            try checkSize(width, height)
            guard width * height <= 80_000_000 / images.count else { throw ImageServiceError("输出所有帧合计不得超过 8000 万像素。") }
            frames = try images.map { image in
                if image.width == width && image.height == height { return image }
                let context = try context(width, height, white: false)
                context.draw(image, in: CGRect(x: 0, y: height - image.height, width: image.width, height: image.height))
                guard let frame = context.makeImage() else { throw ImageServiceError("无法创建动画画布。") }
                return frame
            }
            guard (0...65535).contains(loop) else { throw ImageServiceError("动画循环数必须为 0–65535。") }
        }
        if format == .webp {
            try writeWebP(frames, durations: durations, loop: loop, quality: quality, to: output, progress: progress, advance: advance)
        } else {
            let types: [ImageFormat: String] = [.tiff: UTType.tiff.identifier, .gif: UTType.gif.identifier, .png: UTType.png.identifier, .jpeg: UTType.jpeg.identifier, .bmp: UTType.bmp.identifier]
            guard let type = types[format], let writer = CGImageDestinationCreateWithURL(output as CFURL, type as CFString, frames.count, nil) else { throw ImageServiceError("无法创建 \(format.rawValue) 编码器。") }
            if format == .gif { CGImageDestinationSetProperties(writer, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loop]] as CFDictionary) }
            for (index, image) in frames.enumerated() {
                try checkCancellation(progress)
                var image = image
                if format == .jpeg || format == .bmp {
                    let context = try context(image.width, image.height, white: true)
                    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                    guard let whiteImage = context.makeImage() else { throw ImageServiceError("无法生成白色背景。") }
                    image = whiteImage
                }
                if format == .gif {
                    guard durations[index] <= 655.35 else { throw ImageServiceError("GIF 单帧时长不得超过 655.35 秒。") }
                }
                CGImageDestinationAddImage(writer, image, [kCGImageDestinationLossyCompressionQuality: quality, kCGImagePropertyOrientation: 1, kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: durations[index]]] as CFDictionary)
                if advance { progress.completedUnitCount += 1 }
            }
            try checkCancellation(progress)
            guard CGImageDestinationFinalize(writer) else { throw ImageServiceError("\(format.rawValue) 图片编码失败。") }
        }
        try checkCancellation(progress)
        let verified = try open(output)
        guard verified.sizes.count == frames.count else { throw ImageServiceError("输出帧数核对失败。") }
        let decoded = try decode(verified, indices: Array(verified.sizes.indices), progress: progress)
        for index in frames.indices {
            try checkCancellation(progress)
            guard decoded[index].width == frames[index].width, decoded[index].height == frames[index].height else { throw ImageServiceError("输出尺寸核对失败。") }
        }
        if frames.count > 1, format == .gif || format == .webp {
            let tolerance = format == .gif ? 0.011 : 0.0011
            guard verified.loop == loop, zip(verified.durations, durations).allSatisfy({ abs($0 - $1) <= tolerance }) else { throw ImageServiceError("输出动画时长或循环数核对失败。") }
        }
    }

    private func writeWebP(_ images: [CGImage], durations: [Double], loop: Int, quality: Double, to output: URL, progress: Progress, advance: Bool) throws {
        guard let mux = WebPNewInternal(WEBP_MUX_ABI_VERSION) else { throw ImageServiceError("无法创建 WebP 编码器。") }
        defer { WebPMuxDelete(mux) }
        if images.count > 1 {
            var params = WebPMuxAnimParams(bgcolor: 0, loop_count: Int32(loop))
            guard WebPMuxSetAnimationParams(mux, &params) == WEBP_MUX_OK else { throw ImageServiceError("WebP 动画参数设置失败。") }
        }
        for (index, image) in images.enumerated() {
            try checkCancellation(progress)
            guard image.width <= 16383, image.height <= 16383 else { throw ImageServiceError("WebP 宽高均不得超过 16383 像素。") }
            let context = try context(image.width, image.height, white: false)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { throw ImageServiceError("无法读取 WebP 像素。") }
            for offset in stride(from: 0, to: image.width * image.height * 4, by: 4) {
                let alpha = Int(pixels[offset + 3])
                if alpha > 0 && alpha < 255 {
                    for channel in 0..<3 { pixels[offset + channel] = UInt8(min(255, (Int(pixels[offset + channel]) * 255 + alpha / 2) / alpha)) }
                }
            }
            var encoded: UnsafeMutablePointer<UInt8>?
            let count = WebPEncodeRGBA(pixels, Int32(image.width), Int32(image.height), Int32(image.width * 4), Float(quality * 100), &encoded)
            guard count > 0, let encoded else { throw ImageServiceError("WebP 帧编码失败。") }
            defer { WebPFree(encoded) }
            let data = WebPData(bytes: encoded, size: count)
            if images.count == 1 {
                var data = data
                guard WebPMuxSetImage(mux, &data, 1) == WEBP_MUX_OK else { throw ImageServiceError("WebP 图像封装失败。") }
            } else {
                let milliseconds = (durations[index] * 1000).rounded()
                guard milliseconds.isFinite, (0...16_777_215).contains(milliseconds) else { throw ImageServiceError("WebP 单帧时长不得超过 16777.215 秒。") }
                var frame = WebPMuxFrameInfo()
                frame.bitstream = data
                frame.id = WEBP_CHUNK_ANMF
                frame.duration = Int32(milliseconds)
                frame.dispose_method = WEBP_MUX_DISPOSE_NONE
                frame.blend_method = WEBP_MUX_NO_BLEND
                guard WebPMuxPushFrame(mux, &frame, 1) == WEBP_MUX_OK else { throw ImageServiceError("WebP 动画帧封装失败。") }
            }
            if advance { progress.completedUnitCount += 1 }
        }
        try checkCancellation(progress)
        var assembled = WebPData()
        defer { WebPFree(UnsafeMutableRawPointer(mutating: assembled.bytes)) }
        guard WebPMuxAssemble(mux, &assembled) == WEBP_MUX_OK, let bytes = assembled.bytes else { throw ImageServiceError("WebP 文件封装失败。") }
        try Data(bytes: bytes, count: assembled.size).write(to: output)
    }

    private func context(_ width: Int, _ height: Int, white: Bool) throws -> CGContext {
        try checkSize(width, height)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ImageServiceError("无法分配图片内存。") }
        if white {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return context
    }

    private func checkSize(_ width: Int, _ height: Int) throws {
        guard width > 0, height > 0, width <= 40_000_000, height <= 40_000_000, width <= 40_000_000 / height else { throw ImageServiceError("图片单帧不得超过 4000 万像素，宽高必须大于零。") }
    }

    private func checkCount(_ count: Int) throws {
        guard (1...1000).contains(count) else { throw ImageServiceError("图片帧数必须为 1–1000。") }
    }

    private func checkPath(_ url: URL) throws {
        guard !url.pathComponents.contains(where: { $0 == "." || $0 == ".." }) else { throw ImageServiceError("图片路径不能包含相对目录组件。") }
        let rootPath = root.resolvingSymlinksInPath().path
        let candidate = url.standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath().path
        guard root.isFileURL, url.isFileURL, candidate.path == rootPath || candidate.path.hasPrefix(rootPath + "/"), resolved == rootPath || resolved.hasPrefix(rootPath + "/") else { throw ImageServiceError("图片输入和目标必须位于工作区内。") }
        var current = candidate
        while true {
            guard try current.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ImageServiceError("不支持符号链接路径。") }
            if current.path == rootPath { break }
            current.deleteLastPathComponent()
        }
    }

    private func checkFolder(_ folder: URL) throws {
        try checkPath(folder)
        guard try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw ImageServiceError("目的位置必须是已有文件夹。") }
    }

    private func validName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != ".", value != "..", !value.contains("/"), !value.contains("\0") else { throw ImageServiceError("输出名称无效。") }
        return value
    }

    private func fileName(_ name: String, format: ImageFormat) throws -> String {
        let value = try validName(name)
        return value.lowercased().hasSuffix("." + format.rawValue) ? value : value + "." + format.rawValue
    }

    private func withStaging(_ operation: (URL) throws -> URL) throws -> URL {
        try checkFolder(root)
        let staging = root.resolvingSymlinksInPath().appendingPathComponent(".image-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        let result: URL
        do { result = try operation(staging) }
        catch {
            do { try manager.removeItem(at: staging) }
            catch { throw ImageServiceError("图片暂存清理失败：\(error.localizedDescription)") }
            throw error
        }
        do { try manager.removeItem(at: staging) }
        catch {
            let cleanup = error
            do { try manager.removeItem(at: result) }
            catch { throw ImageServiceError("图片暂存清理及结果撤回失败：\(error.localizedDescription)") }
            throw ImageServiceError("图片暂存清理失败：\(cleanup.localizedDescription)")
        }
        return result
    }

    private func publish(_ output: URL, in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkFolder(folder)
        try checkCancellation(progress)
        let sourceVolume = try manager.attributesOfFileSystem(forPath: output.path)[.systemNumber] as? NSNumber
        let targetVolume = try manager.attributesOfFileSystem(forPath: folder.path)[.systemNumber] as? NSNumber
        guard let sourceVolume, let targetVolume, sourceVolume == targetVolume else { throw ImageServiceError("图片输出目标必须与工作区位于同一磁盘。") }
        let store = try FileStore(root: root)
        let ready = try store.rename(output, to: name)
        try checkCancellation(progress)
        let result = try store.move(ready, to: folder)
        if progress.isCancelled {
            try manager.removeItem(at: result)
            throw CancellationError()
        }
        return result
    }

    private func checkCancellation(_ progress: Progress) throws {
        if progress.isCancelled { throw CancellationError() }
    }
}

private struct ImageServiceError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
