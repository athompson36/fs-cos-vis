import Foundation

/// E1.31 multicast group `239.255.(universe>>8).(universe&0xFF)` for inbound sACN (IGMP join on Wi‑Fi/LAN).
enum SACNMulticastAddress {
    static func multicastString(forWireUniverse u: Int) -> String {
        let n = max(0, min(63999, u))
        let hi = (n >> 8) & 0xFF
        let lo = n & 0xFF
        return "239.255.\(hi).\(lo)"
    }

    static func membershipRequest(forWireUniverse u: Int) -> ip_mreq {
        var mreq = ip_mreq()
        let s = multicastString(forWireUniverse: u)
        s.withCString { ptr in
            _ = inet_pton(AF_INET, ptr, &mreq.imr_multiaddr)
        }
        mreq.imr_interface.s_addr = 0 // INADDR_ANY — default interface (Wi‑Fi or Ethernet)
        return mreq
    }
}

private enum SACNIPMulticastOption {
    /// `netinet/in.h` — `IP_ADD_MEMBERSHIP` / `IP_DROP_MEMBERSHIP`
    static let addMembership: Int32 = 12
    static let dropMembership: Int32 = 13
}

enum DMXOutputError: LocalizedError {
    case socketOpenFailed
    case invalidHost(String)
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .socketOpenFailed:
            return "Unable to open UDP socket."
        case let .invalidHost(host):
            return "Invalid network host: \(host)"
        case .sendFailed:
            return "Failed to send UDP DMX packet."
        }
    }
}

struct DMXPerformanceSnapshot: Equatable, Sendable {
    var frameCount: UInt64
    var overBudgetFrameCount: UInt64
    var avgBuildMS: Double
    var avgSendMS: Double
    var avgTotalMS: Double
    var maxBuildMS: Double
    var maxSendMS: Double
    var maxTotalMS: Double
    /// Counts of **total** frame time (ms) into fixed buckets; array length matches ``DMXPerformanceProfiler.totalMSHistogramBinCount``.
    var totalMSHistogramBinCounts: [UInt64]
    /// Last tick: patched fixture instances (for large-rig context).
    var rigFixtureInstanceCount: Int
    /// Last tick: modulation definitions count.
    var rigModulatorCount: Int
    /// Last tick: logical universes in the built output map (1 for USB/sim single-universe path).
    var outputLogicalUniverseCount: Int
    /// Approximate median **total** frame time (ms) from histogram bins (uniform within each bin); `nil` when `frameCount == 0`.
    var approxMedianTotalMS: Double?
    /// Approximate 95th percentile of **total** frame time (ms); `nil` when `frameCount == 0`.
    var approxP95TotalMS: Double?
    /// Approximate median **build** phase time (ms); `nil` when `frameCount == 0`.
    var approxMedianBuildMS: Double?
    var approxP95BuildMS: Double?
    /// Approximate median **send** phase time (ms); `nil` when `frameCount == 0`.
    var approxMedianSendMS: Double?
    var approxP95SendMS: Double?

    /// Labels for ``totalMSHistogramBinCounts`` buckets (ms, half-open except last).
    static let totalMSHistogramBinLabels: [String] = [
        "0–2", "2–4", "4–6", "6–8", "8–12", "12–16", "16–24", "24–40", "40+"
    ]

    /// Compact distribution line for Settings (e.g. `0–2:12 · 2–4:3 · …`).
    var totalMSHistogramSummary: String {
        guard totalMSHistogramBinCounts.count == Self.totalMSHistogramBinLabels.count else { return "" }
        return zip(Self.totalMSHistogramBinLabels, totalMSHistogramBinCounts).map { "\($0.0):\($0.1)" }.joined(separator: " · ")
    }
}

struct DMXPerformanceProfiler: Sendable {
    /// Buckets for **total** frame duration (ms): `[0,2), [2,4), …, [40, ∞)`.
    static let totalMSHistogramBinCount = 9

    private(set) var frameCount: UInt64 = 0
    private(set) var overBudgetFrameCount: UInt64 = 0
    private(set) var totalBuildMS: Double = 0
    private(set) var totalSendMS: Double = 0
    private(set) var totalFrameMS: Double = 0
    private(set) var maxBuildMS: Double = 0
    private(set) var maxSendMS: Double = 0
    private(set) var maxFrameMS: Double = 0
    private var totalMSHistogram: [UInt64] = [UInt64](repeating: 0, count: DMXPerformanceProfiler.totalMSHistogramBinCount)
    private var buildMSHistogram: [UInt64] = [UInt64](repeating: 0, count: DMXPerformanceProfiler.totalMSHistogramBinCount)
    private var sendMSHistogram: [UInt64] = [UInt64](repeating: 0, count: DMXPerformanceProfiler.totalMSHistogramBinCount)
    private(set) var lastRigFixtureInstanceCount: Int = 0
    private(set) var lastRigModulatorCount: Int = 0
    private(set) var lastOutputLogicalUniverseCount: Int = 0

