import Foundation
import Darwin
import ShuNetwork

enum NetworkSharingAddresses {
    static func urls(port: UInt16) throws -> [URL] {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { freeifaddrs(interfaces) }
        var addresses = Set<String>()
        var pointer = interfaces
        while let current = pointer {
            let entry = current.pointee
            pointer = entry.ifa_next
            guard let address = entry.ifa_addr, entry.ifa_flags & UInt32(IFF_UP) != 0,
                  entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            let type = ShuInterfaceFunctionalType(entry.ifa_name)
            guard type == IFRTYPE_FUNCTIONAL_WIFI_INFRA || type == IFRTYPE_FUNCTIONAL_WIRED else { continue }
            guard address.pointee.sa_family == UInt8(AF_INET) || address.pointee.sa_family == UInt8(AF_INET6) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            guard result == 0 else { throw NSError(domain: "NetworkAddresses", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "无法读取网络接口地址。"] ) }
            addresses.insert(String(cString: host))
        }
        return try addresses.sorted().map { host in
            let authority = host.contains(":") ? "[\(host.replacingOccurrences(of: "%", with: "%25"))]" : host
            guard let url = URL(string: "http://\(authority):\(port)/") else { throw NSError(domain: "NetworkAddresses", code: 1, userInfo: [NSLocalizedDescriptionKey: "网络接口地址无效。"] ) }
            return url
        }
    }
}
