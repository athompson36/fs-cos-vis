import Foundation

/// Maps a subset of live parameters into a single DMX universe and pushes frames at ~44 Hz.
final class DMXOutputService: ControlBus {
    private weak var model: AppModel?
    private let writer = OpenDMXUSBWriter()
    private var timer: DispatchSourceTimer?
    private(set) var isRunning = false
    private var universe = [UInt8](repeating: 0, count: 512)
    private var lastError: String?

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

        universe = DMXOutputService.buildUniverse(from: model)

        do {
            try writer.ensureOpen(path: path)
            try writer.send(universe: universe)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    static func buildUniverse(from model: AppModel) -> [UInt8] {
        var u = [UInt8](repeating: 0, count: 512)
        let idx = min(max(0, model.sceneManager.currentIndex), 255)
        u[0] = UInt8(idx)
        let sceneID = model.sceneManager.scenes.indices.contains(model.sceneManager.currentIndex)
            ? model.sceneManager.scenes[model.sceneManager.currentIndex].id
            : nil
        let edit = sceneID.flatMap { model.sceneEditStates[$0] } ?? SceneEditState()
        u[1] = DMXControlStub.clampChannel(edit.layer.fractalZoom * 100)
        u[2] = DMXControlStub.clampChannel(edit.layer.liquidTurbulence * 80)
        u[3] = DMXControlStub.clampChannel(edit.layer.compositeBlend * 255)
        let bpm = min(255, max(0, Int(model.tempoClock.effectiveBPM.rounded())))
        u[4] = UInt8(bpm)
        return u
    }

    func diagnostics() -> (lastError: String?, running: Bool) {
        (lastError, isRunning)
    }

    /// Nominal frame rate (timer interval); adapters may vary.
    func extendedDiagnostics() -> (lastError: String?, running: Bool, nominalHz: Double) {
        (lastError, isRunning, 44.0)
    }
}