    private static func durationHistogramBinIndex(_ ms: Double) -> Int {
        let t = max(0, ms)
        switch t {
        case ..<2: return 0
        case ..<4: return 1
        case ..<6: return 2
        case ..<8: return 3
        case ..<12: return 4
        case ..<16: return 5
        case ..<24: return 6
        case ..<40: return 7
        default: return 8
        }
    }

    /// Lower bounds (ms) for each histogram bin; must stay aligned with ``durationHistogramBinIndex``.
    private static let durationHistogramBinLowerMs: [Double] = [0, 2, 4, 6, 8, 12, 16, 24, 40]

    /// Linear interpolation on the empirical histogram CDF: `quantile` in (0,1), `t = quantile * n` sample-ranks.
    static func approximateDurationQuantile(
        bins: [UInt64],
        frameCount: UInt64,
        quantile: Double,
        maxObservedMS: Double
    ) -> Double? {
        guard frameCount > 0, quantile > 0, quantile < 1, bins.count == totalMSHistogramBinCount else { return nil }
        let n = Double(frameCount)
        let t = quantile * n
        var cum: UInt64 = 0
        let lowers = durationHistogramBinLowerMs
        for i in 0 ..< totalMSHistogramBinCount {
            let c = bins[i]
            if c == 0 { continue }
            let before = cum
            cum += c
            if Double(cum) >= t {
                let lo = lowers[i]
                let hi: Double = i < 8 ? lowers[i + 1] : max(40.000_001, maxObservedMS)
                let offset = t - Double(before)
                return lo + (offset / Double(c)) * (hi - lo)
            }
        }
        return nil
    }

    mutating func recordFrame(
        buildMS: Double,
        sendMS: Double,
        totalMS: Double,
        budgetMS: Double,
        rigFixtureInstanceCount: Int,
        rigModulatorCount: Int,
        outputLogicalUniverseCount: Int
    ) {
        frameCount &+= 1
        totalBuildMS += buildMS
        totalSendMS += sendMS
        totalFrameMS += totalMS
        maxBuildMS = max(maxBuildMS, buildMS)
        maxSendMS = max(maxSendMS, sendMS)
        maxFrameMS = max(maxFrameMS, totalMS)
        let biTotal = Self.durationHistogramBinIndex(totalMS)
        totalMSHistogram[biTotal] &+= 1
        buildMSHistogram[Self.durationHistogramBinIndex(buildMS)] &+= 1
        sendMSHistogram[Self.durationHistogramBinIndex(sendMS)] &+= 1
        lastRigFixtureInstanceCount = rigFixtureInstanceCount
        lastRigModulatorCount = rigModulatorCount
        lastOutputLogicalUniverseCount = outputLogicalUniverseCount
        if totalMS > budgetMS {
            overBudgetFrameCount &+= 1
        }
    }

    func snapshot() -> DMXPerformanceSnapshot {
        let divisor = max(1.0, Double(frameCount))
        let med = Self.approximateDurationQuantile(
            bins: totalMSHistogram,
            frameCount: frameCount,
            quantile: 0.5,
            maxObservedMS: maxFrameMS
        )
        let p95 = Self.approximateDurationQuantile(
            bins: totalMSHistogram,
            frameCount: frameCount,
            quantile: 0.95,
            maxObservedMS: maxFrameMS
        )
        let medB = Self.approximateDurationQuantile(
            bins: buildMSHistogram,
            frameCount: frameCount,
            quantile: 0.5,
            maxObservedMS: maxBuildMS
        )
        let p95B = Self.approximateDurationQuantile(
            bins: buildMSHistogram,
            frameCount: frameCount,
            quantile: 0.95,
            maxObservedMS: maxBuildMS
        )
        let medS = Self.approximateDurationQuantile(
            bins: sendMSHistogram,
            frameCount: frameCount,
            quantile: 0.5,
            maxObservedMS: maxSendMS
        )
        let p95S = Self.approximateDurationQuantile(
            bins: sendMSHistogram,
            frameCount: frameCount,
            quantile: 0.95,
            maxObservedMS: maxSendMS
        )
        return DMXPerformanceSnapshot(
            frameCount: frameCount,
            overBudgetFrameCount: overBudgetFrameCount,
            avgBuildMS: totalBuildMS / divisor,
            avgSendMS: totalSendMS / divisor,
            avgTotalMS: totalFrameMS / divisor,
            maxBuildMS: maxBuildMS,
            maxSendMS: maxSendMS,
            maxTotalMS: maxFrameMS,
            totalMSHistogramBinCounts: totalMSHistogram,
            rigFixtureInstanceCount: lastRigFixtureInstanceCount,
            rigModulatorCount: lastRigModulatorCount,
            outputLogicalUniverseCount: lastOutputLogicalUniverseCount,
            approxMedianTotalMS: med,
            approxP95TotalMS: p95,
            approxMedianBuildMS: medB,
            approxP95BuildMS: p95B,
            approxMedianSendMS: medS,
            approxP95SendMS: p95S
        )
    }

