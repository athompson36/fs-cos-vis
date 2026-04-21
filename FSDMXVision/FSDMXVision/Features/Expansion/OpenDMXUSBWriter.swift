import Darwin
import Foundation

#if os(macOS)
/// `IOSSIOSPEED` from `<IOKit/serial/ioss.h>` (custom baud for USB serial).
private let kIOSSIOSPEED: UInt = 0x8004_5402
#endif

enum OpenDMXError: Error {
    case openFailed
    case configureFailed
    case writeFailed
}

/// Minimal EntTEC OpenDMX–style USB-UART writer (break + start code 0 + 512 slots).
final class OpenDMXUSBWriter {
    private var fd: Int32 = -1
    private var openPath: String?

    func close() {
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
        openPath = nil
    }

    deinit { close() }

    func ensureOpen(path: String) throws {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OpenDMXError.openFailed }
        if fd >= 0, openPath == trimmed { return }
        close()
        try open(path: trimmed)
    }

    func open(path: String) throws {
        close()
        fd = Darwin.open(path, O_RDWR | O_NOCTTY)
        guard fd >= 0 else { throw OpenDMXError.openFailed }
        openPath = path
        try configure250k8N2()
    }

    private func configure250k8N2() throws {
        try OpenDMXSerialPort.configure250k8N2(fd: fd)
    }

    func send(universe: [UInt8]) throws {
        guard fd >= 0 else { throw OpenDMXError.openFailed }
        precondition(universe.count == 512)
        _ = ioctl(fd, TIOCSBRK, 0)
        usleep(120)
        _ = ioctl(fd, TIOCCBRK, 0)
        usleep(16)

        var payload = [UInt8(0)] + universe
        let wrote = payload.withUnsafeBytes { raw -> ssize_t in
            Darwin.write(fd, raw.baseAddress!, raw.count)
        }
        guard wrote == payload.count else { throw OpenDMXError.writeFailed }
    }
}

/// Shared 250k 8N2 termios setup for Open DMX–class USB-UART devices (TX or RX).
enum OpenDMXSerialPort {
    static func configure250k8N2(fd: Int32) throws {
        var t = termios()
        guard tcgetattr(fd, &t) == 0 else { throw OpenDMXError.configureFailed }
        cfmakeraw(&t)
        t.c_cflag &= ~tcflag_t(CSIZE)
        t.c_cflag |= tcflag_t(CS8)
        t.c_cflag |= tcflag_t(CSTOPB)
        t.c_cflag &= ~tcflag_t(PARENB)
        t.c_cflag |= tcflag_t(CLOCAL)
        t.c_cflag &= ~tcflag_t(CRTSCTS)
        guard tcsetattr(fd, TCSANOW, &t) == 0 else { throw OpenDMXError.configureFailed }

        #if os(macOS)
        var speed: speed_t = 250_000
        if ioctl(fd, kIOSSIOSPEED, &speed) == -1 {
            var t2 = termios()
            _ = tcgetattr(fd, &t2)
            cfsetspeed(&t2, speed_t(B230400))
            _ = tcsetattr(fd, TCSANOW, &t2)
        }
        #else
        var t2 = termios()
        _ = tcgetattr(fd, &t2)
        cfsetspeed(&t2, speed_t(B230400))
        guard tcsetattr(fd, TCSANOW, &t2) == 0 else { throw OpenDMXError.configureFailed }
        #endif
    }
}
