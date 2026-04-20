import Foundation

struct CalibrationSample: Codable, Equatable, Sendable {
    var fixtureId: UUID
    var channelIndex: Int
    var dmxValue: UInt8
    /// Normalized observed screen luma 0...1 from webcam heuristic.
    var observedLuma: Double
}

struct CalibrationDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var updatedAt: Date
    var notes: String
    var samples: [CalibrationSample]

    init(version: Int = currentVersion, updatedAt: Date = Date(), notes: String = "", samples: [CalibrationSample] = []) {
        self.version = version
        self.updatedAt = updatedAt
        self.notes = notes
        self.samples = samples
    }
}

/// Steps DMX manual values while sampling webcam luma; **not** for audience-facing shows.
@MainActor
final class DMXSweepCalibrationService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var progress: String = ""

    private var task: Task<Void, Never>?

    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
        progress = ""
    }

    /// Sweeps first channels of the first fixture (v1 scope); writes `context/calibration.json`.
    func runSweep(
        model: AppModel,
        webcam: WebcamCaptureService,
        outputFolder: URL,
        stepHz: Double = 1.0
    ) {
        cancel()
        isRunning = true
        progress = "Starting…"
        task = Task { @MainActor in
            do {
                try await webcam.startIfAuthorized()
            } catch {
                self.isRunning = false
                self.progress = "Camera error: \(error.localizedDescription)"
                return
            }
            defer { webcam.stop() }

            let interval = max(0.25, min(2.0, 1.0 / stepHz))
            var samples: [CalibrationSample] = []
            let patch = model.dmxPatchDocument
            guard let inst = patch.instances.first,
                  let profile = patch.profile(id: inst.profileID)
            else {
                self.isRunning = false
                self.progress = "No fixtures to sweep."
                return
            }
            let chCount = min(profile.channels.count, 8)
            for ch in 0 ..< chCount {
                if Task.isCancelled { break }
                for step in stride(from: 0, through: 255, by: 32) {
                    if Task.isCancelled { break }
                    let v = UInt8(step)
                    var doc = model.dmxPatchDocument
                    guard let idx = doc.instances.firstIndex(where: { $0.id == inst.id }) else { break }
                    doc.instances[idx].setManual(channelIndex: ch, value: v)
                    model.applyDMXPatchDocument(doc)
                    self.progress = "Fixture \(inst.id.uuidString.prefix(6)) ch \(ch) = \(v)"
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    let lum = webcam.latestSampleLuma
                    samples.append(CalibrationSample(fixtureId: inst.id, channelIndex: ch, dmxValue: v, observedLuma: lum))
                }
            }
            let doc = CalibrationDocument(samples: samples)
            let data = try? JSONEncoder().encode(doc)
            let ctx = outputFolder.appendingPathComponent("context", isDirectory: true)
            try? FileManager.default.createDirectory(at: ctx, withIntermediateDirectories: true)
            if let data {
                try? data.write(to: ctx.appendingPathComponent(ShowContextDiskLayout.calibrationFilename), options: .atomic)
            }
            self.isRunning = false
            self.progress = "Saved \(samples.count) samples."
            model.exportAIContextNow(targetRoot: outputFolder)
        }
    }
}
