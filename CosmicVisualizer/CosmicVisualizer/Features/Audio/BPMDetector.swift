import Foundation

/// Onset-driven tempo estimate from a spectral-flux stream (or any positive onset strength scalar per hop).
final class BPMDetector {
    private let clock: () -> TimeInterval
    private let fluxSmoothing: Float = 0.92
    private let onsetThresholdFactor: Float = 1.65
    private let refractorySeconds: TimeInterval = 0.18
    private let maxIntervals = 10

    private var fluxEMA: Float = 0
    private var lastFlux: Float = 0
    private var lastOnsetTime: TimeInterval?
    private var intervals: [TimeInterval] = []
    private var smoothedBPM: Double = 0

    /// - Parameter clock: Monotonic seconds; inject a fake in tests.
    init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.clock = clock
    }

    func reset() {
        fluxEMA = 0
        lastFlux = 0
        lastOnsetTime = nil
        intervals.removeAll()
        smoothedBPM = 0
    }

    /// Feed one analysis hop. Returns smoothed BPM and confidence in `[0, 1]`.
    func ingest(spectralFlux: Float) -> (bpm: Double, confidence: Double) {
        fluxEMA = fluxSmoothing * fluxEMA + (1 - fluxSmoothing) * spectralFlux
        let threshold = max(1e-5, fluxEMA * onsetThresholdFactor)

        let rising = spectralFlux > lastFlux
        let strong = spectralFlux > threshold
        lastFlux = spectralFlux

        let now = clock()
        if strong, rising {
            if let last = lastOnsetTime {
                let dt = now - last
                if dt >= refractorySeconds {
                    intervals.append(dt)
                    if intervals.count > maxIntervals { intervals.removeFirst() }
                    lastOnsetTime = now
                }
            } else {
                lastOnsetTime = now
            }
        }

        guard intervals.count >= 2 else {
            return (smoothedBPM > 0 ? smoothedBPM : 0, 0)
        }

        let bpms = intervals.map { 60.0 / $0 }.sorted()
        let median = bpms[bpms.count / 2]
        let mean = bpms.reduce(0, +) / Double(bpms.count)
        let variance = bpms.map { pow($0 - mean, 2) }.reduce(0, +) / Double(bpms.count)
        let std = sqrt(variance)
        let confidence = max(0, min(1, 1 - Double(std) / max(mean, 40)))
        let raw = clampBPM(median)
        if smoothedBPM == 0 {
            smoothedBPM = raw
        } else {
            smoothedBPM = smoothedBPM * 0.82 + raw * 0.18
        }
        smoothedBPM = clampBPM(smoothedBPM)
        return (smoothedBPM, confidence)
    }

    private func clampBPM(_ value: Double) -> Double {
        min(220, max(40, value))
    }
}
