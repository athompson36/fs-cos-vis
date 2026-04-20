import Foundation

/// In-memory crossfade between two lighting cues (not persisted).
struct LightingCueCrossfade: Equatable, Sendable {
    var fromIndex: Int?
    var toIndex: Int
    var startedAt: TimeInterval
    var durationSeconds: Double
}

enum LightingCueResolver {
    /// Linear blend between two channel maps; keys union from both.
    static func blendedMap(
        from: [Int: UInt8],
        to: [Int: UInt8],
        progress: Float
    ) -> [Int: UInt8] {
        let t = max(0, min(1, progress))
        var keys = Set(from.keys)
        keys.formUnion(to.keys)
        var out: [Int: UInt8] = [:]
        for ch in keys {
            let a = Float(from[ch] ?? 0)
            let b = Float(to[ch] ?? 0)
            out[ch] = UInt8(a * (1 - t) + b * t)
        }
        return out
    }

    /// Resolves the channel overlay map for one DMX frame.
    static func resolveChannelMap(
        document: LightingCueDocument,
        crossfade: LightingCueCrossfade?,
        now: TimeInterval
    ) -> [Int: UInt8] {
        guard let active = document.activeCueIndex, document.cues.indices.contains(active) else {
            return [:]
        }

        guard let xf = crossfade,
              xf.toIndex == active,
              xf.durationSeconds > 0.0001
        else {
            return document.cues[active].channelMap
        }

        let elapsed = now - xf.startedAt
        if elapsed >= xf.durationSeconds {
            return document.cues[active].channelMap
        }

        let fromMap: [Int: UInt8] = {
            if let fi = xf.fromIndex, document.cues.indices.contains(fi) {
                return document.cues[fi].channelMap
            }
            return [:]
        }()
        let toMap = document.cues[xf.toIndex].channelMap
        let p = Float(elapsed / xf.durationSeconds)
        return blendedMap(from: fromMap, to: toMap, progress: p)
    }
}