    /// Clears all accumulated timing stats (histogram, maxima, counts). Safe to call from any thread.
    mutating func reset() {
        frameCount = 0
        overBudgetFrameCount = 0
        totalBuildMS = 0
        totalSendMS = 0
        totalFrameMS = 0
        maxBuildMS = 0
        maxSendMS = 0
        maxFrameMS = 0
        totalMSHistogram = [UInt64](repeating: 0, count: Self.totalMSHistogramBinCount)
        buildMSHistogram = [UInt64](repeating: 0, count: Self.totalMSHistogramBinCount)
        sendMSHistogram = [UInt64](repeating: 0, count: Self.totalMSHistogramBinCount)
        lastRigFixtureInstanceCount = 0
        lastRigModulatorCount = 0
        lastOutputLogicalUniverseCount = 0
    }
}

enum DMXNetworkPacketBuilder {
    static func requiresSerialPath(mode: String) -> Bool {
        mode == "hardware"
    }

    static func makeArtNetPacket(universe: Int, frame: [UInt8]) -> [UInt8] {
        let normalized = max(0, min(32767, universe))
        var packet: [UInt8] = Array("Art-Net".utf8) + [0x00]
        packet += [0x00, 0x50] // OpOutput / ArtDMX (little-endian)
        packet += [0x00, 0x0E] // protocol version 14
        packet += [0x00, 0x00] // sequence, physical
        packet += [UInt8(normalized & 0xFF), UInt8((normalized >> 8) & 0x7F)]
        packet += [UInt8((frame.count >> 8) & 0xFF), UInt8(frame.count & 0xFF)]
        packet += frame
        return packet
    }

    /// ANSI E1.31 (sACN) **Data** packet — 638 bytes with 512-channel payload (start code 0x00).
    /// Layout aligned with common open implementations (Root + Framing + DMP layers).
    static func makeSACNPacket(universe: Int, frame: [UInt8], sequence: UInt8) -> [UInt8] {
        let normalized = max(0, min(63999, universe))
        var channels = [UInt8](repeating: 0, count: 512)
        for i in 0 ..< min(512, frame.count) {
            channels[i] = frame[i]
        }
        let totalLength = 638

        var p: [UInt8] = []
        p.reserveCapacity(totalLength)
        // Root: preamble + ACN packet identifier `ASC-E1.17` + padding (per ESTA E1.31)
        p.append(contentsOf: [
            0x00, 0x10, 0x00, 0x00,
            0x41, 0x53, 0x43, 0x2d, 0x45, 0x31, 0x2e, 0x31, 0x37, 0x00, 0x00, 0x00
        ])
        p.append(contentsOf: Self.acnFlagsAndLength12(totalLength - 16))
        p.append(contentsOf: [0x00, 0x00, 0x00, 0x04]) // VECTOR_ROOT_E131_DATA
        p.append(contentsOf: Self.sacnSenderCID)
        // Framing layer
        p.append(contentsOf: Self.acnFlagsAndLength12(totalLength - 38))
        p.append(contentsOf: [0x00, 0x00, 0x00, 0x02]) // VECTOR_E131_DATA_PACKET
        let sourceLabel = Array("Cosmic Visualizer".utf8)
        for i in 0 ..< 64 {
            p.append(i < sourceLabel.count ? sourceLabel[i] : 0)
        }
        p.append(100) // priority (default)
        p.append(0x00)
        p.append(0x00) // sync address
        p.append(sequence)
        p.append(0x00) // options
        p.append(UInt8((normalized >> 8) & 0xFF))
        p.append(UInt8(normalized & 0xFF))
        // DMP layer
        p.append(contentsOf: Self.acnFlagsAndLength12(totalLength - 115))
        p.append(0x02) // VECTOR_DMP_SET_PROPERTY
        p.append(contentsOf: [0xa1, 0x00, 0x00, 0x00, 0x01])
        let propCount = 513 // start code + 512 slots
        p.append(UInt8((propCount >> 8) & 0xFF))
        p.append(UInt8(propCount & 0xFF))
        p.append(0x00) // DMX start code
        p.append(contentsOf: channels)
        precondition(p.count == totalLength)
        return p
    }

    /// 16-byte Component Identifier (unique per sender; stable for this app build).
    private static let sacnSenderCID: [UInt8] = {
        var b = [UInt8](repeating: 0, count: 16)
        let label = Array("Cosmic Visualizer".utf8)
        for i in 0 ..< min(16, label.count) {
            b[i] = label[i]
        }
        return b
    }()

    private static func acnFlagsAndLength12(_ length: Int) -> [UInt8] {
        let len = min(length, 0x0FFF)
        let hi = UInt8(0x70 | UInt8((len & 0x0F00) >> 8))
        let lo = UInt8(len & 0xFF)
        return [hi, lo]
    }
}

