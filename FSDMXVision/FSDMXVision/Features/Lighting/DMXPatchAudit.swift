import Foundation

/// Static checks on a DMX patch (universe 0, single-universe USB path).
enum DMXPatchAudit {
    /// Human-readable lines for channels claimed by more than one patched fixture (universe 0 only).
    static func universeZeroConflictMessages(patch: DMXPatchDocument) -> [String] {
        var occupant: [Int: [UUID]] = [:]
        for inst in patch.instances {
            guard inst.universe == 0 else { continue }
            guard let profile = patch.profile(id: inst.profileID) else { continue }
            for idx in profile.channels.indices {
                let dmx = inst.startAddress + idx
                guard dmx >= 1, dmx <= 512 else { continue }
                occupant[dmx, default: []].append(inst.id)
            }
        }
        var lines: [String] = []
        for ch in occupant.keys.sorted() where Set(occupant[ch]!).count > 1 {
            let ids = Array(Set(occupant[ch]!))
            let labels = ids.map { fixtureLabel(patch: patch, instanceID: $0) }.sorted()
            lines.append("Channel \(ch): \(labels.joined(separator: " · "))")
        }
        return lines
    }

    /// Resolves a DMX channel (1…512) to a patched fixture and profile channel index (universe 0 only).
    static func fixtureAndProfileIndex(forDMXChannel channel: Int, patch: DMXPatchDocument) -> (instance: FixtureInstance, channelIndex: Int)? {
        guard channel >= 1, channel <= 512 else { return nil }
        for inst in patch.instances {
            guard inst.universe == 0 else { continue }
            guard let profile = patch.profile(id: inst.profileID) else { continue }
            for idx in profile.channels.indices {
                if inst.startAddress + idx == channel {
                    return (inst, idx)
                }
            }
        }
        return nil
    }

    private static func fixtureLabel(patch: DMXPatchDocument, instanceID: UUID) -> String {
        guard let idx = patch.instances.firstIndex(where: { $0.id == instanceID }) else {
            return String(instanceID.uuidString.prefix(8))
        }
        let inst = patch.instances[idx]
        let name = patch.profile(id: inst.profileID)?.name ?? "Profile"
        return "\(name) #\(idx + 1)"
    }
}
