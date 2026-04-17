import Foundation

struct WebControlStateDTO: Codable, Equatable, Sendable {
    struct SceneSummary: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
    }

    struct AudioDeviceSummary: Codable, Equatable, Sendable {
        var id: UInt32
        var name: String
    }

    struct PaletteSummary: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
    }

    var bpm: Double
    var beatPhase: Double
    var beatConfidence: Double
    var syncSource: String
    var midiClockRunning: Bool
    var sceneIndex: Int
    var sceneCount: Int
    var scenes: [SceneSummary]
    var currentSceneID: UUID?
    var performanceMode: Bool
    var overlayEnabled: Bool
    var audioRMS: Float
    var audioPeak: Float
    var audioError: String?
    var audioInputDevices: [AudioDeviceSummary]
    var selectedAudioDeviceID: UInt32?
    var remoteControlEnabled: Bool
    var remotePort: Int
    var bindLAN: Bool
    var dmxEnabled: Bool
    var dmxSerialPath: String
    var dmxLastError: String?
    var dmxNominalHz: Double
    var externalScreenCount: Int
    var externalPresentationOpen: Bool
    var externalOutputScreenIndex: Int
    var palettes: [PaletteSummary]
    var selectedPaletteID: UUID?

    /// Patched fixtures (universe 0 instances) for quick remote readouts.
    var lightingPatchFixtureCount: Int
    var lightingCueCount: Int
    /// Active cue list index when set.
    var lightingActiveCueIndex: Int?
    /// Name of the active cue, if any.
    var lightingActiveCueName: String?
    var lightingModulatorCount: Int
    /// Cue library names in list order (index matches `SetActiveLightingCueIndex`).
    var lightingCueNames: [String]
}