/// Non-DMX E1.31 root **extended** PDUs (same UDP port as data). We do not apply sync/discovery semantics yet; counting aids field diagnostics.
enum SACNE131InboundNonData: Equatable {
    case synchronization
    case universeDiscovery
}

/// Classifies E1.31 **extended** packets (root vector `0x08`) by framing-layer vector. Returns `nil` for data packets, non-ACN, or unknown layouts.
enum SACNE131InboundClassifier {
    private static let rootVectorExtended: [UInt8] = [0x00, 0x00, 0x00, 0x08]
    /// Framing: `VECTOR_E131_EXTENDED_SYNCHRONIZATION`
    private static let framingVectorSync: [UInt8] = [0x00, 0x00, 0x00, 0x01]
    /// Framing: `VECTOR_E131_EXTENDED_DISCOVERY`
    private static let framingVectorDiscovery: [UInt8] = [0x00, 0x00, 0x00, 0x02]

    /// Preamble + ACN packet identifier `ASC-E1.17` (ESTA E1.31 root layer).
    private static func matchesE131RootPreamble(_ packet: [UInt8]) -> Bool {
        guard packet.count >= 16 else { return false }
        if packet[0] != 0x00 || packet[1] != 0x10 || packet[2] != 0x00 || packet[3] != 0x00 { return false }
        let label: [UInt8] = [0x41, 0x53, 0x43, 0x2d, 0x45, 0x31, 0x2e, 0x31, 0x37, 0x00, 0x00, 0x00]
        return Array(packet[4 ..< 16]) == label
    }

    static func extendedNonDataKind(packet: [UInt8]) -> SACNE131InboundNonData? {
        guard packet.count >= 44 else { return nil }
        guard matchesE131RootPreamble(packet) else { return nil }
        let rootVec = Array(packet[18 ..< 22])
        guard rootVec == rootVectorExtended else { return nil }
        let framingVec = Array(packet[40 ..< 44])
        if framingVec == framingVectorSync { return .synchronization }
        if framingVec == framingVectorDiscovery { return .universeDiscovery }
        return nil
    }
}

/// Inbound DMX decode result. `priority` follows **E1.31** (0–200; higher wins); Art-Net and legacy sACN scaffold use ``defaultPriority``.
struct DMXInboundDecoded {
    var universe: Int
    var frame: [UInt8]
    var priority: UInt8
    /// Wire default when priority is not defined (E1.31 default; used for Art-Net and legacy scaffold).
    static let defaultPriority: UInt8 = 100
}

enum DMXInboundPacketDecoder {
    static func decode(packet: [UInt8], mode: String) -> DMXInboundDecoded? {
        if mode == "sacn" {
            return decodeSACN(packet: packet)
        }
        return decodeArtNet(packet: packet)
    }

    private static func decodeArtNet(packet: [UInt8]) -> DMXInboundDecoded? {
        guard packet.count >= 18 else { return nil }
        guard String(decoding: packet.prefix(8), as: UTF8.self) == "Art-Net\u{0}" else { return nil }
        guard packet[8] == 0x00, packet[9] == 0x50 else { return nil }
        let universe = Int(packet[14]) | (Int(packet[15] & 0x7F) << 8)
        let declaredLength = (Int(packet[16]) << 8) | Int(packet[17])
        let payloadStart = 18
        guard packet.count >= payloadStart + declaredLength else { return nil }
        let frame = Array(packet[payloadStart ..< payloadStart + min(512, declaredLength)])
        guard frame.count == 512 else { return nil }
        return DMXInboundDecoded(universe: universe, frame: frame, priority: DMXInboundDecoded.defaultPriority)
    }

    private static func decodeSACN(packet: [UInt8]) -> DMXInboundDecoded? {
        if packet.count >= 638,
           packet[18] == 0, packet[19] == 0, packet[20] == 0, packet[21] == 0x04,
           packet[40] == 0, packet[41] == 0, packet[42] == 0, packet[43] == 0x02,
           packet[117] == 0x02 {
            let universe = (Int(packet[113]) << 8) | Int(packet[114])
            guard packet[125] == 0x00 else { return nil }
            // Framing layer priority (E1.31): higher value wins when merging sources.
            let priority = packet[108]
            let frame = Array(packet[126 ..< 638])
            guard frame.count == 512 else { return nil }
            return DMXInboundDecoded(universe: universe, frame: frame, priority: priority)
        }
        return decodeSACNLegacyScaffold(packet: packet)
    }

    /// Legacy 523-byte scaffold (`ASC-E1.31` + universe + 512 channels) kept for tests / old senders.
    private static func decodeSACNLegacyScaffold(packet: [UInt8]) -> DMXInboundDecoded? {
        guard packet.count >= 11 else { return nil }
        guard String(decoding: packet.prefix(9), as: UTF8.self) == "ASC-E1.31" else { return nil }
        let universe = (Int(packet[9]) << 8) | Int(packet[10])
        let frame = Array(packet.dropFirst(11).prefix(512))
        guard frame.count == 512 else { return nil }
        return DMXInboundDecoded(universe: universe, frame: frame, priority: DMXInboundDecoded.defaultPriority)
    }
}

