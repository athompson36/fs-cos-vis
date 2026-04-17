import Foundation

/// Future-facing control surface (MIDI, OSC, DMX). Stubs keep wiring testable without hardware.
protocol ControlBus: AnyObject {
    var isRunning: Bool { get }
    func start()
    func stop()
}

final class MIDIControlBusStub: ControlBus {
    private(set) var isRunning = false

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}

final class OSCControlBusStub: ControlBus {
    private(set) var isRunning = false

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    /// Parses `/cosmic/bpm f 128.5` style messages (whitespace-separated).
    static func parseSimpleMessage(_ line: String) -> (address: String, floatValue: Float)? {
        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 3, parts[1] == "f", let value = Float(parts[2]) else { return nil }
        let addr = parts[0]
        guard addr.hasPrefix("/") else { return nil }
        return (addr, value)
    }

    static func parseCommand(_ line: String, requiredToken: String = "") -> RemoteControlCommand? {
        var parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !parts.isEmpty else { return nil }

        let trimmedToken = requiredToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedToken.isEmpty {
            guard let tokenPartIndex = parts.firstIndex(where: { $0.hasPrefix("token=") }) else { return nil }
            let tokenValue = String(parts[tokenPartIndex].dropFirst("token=".count))
            guard tokenValue == trimmedToken else { return nil }
            parts.remove(at: tokenPartIndex)
            guard !parts.isEmpty else { return nil }
        }

        let addr = parts[0]
        guard addr.hasPrefix("/") else { return nil }
        let floatValue: Float? = {
            guard parts.count >= 3, parts[1] == "f" else { return nil }
            return Float(parts[2])
        }()
        let intValue: Int? = {
            guard parts.count >= 3, parts[1] == "i" else { return nil }
            return Int(parts[2])
        }()
        let stringValue: String? = {
            guard parts.count >= 2 else { return nil }
            if parts.count >= 3, (parts[1] == "f" || parts[1] == "i" || parts[1] == "s") {
                return parts[2]
            }
            return parts[1]
        }()
        let boolValue = (floatValue ?? 0) >= 0.5

        switch addr {
        case "/cosmic/scene/next":
            return RemoteControlCommand(type: "NextScene")
        case "/cosmic/scene/previous":
            return RemoteControlCommand(type: "PreviousScene")
        case "/cosmic/scene/random":
            return RemoteControlCommand(type: "RandomScene")
        case "/cosmic/tempo/tap":
            return RemoteControlCommand(type: "TapTempo")
        case "/cosmic/tempo/bpm":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetManualBPM", bpm: Double(v))
        case "/cosmic/fractal/zoom":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetFractalZoom", fractalZoom: v)
        case "/cosmic/liquid/turbulence":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetLiquidTurbulence", liquidTurbulence: v)
        case "/cosmic/composite/blend":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetCompositeBlend", compositeBlend: v)
        case "/cosmic/overlay/enabled":
            return RemoteControlCommand(type: "SetOverlayEnabled", enabled: boolValue)
        case "/cosmic/liquid/enabled":
            return RemoteControlCommand(type: "SetLiquidLightEnabled", enabled: boolValue)
        case "/cosmic/performance/enabled":
            return RemoteControlCommand(type: "SetPerformanceMode", enabled: boolValue)
        case "/cosmic/scene/jump":
            guard let raw = stringValue, let id = UUID(uuidString: raw) else { return nil }
            return RemoteControlCommand(type: "JumpToScene", sceneID: id)
        case "/cosmic/palette/select":
            guard let raw = stringValue, let id = UUID(uuidString: raw) else { return nil }
            return RemoteControlCommand(type: "SetSelectedPalette", paletteID: id)
        case "/cosmic/lighting/cue/index":
            let idx = intValue ?? Int(floatValue ?? -1)
            guard idx >= 0 else { return nil }
            return RemoteControlCommand(type: "SetActiveLightingCueIndex", index: idx)
        case "/cosmic/recording/start":
            return RemoteControlCommand(type: "StartLiveOutputRecording")
        case "/cosmic/recording/stop":
            return RemoteControlCommand(type: "StopLiveOutputRecording")
        case "/cosmic/recording/source":
            guard let raw = stringValue else { return nil }
            return RemoteControlCommand(type: "SetLiveOutputRecordingSource", source: raw)
        case "/cosmic/recording/quality":
            guard let raw = stringValue else { return nil }
            return RemoteControlCommand(type: "SetLiveOutputRecordingQualityPreset", source: raw)
        default:
            return nil
        }
    }

