import Foundation

/// Maps a subset of live parameters into a single DMX universe and pushes frames at ~44 Hz.
final class DMXOutputService: ControlBus {
    private weak var model: AppModel?
    private let writer = OpenDMXUSBWriter()
    private var timer: DispatchSourceTimer?
    private(set) var isRunning = false
    private var universe = [UInt8](repeating: 0, count: 512)
    private var lastError: String?
    private var modulationLastSmoothed: [UUID: Float] = [:]

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
        writer.close()
        isRunning = false
    }

    private func tick() {
        guard let model else { return }
        guard model.remoteSettings.dmxOutputEnabled else { return }
        let path = model.remoteSettings.dmxSerialDevicePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }

        let t = CFAbsoluteTimeGetCurrent()
        universe = model.buildDMXUniverse(time: t, lastSmoothed: &modulationLastSmoothed)

        do {
            try writer.ensureOpen(path: path)
            try writer.send(universe: universe)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func diagnostics() -> (lastError: String?, running: Bool) {
        (lastError, isRunning)
    }

    /// Nominal frame rate (timer interval); adapters may vary.
    func extendedDiagnostics() -> (lastError: String?, running: Bool, nominalHz: Double) {
        (lastError, isRunning, 44.0)
    }
}