private final class UDPDMXClient {
    private var socketFD: Int32 = -1
    private var destinationAddress = sockaddr_in()
    private var destinationLength: socklen_t = 0
    private var configuredHost = ""
    private var configuredPort: UInt16 = 0

    func configure(host: String, port: UInt16) throws {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedHost.isEmpty else { throw DMXOutputError.invalidHost(host) }

        if socketFD < 0 {
            socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard socketFD >= 0 else { throw DMXOutputError.socketOpenFailed }
            let yes: Int32 = 1
            _ = withUnsafePointer(to: yes) {
                setsockopt(socketFD, SOL_SOCKET, SO_BROADCAST, $0, socklen_t(MemoryLayout<Int32>.size))
            }
        }

        if configuredHost == normalizedHost, configuredPort == port { return }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(port)
        let parseResult = normalizedHost.withCString { cString in
            inet_pton(AF_INET, cString, &addr.sin_addr)
        }
        guard parseResult == 1 else { throw DMXOutputError.invalidHost(normalizedHost) }

        destinationAddress = addr
        destinationLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        configuredHost = normalizedHost
        configuredPort = port
    }

    func send(payload: [UInt8]) throws {
        guard socketFD >= 0 else { throw DMXOutputError.socketOpenFailed }
        let result = payload.withUnsafeBytes { bytes -> Int in
            guard let base = bytes.baseAddress else { return -1 }
            return withUnsafePointer(to: &destinationAddress) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(socketFD, base, payload.count, 0, sockaddrPtr, destinationLength)
                }
            }
        }
        guard result == payload.count else { throw DMXOutputError.sendFailed }
    }

    func close() {
        if socketFD >= 0 {
            Darwin.close(socketFD)
            socketFD = -1
        }
        configuredHost = ""
        configuredPort = 0
    }
}

final class DMXInputService {
    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private(set) var isRunning = false
    private var mode: String = "artnet"
    private var universeStart: Int = 0
    private var universeCount: Int = 1
    private var onFrame: ((Int, [UInt8], UInt8) -> Void)?
    private var lastError: String?
    private var receivedFrameCount: UInt64 = 0
    private var sacnSyncPacketCount: UInt64 = 0
    private var sacnDiscoveryPacketCount: UInt64 = 0
    /// Wire universes for which `IP_ADD_MEMBERSHIP` succeeded (sACN only); dropped in `stop()`.
    private var sacnJoinedUniverses: [Int] = []

    func configure(
        mode: String,
        universeStart: Int,
        universeCount: Int,
        onFrame: @escaping (Int, [UInt8], UInt8) -> Void
    ) {
        self.mode = mode
        self.universeStart = max(0, universeStart)
        self.universeCount = max(1, min(64, universeCount))
        self.onFrame = onFrame
    }

    func start() {
        guard !isRunning else { return }
        let port: UInt16 = mode == "sacn" ? 5568 : 6454
        socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            lastError = DMXOutputError.socketOpenFailed.localizedDescription
            return
        }