    static func isStateQuery(_ line: String, requiredToken: String = "") -> Bool {
        var parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !parts.isEmpty else { return false }
        let trimmedToken = requiredToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedToken.isEmpty {
            guard let tokenPartIndex = parts.firstIndex(where: { $0.hasPrefix("token=") }) else { return false }
            let tokenValue = String(parts[tokenPartIndex].dropFirst("token=".count))
            guard tokenValue == trimmedToken else { return false }
            parts.remove(at: tokenPartIndex)
            guard !parts.isEmpty else { return false }
        }
        return parts[0] == "/cosmic/state/get"
    }
}

final class OSCControlService: ControlBus {
    private(set) var isRunning = false
    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var requiredToken = ""
    private var onCommand: ((RemoteControlCommand) -> Void)?
    private var onStateQuery: (() -> String)?

    func configure(
        port: Int,
        bindLAN: Bool,
        requiredToken: String,
        onCommand: @escaping (RemoteControlCommand) -> Void,
        onStateQuery: @escaping () -> String
    ) -> String? {
        stop()
        self.requiredToken = requiredToken
        self.onCommand = onCommand
        self.onStateQuery = onStateQuery

        socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            return "OSC socket open failed."
        }

        let yes: Int32 = 1
        _ = withUnsafePointer(to: yes) {
            setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, $0, socklen_t(MemoryLayout<Int32>.size))
        }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(UInt16(clamping: max(1024, port)))
        addr.sin_addr.s_addr = bindLAN ? INADDR_ANY.bigEndian : inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            stop()
            return "OSC bind failed on port \(port)."
        }
        start()
        return nil
    }

    func start() {
        guard !isRunning, socketFD >= 0 else { return }
        let queue = DispatchQueue(label: "com.cosmicvisualizer.osc", qos: .userInitiated)
        let source = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.handleReadable()
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
        readSource?.cancel()
        readSource = nil
        if socketFD >= 0 {
            Darwin.close(socketFD)
            socketFD = -1
        }
        isRunning = false
    }

    private func handleReadable() {
        guard socketFD >= 0 else { return }
        var buffer = [UInt8](repeating: 0, count: 2048)
        var srcAddr = sockaddr_storage()
        var srcLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let readLen = withUnsafeMutablePointer(to: &srcAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                recvfrom(socketFD, &buffer, buffer.count, 0, sockaddrPtr, &srcLen)
            }
        }
        guard readLen > 0 else { return }
        let data = Data(buffer.prefix(readLen))
        guard let line = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }
        if let cmd = OSCControlBusStub.parseCommand(line, requiredToken: requiredToken) {
            onCommand?(cmd)
            return
        }
        guard OSCControlBusStub.isStateQuery(line, requiredToken: requiredToken),
              let payload = onStateQuery?().data(using: .utf8)
        else { return }
        _ = withUnsafePointer(to: &srcAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                sendto(socketFD, (payload as NSData).bytes, payload.count, 0, sockaddrPtr, srcLen)
            }
        }
    }
}

/// Placeholder for DMX channel mapping — no I/O yet.
final class DMXControlStub: ControlBus {
    private(set) var isRunning = false

    func start() { isRunning = true }
    func stop() { isRunning = false }

    static func clampChannel(_ v: Float) -> UInt8 {
        UInt8(max(0, min(255, v)))
    }
}
