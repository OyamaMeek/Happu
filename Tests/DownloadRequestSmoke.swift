import Foundation

@main
struct DownloadRequestSmoke {
    static func main() throws {
        let request = try DownloadRequest.make(
            urlText: "https://example.com/file.zip",
            headersText: "User-Agent: ShuReplica\nCookie: session=abc"
        )
        assert(request.url?.absoluteString == "https://example.com/file.zip")
        assert(request.value(forHTTPHeaderField: "Cookie") == "session=abc")

        for invalid in ["file:///etc/passwd", "http://", "https://user:pass@example.com/"] {
            do {
                _ = try DownloadRequest.make(urlText: invalid, headersText: "")
                fatalError("Accepted invalid URL: \(invalid)")
            } catch DownloadRequest.ValidationError.invalidURL {}
        }

        do {
            _ = try DownloadRequest.make(urlText: "https://example.com", headersText: "BadHeader")
            fatalError("Accepted invalid header")
        } catch DownloadRequest.ValidationError.invalidHeader {}

        print("DownloadRequest smoke passed")
    }
}