        let yes: Int32 = 1
        _ = withUnsafePointer(to: yes) {
            setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, $0, socklen_t(MemoryLayout<Int32>.size))
        }
        _ = withUnsafePointer(to: yes) {
            setsockopt(socketFD, SOL_SOCKET, SO_BROADCAST, $0, socklen_t(MemoryLayout<Int32>.size))
        }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        addr.sin_port = CFSwapInt16HostToBig(port)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            lastError = "Unable to bind inbound DMX port \(port)."
            stop()
            return
        }

        sacnJoinedUniverses.removeAll()
        if mode == "sacn" {
            lastError = joinSACNMulticastGroups(socketFD: socketFD)
        } else {
            lastError = nil
        }

        let queue = DispatchQueue(label: "com.cosmicvisualizer.dmx.input", qos: .userInitiated)
        let source = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.handleSocketReadable()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.socketFD >= 0 {
                Darwin.close(self.socketFD)
                self.socketFD = -1
            }
        }
        readSource = source
        source.resume()
        isRunning = true
    }

    func stop() {
        leaveSACNMulticastGroupsIfNeeded()
        readSource?.cancel()
        readSource = nil
        if socketFD >= 0 {
            Darwin.close(socketFD)
            socketFD = -1
        }
        isRunning = false
    }

    private func joinSACNMulticastGroups(socketFD: Int32) -> String? {
        var failed: [String] = []
        for u in universeStart ..< (universeStart + universeCount) {
            var mreq = SACNMulticastAddress.membershipRequest(forWireUniverse: u)
            let code = setsockopt(
                socketFD,
                IPPROTO_IP,
                SACNIPMulticastOption.addMembership,
                &mreq,
                socklen_t(MemoryLayout<ip_mreq>.size)
            )
            if code == 0 {
                sacnJoinedUniverses.append(u)
            } else {
                failed.append("\(u)")
            }
        }
        guard !failed.isEmpty else { return nil }
        return "sACN multicast join failed for universe(s): \(failed.joined(separator: ", ")). Check IGMP / Wi‑Fi AP; unicast to this Mac may still work."
    }

    private func leaveSACNMulticastGroupsIfNeeded() {
        guard socketFD >= 0, !sacnJoinedUniverses.isEmpty else {
            sacnJoinedUniverses.removeAll()
            return
        }
        for u in sacnJoinedUniverses {
            var mreq = SACNMulticastAddress.membershipRequest(forWireUniverse: u)
            _ = setsockopt(
                socketFD,
                IPPROTO_IP,
                SACNIPMulticastOption.dropMembership,
                &mreq,
                socklen_t(MemoryLayout<ip_mreq>.size)
            )
        }
        sacnJoinedUniverses.removeAll()
    }

    func diagnostics() -> (lastError: String?, running: Bool, frames: UInt64, sacnSyncPackets: UInt64, sacnDiscoveryPackets: UInt64) {
        (lastError: lastError, running: isRunning, frames: receivedFrameCount, sacnSyncPackets: sacnSyncPacketCount, sacnDiscoveryPackets: sacnDiscoveryPacketCount)
    }

    private func handleSocketReadable() {
        guard socketFD >= 0 else { return }
        var buffer = [UInt8](repeating: 0, count: 1500)
        var srcAddr = sockaddr_storage()
        var srcLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let readBytes = withUnsafeMutablePointer(to: &srcAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                recvfrom(socketFD, &buffer, buffer.count, 0, sockaddrPtr, &srcLen)
            }
        }
        guard readBytes > 0 else { return }
        let packet = Array(buffer.prefix(readBytes))
        if mode == "sacn", let kind = SACNE131InboundClassifier.extendedNonDataKind(packet: packet) {
            switch kind {
            case .synchronization:
                sacnSyncPacketCount &+= 1
            case .universeDiscovery:
                sacnDiscoveryPacketCount &+= 1
            }
            return
        }
        guard let decoded = DMXInboundPacketDecoder.decode(packet: packet, mode: mode) else { return }
        let u = decoded.universe
        guard u >= universeStart, u < universeStart + universeCount else { return }
        receivedFrameCount &+= 1
        onFrame?(u, decoded.frame, decoded.priority)
    }
}

struct RDMDeviceSummary: Equatable, Sendable {
    var uid: String
    var manufacturer: String
    var modelLabel: String
    var footprint: Int
    var startAddress: Int
}

struct RDMDiscoveryResult: Equatable, Sendable {
    var mode: String
    var universe: Int
    var devices: [RDMDeviceSummary]
    var notes: String
}

final class RDMDiscoveryService {
    func runMockProbe(mode: String, universe: Int, serialPath: String) async -> RDMDiscoveryResult {
        let normalizedMode = mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedUniverse = max(0, universe)
        let transportHint: String = {
            if normalizedMode == "hardware" {
                let trimmed = serialPath.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "hardware:no_serial_path" : "hardware:\(trimmed)"
            }
            return normalizedMode
        }()
        let devices: [RDMDeviceSummary] = [
            RDMDeviceSummary(
                uid: "7A70:00000001",
                manufacturer: "ADJ",
                modelLabel: "Mega Par Profile",
                footprint: 8,
                startAddress: 1
            ),
            RDMDeviceSummary(
                uid: "7A70:00000002",
                manufacturer: "Antari",
                modelLabel: "HZ-500 Hazer",
                footprint: 5,
                startAddress: 65
            ),
        ]
        return RDMDiscoveryResult(
            mode: normalizedMode.isEmpty ? "hardware" : normalizedMode,
            universe: normalizedUniverse,
            devices: devices,
            notes: "Mock RDM probe (\(transportHint)); replace with transport-native discovery sequence in production."
        )
    }
}

private protocol DMXTransport: AnyObject {
    func prepare(with model: AppModel) throws
    func send(universe: [UInt8]) throws
    func close()
    var diagnosticsLabel: String { get }
}

private final class OpenDMXHardwareTransport: DMXTransport {
    private let writer = OpenDMXUSBWriter()
    private var path: String = ""
    func prepare(with model: AppModel) throws {
        let nextPath = model.remoteSettings.dmxSerialDevicePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nextPath.isEmpty else { throw OpenDMXError.openFailed }
        path = nextPath
        try writer.ensureOpen(path: nextPath)
    }

    func send(universe: [UInt8]) throws {
        try writer.send(universe: universe)
    }

    func close() {
        writer.close()
    }

