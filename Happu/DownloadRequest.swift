import Foundation

enum DownloadRequest {
    enum ValidationError: LocalizedError {
        case invalidURL
        case invalidHeader

        var errorDescription: String? {
            switch self {
            case .invalidURL: "请输入有效的 HTTP 或 HTTPS 链接"
            case .invalidHeader: "请求头格式应为 名称: 内容，每行一项"
            }
        }
    }

    static func make(urlText: String, headersText: String) throws -> URLRequest {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else {
            throw ValidationError.invalidURL
        }

        var request = URLRequest(url: url)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'*+-.^_`|~")
        for rawLine in headersText.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            guard let colon = line.firstIndex(of: ":") else { throw ValidationError.invalidHeader }
            let name = String(line[..<colon])
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty,
                  name.unicodeScalars.allSatisfy(allowed.contains),
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw ValidationError.invalidHeader
            }
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}
