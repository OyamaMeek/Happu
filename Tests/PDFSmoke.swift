import Foundation
import CoreGraphics
import CoreText
import PDFKit
import ImageIO

@main
struct PDFSmoke {
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "PDFSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func fixture(_ url: URL, pages: [(String, CGRect, Int)]) throws {
        var defaultBox = CGRect(x: 0, y: 0, width: 200, height: 100)
        guard let context = CGContext(url as CFURL, mediaBox: &defaultBox, nil) else { throw CocoaError(.fileWriteUnknown) }
        for (text, box, _) in pages {
            var media = box
            let data = NSData(bytes: &media, length: MemoryLayout<CGRect>.size)
            context.beginPDFPage([kCGPDFContextMediaBox as String: data] as CFDictionary)
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: box.midX - 15, y: box.midY - 15, width: 30, height: 30))
            let font = CTFontCreateWithName("Helvetica" as CFString, 16, nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
            context.textPosition = CGPoint(x: box.minX + 8, y: box.minY + 8)
            CTLineDraw(line, context)
            context.endPDFPage()
        }
        context.closePDF()
        let doc = PDFDocument(url: url)!
        for (index, page) in pages.enumerated() { doc.page(at: index)!.rotation = page.2 }
        try check(doc.write(to: url), "Fixture write failed")
    }

    static func imageCheck(_ url: URL, width: Int, height: Int) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CocoaError(.fileReadCorruptFile) }
        try check(image.width == width && image.height == height, "Unexpected dimensions: \(image.width)x\(image.height), expected \(width)x\(height)")
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        try check(pixel[0] > 180 && pixel[1] < 80 && pixel[2] < 80, "Media-box center content was lost")
        context.clear(CGRect(x: 0, y: 0, width: 1, height: 1))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        try check(pixel[0] > 240 && pixel[1] > 240 && pixel[2] > 240, "Page background must be white")
    }

    static func raster(_ page: PDFPage) -> Data {
        let rotated = page.rotation == 90 || page.rotation == 270
        let box = page.bounds(for: .mediaBox)
        let width = Int(rotated ? box.height : box.width)
        let height = Int(rotated ? box.width : box.height)
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.concatenate(page.pageRef!.getDrawingTransform(.mediaBox, rect: rect, rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page.pageRef!)
        return Data(bytes: context.data!, count: width * height * 4)
    }

    static func main() throws {
        let manager = FileManager.default
        let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).standardizedFileURL
        let run = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = try FileStore(root: run.appendingPathComponent("workspace", isDirectory: true))
        let root = store.root
        let folder = root.appendingPathComponent("文稿", isDirectory: true)
        let first = folder.appendingPathComponent("first.pdf")
        let second = folder.appendingPathComponent("second.pdf")
        try fixture(first, pages: [("A", CGRect(x: 20, y: 30, width: 200, height: 100), 0), ("B", CGRect(x: -10, y: 15, width: 120, height: 180), 90)])
        try fixture(second, pages: [("C", CGRect(x: 0, y: 0, width: 80, height: 60), 0)])
        let independentSource = PDFDocument(url: first)!
        try check(independentSource.page(at: 0)!.pageRef!.getBoxRect(.mediaBox) == CGRect(x: 20, y: 30, width: 200, height: 100), "Serialized source must retain positive mediaBox origin")
        try check(independentSource.page(at: 1)!.pageRef!.getBoxRect(.mediaBox) == CGRect(x: -10, y: 15, width: 120, height: 180), "Serialized source must retain negative mediaBox origin")
        let service = PDFService(root: root)
        let initialParts = try service.split(first, password: nil, pagesPerPart: 1, in: folder, named: "initialParts", progress: Progress())
        try check(manager.contentsOfDirectory(atPath: initialParts.path).count == 2, "Split must publish every part")
        let progress = Progress()
        let merged = try service.merge([second, first], passwords: [:], in: folder, named: "merged", progress: progress)
        let document = PDFDocument(url: merged)!
        try check(document.pageCount == 3, "Merge must retain every page")
        for (index, text) in ["C", "A", "B"].enumerated() {
            try check(document.page(at: index)!.string?.trimmingCharacters(in: .whitespacesAndNewlines) == text, "Merge page order/content mismatch")
        }
        try check(document.page(at: 1)!.bounds(for: .mediaBox).size == CGSize(width: 200, height: 100), "Merge changed page size")
        try check(document.page(at: 2)!.rotation == 90, "Merge changed rotation")
        let sourceDocument = PDFDocument(url: first)!
        for index in 0..<2 {
            try check(raster(sourceDocument.page(at: index)!) == raster(document.page(at: index + 1)!), "Merge shifted or clipped nonzero mediaBox content")
        }
        try check(progress.totalUnitCount == 3 && progress.completedUnitCount == 3, "Merge progress mismatch")
        let splitProgress = Progress()
        let parts = try service.split(merged, password: nil, pagesPerPart: 2, in: folder, named: "parts", progress: splitProgress)
        let partFiles = try manager.contentsOfDirectory(at: parts, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent < $1.lastPathComponent }
        try check(partFiles.count == 2, "Split remainder was lost")
        for (index, texts) in [["C", "A"], ["B"]].enumerated() {
            let part = PDFDocument(url: partFiles[index])!
            try check(part.pageCount == texts.count, "Split page count mismatch")
            for (pageIndex, text) in texts.enumerated() {
                try check(part.page(at: pageIndex)!.string == text, "Split text/order mismatch")
                try check(raster(part.page(at: pageIndex)!) == raster(document.page(at: index * 2 + pageIndex)!), "Split changed page rendering")
            }
        }
        try check(splitProgress.totalUnitCount == 3 && splitProgress.completedUnitCount == 3, "Split progress mismatch")
        let numberedParts = try service.split(merged, password: nil, pagesPerPart: 2, in: folder, named: "parts", progress: Progress())
        try check(numberedParts.lastPathComponent == "parts 2", "Split overwrote result directory")
        let original = try Data(contentsOf: merged)
        let numbered = try service.merge([second, first], passwords: [:], in: folder, named: "merged.pdf", progress: Progress())
        try check(numbered.lastPathComponent == "merged 2.pdf" && Data(contentsOf: merged) == original, "Same-name output overwrote file")

        let protected = folder.appendingPathComponent("protected.pdf")
        let plain = PDFDocument(url: first)!
        try check(plain.write(to: protected, withOptions: [.userPasswordOption: "secret", .ownerPasswordOption: "owner"]), "Encrypted fixture write failed")
        try check(PDFDocument(url: protected)!.isLocked, "Fixture must be encrypted")
        let unlocked = try service.removePassword(protected, password: "secret", in: folder, named: "unlocked", progress: Progress())
        let restored = PDFDocument(url: unlocked)!
        try check(!restored.isEncrypted && !restored.isLocked && restored.pageCount == 2, "Remove password retained encryption/pages mismatch")
        try check(restored.page(at: 0)!.string?.contains("A") == true && restored.page(at: 1)!.string?.contains("B") == true, "Remove password lost text")
        try check(restored.page(at: 0)!.bounds(for: .mediaBox).size == plain.page(at: 0)!.bounds(for: .mediaBox).size && restored.page(at: 1)!.rotation == 90, "Remove password changed geometry")
        let encryptedSource = PDFDocument(url: protected)!
        try check(encryptedSource.unlock(withPassword: "secret"), "Encrypted source unlock failed")
        for index in 0..<2 {
            try check(raster(restored.page(at: index)!) == raster(encryptedSource.page(at: index)!), "Remove password changed rendered content")
        }
        let secretParts = try service.split(protected, password: "secret", pagesPerPart: 1, in: folder, named: "secretParts", progress: Progress())
        let secretPart = PDFDocument(url: secretParts.appendingPathComponent("part-000001.pdf"))!
        try check(!secretPart.isEncrypted && secretPart.page(at: 0)!.string == "A", "Password split failed")
        let passwordMerge = try service.merge([second, protected], passwords: [protected: "secret"], in: folder, named: "passwordMerge", progress: Progress())
        try check(PDFDocument(url: passwordMerge)!.pageCount == 3 && !PDFDocument(url: passwordMerge)!.isEncrypted, "Encrypted merge failed")

        for (jpeg, dpi, dimensions) in [(false, 72.0, [(200, 100), (180, 120)]), (true, 144.0, [(400, 200), (360, 240)])] {
            let exportProgress = Progress()
            let result = try service.exportPages(protected, password: "secret", dpi: dpi, jpeg: jpeg, in: folder, named: jpeg ? "JPEG" : "PNG", progress: exportProgress)
            let files = try manager.contentsOfDirectory(at: result, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent < $1.lastPathComponent }
            try check(files.count == 2, "Export must include all pages")
            for (index, file) in files.enumerated() {
                try check(file.pathExtension == (jpeg ? "jpg" : "png"), "Export type mismatch")
                try imageCheck(file, width: dimensions[index].0, height: dimensions[index].1)
            }
            try check(exportProgress.totalUnitCount == 2 && exportProgress.completedUnitCount == 2, "Export progress mismatch")
        }
        let png2 = try service.exportPages(first, password: nil, dpi: 36, jpeg: false, in: folder, named: "PNG", progress: Progress())
        try check(png2.lastPathComponent == "PNG 2", "Same-name directory overwritten")
        let broken = folder.appendingPathComponent("broken.pdf")
        try Data("broken PDF".utf8).write(to: broken)
        let empty = folder.appendingPathComponent("empty.pdf")
        try manager.copyItem(at: URL(fileURLWithPath: "Tests/fixtures/empty.pdf"), to: empty)
        try check(!Data(contentsOf: empty).isEmpty, "Empty-page fixture must be a nonempty PDF file")
        let giant = folder.appendingPathComponent("giant.pdf")
        try fixture(giant, pages: [("G", CGRect(x: 0, y: 0, width: 10000, height: 10000), 0)])
        let outside = run.appendingPathComponent("outside.pdf")
        try manager.copyItem(at: first, to: outside)
        let symlink = folder.appendingPathComponent("link.pdf")
        try manager.createSymbolicLink(at: symlink, withDestinationURL: first)
        let linkedFolder = root.appendingPathComponent("linked")
        try manager.createSymbolicLink(at: linkedFolder, withDestinationURL: folder)
        let external = run.appendingPathComponent("external", isDirectory: true)
        let externalChild = external.appendingPathComponent("child", isDirectory: true)
        let externalTarget = external.appendingPathComponent("target", isDirectory: true)
        try manager.createDirectory(at: externalChild, withIntermediateDirectories: true)
        try manager.createDirectory(at: externalTarget, withIntermediateDirectories: false)
        let externalPDF = external.appendingPathComponent("traversal.pdf")
        try fixture(externalPDF, pages: [("X", CGRect(x: 0, y: 0, width: 80, height: 60), 0), ("Y", CGRect(x: 0, y: 0, width: 80, height: 60), 0)])
        let insideDecoy = root.appendingPathComponent("traversal.pdf")
        try manager.copyItem(at: first, to: insideDecoy)
        let insideTarget = root.appendingPathComponent("target", isDirectory: true)
        try manager.createDirectory(at: insideTarget, withIntermediateDirectories: false)
        let traversalLink = root.appendingPathComponent("escape")
        try manager.createSymbolicLink(at: traversalLink, withDestinationURL: externalChild)
        let traversalInput = URL(fileURLWithPath: root.path + "/escape/../traversal.pdf")
        let traversalTarget = URL(fileURLWithPath: root.path + "/escape/../target", isDirectory: true)
        try check(traversalInput.pathComponents.contains(".."), "Traversal fixture must retain original dot component")
        try check(PDFDocument(url: traversalInput)?.page(at: 0)?.string == "X", "Original URL must read outside fixture through symlink")
        let sentinel = externalTarget.appendingPathComponent("sentinel.txt")
        try Data("outside sentinel".utf8).write(to: sentinel)
        let externalOriginal = try Data(contentsOf: externalPDF)
        let decoyOriginal = try Data(contentsOf: insideDecoy)

        func clean() throws {
            try check(manager.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".pdf-") }, "Staging leaked")
        }
        func reject(_ action: () throws -> URL, cancellation: Bool = false) throws {
            let before = try manager.contentsOfDirectory(atPath: folder.path).sorted()
            var failed = false
            do { _ = try action() } catch {
                failed = true
                if cancellation { try check(error is CancellationError, "Cancellation must preserve error type") }
            }
            try check(failed, "Invalid operation unexpectedly succeeded")
            try check(manager.contentsOfDirectory(atPath: folder.path).sorted() == before, "Failed operation changed destination")
            try clean()
        }
        for operation in 0...3 {
            try reject {
                switch operation {
                case 0: return try service.merge([first, traversalInput], passwords: [:], in: folder, named: "traversal", progress: Progress())
                case 1: return try service.split(traversalInput, password: nil, pagesPerPart: 1, in: folder, named: "traversal", progress: Progress())
                case 2: return try service.exportPages(traversalInput, password: nil, dpi: 72, jpeg: false, in: folder, named: "traversal", progress: Progress())
                default: return try service.removePassword(traversalInput, password: "", in: folder, named: "traversal", progress: Progress())
                }
            }
            try reject {
                switch operation {
                case 0: return try service.merge([first, second], passwords: [:], in: traversalTarget, named: "traversal", progress: Progress())
                case 1: return try service.split(first, password: nil, pagesPerPart: 1, in: traversalTarget, named: "traversal", progress: Progress())
                case 2: return try service.exportPages(first, password: nil, dpi: 72, jpeg: false, in: traversalTarget, named: "traversal", progress: Progress())
                default: return try service.removePassword(protected, password: "secret", in: traversalTarget, named: "traversal", progress: Progress())
                }
            }
            try check(manager.contentsOfDirectory(atPath: externalTarget.path) == ["sentinel.txt"], "Traversal changed outside output directory")
            try check(manager.contentsOfDirectory(atPath: insideTarget.path).isEmpty, "Traversal changed decoy output directory")
            try check(Data(contentsOf: sentinel) == Data("outside sentinel".utf8), "Traversal changed outside sentinel")
            try check(Data(contentsOf: externalPDF) == externalOriginal && Data(contentsOf: insideDecoy) == decoyOriginal, "Traversal changed input files")
        }
        let internalLink = root.appendingPathComponent("internalLink")
        try manager.createSymbolicLink(at: internalLink, withDestinationURL: folder)
        let internalInput = URL(fileURLWithPath: root.path + "/internalLink/../traversal.pdf")
        let internalTarget = URL(fileURLWithPath: root.path + "/internalLink/../target", isDirectory: true)
        try check(internalInput.pathComponents.contains("..") && internalInput.standardizedFileURL.path == insideDecoy.path, "Internal link fixture must normalize inside workspace")
        try reject { try service.merge([first, internalInput], passwords: [:], in: folder, named: "internalTraversal", progress: Progress()) }
        try reject { try service.exportPages(first, password: nil, dpi: 72, jpeg: false, in: internalTarget, named: "internalTraversal", progress: Progress()) }
        try check(manager.contentsOfDirectory(atPath: insideTarget.path).isEmpty, "Internal link changed decoy output directory")
        for inputs in [[], [first], [first, broken], [first, empty], [first, outside], [first, symlink], [first, linkedFolder.appendingPathComponent("first.pdf")], [first, folder]] {
            try reject { try service.merge(inputs, passwords: [:], in: folder, named: "bad", progress: Progress()) }
        }
        try reject { try service.merge([first, protected], passwords: [protected: "wrong"], in: folder, named: "bad", progress: Progress()) }
        try reject { try service.removePassword(protected, password: "wrong", in: folder, named: "bad", progress: Progress()) }
        let ownerOnly = folder.appendingPathComponent("owner-only.pdf")
        try check(plain.write(to: ownerOnly, withOptions: [.userPasswordOption: "", .ownerPasswordOption: "owner"]), "Owner-only fixture write failed")
        try check(PDFDocument(url: ownerOnly)!.isEncrypted && !PDFDocument(url: ownerOnly)!.isLocked, "Owner-only fixture must open unlocked")
        try reject { try service.removePassword(ownerOnly, password: "wrong", in: folder, named: "bad", progress: Progress()) }
        for password in ["", "owner"] {
            let result = try service.removePassword(ownerOnly, password: password, in: folder, named: "owner-unlocked", progress: Progress())
            try check(!PDFDocument(url: result)!.isEncrypted && PDFDocument(url: result)!.pageCount == 2, "Owner-only known password removal failed")
        }
        try reject { try service.split(protected, password: "wrong", pagesPerPart: 1, in: folder, named: "bad", progress: Progress()) }
        for count in [0, -1, 3, Int.max] {
            try reject { try service.split(merged, password: nil, pagesPerPart: count, in: folder, named: "bad", progress: Progress()) }
        }
        try reject { try service.exportPages(protected, password: nil, dpi: 72, jpeg: false, in: folder, named: "bad", progress: Progress()) }
        for dpi in [0, 35, 301, Double.nan, Double.infinity] {
            try reject { try service.exportPages(first, password: nil, dpi: dpi, jpeg: false, in: folder, named: "bad", progress: Progress()) }
        }
        try reject { try service.exportPages(giant, password: nil, dpi: 72, jpeg: false, in: folder, named: "bad", progress: Progress()) }
        for name in ["", ".", "..", "../bad", "bad\0name"] {
            try reject { try service.merge([first, second], passwords: [:], in: folder, named: name, progress: Progress()) }
        }
        for destination in [run, linkedFolder, first, root.appendingPathComponent("missing")] {
            try reject { try service.merge([first, second], passwords: [:], in: destination, named: "bad", progress: Progress()) }
        }
        try manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        do {
            defer { try! manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
            try reject { try service.split(first, password: nil, pagesPerPart: 1, in: folder, named: "denied", progress: Progress()) }
            try reject { try service.merge([first, second], passwords: [:], in: folder, named: "denied", progress: Progress()) }
        }
        for operation in 0...3 {
            for boundary in [0, 1, 2] {
                let cancelled = Progress()
                if boundary == 0 { cancelled.cancel() }
                let observation = cancelled.observe(\.completedUnitCount) { value, _ in
                    if boundary == 1 && value.completedUnitCount >= 1 || boundary == 2 && value.completedUnitCount == value.totalUnitCount { value.cancel() }
                }
                try reject({
                    switch operation {
                    case 0: return try service.merge([first, second], passwords: [:], in: folder, named: "cancel", progress: cancelled)
                    case 1: return try service.exportPages(first, password: nil, dpi: 72, jpeg: false, in: folder, named: "cancel", progress: cancelled)
                    case 2: return try service.removePassword(protected, password: "secret", in: folder, named: "cancel", progress: cancelled)
                    default: return try service.split(first, password: nil, pagesPerPart: 1, in: folder, named: "cancel", progress: cancelled)
                    }
                }, cancellation: true)
                withExtendedLifetime(observation) {}
                if boundary > 0 { try check(cancelled.completedUnitCount >= 1, "Cancellation did not reach a page boundary") }
                if boundary == 2 { try check(cancelled.completedUnitCount == cancelled.totalUnitCount, "Final-page cancellation did not reach completion boundary") }
            }
        }
        try clean()
        try check(Data(contentsOf: first) == Data(contentsOf: outside), "Input was modified")
        print("PDFSmoke passed: merge/split order/text/geometry/rendering, encryption, PNG/JPEG content/dimensions, progress, collisions, invalid input, boundaries, cancellation, cleanup")
    }
}
