import Foundation

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
        if mode != "simulated" {
            let path = model.remoteSettings.dmxSerialDevicePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return }
        }

        let t = CFAbsoluteTimeGetCurrent()
        universe = model.buildDMXUniverse(time: t, lastSmoothed: &modulationLastSmoothed)

        do {
            let transport = try resolveTransport(model: model)
            try transport.prepare(with: model)
            try transport.send(universe: universe)
            transportInfo = transport.diagnosticsLabel
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
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
    func extendedDiagnostics() -> (lastError: String?, running: Bool, nominalHz: Double) {
        (lastError, isRunning, 44.0)
    }

    func simulationSnapshot() -> (mode: String, info: String, universe: [UInt8])? {
        guard let mock = transport as? MockOpenDMXTransport else { return nil }
        return (mode: "simulated", info: mock.diagnosticsLabel, universe: mock.lastUniverse)
    }
}
