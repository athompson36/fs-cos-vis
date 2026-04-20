import Darwin
import Foundation

/// Shared logic for binding HTTP (TCP) and OSC (UDP) control listeners without colliding with other processes.
enum ControlPlanePortBinding {
    static let minimumPort: UInt16 = 1024
    static let maximumPort: UInt16 = 65_535
    static let defaultScanAttempts = 48

    static func clampUserPort(_ raw: Int) -> UInt16 {
        UInt16(clamping: max(Int(minimumPort), min(Int(maximumPort), raw)))
    }

    /// Finds the first TCP port starting at `startingAt` where a bind would succeed (same address mode as the HTTP server).
    static func firstAvailableTCPPort(startingAt requested: Int, bindLAN: Bool, maxAttempts: Int = defaultScanAttempts) -> UInt16? {
        let base = clampUserPort(requested)
        for offset in 0 ..< max(1, maxAttempts) {
            guard let candidate = portByAdding(offset, to: base) else { break }
            if tcpBindProbe(bindLAN: bindLAN, port: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Finds the first UDP port starting at `startingAt` where a bind would succeed (same address mode as OSC).
    static func firstAvailableUDPPort(startingAt requested: Int, bindLAN: Bool, maxAttempts: Int = defaultScanAttempts) -> UInt16? {
        let base = clampUserPort(requested)
        for offset in 0 ..< max(1, maxAttempts) {
            guard let candidate = portByAdding(offset, to: base) else { break }
            if udpBindProbe(bindLAN: bindLAN, port: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func portByAdding(_ offset: Int, to base: UInt16) -> UInt16? {
        let v = Int(base) + offset
        guard v >= Int(minimumPort), v <= Int(maximumPort) else { return nil }
        return UInt16(v)
    }

    private static func tcpBindProbe(bindLAN: Bool, port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }

        var yes: Int32 = 1
        _ = withUnsafePointer(to: &yes) {
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, $0, socklen_t(MemoryLayout<Int32>.size))
        }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(port)
        addr.sin_addr.s_addr = bindLAN ? INADDR_ANY.bigEndian : inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return bindResult == 0
    }

    private static func udpBindProbe(bindLAN: Bool, port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }

        var yes: Int32 = 1
        _ = withUnsafePointer(to: &yes) {
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, $0, socklen_t(MemoryLayout<Int32>.size))
        }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(port)
        addr.sin_addr.s_addr = bindLAN ? INADDR_ANY.bigEndian : inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return bindResult == 0
    }
}
