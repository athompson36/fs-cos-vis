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
        case "/cosmic/tempo/source":
            guard let raw = stringValue else { return nil }
            return RemoteControlCommand(type: "SetTempoSource", source: raw)
        case "/cosmic/scene/index":
            let idx = intValue ?? Int(floatValue ?? -1)
            guard idx >= 0 else { return nil }
            return RemoteControlCommand(type: "JumpToSceneIndex", index: idx)
        case "/cosmic/fractal/zoom":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetFractalZoom", fractalZoom: v)
        case "/cosmic/liquid/turbulence":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetLiquidTurbulence", liquidTurbulence: v)
        case "/cosmic/liquid/focus":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetLiquidFocus", liquidFocus: v)
        case "/cosmic/fractal/appearance":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetFractalAppearance", fractalAppearance: v)
        case "/cosmic/fractal/overlay_fusion":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetOverlayFractalFusion", overlayFractalFusion: v)
        case "/cosmic/fractal/explore":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetFractalExplore", fractalExplore: v)
        case "/cosmic/fractal/explore_speed":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetFractalExploreSpeed", fractalExploreSpeed: v)
        case "/cosmic/fractal/iter_boost":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetFractalIterBoost", fractalIterBoost: v)
        case "/cosmic/fractal/zoom_effect":
            let idx = intValue ?? Int(floatValue ?? -1)
            guard (0 ... 2).contains(idx) else { return nil }
            return RemoteControlCommand(type: "SetZoomEffectType", index: idx)
        case "/cosmic/liquid/reconstitute_amount":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetLiquidReconstituteAmount", liquidReconstituteAmount: v)
        case "/cosmic/liquid/reconstitute_rate":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetLiquidReconstituteRate", liquidReconstituteRate: v)
        case "/cosmic/liquid/reconstitute_bpm_sync":
            return RemoteControlCommand(type: "SetLiquidReconstituteBPMSync", enabled: boolValue)
        case "/cosmic/liquid/dye_mix":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetDyeMix", dyeMix: v)
        case "/cosmic/fractal/smooth_shading":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetFractalSmoothShading", fractalSmoothShading: v)
        case "/cosmic/composite/bloom":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetCompositeBloomStrength", compositeBloomStrength: v)
        case "/cosmic/composite/vignette":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetCompositeVignetteStrength", compositeVignetteStrength: v)
        case "/cosmic/composite/blend":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetCompositeBlend", compositeBlend: v)
        case "/cosmic/composite/spectrum_warp":
            guard let v = floatValue else { return nil }
            return RemoteControlCommand(type: "SetSpectrumWarpAmount", spectrumWarpAmount: max(0, min(1, v)))
        case "/cosmic/fractal/geometry":
            let idx = intValue ?? Int(floatValue ?? -1)
            guard (0 ... 6).contains(idx) else { return nil }
            return RemoteControlCommand(type: "SetFractalGeometryIndex", index: idx)
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
        case "/cosmic/lighting/cue/next":
            return RemoteControlCommand(type: "NextLightingCue")
        case "/cosmic/lighting/cue/previous":
            return RemoteControlCommand(type: "PreviousLightingCue")
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
    /// Queue that owns socket read callbacks; UDP replies hop here after snapshot work on the main queue (avoids `main.sync` deadlocks).
    private var socketEventQueue: DispatchQueue?
    private var requiredToken = ""
    private var onCommand: (@Sendable (RemoteControlCommand) -> Void)?
    private var onStateQuery: (@Sendable () -> String)?

    /// - Returns: `(errorMessage, effectiveUDPPort)` — error is `nil` when listening on `effectiveUDPPort` (may differ from the requested port if it was busy).
    func configure(
        port: Int,
        bindLAN: Bool,
        requiredToken: String,
        onCommand: @escaping @Sendable (RemoteControlCommand) -> Void,
        onStateQuery: @escaping @Sendable () -> String
    ) -> (String?, Int) {
        stop()
        self.requiredToken = requiredToken
        self.onCommand = onCommand
        self.onStateQuery = onStateQuery

        // Fail-safe: don't accept OSC from the LAN (INADDR_ANY) without a token, or any sender
        // could drive the app. Fall back to loopback until an OSC token is configured.
        let effectiveBindLAN = bindLAN && !requiredToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let requestedBase = max(1024, min(65_535, port))
        for offset in 0 ..< ControlPlanePortBinding.defaultScanAttempts {
            let candidate = requestedBase + offset
            guard candidate <= 65_535 else { break }

            socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard socketFD >= 0 else {
                return ("OSC socket open failed.", requestedBase)
            }

            let yes: Int32 = 1
            _ = withUnsafePointer(to: yes) {
                setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, $0, socklen_t(MemoryLayout<Int32>.size))
            }

            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = CFSwapInt16HostToBig(UInt16(candidate))
            addr.sin_addr.s_addr = effectiveBindLAN ? INADDR_ANY.bigEndian : inet_addr("127.0.0.1")

            let bindResult = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    bind(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if bindResult == 0 {
                start()
                return (nil, candidate)
            }
            stop()
        }
        return ("OSC: could not bind UDP (tried \(requestedBase)–\(min(65_535, requestedBase + ControlPlanePortBinding.defaultScanAttempts - 1))).", requestedBase)
    }

    func start() {
        guard !isRunning, socketFD >= 0 else { return }
        let queue = DispatchQueue(label: "com.fsdmxvision.osc", qos: .userInitiated)
        socketEventQueue = queue
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
        socketEventQueue = nil
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
        guard OSCControlBusStub.isStateQuery(line, requiredToken: requiredToken) else { return }
        let destAddrCopy = srcAddr
        let destLenCopy = srcLen
        let onQuery = onStateQuery
        let sendQueue = socketEventQueue
        let fdSnapshot = socketFD
        Task { @Sendable in
            let json = await MainActor.run {
                onQuery?() ?? "{}"
            }
            guard let payload = json.data(using: .utf8),
                  let q = sendQueue
            else { return }
            let fdSend = fdSnapshot
            guard fdSend >= 0 else { return }
            q.async {
                guard fdSend >= 0 else { return }
                Self.sendOSCUDPReply(fd: fdSend, payload: payload, dest: destAddrCopy, destLen: destLenCopy)
            }
        }
    }

    private static func sendOSCUDPReply(fd: Int32, payload: Data, dest: sockaddr_storage, destLen: socklen_t) {
        var mutableDest = dest
        _ = withUnsafePointer(to: &mutableDest) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                sendto(fd, (payload as NSData).bytes, payload.count, 0, sockaddrPtr, destLen)
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
