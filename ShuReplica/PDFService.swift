import Foundation
import PDFKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct PDFService {
    let root: URL
    private let manager = FileManager.default

    func split(_ input: URL, password: String?, pagesPerPart: Int, in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkCancellation(progress)
        try checkFolder(folder)
        let outputName = try validName(name)
        guard pagesPerPart > 0 else { throw PDFServiceError("每份 PDF 页数必须大于零。") }
        let document = try open(input, password: password)
        guard document.pageCount > pagesPerPart else { throw PDFServiceError("当前页数无需按该页数分割。") }
        progress.totalUnitCount = Int64(document.pageCount)
        progress.completedUnitCount = 0
        return try withStaging { staging in
            let output = staging.appendingPathComponent("parts", isDirectory: true)
            try manager.createDirectory(at: output, withIntermediateDirectories: false)
            for start in stride(from: 0, to: document.pageCount, by: pagesPerPart) {
                try checkCancellation(progress)
                let part = PDFDocument()
                for index in start..<min(start + pagesPerPart, document.pageCount) {
                    try checkCancellation(progress)
                    guard let page = document.page(at: index)?.copy() as? PDFPage else { throw PDFServiceError("无法复制 PDF 页面。") }
                    part.insert(page, at: part.pageCount)
                    progress.completedUnitCount += 1
                }
                let file = output.appendingPathComponent(String(format: "part-%06d.pdf", start / pagesPerPart + 1))
                try writeVerified(part, to: file, progress: progress)
            }
            return try publish(output, in: folder, named: outputName, progress: progress)
        }
    }

    func merge(_ inputs: [URL], passwords: [URL: String], in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkCancellation(progress)
        try checkFolder(folder)
        let outputName = try pdfName(name)
        guard inputs.count >= 2 else { throw PDFServiceError("合并 PDF 至少需要两个输入文件。") }
        var documents: [PDFDocument] = []
        for input in inputs {
            try checkCancellation(progress)
            documents.append(try open(input, password: passwords[input]))
        }
        return try rebuild(documents, in: folder, named: outputName, progress: progress)
    }

    func exportPages(_ input: URL, password: String?, dpi: Double, jpeg: Bool, in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkCancellation(progress)
        try checkFolder(folder)
        let outputName = try validName(name)
        guard dpi.isFinite, (36...300).contains(dpi) else { throw PDFServiceError("PDF 导出分辨率必须为 36–300 dpi。") }
        let document = try open(input, password: password)
        progress.totalUnitCount = Int64(document.pageCount)
        progress.completedUnitCount = 0
        return try withStaging { staging in
            let output = staging.appendingPathComponent("pages", isDirectory: true)
            try manager.createDirectory(at: output, withIntermediateDirectories: false)
            for index in 0..<document.pageCount {
                try checkCancellation(progress)
                try autoreleasepool {
                    guard let page = document.page(at: index)?.pageRef else { throw PDFServiceError("无法读取 PDF 页面。") }
                    let size = try pixelSize(page, dpi: dpi)
                    guard let context = CGContext(data: nil, width: size.width, height: size.height, bitsPerComponent: 8, bytesPerRow: size.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                        throw PDFServiceError("无法为 PDF 页面分配图像内存。")
                    }
                    let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                    context.setFillColor(CGColor(gray: 1, alpha: 1))
                    context.fill(rect)
                    context.concatenate(page.getDrawingTransform(.mediaBox, rect: rect, rotate: 0, preserveAspectRatio: true))
                    context.drawPDFPage(page)
                    guard let image = context.makeImage() else { throw PDFServiceError("无法绘制 PDF 页面。") }
                    let destination = output.appendingPathComponent(String(format: "page-%06d.%@", index + 1, jpeg ? "jpg" : "png"))
                    guard let writer = CGImageDestinationCreateWithURL(destination as CFURL, (jpeg ? UTType.jpeg.identifier : UTType.png.identifier) as CFString, 1, nil) else {
                        throw PDFServiceError("无法创建 PDF 页面图像。")
                    }
                    CGImageDestinationAddImage(writer, image, jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary : nil)
                    guard CGImageDestinationFinalize(writer), let source = CGImageSourceCreateWithURL(destination as CFURL, nil), let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil), decoded.width == size.width, decoded.height == size.height else {
                        throw PDFServiceError("PDF 页面图像编码或核对失败。")
                    }
                }
                progress.completedUnitCount += 1
            }
            return try publish(output, in: folder, named: outputName, progress: progress)
        }
    }

    func removePassword(_ input: URL, password: String, in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkCancellation(progress)
        try checkFolder(folder)
        let outputName = try pdfName(name)
        let document = try open(input, password: password)
        return try rebuild([document], in: folder, named: outputName, progress: progress)
    }

    private func rebuild(_ documents: [PDFDocument], in folder: URL, named name: String, progress: Progress) throws -> URL {
        progress.totalUnitCount = Int64(documents.reduce(0) { $0 + $1.pageCount })
        progress.completedUnitCount = 0
        return try withStaging { staging in
            let outputDocument = PDFDocument()
            for document in documents {
                for index in 0..<document.pageCount {
                    try checkCancellation(progress)
                    guard let page = document.page(at: index)?.copy() as? PDFPage else { throw PDFServiceError("无法复制 PDF 页面。") }
                    outputDocument.insert(page, at: outputDocument.pageCount)
                    progress.completedUnitCount += 1
                }
            }
            try checkCancellation(progress)
            let output = staging.appendingPathComponent("output.pdf")
            try writeVerified(outputDocument, to: output, progress: progress)
            return try publish(output, in: folder, named: name, progress: progress)
        }
    }

    private func writeVerified(_ document: PDFDocument, to output: URL, progress: Progress) throws {
        try checkCancellation(progress)
        guard document.write(to: output), let verified = PDFDocument(url: output), !verified.isEncrypted, !verified.isLocked, verified.pageCount == document.pageCount else {
            throw PDFServiceError("PDF 写入或页数核对失败。")
        }
        for index in 0..<document.pageCount {
            try checkCancellation(progress)
            guard let expected = document.page(at: index), let actual = verified.page(at: index), expected.string == actual.string, expected.bounds(for: .mediaBox).size == actual.bounds(for: .mediaBox).size, expected.rotation == actual.rotation else {
                throw PDFServiceError("PDF 页面文字或尺寸核对失败。")
            }
        }
    }

    private func open(_ input: URL, password: String?) throws -> PDFDocument {
        try checkPath(input)
        guard try input.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { throw PDFServiceError("PDF 输入必须是普通文件。") }
        guard let document = PDFDocument(url: input) else { throw PDFServiceError("无法打开 PDF，文件可能已损坏。") }
        if document.isLocked {
            guard let password, document.unlock(withPassword: password) else { throw PDFServiceError("PDF 密码缺失或不正确。") }
        } else if document.isEncrypted, let password, !password.isEmpty {
            guard document.unlock(withPassword: password), document.permissionsStatus == .owner else { throw PDFServiceError("PDF 所有者密码不正确。") }
        }
        guard document.pageCount > 0 else { throw PDFServiceError("PDF 不包含页面。") }
        for index in 0..<document.pageCount {
            guard document.page(at: index)?.pageRef != nil else { throw PDFServiceError("PDF 包含无法读取的页面。") }
        }
        return document
    }

    private func pixelSize(_ page: CGPDFPage, dpi: Double) throws -> (width: Int, height: Int) {
        let box = page.getBoxRect(.mediaBox)
        let rotation = ((page.rotationAngle % 360) + 360) % 360
        guard [0, 90, 180, 270].contains(rotation), box.origin.x.isFinite, box.origin.y.isFinite, box.width.isFinite, box.height.isFinite, box.width > 0, box.height > 0 else {
            throw PDFServiceError("PDF 页面尺寸或旋转角度无效。")
        }
        let width = ceil((rotation == 90 || rotation == 270 ? box.height : box.width) * dpi / 72)
        let height = ceil((rotation == 90 || rotation == 270 ? box.width : box.height) * dpi / 72)
        guard width.isFinite, height.isFinite, width >= 1, height >= 1, width <= 40_000_000, height <= 40_000_000, width * height <= 40_000_000 else {
            throw PDFServiceError("PDF 单页导出不得超过 4000 万像素；请降低 dpi。")
        }
        return (Int(width), Int(height))
    }

    private func checkPath(_ url: URL) throws {
        let rootPath = root.resolvingSymlinksInPath().path
        let candidate = url.standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath().path
        guard root.isFileURL, url.isFileURL, candidate.path == rootPath || candidate.path.hasPrefix(rootPath + "/"), resolved == rootPath || resolved.hasPrefix(rootPath + "/") else {
            throw PDFServiceError("PDF 输入和目标必须位于工作区内。")
        }
        var current = candidate
        while true {
            guard try current.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw PDFServiceError("不支持符号链接路径。") }
            if current.path == rootPath { break }
            current.deleteLastPathComponent()
        }
    }

    private func checkFolder(_ folder: URL) throws {
        try checkPath(folder)
        guard try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw PDFServiceError("目的位置必须是已有文件夹。") }
    }

    private func validName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != ".", value != "..", !value.contains("/"), !value.contains("\0") else { throw PDFServiceError("输出名称无效。") }
        return value
    }

    private func pdfName(_ name: String) throws -> String {
        let value = try validName(name)
        return value.lowercased().hasSuffix(".pdf") ? value : value + ".pdf"
    }

    private func withStaging(_ operation: (URL) throws -> URL) throws -> URL {
        try checkFolder(root)
        let staging = root.resolvingSymlinksInPath().appendingPathComponent(".pdf-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        let result: URL
        do { result = try operation(staging) }
        catch {
            do { try manager.removeItem(at: staging) }
            catch { throw PDFServiceError("PDF 暂存清理失败：\(error.localizedDescription)") }
            throw error
        }
        do { try manager.removeItem(at: staging) }
        catch {
            let cleanup = error
            do { try manager.removeItem(at: result) }
            catch { throw PDFServiceError("PDF 暂存清理及结果撤回失败：\(error.localizedDescription)") }
            throw PDFServiceError("PDF 暂存清理失败：\(cleanup.localizedDescription)")
        }
        return result
    }

    private func publish(_ output: URL, in folder: URL, named name: String, progress: Progress) throws -> URL {
        try checkFolder(folder)
        try checkCancellation(progress)
        let sourceVolume = try manager.attributesOfFileSystem(forPath: output.path)[.systemNumber] as? NSNumber
        let targetVolume = try manager.attributesOfFileSystem(forPath: folder.path)[.systemNumber] as? NSNumber
        guard let sourceVolume, let targetVolume, sourceVolume == targetVolume else { throw PDFServiceError("PDF 输出目标必须与工作区位于同一磁盘。") }
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

private struct PDFServiceError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
