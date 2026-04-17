import Foundation

/// Structured operations the copilot may propose; validated before applying.
enum LightingPatchOperation: Codable, Equatable, Sendable {
    case addFixture(profileID: UUID, startAddress: Int)
    case setFixtureAddress(instanceID: UUID, startAddress: Int)
    case setStagePlacement(instanceID: UUID, placement: StagePlacement)
    case setCueActive(index: Int?)
    case suggestModulator(ModulatorDefinition)
}

enum LightingCopilotValidationError: Error, LocalizedError {
    case invalidChannel(Int)
    case invalidAddress(Int)
    case unknownOperation

    var errorDescription: String? {
        switch self {
        case .invalidChannel(let c): return "DMX channel out of range: \(c)"
        case .invalidAddress(let a): return "Start address out of range: \(a)"
        case .unknownOperation: return "Unknown copilot operation"
        }
    }
}

/// Feature-scoped assistant (v1: local heuristics; swap for LLM + JSON schema later).
final class LightingCopilotService: Sendable {
    init() {}

    func validate(operations: [LightingPatchOperation]) -> Result<Void, LightingCopilotValidationError> {
        for op in operations {
            switch op {
            case .addFixture(_, let addr), .setFixtureAddress(_, let addr):
                guard (1 ... 512).contains(addr) else { return .failure(.invalidAddress(addr)) }
            case .setStagePlacement:
                break
            case .setCueActive(let idx):
                if let i = idx, !(0 ... 10_000).contains(i) { return .failure(.unknownOperation) }
            case .suggestModulator(let m):
                guard (1 ... 512).contains(m.targetChannel) else { return .failure(.invalidChannel(m.targetChannel)) }
            }
        }
        return .success(())
    }

    /// Greedy gap-filling addresses for new fixtures (single universe, no overlap check against profile width in v1).
    func suggestNextAddresses(patch: DMXPatchDocument, profile: FixtureProfile, count: Int) -> [Int] {
        let width = max(1, profile.channels.count)
        var used = Set<Int>()
        for inst in patch.instances {
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
