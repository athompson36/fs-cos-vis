import Foundation

/// Single snapshot of patch, cues, modulation, and stage for backup / transfer.
struct LightingWorkspaceBundle: Codable, Equatable, Sendable {
    var version: Int
    var dmxPatch: DMXPatchDocument
    var lightingCues: LightingCueDocument
    var modulation: ModulationDocument
    var stageLayout: StageLayoutDocument

    static let currentVersion = 1

    init(
        version: Int = currentVersion,
        dmxPatch: DMXPatchDocument,
        lightingCues: LightingCueDocument,
        modulation: ModulationDocument,
        stageLayout: StageLayoutDocument
    ) {
        self.version = version
        self.dmxPatch = dmxPatch
        self.lightingCues = lightingCues
        self.modulation = modulation
        self.stageLayout = stageLayout
    }
}
