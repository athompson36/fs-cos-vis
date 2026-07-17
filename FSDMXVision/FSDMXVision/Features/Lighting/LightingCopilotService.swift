import Foundation

/// Feature-scoped assistant (v1: local heuristics; swap for LLM + JSON schema later).
final class LightingCopilotService: Sendable {
    init() {}

    /// Greedy gap-filling addresses for new fixtures (single universe, no overlap check against profile width in v1).
    /// `excludingInstanceIDs` omits those fixtures from occupancy (e.g. when relocating one fixture).
    func suggestNextAddresses(
        patch: DMXPatchDocument,
        profile: FixtureProfile,
        count: Int,
        excludingInstanceIDs: Set<UUID> = []
    ) -> [Int] {
        let width = max(1, profile.channels.count)
        var used = Set<Int>()
        for inst in patch.instances {
            if excludingInstanceIDs.contains(inst.id) { continue }
            for i in 0 ..< (patch.profile(id: inst.profileID)?.channels.count ?? 1) {
                used.insert(inst.startAddress + i)
            }
        }
        var results: [Int] = []
        var candidate = 1
        while results.count < count, candidate + width - 1 <= 512 {
            let span = candidate ..< (candidate + width)
            if span.allSatisfy({ !used.contains($0) }) {
                results.append(candidate)
                candidate += width + 1
            } else {
                candidate += 1
            }
        }
        return results
    }

    /// Draft cue list from simple song sections placeholder (structure for future ML).
    func draftCuesFromSongStructurePlaceholder(sectionCount: Int) -> [LightingCue] {
        (0 ..< max(0, sectionCount)).map { i in
            LightingCue(
                name: "Section \(i + 1)",
                fadeSeconds: 2,
                channelValues: [ChannelValue(channel: 1, value: UInt8(32 + i * 16))]
            )
        }
    }
}
