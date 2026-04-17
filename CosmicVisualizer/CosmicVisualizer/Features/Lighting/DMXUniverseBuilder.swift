import Foundation

/// Builds a single 512-channel universe from the legacy mapping, fixture patch, active cue, and modulation offsets.
enum DMXUniverseBuilder {
    /// `modulationOffsets` maps channel 1...512 to additive offset in [-1, 1] applied after base byte value.
    static func build(
        model: AppModel,
        patch: DMXPatchDocument,
        cueChannelMap: [Int: UInt8],
        modulationOffsets: [Int: Float]
    ) -> [UInt8] {
        var u = [UInt8](repeating: 0, count: 512)

        if patch.useLegacyVisualizationSlots {
            applyLegacyVisualizationMapping(to: &u, model: model)
        }

        for inst in patch.instances {
            guard inst.universe == 0 else { continue }
            guard let profile = patch.profile(id: inst.profileID) else { continue }
            for (idx, _) in profile.channels.enumerated() {
                let dmxChannel = inst.startAddress + idx
                guard dmxChannel >= 1, dmxChannel <= 512 else { continue }
                let base = Float(inst.manual(forChannelIndex: idx))
                u[dmxChannel - 1] = DMXControlStub.clampChannel(base)
            }
        }

        for (ch, val) in cueChannelMap {
            guard ch >= 1, ch <= 512 else { continue }
            u[ch - 1] = val
        }

        for ch in 1 ... 512 {
            guard let off = modulationOffsets[ch] else { continue }
            let v = Float(u[ch - 1]) + off * 255
            u[ch - 1] = DMXControlStub.clampChannel(v)
        }

        return u
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
