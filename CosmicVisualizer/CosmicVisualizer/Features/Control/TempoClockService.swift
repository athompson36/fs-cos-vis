import Combine
import Foundation

/// Drives effective tempo and beat phase for visuals from audio detection, manual BPM, tap, or MIDI clock.
final class TempoClockService: ObservableObject {
    enum SyncSource: String, Codable, CaseIterable, Sendable {
        case audioDetection
        case manual
        case tapTempo
        case midiClock
    }

    @Published private(set) var syncSource: SyncSource = .audioDetection
    @Published private(set) var effectiveBPM: Double = 0
    ///0...1 within a quarter-note beat (24 MIDI ticks = one quarter when using MIDI clock).
    @Published private(set) var beatPhase: Double = 0
    @Published private(set) var midiClockRunning: Bool = false
    @Published var manualBPM: Double = 120 {
        didSet { if syncSource == .manual { recomputeEffective() } }
    }

    private var detectedBPM: Double = 0
    private var detectedConfidence: Double = 0

    private var tapTimes: [TimeInterval] = []
    private let tapSmoothingCount = 6
    private let clock = { ProcessInfo.processInfo.systemUptime }

    private var midiTickCount: Int = 0
    private var lastQuarterTime: TimeInterval?
    /// BPM inferred from tap intervals or MIDI quarter-note spacing.
    private var intervalDerivedBPM: Double = 0

    func setSyncSource(_ source: SyncSource) {
        syncSource = source
        if source != .midiClock {
            midiClockRunning = false
            midiTickCount = 0
            lastQuarterTime = nil
        }
        recomputeEffective()
    }

    func ingestAudioDetection(bpm: Float, confidence: Float) {
        detectedBPM = Double(bpm)
        detectedConfidence = Double(confidence)
        if syncSource == .audioDetection {
            recomputeEffective()
        }
    }

    func tap() {
        let t = clock()
        tapTimes.append(t)
        if tapTimes.count > tapSmoothingCount { tapTimes.removeFirst() }
        guard tapTimes.count >= 2 else { return }
        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0 - $1 }
        let sorted = intervals.sorted()
        let median = sorted[sorted.count / 2]
        guard median > 0.12, median < 2.5 else { return }
        let tapped = 60.0 / median
        intervalDerivedBPM = min(220, max(40, tapped))
        if syncSource == .tapTempo {
            recomputeEffective()
        }
    }

    /// Switches sync to tap and records this tap (live performance).
    func tapTempoFromLiveControl() {
        syncSource = .tapTempo
        tap()
        recomputeEffective()
    }

    func ingestMIDIClockTick() {
        let t = clock()
        midiTickCount += 1
        if midiTickCount >= 24 {
            midiTickCount = 0
            if let last = lastQuarterTime {
                let dt = t - last
                if dt > 0.05, dt < 2.0 {
                    intervalDerivedBPM = min(220, max(40, 60.0 / dt))
                }
            }
            lastQuarterTime = t
            beatPhase = 0
        } else {
            beatPhase = Double(midiTickCount) / 24.0
        }
        midiClockRunning = true
        if syncSource == .midiClock {
            recomputeEffective()
        }
    }

    func midiTransportStart() {
        midiTickCount = 0
        lastQuarterTime = clock()
        midiClockRunning = true
        beatPhase = 0
    }

    func midiTransportStop() {
        midiClockRunning = false
        midiTickCount = 0
        lastQuarterTime = nil
    }

    func midiTransportContinue() {
        midiClockRunning = true
    }

    /// Advances beat phase when not using MIDI clock (audio/manual/tap) from effective BPM.
    func advanceBeatPhaseIfNeeded(deltaTime: TimeInterval) {
        guard syncSource != .midiClock || !midiClockRunning else { return }
        let bpm = effectiveBPM
        guard bpm > 1 else { return }
        let beatsPerSec = bpm / 60.0
        beatPhase = (beatPhase + deltaTime * beatsPerSec).truncatingRemainder(dividingBy: 1)
    }

    private func recomputeEffective() {
        switch syncSource {
        case .audioDetection:
            effectiveBPM = detectedBPM
        case .manual:
            effectiveBPM = min(220, max(40, manualBPM))
        case .tapTempo:
            effectiveBPM = intervalDerivedBPM > 0 ? intervalDerivedBPM : detectedBPM
        case .midiClock:
            effectiveBPM = intervalDerivedBPM > 0 ? intervalDerivedBPM : detectedBPM
        }
        objectWillChange.send()
    }

    /// Beat pulse0...1 for shaders (combines phase with confidence when from audio).
    func shaderBeatPulse(audioConfidence: Float) -> Float {
        let phasePulse = Float(0.5 + 0.5 * sin(beatPhase * .pi * 2))
        switch syncSource {
        case .audioDetection:
            return min(1, Float(detectedConfidence) * 1.1 + phasePulse * 0.35)
        default:
            return min(1, phasePulse * 0.85 + 0.15)
        }
    }

    var displayConfidence: Double {
        syncSource == .audioDetection ? detectedConfidence : (midiClockRunning ? 1.0 : 0.75)
    }
}
