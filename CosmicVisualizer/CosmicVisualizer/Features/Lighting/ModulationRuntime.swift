import Foundation

/// Evaluates modulation definitions into per-channel offsets in [-depth, depth].
enum ModulationRuntime {
    static func offsets(
        document: ModulationDocument,
        time: TimeInterval,
        bpm: Double,
        beatPhase: Double,
        audio: AudioFeatures,
        lastSmoothed: inout [UUID: Float]
    ) -> [Int: Float] {
        var out: [Int: Float] = [:]

        for m in document.modulators where m.enabled {
            guard m.targetChannel >= 1, m.targetChannel <= 512 else { continue }
            let d = max(0, min(1, m.depth))
            var raw: Float = 0

            switch m.kind {
            case .lfoSine:
                raw = sin(Float(time * Double(m.rateHz) * 2 * .pi))
            case .lfoTriangle:
                let p = Float(time * Double(m.rateHz))
                let f = p - floor(p)
                raw = f < 0.5 ? (f * 4 - 1) : (3 - f * 4)
            case .tempoPulse:
                let div = max(0.25, m.tempoDivisions)
                let phase = Float(beatPhase) * div * 2 * Float.pi
                raw = sin(phase)
            case .audioBandLow:
                raw = smooth(audio.lowBandEnergy, key: m.id, amount: m.smoothing, last: &lastSmoothed) * 2 - 1
            case .audioBandMid:
                raw = smooth(audio.midBandEnergy, key: m.id, amount: m.smoothing, last: &lastSmoothed) * 2 - 1
            case .audioBandHigh:
                raw = smooth(audio.highBandEnergy, key: m.id, amount: m.smoothing, last: &lastSmoothed) * 2 - 1
            }

            let off = raw * d
            out[m.targetChannel, default: 0] += off
        }

        return out
    }

    private static func smooth(_ v: Float, key: UUID, amount: Float, last: inout [UUID: Float]) -> Float {
        let a = max(0, min(1, amount))
        let prev = last[key] ?? v
        let next = prev * a + v * (1 - a)
        last[key] = next
        return max(0, min(1, next))
    }
}
