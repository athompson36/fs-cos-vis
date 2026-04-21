import Darwin
import Foundation

/// Pulls complete DMX data frames (512 slots) from a byte stream.
///
/// Two strategies:
/// 1. **Gap-aligned** — when `OpenDMXUSBInputService` sees idle between USB read batches (~new DMX packet), the next byte is treated as the start code (`0x00`) followed by 512 slots, avoiding false sync on channel values of `0`.
/// 2. **Legacy scan** — find `0x00` then 512 slots (best-effort; many zeros in a row can misalign without gap hints).
enum OpenDMXFrameAssembler {
    /// Minimum idle between ``OpenDMXUSBInputService/drainReadable()`` calls to treat the next bytes as a new wire packet (not a USB fragment of the same packet).
    /// A full DMX frame at 250k 8N2 is ~20.5ms of bytes; idle between frames is typically much larger than USB inter-read gaps within one frame.
    static let defaultInterDrainIdleSeconds: TimeInterval = 0.004

    /// Consumes `buffer` prefix for each complete `[0x00][512 slots]` chunk and invokes `onFrame` with slot data only.
    static func pullFrames(buffer: inout [UInt8], onFrame: ([UInt8]) -> Void) {
        pullFrames(buffer: &buffer, leadingPacketAlignedAfterIdle: false, onFrame: onFrame)
    }

    /// - Parameter leadingPacketAlignedAfterIdle: When true, if `buffer` has at least 513 bytes and `buffer[0] == 0`, consumes one DMX-512 frame from the front without scanning for `0x00` inside slot data.
    static func pullFrames(buffer: inout [UInt8], leadingPacketAlignedAfterIdle: Bool, onFrame: ([UInt8]) -> Void) {
        if leadingPacketAlignedAfterIdle && buffer.count >= 513 && buffer[0] == 0x00 {
            let slots = Array(buffer[1 ..< 513])
            onFrame(slots)
            buffer.removeFirst(513)
        }
        pullFramesLegacyScan(buffer: &buffer, onFrame: onFrame)
    }

    /// Start-code scan: find first `0x00`, then take the following 512 bytes as slots.
    static func pullFramesLegacyScan(buffer: inout [UInt8], onFrame: ([UInt8]) -> Void) {
        var safety = 0
        while buffer.count >= 513, safety < 1024 {
            safety += 1
            guard let startIdx = buffer.firstIndex(of: 0) else {
                buffer.removeAll()
                return
            }
            if startIdx > 0 {
                buffer.removeFirst(startIdx)
            }
            guard buffer.count >= 513 else { return }
            let slots = Array(buffer[1 ..< 513])
            onFrame(slots)
            buffer.removeFirst(513)
        }
    }
}

/// Second-interface DMX **input** on a USB serial path (250k 8N2), for traditional desks feeding a receive-capable Open DMX–class adapter.
/// Frames are aligned using **idle-between-reads** resync (see ``OpenDMXFrameAssembler/defaultInterDrainIdleSeconds``) plus start-code `0x00` scan (best-effort when the stream has no detectable gaps).
final class OpenDMXUSBInputService {
    private var fd: Int32 = -1
    private var readSource: DispatchSourceRead?
    private(set) var isRunning = false
    private var devicePath: String = ""
    private var wireUniverse: Int = 0
    private var onFrame: ((Int, [UInt8], UInt8) -> Void)?
    private var assemblyBuffer: [UInt8] = []
    private let maxAssemblyBytes = 16_384
    /// End time of the previous ``drainReadable()`` invocation; used to detect idle between USB batches.
    private var lastDrainEndedAt: CFAbsoluteTime?
    /// When idle exceeds this between drains, partial data in ``assemblyBuffer`` is discarded and the next bytes are tried as gap-aligned frames.
    private var interDrainIdleThreshold: TimeInterval = OpenDMXFrameAssembler.defaultInterDrainIdleSeconds
    private(set) var receivedFrameCount: UInt64 = 0
    private(set) var lastError: String?

    /// Slightly above Art-Net default (100) so a fresh local desk frame wins over network when both are active.
    static let inboundPriority: UInt8 = 110

    func configure(path: String, wireUniverse: Int, onFrame: @escaping (Int, [UInt8], UInt8) -> Void) {
        devicePath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        self.wireUniverse = max(0, wireUniverse)
        self.onFrame = onFrame
    }

    func start() {
        guard !isRunning else { return }
        lastError = nil
        let path = devicePath
        guard !path.isEmpty else {
            lastError = "OpenDMX input path is empty."
            return
        }

        fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else {
            lastError = "Unable to open OpenDMX input device: \(path)"
            return
        }

        do {
            try OpenDMXSerialPort.configure250k8N2(fd: fd)
        } catch {
            Darwin.close(fd)
            fd = -1
            lastError = "OpenDMX input serial config failed: \(path)"
            return
        }

        assemblyBuffer.removeAll(keepingCapacity: true)
        lastDrainEndedAt = nil

        let queue = DispatchQueue(label: "com.fsdmxvision.dmx.opendmx.input", qos: .userInitiated)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.drainReadable()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fd >= 0 {
                Darwin.close(self.fd)
                self.fd = -1
            }
        }
        readSource = source
        source.resume()
        isRunning = true
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
        assemblyBuffer.removeAll()
        lastDrainEndedAt = nil
        isRunning = false
    }

    private func drainReadable() {
        guard fd >= 0 else { return }
        let batchStart = CFAbsoluteTimeGetCurrent()
        let longIdleBeforeBatch = lastDrainEndedAt.map { batchStart - $0 >= interDrainIdleThreshold } ?? false
        if longIdleBeforeBatch && !assemblyBuffer.isEmpty {
            assemblyBuffer.removeAll(keepingCapacity: true)
        }
        var chunk = [UInt8](repeating: 0, count: 4096)
        var useLeadingGapAlign = longIdleBeforeBatch
        while true {
            let n = chunk.withUnsafeMutableBufferPointer { buf in
                Darwin.read(fd, buf.baseAddress!, buf.count)
            }
            if n <= 0 { break }
            assemblyBuffer.append(contentsOf: chunk.prefix(Int(n)))
            if assemblyBuffer.count > maxAssemblyBytes {
                assemblyBuffer.removeFirst(assemblyBuffer.count - maxAssemblyBytes)
            }
            extractFrames(leadingPacketAlignedAfterIdle: useLeadingGapAlign)
            useLeadingGapAlign = false
        }
        lastDrainEndedAt = CFAbsoluteTimeGetCurrent()
    }

    private func extractFrames(leadingPacketAlignedAfterIdle: Bool) {
        OpenDMXFrameAssembler.pullFrames(
            buffer: &assemblyBuffer,
            leadingPacketAlignedAfterIdle: leadingPacketAlignedAfterIdle
        ) { slots in
            guard slots.count == 512 else { return }
            receivedFrameCount &+= 1
            onFrame?(wireUniverse, slots, Self.inboundPriority)
        }
    }
}