    var diagnosticsLabel: String { "hardware:\(path)" }
}

private final class MockOpenDMXTransport: DMXTransport {
    private(set) var frameCount: UInt64 = 0
    private(set) var lastUniverse = [UInt8](repeating: 0, count: 512)
    private(set) var simulatedInterfaceName = "enttec_open_dmx"

    func prepare(with model: AppModel) {
        simulatedInterfaceName = model.remoteSettings.dmxSimulatedInterface
    }

    func send(universe: [UInt8]) {
        lastUniverse = universe
        frameCount &+= 1
    }

    func close() {}

    var diagnosticsLabel: String {
        "simulated:\(simulatedInterfaceName) frames:\(frameCount)"
    }
}

private final class ArtNetTransport: DMXTransport {
    private(set) var frameCount: UInt64 = 0
    private(set) var host = "255.255.255.255"
    private(set) var packetsLastSend = 0
    private let client = UDPDMXClient()

    func prepare(with model: AppModel) throws {
        host = model.remoteSettings.dmxArtNetHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty { host = "255.255.255.255" }
        try client.configure(host: host, port: 6454)
    }

    /// One ArtDMX packet per logical universe; `networkOffset` is added to each fixture’s `universe` index (Settings “Network universe”).
    func sendUniverseMap(_ map: [Int: [UInt8]], networkOffset: Int) throws {
        packetsLastSend = 0
        for (logical, data) in map.sorted(by: { $0.key < $1.key }) {
            let netU = max(0, min(32767, logical + networkOffset))
            let payload = DMXNetworkPacketBuilder.makeArtNetPacket(universe: netU, frame: data)
            try client.send(payload: payload)
            frameCount &+= 1
            packetsLastSend += 1
        }
    }

    func send(universe: [UInt8]) throws {
        let offset = 0
        try sendUniverseMap([0: universe], networkOffset: offset)
    }

    func close() {
        client.close()
    }

    var diagnosticsLabel: String { "artnet:\(host) lastTickPackets:\(packetsLastSend) totalFrames:\(frameCount)" }
}

private final class SACNTransport: DMXTransport {
    private(set) var frameCount: UInt64 = 0
    private(set) var host = "239.255.0.1"
    private(set) var packetsLastSend = 0
    private var sacnSequence: UInt8 = 0
    private let client = UDPDMXClient()

    func prepare(with model: AppModel) throws {
        host = model.remoteSettings.dmxSACNHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty { host = "239.255.0.1" }
        try client.configure(host: host, port: 5568)
    }

    func sendUniverseMap(_ map: [Int: [UInt8]], networkOffset: Int) throws {
        packetsLastSend = 0
        for (logical, data) in map.sorted(by: { $0.key < $1.key }) {
            let netU = max(0, min(63999, logical + networkOffset))
            let payload = DMXNetworkPacketBuilder.makeSACNPacket(universe: netU, frame: data, sequence: sacnSequence)
            sacnSequence &+= 1
            try client.send(payload: payload)
            frameCount &+= 1
            packetsLastSend += 1
        }
    }

    func send(universe: [UInt8]) throws {
        try sendUniverseMap([0: universe], networkOffset: 0)
    }

    func close() {
        client.close()
    }

    var diagnosticsLabel: String { "sacn:\(host) lastTickPackets:\(packetsLastSend) totalFrames:\(frameCount)" }
}

