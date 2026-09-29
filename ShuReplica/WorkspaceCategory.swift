import Foundation
import UniformTypeIdentifiers

enum WorkspaceCategory: String, CaseIterable {
    case document = "文稿"
    case picture = "图片"
    case video = "视频"
    case audio = "音频"
    case ebook = "电子书"
    case archive = "压缩文档"
    case diskImage = "镜像文件"
    case script = "脚本配置"
    case utility = "工具配置"

    var systemImage: String {
        switch self {
        case .document: "doc.text"
        case .picture: "photo"
        case .video: "film"
        case .audio: "waveform"
        case .ebook: "books.vertical"
        case .archive: "archivebox"
        case .diskImage: "opticaldisc"
        case .script: "chevron.left.forwardslash.chevron.right"
        case .utility: "wrench.and.screwdriver"
        }
    }

    static func forFile(_ url: URL) -> WorkspaceCategory? {
        let ext = url.pathExtension.lowercased()
        if ["epub", "mobi", "azw", "azw3"].contains(ext) { return .ebook }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"].contains(ext) { return .archive }
        if ["dmg", "iso", "img"].contains(ext) { return .diskImage }
        if ["sh", "bash", "zsh", "py", "js", "swift", "rb"].contains(ext) { return .script }
        if ["json", "yaml", "yml", "plist", "ini", "conf", "cfg", "toml"].contains(ext) { return .utility }
        if ["jpg", "jpeg", "png", "gif", "heic", "webp", "tif", "tiff", "bmp"].contains(ext) { return .picture }
        if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) { return .video }
        if ["mp3", "m4a", "wav", "aac", "flac"].contains(ext) { return .audio }
        if ["pdf", "txt", "md", "rtf", "doc", "docx", "pages"].contains(ext) { return .document }

        guard let type = UTType(filenameExtension: ext) else { return nil }
        if type.conforms(to: .image) { return .picture }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .pdf) || type.conforms(to: .text) || type.conforms(to: .compositeContent) {
            return .document
        }
        return nil
    }
}
