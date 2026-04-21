import Foundation

/// Resolves modulator targets from patch + optional stored fixture/channel index (stable when addresses move).
enum ModulationTargetResolution {
    /// Absolute DMX channel 1...512 for single-channel modulation kinds.
    static func primaryDMXChannel(for mod: ModulatorDefinition, patch: DMXPatchDocument) -> Int? {
        if mod.kind == .hsiHueSweep {
            return nil
        }
        if let fid = mod.targetFixtureInstanceID, let ci = mod.targetChannelIndexInProfile,
           let inst = patch.instances.first(where: { $0.id == fid }),
           let profile = patch.profile(id: inst.profileID),
           profile.channels.indices.contains(ci)
        {
            let dmx = inst.startAddress + ci
            guard dmx >= 1, dmx <= 512 else { return nil }
            return dmx
        }
        guard mod.targetChannel >= 1, mod.targetChannel <= 512 else { return nil }
        return mod.targetChannel
    }

    /// DMX channels for R,G,B when the profile defines those roles.
    static func rgbDMXChannels(for mod: ModulatorDefinition, patch: DMXPatchDocument) -> (Int, Int, Int)? {
        guard mod.kind == .hsiHueSweep,
              let fid = mod.targetFixtureInstanceID,
              let inst = patch.instances.first(where: { $0.id == fid }),
              let profile = patch.profile(id: inst.profileID)
        else { return nil }
        guard let ri = profile.channels.firstIndex(where: { $0.role == .red }),
              let gi = profile.channels.firstIndex(where: { $0.role == .green }),
              let bi = profile.channels.firstIndex(where: { $0.role == .blue })
        else { return nil }
        let r = inst.startAddress + ri
        let g = inst.startAddress + gi
        let b = inst.startAddress + bi
        guard r >= 1, r <= 512, g >= 1, g <= 512, b >= 1, b <= 512 else { return nil }
        return (r, g, b)
    }

    /// Updates stored fixture fields when the operator picks a raw DMX channel (legacy / advanced).
    static func syncFixtureFieldsFromAbsoluteChannel(mod: inout ModulatorDefinition, patch: DMXPatchDocument) {
        guard mod.kind != .hsiHueSweep,
              let m = DMXPatchAudit.fixtureAndProfileIndex(forDMXChannel: mod.targetChannel, patch: patch)
        else {
            if mod.kind != .hsiHueSweep {
                mod.targetFixtureInstanceID = nil
                mod.targetChannelIndexInProfile = nil
            }
            return
        }
        mod.targetFixtureInstanceID = m.instance.id
        mod.targetChannelIndexInProfile = m.channelIndex
    }
}