/// Maps a subset of live parameters into a single DMX universe and pushes frames at ~44 Hz.
final class DMXOutputService: ControlBus {
    private weak var model: AppModel?
    private var timer: DispatchSourceTimer?
    private(set) var isRunning = false
    private var universe = [UInt8](repeating: 0, count: 512)
    private var lastError: String?
    private var transportInfo: String?
    private var modulationLastSmoothed: [UUID: Float] = [:]
    private var transport: DMXTransport?
    private var performanceProfiler = DMXPerformanceProfiler()
    private let performanceProfilerLock = NSLock()
    /// UDP packets sent in the last timer tick (1 for USB/sim; N for multi-universe Art-Net/sACN).
    private(set) var packetsLastTimerTick: Int = 1

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let queue = DispatchQueue(label: "com.cosmicvisualizer.dmx", qos: .userInitiated)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 1.0 / 44.0)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
        transport?.close()
        isRunning = false
    }

    private func tick() {
        guard let model else { return }
        guard model.remoteSettings.dmxOutputEnabled else { return }
        let mode = model.remoteSettings.dmxOutputMode
        if DMXNetworkPacketBuilder.requiresSerialPath(mode: mode) {
            let path = model.remoteSettings.dmxSerialDevicePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return }
        }

        let tickStart = CFAbsoluteTimeGetCurrent()

        if mode == "artnet" || mode == "sacn" {
            let buildStart = tickStart
            let map = model.buildDMXUniversesForNetwork(time: buildStart, lastSmoothed: &modulationLastSmoothed)
            let buildMS = max(0, (CFAbsoluteTimeGetCurrent() - buildStart) * 1000)
            let sendStart = CFAbsoluteTimeGetCurrent()
            do {
                let transport = try resolveTransport(model: model)
                try transport.prepare(with: model)
                let offset = model.remoteSettings.dmxNetworkUniverse
                if let art = transport as? ArtNetTransport {
                    try art.sendUniverseMap(map, networkOffset: offset)
                    packetsLastTimerTick = art.packetsLastSend
                    transportInfo = art.diagnosticsLabel
                } else if let sacn = transport as? SACNTransport {
                    try sacn.sendUniverseMap(map, networkOffset: offset)
                    packetsLastTimerTick = sacn.packetsLastSend
                    transportInfo = sacn.diagnosticsLabel
                }
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
            let sendMS = max(0, (CFAbsoluteTimeGetCurrent() - sendStart) * 1000)
            let totalMS = max(0, (CFAbsoluteTimeGetCurrent() - tickStart) * 1000)
            let rig = model.dmxRigMetricsForProfiling(outputLogicalUniverseCount: map.count)
            recordProfilerFrame(
                buildMS: buildMS,
                sendMS: sendMS,
                totalMS: totalMS,
                rig: rig
            )
            return
        }

        let buildStart = tickStart
        universe = model.buildDMXUniverse(time: buildStart, lastSmoothed: &modulationLastSmoothed)
        let buildMS = max(0, (CFAbsoluteTimeGetCurrent() - buildStart) * 1000)

        let sendStart = CFAbsoluteTimeGetCurrent()
        do {
            let transport = try resolveTransport(model: model)
            try transport.prepare(with: model)
            try transport.send(universe: universe)
            transportInfo = transport.diagnosticsLabel
            packetsLastTimerTick = 1
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        let sendMS = max(0, (CFAbsoluteTimeGetCurrent() - sendStart) * 1000)
        let totalMS = max(0, (CFAbsoluteTimeGetCurrent() - tickStart) * 1000)
        let rig = model.dmxRigMetricsForProfiling(outputLogicalUniverseCount: 1)
        recordProfilerFrame(
            buildMS: buildMS,
            sendMS: sendMS,
            totalMS: totalMS,
            rig: rig
        )
    }

    private func recordProfilerFrame(
        buildMS: Double,
        sendMS: Double,
        totalMS: Double,
        rig: (fixtureInstances: Int, modulators: Int, outputLogicalUniverses: Int)
    ) {
        performanceProfilerLock.lock()
        performanceProfiler.recordFrame(
            buildMS: buildMS,
            sendMS: sendMS,
            totalMS: totalMS,
            budgetMS: 1000.0 / 44.0,
            rigFixtureInstanceCount: rig.fixtureInstances,
            rigModulatorCount: rig.modulators,
            outputLogicalUniverseCount: rig.outputLogicalUniverses
        )
        performanceProfilerLock.unlock()
    }

    private func resolveTransport(model: AppModel) throws -> DMXTransport {
        let mode = model.remoteSettings.dmxOutputMode
        if mode == "simulated" {
            if let existing = transport as? MockOpenDMXTransport {
                return existing
            }
            transport?.close()
            let created = MockOpenDMXTransport()
            transport = created
            return created
        }
        if mode == "artnet" {
            if let existing = transport as? ArtNetTransport {
                return existing
            }
            transport?.close()
            let created = ArtNetTransport()
            transport = created
            return created
        }
        if mode == "sacn" {
            if let existing = transport as? SACNTransport {
                return existing
            }
            transport?.close()
            let created = SACNTransport()
            transport = created
            return created
        }
        if let existing = transport as? OpenDMXHardwareTransport {
            return existing
        }
        transport?.close()
        let created = OpenDMXHardwareTransport()
        transport = created
        return created
    }

    func diagnostics() -> (lastError: String?, running: Bool) {
        (lastError, isRunning)
    }

    /// Nominal frame rate (timer interval); adapters may vary.
    func extendedDiagnostics() -> (lastError: String?, running: Bool, nominalHz: Double, packetsLastTimerTick: Int) {
        (lastError, isRunning, 44.0, packetsLastTimerTick)
    }

    func simulationSnapshot() -> (mode: String, info: String, universe: [UInt8])? {
        guard let mock = transport as? MockOpenDMXTransport else { return nil }
        return (mode: "simulated", info: mock.diagnosticsLabel, universe: mock.lastUniverse)
    }

    func performanceSnapshot() -> DMXPerformanceSnapshot {
        performanceProfilerLock.lock()
        let snap = performanceProfiler.snapshot()
        performanceProfilerLock.unlock()
        return snap
    }

    /// Clears DMX frame timing accumulators (histogram, averages, maxima). Thread-safe with the output timer.
    func resetPerformanceProfiler() {
        performanceProfilerLock.lock()
        performanceProfiler.reset()
        performanceProfilerLock.unlock()
    }
}
