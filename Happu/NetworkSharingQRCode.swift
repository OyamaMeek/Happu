import Foundation
import CoreImage

enum NetworkSharingQRCode {
    static func image(for url: URL) throws -> CGImage {
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let image = CIContext().createCGImage(output, from: output.extent) else {
            throw NSError(domain: "NetworkQRCode", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法生成共享地址二维码。"] )
        }
        return image
    }
}
