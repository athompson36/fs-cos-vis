import Foundation

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
    var maxTotalMS: Double
}

struct DMXPerformanceProfiler: Sendable {
    private(set) var frameCount: UInt64 = 0
    private(set) var overBudgetFrameCount: UInt64 = 0
    private(set) var totalBuildMS: Double = 0
    private(set) var totalSendMS: Double = 0
    private(set) var totalFrameMS: Double = 0
    private(set) var maxFrameMS: Double = 0

    mutating func recordFrame(buildMS: Double, sendMS: Double, totalMS: Double, budgetMS: Double) {
        frameCount &+= 1
        totalBuildMS += buildMS
        totalSendMS += sendMS
        totalFrameMS += totalMS
        maxFrameMS = max(maxFrameMS, totalMS)
        if totalMS > budgetMS {
            overBudgetFrameCount &+= 1
        }
    }

    func snapshot() -> DMXPerformanceSnapshot {
        let divisor = max(1.0, Double(frameCount))
        return DMXPerformanceSnapshot(
            frameCount: frameCount,
            overBudgetFrameCount: overBudgetFrameCount,
            avgBuildMS: totalBuildMS / divisor,
            avgSendMS: totalSendMS / divisor,
            avgTotalMS: totalFrameMS / divisor,
            maxTotalMS: maxFrameMS
        )
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

    static func makeSACNPacket(universe: Int, frame: [UInt8]) -> [UInt8] {
        let normalized = max(0, min(63999, universe))
        // Lightweight scaffold payload for future full E1.31 framing.
        var packet = Array("ASC-E1.31".utf8)
        packet += [UInt8((normalized >> 8) & 0xFF), UInt8(normalized & 0xFF)]
        packet += frame
        return packet
    }
}

enum DMXInboundPacketDecoder {
    static func decode(packet: [UInt8], mode: String) -> (universe: Int, frame: [UInt8])? {
        if mode == "sacn" {
            return decodeSACN(packet: packet)
        }
        return decodeArtNet(packet: packet)
    }

    private static func decodeArtNet(packet: [UInt8]) -> (universe: Int, frame: [UInt8])? {
        guard packet.count >= 18 else { return nil }
        guard String(decoding: packet.prefix(8), as: UTF8.self) == "Art-Net\u{0}" else { return nil }
        guard packet[8] == 0x00, packet[9] == 0x50 else { return nil }
        let universe = Int(packet[14]) | (Int(packet[15] & 0x7F) << 8)
        let declaredLength = (Int(packet[16]) << 8) | Int(packet[17])
        let payloadStart = 18
        guard packet.count >= payloadStart + declaredLength else { return nil }
        let frame = Array(packet[payloadStart ..< payloadStart + min(512, declaredLength)])
        guard frame.count == 512 else { return nil }
        return (universe, frame)
    }

    private static func decodeSACN(packet: [UInt8]) -> (universe: Int, frame: [UInt8])? {
        guard packet.count >= 11 else { return nil }
        guard String(decoding: packet.prefix(9), as: UTF8.self) == "ASC-E1.31" else { return nil }
        let universe = (Int(packet[9]) << 8) | Int(packet[10])
        let frame = Array(packet.dropFirst(11).prefix(512))
        guard frame.count == 512 else { return nil }
        return (universe, frame)
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
    private var universe: Int = 0
    private var onFrame: ((Int, [UInt8]) -> Void)?
    private var lastError: String?
    private var receivedFrameCount: UInt64 = 0

    func configure(
        mode: String,
        universe: Int,
        onFrame: @escaping (Int, [UInt8]) -> Void
    ) {
        self.mode = mode
        self.universe = max(0, universe)
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
        lastError = nil
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
        if socketFD >= 0 {
            Darwin.close(socketFD)
            socketFD = -1
        }
        isRunning = false
    }

    func diagnostics() -> (lastError: String?, running: Bool, frames: UInt64) {
        (lastError: lastError, running: isRunning, frames: receivedFrameCount)
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
        guard let decoded = DMXInboundPacketDecoder.decode(packet: packet, mode: mode) else { return }
        guard decoded.universe == universe else { return }
        receivedFrameCount &+= 1
        onFrame?(decoded.universe, decoded.frame)
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
            let payload = DMXNetworkPacketBuilder.makeSACNPacket(universe: netU, frame: data)
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
            performanceProfiler.recordFrame(buildMS: buildMS, sendMS: sendMS, totalMS: totalMS, budgetMS: 1000.0 / 44.0)
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
        performanceProfiler.recordFrame(buildMS: buildMS, sendMS: sendMS, totalMS: totalMS, budgetMS: 1000.0 / 44.0)
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
        performanceProfiler.snapshot()
    }
}
