import Foundation

/// Builds a single 512-channel universe from the legacy mapping, fixture patch, active cue, and modulation offsets.
enum DMXUniverseBuilder {
    /// `modulationOffsets` maps channel 1...512 to additive offset in [-1, 1] applied after base byte value.
    /// Single-universe path (USB / compatibility): universe 0 only, same as historical behavior.
    static func build(
        model: AppModel,
        patch: DMXPatchDocument,
        cueChannelMap: [Int: UInt8],
        modulationOffsets: [Int: Float],
        hazeEmergencyKill: Bool = false
    ) -> [UInt8] {
        buildUniverse(
            universe: 0,
            model: model,
            patch: patch,
            cueChannelMap: cueChannelMap,
            modulationOffsets: modulationOffsets,
            hazeEmergencyKill: hazeEmergencyKill
        )
    }

    /// One 512-channel buffer for `universe` (0…255). Legacy slots, cues, modulation, and haze kill apply **only** to universe 0.
    static func buildUniverse(
        universe: Int,
        model: AppModel,
        patch: DMXPatchDocument,
        cueChannelMap: [Int: UInt8],
        modulationOffsets: [Int: Float],
        hazeEmergencyKill: Bool = false
    ) -> [UInt8] {
        var u = [UInt8](repeating: 0, count: 512)

        if universe == 0, patch.useLegacyVisualizationSlots {
            applyLegacyVisualizationMapping(to: &u, model: model)
        }

        let u8 = UInt8(clamping: universe)
        for inst in patch.instances {
            guard inst.universe == u8 else { continue }
            guard let profile = patch.profile(id: inst.profileID) else { continue }
            for (idx, _) in profile.channels.enumerated() {
                let dmxChannel = inst.startAddress + idx
                guard dmxChannel >= 1, dmxChannel <= 512 else { continue }
                let base = Float(inst.manual(forChannelIndex: idx))
                u[dmxChannel - 1] = DMXControlStub.clampChannel(base)
            }
        }

        if universe == 0 {
            for (ch, val) in cueChannelMap {
                guard ch >= 1, ch <= 512 else { continue }
                u[ch - 1] = val
            }

            for ch in 1 ... 512 {
                guard let off = modulationOffsets[ch] else { continue }
                let v = Float(u[ch - 1]) + off * 255
                u[ch - 1] = DMXControlStub.clampChannel(v)
            }

            if hazeEmergencyKill {
                applyHazeEmergencyKill(to: &u, patch: patch)
            }
        }

        return u
    }

    /// Logical universe indices that need output this frame (for Art-Net / sACN multi-universe send).
    static func logicalUniverseIDs(
        patch: DMXPatchDocument,
        cueChannelMap: [Int: UInt8],
        modulationOffsets: [Int: Float],
        hazeEmergencyKill: Bool
    ) -> [Int] {
        var s = Set(patch.instances.map { Int($0.universe) })
        if patch.useLegacyVisualizationSlots { s.insert(0) }
        if !cueChannelMap.isEmpty { s.insert(0) }
        if !modulationOffsets.isEmpty { s.insert(0) }
        if hazeEmergencyKill { s.insert(0) }
        if s.isEmpty { s.insert(0) }
        return s.sorted()
    }

    /// Full map of logical universe → 512 channels (for network transports).
    static func buildPerUniverse(
        model: AppModel,
        patch: DMXPatchDocument,
        cueChannelMap: [Int: UInt8],
        modulationOffsets: [Int: Float],
        hazeEmergencyKill: Bool = false
    ) -> [Int: [UInt8]] {
        var out: [Int: [UInt8]] = [:]
        for id in logicalUniverseIDs(
            patch: patch,
            cueChannelMap: cueChannelMap,
            modulationOffsets: modulationOffsets,
            hazeEmergencyKill: hazeEmergencyKill
        ) {
            out[id] = buildUniverse(
                universe: id,
                model: model,
                patch: patch,
                cueChannelMap: cueChannelMap,
                modulationOffsets: modulationOffsets,
                hazeEmergencyKill: hazeEmergencyKill
            )
        }
        return out
    }

    /// Final override: hazer output and pump to 0 (fan unchanged).
    private static func applyHazeEmergencyKill(to u: inout [UInt8], patch: DMXPatchDocument) {
        for inst in patch.instances {
            guard inst.universe == 0 else { continue }
            guard let profile = patch.profile(id: inst.profileID) else { continue }
            for (idx, def) in profile.channels.enumerated() {
                guard def.role == .hazeOutput || def.role == .hazePump else { continue }
                let dmx = inst.startAddress + idx
                guard dmx >= 1, dmx <= 512 else { continue }
                u[dmx - 1] = 0
            }
        }
    }

    private static func applyLegacyVisualizationMapping(to u: inout [UInt8], model: AppModel) {
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
    }
}
