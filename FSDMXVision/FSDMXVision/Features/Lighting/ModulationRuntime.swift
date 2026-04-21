import Foundation

/// Evaluates modulation definitions into per-channel offsets in [-depth, depth] (additive to 8-bit DMX values).
enum ModulationRuntime {
    static func offsets(
        document: ModulationDocument,
        patch: DMXPatchDocument,
        time: TimeInterval,
        bpm: Double,
        beatPhase: Double,
        audio: AudioFeatures,
        lastSmoothed: inout [UUID: Float]
    ) -> [Int: Float] {
        var out: [Int: Float] = [:]

        for m in document.modulators where m.enabled {
            let d = max(0, min(1, m.depth))

            switch m.kind {
            case .hsiHueSweep:
                guard let rgb = ModulationTargetResolution.rgbDMXChannels(for: m, patch: patch) else { continue }
                let raw: Float = sin(Float(time * Double(m.rateHz) * 2 * .pi))
                let hue = Float((Double(raw) * 0.5 + 0.5) * 360.0)
                let s = max(0, min(1, m.hsiSaturation))
                let v = max(0, min(1, m.hsiIntensity))
                let (rf, gf, bf) = hsvToRgb(hDegrees: hue, s: s, v: v)
                let offR = (rf - 0.5) * 2 * d
                let offG = (gf - 0.5) * 2 * d
                let offB = (bf - 0.5) * 2 * d
                out[rgb.0, default: 0] += offR
                out[rgb.1, default: 0] += offG
                out[rgb.2, default: 0] += offB

            case .lfoSine, .lfoTriangle, .tempoPulse, .audioBandLow, .audioBandMid, .audioBandHigh:
                guard let ch = ModulationTargetResolution.primaryDMXChannel(for: m, patch: patch) else { continue }
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
                case .hsiHueSweep:
                    raw = 0
                }
                let off = raw * d
                out[ch, default: 0] += off
            }
        }

        return out
    }

    /// HSV with hue in degrees 0...360, S/V in 0...1 → RGB 0...1.
    private static func hsvToRgb(hDegrees: Float, s: Float, v: Float) -> (Float, Float, Float) {
        let hh = (hDegrees / 60).truncatingRemainder(dividingBy: 6)
        let i = floor(hh)
        let f = hh - i
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))
        let sector = Int(i) % 6
        switch sector {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }

    private static func smooth(_ v: Float, key: UUID, amount: Float, last: inout [UUID: Float]) -> Float {
        let a = max(0, min(1, amount))
        let prev = last[key] ?? v
        let next = prev * a + v * (1 - a)
        last[key] = next
        return max(0, min(1, next))
    }
}
