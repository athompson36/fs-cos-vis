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

    /// DMX output frame profiler (from ``AppModel/dmxPerformanceDiagnostics()``). Omitted in older payloads when decoding.
    struct DMXPerformanceSummary: Codable, Equatable, Sendable {
        var frameCount: UInt64
        var overBudgetFrameCount: UInt64
        var avgBuildMS: Double
        var avgSendMS: Double
        var avgTotalMS: Double
        var maxBuildMS: Double
        var maxSendMS: Double
        var maxTotalMS: Double
        /// Exact median / p95 from the last ≤512 raw frame samples (when available).
        var exactMedianTotalMS: Double?
        var exactP95TotalMS: Double?
        var exactMedianBuildMS: Double?
        var exactP95BuildMS: Double?
        var exactMedianSendMS: Double?
        var exactP95SendMS: Double?
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
    var liveOutputRecording: Bool
    var liveOutputRecordingSource: String
    var liveOutputRecordingQualityPreset: String
    var liveOutputRecordingStatus: String
    var liveOutputRecordingAudioDiagnostic: String
    var liveOutputLastRecordingPath: String?

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
    /// Bookmark order: each entry is a cue **list index** (same as `SetActiveLightingCueIndex`); parallel names for display.
    var lightingBookmarkCueIndices: [Int]?
    var lightingBookmarkCueNames: [String]?
    /// Present when the host encodes profiler data; absent/`nil` when decoding legacy JSON without this field.
    var dmxPerformance: DMXPerformanceSummary?

    // MARK: - Inbound DMX (Art-Net/sACN + optional USB serial)

    /// Mirrors Settings inbound merge toggles; `nil` when decoding legacy `/api/state` JSON without these keys.
    var dmxInboundEnabled: Bool?
    var dmxInboundMode: String?
    var dmxInboundUniverse: Int?
    var dmxInboundUniverseCount: Int?
    var dmxInboundMergeMode: String?
    var dmxInboundOpenDMXEnabled: Bool?
    /// Inbound-only serial path (may match output path in misconfiguration; see status line).
    var dmxInboundOpenDMXPath: String?

    /// Human-readable inbound line (same family as Settings diagnostics).
    var dmxInboundStatus: String?

    /// Live counters from the UDP listener + OpenDMX USB input service; `nil` for legacy payloads.
    var dmxInboundTelemetry: DMXInboundTelemetry?
}

/// Compact inbound diagnostics for remote `/api/state` (optional for backward-compatible decode).
struct DMXInboundTelemetry: Codable, Equatable, Sendable {
    var lastError: String?
    var networkListenerRunning: Bool
    var networkFrames: UInt64
    var sacnSyncPackets: UInt64
    var sacnDiscoveryPackets: UInt64
    var sacnLastSyncUniverse: Int?
    var sacnLastDiscoveryUniverses: [Int]
    var openDMXSerialRunning: Bool
    var openDMXSerialFrames: UInt64
    var openDMXSerialLastError: String?
}

extension DMXInboundTelemetry {
    init(_ d: DMXInboundDiagnostics) {
        lastError = d.lastError
        networkListenerRunning = d.running
        networkFrames = d.frames
        sacnSyncPackets = d.sacnSyncPackets
        sacnDiscoveryPackets = d.sacnDiscoveryPackets
        sacnLastSyncUniverse = d.sacnLastSyncUniverse
        sacnLastDiscoveryUniverses = d.sacnLastDiscoveryUniverses
        openDMXSerialRunning = d.openDMXSerialRunning
        openDMXSerialFrames = d.openDMXSerialFrames
        openDMXSerialLastError = d.openDMXSerialLastError
    }
}
