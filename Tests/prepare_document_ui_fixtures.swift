import Foundation
import AppKit
import PDFKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Darwin

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let manager = FileManager.default
let expectedOutputs: Set<String> = ["ui-merged.pdf", "ui-split", "ui-pages", "ui-unlocked.pdf", "ui-retry.pdf", "ui-quality.jpeg", "ui-frame.png", "ui-frames", "ui-composed.png", "ui-imported-pages"]
if CommandLine.arguments.contains("--reset-outputs") {
    precondition(root.lastPathComponent == "DocumentUITests")
    precondition(PDFDocument(url: root.appendingPathComponent("PDFs/a.pdf"))?.pageCount == 3)
    let output = root.appendingPathComponent("Output")
    let names = try manager.contentsOfDirectory(atPath: output.path)
    precondition(Set(names).isSubset(of: expectedOutputs))
    for name in names { try manager.removeItem(at: output.appendingPathComponent(name)) }
    let imported = root.deletingLastPathComponent().appendingPathComponent("b.pdf")
    if manager.fileExists(atPath: imported.path) {
        let importedBytes = try Data(contentsOf: imported)
        let inputBytes = try Data(contentsOf: root.appendingPathComponent("PDFs/b.pdf"))
        precondition(importedBytes == inputBytes)
        try manager.removeItem(at: imported)
    }
    print("Document UI controlled outputs reset; input fixtures preserved")
    exit(0)
}
if CommandLine.arguments.contains("--verify") {
    let output = root.appendingPathComponent("Output")
    let outputNames = try manager.contentsOfDirectory(atPath: output.path)
    precondition(Set(outputNames) == expectedOutputs)
    for (folder, names) in [
        "ui-split": ["part-000001.pdf", "part-000002.pdf"],
        "ui-pages": ["page-000001.png", "page-000002.png"],
        "ui-imported-pages": ["page-000001.png", "page-000002.png"],
        "ui-frames": ["frame-000001.png", "frame-000002.png"]
    ] {
        let actual = try manager.contentsOfDirectory(atPath: output.appendingPathComponent(folder).path)
        precondition(Set(actual) == Set(names))
    }
    func readPDF(_ name: String) -> PDFDocument {
        let document = PDFDocument(url: output.appendingPathComponent(name))!
        precondition(!document.isEncrypted && !document.isLocked)
        return document
    }
    let merged = readPDF("ui-merged.pdf")
    precondition(merged.pageCount == 5)
    for (index, text) in ["LOCKED1", "LOCKED2", "A1", "A2", "A3"].enumerated() {
        precondition(merged.page(at: index)!.string!.trimmingCharacters(in: .whitespacesAndNewlines) == text)
    }
    precondition(readPDF("ui-split/part-000001.pdf").pageCount == 2)
    precondition(readPDF("ui-split/part-000002.pdf").pageCount == 1)
    for name in ["ui-unlocked.pdf", "ui-retry.pdf"] {
        let document = readPDF(name)
        precondition(document.pageCount == 2 && document.page(at: 0)!.string!.contains("LOCKED1"))
    }
    func readImage(_ name: String, width: Int, height: Int) -> CGImage {
        let source = CGImageSourceCreateWithURL(output.appendingPathComponent(name) as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        precondition(image.width == width && image.height == height)
        return image
    }
    func color(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes {
            let context = CGContext(data: $0.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                    bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let index = (y * image.width + x) * 4
        return Array(bytes[index..<index + 3])
    }
    for index in 1...2 { _ = readImage(String(format: "ui-pages/page-%06d.png", index), width: 288, height: 432) }
    for index in 1...2 { _ = readImage(String(format: "ui-imported-pages/page-%06d.png", index), width: 144, height: 216) }
    let quality = readImage("ui-quality.jpeg", width: 24, height: 32)
    let qualityColor = color(quality, x: 10, y: 10)
    let sourceRed = CGImageSourceCreateWithURL(root.appendingPathComponent("Images/red.png") as CFURL, nil)!
    let sourceBlue = CGImageSourceCreateWithURL(root.appendingPathComponent("Images/blue.png") as CFURL, nil)!
    let sourceGIF = CGImageSourceCreateWithURL(root.appendingPathComponent("Images/animation.gif") as CFURL, nil)!
    let redColor = color(CGImageSourceCreateImageAtIndex(sourceRed, 0, nil)!, x: 10, y: 10)
    let blueColor = color(CGImageSourceCreateImageAtIndex(sourceBlue, 0, nil)!, x: 10, y: 10)
    precondition(CGImageSourceGetCount(sourceGIF) == 2 && redColor != blueColor)
    precondition(zip(qualityColor, redColor).allSatisfy { abs(Int($0.0) - Int($0.1)) <= 2 })
    let gifColors = (0...1).map { color(CGImageSourceCreateImageAtIndex(sourceGIF, $0, nil)!, x: 10, y: 10) }
    precondition(color(readImage("ui-frame.png", width: 24, height: 32), x: 10, y: 10) == gifColors[1])
    for index in 0...1 {
        let name = String(format: "ui-frames/frame-%06d.png", index + 1)
        precondition(color(readImage(name, width: 24, height: 32), x: 10, y: 10) == gifColors[index])
    }
    let composed = readImage("ui-composed.png", width: 24, height: 52)
    precondition(color(composed, x: 10, y: 10) == redColor)
    precondition(color(composed, x: 10, y: 42) == blueColor)
    for name in ["ui-cancelled", "ui-close-cancelled"] {
        precondition(!manager.fileExists(atPath: root.appendingPathComponent("PDFs/" + name).path))
    }
    precondition(PDFDocument(url: root.appendingPathComponent("PDFs/locked.pdf"))!.isLocked)
    precondition(PDFDocument(url: root.appendingPathComponent("PDFs/cancel.pdf"))!.pageCount == 600)
    let workspace = root.deletingLastPathComponent()
    let importedPDF = try Data(contentsOf: workspace.appendingPathComponent("b.pdf"))
    let originalPDF = try Data(contentsOf: root.appendingPathComponent("PDFs/b.pdf"))
    precondition(importedPDF == originalPDF)
    let workspaceNames = try manager.contentsOfDirectory(atPath: workspace.path)
    precondition(workspaceNames.allSatisfy { !$0.hasPrefix(".pdf-") && !$0.hasPrefix(".image-") })
    print("Document UI actual outputs verified: PDF order/text/split/unlock/dpi, image quality/frame/extraction/composition, cancellation cleanup and original preservation")
    exit(0)
}
try manager.createDirectory(at: root, withIntermediateDirectories: true)

func pdf(_ name: String, labels: [String], large: Bool = false) throws -> PDFDocument {
    let url = root.appendingPathComponent("PDFs/" + name)
    var bounds = CGRect(x: 0, y: 0, width: large ? 612 : 144, height: large ? 792 : 216)
    guard let context = CGContext(url as CFURL, mediaBox: &bounds, nil) else { fatalError("PDF writer") }
    for label in labels {
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (label as NSString).draw(at: CGPoint(x: 10, y: 100), withAttributes: [.font: NSFont.systemFont(ofSize: 16)])
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
    }
    context.closePDF()
    let document = PDFDocument(url: url)!
    precondition(document.pageCount == labels.count)
    precondition(document.page(at: 0)!.string!.contains(labels[0]))
    return document
}

func image(_ color: CGColor, width: Int = 24, height: Int = 32) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(color)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

for folder in ["PDFs", "Images", "Output"] {
    try manager.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
}
_ = try pdf("a.pdf", labels: ["A1", "A2", "A3"])
_ = try pdf("b.pdf", labels: ["B1", "B2"])
let encrypted = try pdf("locked.pdf", labels: ["LOCKED1", "LOCKED2"])
precondition(encrypted.write(to: root.appendingPathComponent("PDFs/locked.pdf"), withOptions: [.userPasswordOption: "secret", .ownerPasswordOption: "owner"]))
precondition(PDFDocument(url: root.appendingPathComponent("PDFs/locked.pdf"))!.isLocked)
_ = try pdf("cancel.pdf", labels: (1...600).map { "CANCEL\($0)" }, large: true)
let red = image(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
let blue = image(CGColor(red: 0, green: 0, blue: 1, alpha: 1), width: 16, height: 20)
for (name, picture) in [("red.png", red), ("blue.png", blue)] {
    let destination = CGImageDestinationCreateWithURL(root.appendingPathComponent("Images/" + name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, picture, nil)
    precondition(CGImageDestinationFinalize(destination))
}
let gif = CGImageDestinationCreateWithURL(root.appendingPathComponent("Images/animation.gif") as CFURL, UTType.gif.identifier as CFString, 2, nil)!
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 3]] as CFDictionary)
for (frame, duration) in [(red, 0.1), (image(CGColor(red: 0, green: 0, blue: 1, alpha: 1)), 0.3)] {
    CGImageDestinationAddImage(gif, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: duration]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(gif))
precondition(CGImageSourceGetCount(CGImageSourceCreateWithURL(root.appendingPathComponent("Images/animation.gif") as CFURL, nil)!) == 2)
print("Document UI fixtures prepared: text PDF, encrypted PDF, 600-page cancellation PDF, colored PNG and two-frame GIF")
