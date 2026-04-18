import AppKit
import CoreGraphics
import Foundation

/// How the main-window Metal previews (Live Show, Scene Studio) are letterboxed to match output or a chosen frame.
enum PreviewAspectRatioSelection: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    /// Match the fullscreen presentation rectangle on the selected **Output screen** (external backdrop).
    case auto = "auto"
    /// Match the main application window’s content aspect (updates when the window is resized).
    case applicationWindow = "application_window"
    case ratio16_9 = "16:9"
    case ratio4_3 = "4:3"
    case ratio16_10 = "16:10"
    case ratio21_9 = "21:9"
    case ratio3_2 = "3:2"
    case ratio239_1 = "2.39:1"
    case ratio1_1 = "1:1"

    var id: String { rawValue }

    var pickerLabel: String {
        switch self {
        case .auto: return "Auto"
        case .applicationWindow: return "Application window"
        case .ratio16_9: return "16∶9"
        case .ratio4_3: return "4∶3"
        case .ratio16_10: return "16∶10"
        case .ratio21_9: return "21∶9"
        case .ratio3_2: return "3∶2"
        case .ratio239_1: return "2.39∶1 (scope)"
        case .ratio1_1: return "1∶1"
        }
    }

    /// Width ÷ height for letterboxing the preview.
    func resolvedAspect(externalScreenIndex: Int) -> CGFloat {
        switch self {
        case .auto:
            return ExternalDisplayRouter.performanceAspectRatio(screenIndex: externalScreenIndex)
        case .applicationWindow:
            return Self.applicationWindowContentAspectRatio()
        case .ratio16_9:
            return 16 / 9
        case .ratio4_3:
            return 4 / 3
        case .ratio16_10:
            return 16 / 10
        case .ratio21_9:
            return 21 / 9
        case .ratio3_2:
            return 3 / 2
        case .ratio239_1:
            return 2.39
        case .ratio1_1:
            return 1
        }
    }

    private static func applicationWindowContentAspectRatio() -> CGFloat {
        guard let win = NSApp.mainWindow ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
              let view = win.contentView
        else {
            return 16 / 9
        }
        let s = view.bounds.size
        let w = max(s.width, 1)
        let h = max(s.height, 1)
        return w / h
    }

    /// Largest size that fits `container` while preserving `aspect` (width ÷ height).
    static func aspectFitSize(container: CGSize, aspect: CGFloat) -> CGSize {
        let cw = max(container.width, 1)
        let ch = max(container.height, 1)
        guard aspect > 0 else { return CGSize(width: cw, height: ch) }
        let containerAspect = cw / ch
        if containerAspect > aspect {
            let h = ch
            let w = h * aspect
            return CGSize(width: w, height: h)
        } else {
            let w = cw
            let h = w / aspect
            return CGSize(width: w, height: h)
        }
    }
}

extension PreviewAspectRatioSelection {
    /// Longest edge (pixels) for the Syphon/OBS offscreen render target.
    static var obsStreamMaxLongEdge: CGFloat { 1920 }

    func obsStreamDrawableSize(externalScreenIndex: Int) -> CGSize {
        let aspect = resolvedAspect(externalScreenIndex: externalScreenIndex)
        let maxLong = Self.obsStreamMaxLongEdge
        if aspect >= 1 {
            let w = maxLong
            let h = max(1, (w / aspect).rounded())
            return CGSize(width: w, height: h)
        } else {
            let h = maxLong
            let w = max(1, (h * aspect).rounded())
            return CGSize(width: w, height: h)
        }
    }
}

/// User-controlled remote / hardware I/O settings (persisted).
struct RemoteControlSettings: Equatable {
    var remoteControlEnabled: Bool = false
    var remoteControlPort: Int = 8765
    var oscControlEnabled: Bool = false
    var oscControlPort: Int = 9000
    /// When false, HTTP server binds to loopback only.
    var bindLAN: Bool = false
    /// When false, OSC listener binds to loopback only.
    var oscBindLAN: Bool = false
    var authToken: String = ""
    var oscAuthToken: String = ""
    var midiInputUID: String = ""
    /// Audio input device UID from CoreAudio. Empty = system default.
    var audioInputDeviceUID: String = ""
    /// -1 means mix all channels, otherwise 0-based input channel index.
    var audioInputChannelIndex: Int = -1
    /// `stereo_pair` (default), `mono`, or `mix_all`.
    var audioInputChannelMode: String = "stereo_pair"
    /// 0-based starting channel for stereo pair or mono channel index (depending on mode).
    var audioInputChannelStartIndex: Int = 0
    /// Forward selected audio input to an output device OBS can capture (e.g. BlackHole).
    var obsAudioForwardEnabled: Bool = false
    /// Output device UID used when OBS audio forwarding is enabled.
    var obsAudioForwardOutputDeviceUID: String = ""
    var dmxSerialDevicePath: String = ""
    var dmxOutputEnabled: Bool = false
    /// `hardware`, `simulated`, `artnet`, or `sacn`.
    var dmxOutputMode: String = "hardware"
    /// Simulated adapter profile for offline workflow.
    var dmxSimulatedInterface: String = "enttec_open_dmx"
    /// Network target host/IP for Art-Net unicast output.
    var dmxArtNetHost: String = "255.255.255.255"
    /// Universe number for Art-Net/sACN output.
    var dmxNetworkUniverse: Int = 0
    /// Destination host for sACN output (multicast or unicast).
    var dmxSACNHost: String = "239.255.0.1"
    /// Enable inbound network DMX intake (desk -> app merge path).
    var dmxInboundEnabled: Bool = false
    /// `artnet` or `sacn`.
    var dmxInboundMode: String = "artnet"
    /// First universe index accepted from inbound packets (contiguous range).
    var dmxInboundUniverse: Int = 0
    /// Number of consecutive universes to accept (1…64). USB merge uses `dmxInboundUniverse` only; network merge applies per logical universe.
    var dmxInboundUniverseCount: Int = 1
    /// Merge policy: `htp` (max) or `lpt` (latest takes precedence).
    var dmxInboundMergeMode: String = "htp"
    /// Enables RDM discovery/probing scaffold controls.
    var rdmDiscoveryEnabled: Bool = false
    /// Discovery transport path: `hardware`, `artnet`, or `sacn`.
    var rdmDiscoveryTransportMode: String = "hardware"
    /// Universe targeted by RDM discovery scaffold.
    var rdmDiscoveryUniverse: Int = 0
    /// Letterboxing for Live Show / Scene Studio Metal previews.
    var previewAspectRatioSelection: PreviewAspectRatioSelection = .auto
    /// UI-only scale for Scene Studio live preview panel.
    var sceneStudioPreviewScale: Double = 1.0

    /// Publish a Syphon stream for OBS (**Syphon Client** source). Independent from on-screen preview aspect.
    var obsSyphonStreamEnabled: Bool = false
    /// Auto = match **Presentation display** output; Application window = main window content; or a fixed ratio.
    var obsStreamAspectRatioSelection: PreviewAspectRatioSelection = .auto

    // MARK: - Live Show performance strips

    var lightingPerformanceStripEnabled: Bool = false
    var backdropPerformanceStripEnabled: Bool = false

    // MARK: - Hybrid AI (optional cloud LLM)

    /// When true, Settings exposes LLM fields; tools still work locally without network.
    var hybridAIAssistantEnabled: Bool = false
    var llmProvider: String = "openai"
    var llmModel: String = "gpt-4o-mini"
    /// Empty = default OpenAI-compatible `/v1/chat/completions` for the provider.
    var llmBaseURL: String = ""

    // MARK: - Setup wizard + release support

    var setupWizardCompleted: Bool = false
    var setupWizardLastStepID: String = "welcome"
    var setupWizardSkippedStepIDs: [String] = []
    var setupWizardSessionCount: Int = 0
    var setupWizardStartedAtISO8601: String = ""
    var setupWizardCompletedAtISO8601: String = ""
    var setupWizardStepCompletedCounts: [String: Int] = [:]
    var setupWizardStepSkippedCounts: [String: Int] = [:]
    var githubFeedbackRepository: String = "athompson36/fs-cos-vis"
    /// Personal access token for **direct** GitHub API issue creation (avoid when a relay URL is available).
    var githubFeedbackToken: String = ""
    /// Optional HTTPS endpoint for relay submission (`title`, `body`, `repository`, `appVersion` JSON); server holds GitHub credentials.
    var githubFeedbackRelayURL: String = ""
    /// Optional opaque bearer for the relay only (not a GitHub token).
    var githubFeedbackRelayToken: String = ""
}

extension RemoteControlSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case remoteControlEnabled
        case remoteControlPort
        case oscControlEnabled
        case oscControlPort
        case bindLAN
        case oscBindLAN
        case authToken
        case oscAuthToken
        case midiInputUID
        case audioInputDeviceUID
        case audioInputChannelIndex
        case obsAudioForwardEnabled
        case obsAudioForwardOutputDeviceUID
        case audioInputChannelMode
        case audioInputChannelStartIndex
        case dmxSerialDevicePath
        case dmxOutputEnabled
        case dmxOutputMode
        case dmxSimulatedInterface
        case dmxArtNetHost
        case dmxNetworkUniverse
        case dmxSACNHost
        case dmxInboundEnabled
        case dmxInboundMode
        case dmxInboundUniverse
        case dmxInboundUniverseCount
        case dmxInboundMergeMode
        case rdmDiscoveryEnabled
        case rdmDiscoveryTransportMode
        case rdmDiscoveryUniverse
        case previewAspectRatioSelection
        case sceneStudioPreviewScale
        case obsSyphonStreamEnabled
        case obsStreamAspectRatioSelection
        case lightingPerformanceStripEnabled
        case backdropPerformanceStripEnabled
        case hybridAIAssistantEnabled
        case llmProvider
        case llmModel
        case llmBaseURL
        case setupWizardCompleted
        case setupWizardLastStepID
        case setupWizardSkippedStepIDs
        case setupWizardSessionCount
        case setupWizardStartedAtISO8601
        case setupWizardCompletedAtISO8601
        case setupWizardStepCompletedCounts
        case setupWizardStepSkippedCounts
        case githubFeedbackRepository
        case githubFeedbackToken
        case githubFeedbackRelayURL
        case githubFeedbackRelayToken
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remoteControlEnabled = try c.decodeIfPresent(Bool.self, forKey: .remoteControlEnabled) ?? false
        remoteControlPort = try c.decodeIfPresent(Int.self, forKey: .remoteControlPort) ?? 8765
        oscControlEnabled = try c.decodeIfPresent(Bool.self, forKey: .oscControlEnabled) ?? false
        oscControlPort = try c.decodeIfPresent(Int.self, forKey: .oscControlPort) ?? 9000
        bindLAN = try c.decodeIfPresent(Bool.self, forKey: .bindLAN) ?? false
        oscBindLAN = try c.decodeIfPresent(Bool.self, forKey: .oscBindLAN) ?? false
        authToken = try c.decodeIfPresent(String.self, forKey: .authToken) ?? ""
        oscAuthToken = try c.decodeIfPresent(String.self, forKey: .oscAuthToken) ?? ""
        midiInputUID = try c.decodeIfPresent(String.self, forKey: .midiInputUID) ?? ""
        audioInputDeviceUID = try c.decodeIfPresent(String.self, forKey: .audioInputDeviceUID) ?? ""
        audioInputChannelIndex = try c.decodeIfPresent(Int.self, forKey: .audioInputChannelIndex) ?? -1
        audioInputChannelMode = try c.decodeIfPresent(String.self, forKey: .audioInputChannelMode) ?? "stereo_pair"
        audioInputChannelStartIndex = try c.decodeIfPresent(Int.self, forKey: .audioInputChannelStartIndex) ?? 0
        obsAudioForwardEnabled = try c.decodeIfPresent(Bool.self, forKey: .obsAudioForwardEnabled) ?? false
        obsAudioForwardOutputDeviceUID = try c.decodeIfPresent(String.self, forKey: .obsAudioForwardOutputDeviceUID) ?? ""
        dmxSerialDevicePath = try c.decodeIfPresent(String.self, forKey: .dmxSerialDevicePath) ?? ""
        dmxOutputEnabled = try c.decodeIfPresent(Bool.self, forKey: .dmxOutputEnabled) ?? false
        dmxOutputMode = try c.decodeIfPresent(String.self, forKey: .dmxOutputMode) ?? "hardware"
        dmxSimulatedInterface = try c.decodeIfPresent(String.self, forKey: .dmxSimulatedInterface) ?? "enttec_open_dmx"
        dmxArtNetHost = try c.decodeIfPresent(String.self, forKey: .dmxArtNetHost) ?? "255.255.255.255"
        dmxNetworkUniverse = try c.decodeIfPresent(Int.self, forKey: .dmxNetworkUniverse) ?? 0
        dmxSACNHost = try c.decodeIfPresent(String.self, forKey: .dmxSACNHost) ?? "239.255.0.1"
        dmxInboundEnabled = try c.decodeIfPresent(Bool.self, forKey: .dmxInboundEnabled) ?? false
        dmxInboundMode = try c.decodeIfPresent(String.self, forKey: .dmxInboundMode) ?? "artnet"
        dmxInboundUniverse = try c.decodeIfPresent(Int.self, forKey: .dmxInboundUniverse) ?? 0
        let rawInboundCount = try c.decodeIfPresent(Int.self, forKey: .dmxInboundUniverseCount) ?? 1
        dmxInboundUniverseCount = max(1, min(64, rawInboundCount))
        dmxInboundMergeMode = try c.decodeIfPresent(String.self, forKey: .dmxInboundMergeMode) ?? "htp"
        rdmDiscoveryEnabled = try c.decodeIfPresent(Bool.self, forKey: .rdmDiscoveryEnabled) ?? false
        rdmDiscoveryTransportMode = try c.decodeIfPresent(String.self, forKey: .rdmDiscoveryTransportMode) ?? "hardware"
        rdmDiscoveryUniverse = try c.decodeIfPresent(Int.self, forKey: .rdmDiscoveryUniverse) ?? 0
        previewAspectRatioSelection = try c.decodeIfPresent(PreviewAspectRatioSelection.self, forKey: .previewAspectRatioSelection) ?? .auto
        sceneStudioPreviewScale = try c.decodeIfPresent(Double.self, forKey: .sceneStudioPreviewScale) ?? 1.0
        obsSyphonStreamEnabled = try c.decodeIfPresent(Bool.self, forKey: .obsSyphonStreamEnabled) ?? false
        obsStreamAspectRatioSelection = try c.decodeIfPresent(PreviewAspectRatioSelection.self, forKey: .obsStreamAspectRatioSelection) ?? .auto
        lightingPerformanceStripEnabled = try c.decodeIfPresent(Bool.self, forKey: .lightingPerformanceStripEnabled) ?? false
        backdropPerformanceStripEnabled = try c.decodeIfPresent(Bool.self, forKey: .backdropPerformanceStripEnabled) ?? false
        hybridAIAssistantEnabled = try c.decodeIfPresent(Bool.self, forKey: .hybridAIAssistantEnabled) ?? false
        llmProvider = try c.decodeIfPresent(String.self, forKey: .llmProvider) ?? "openai"
        llmModel = try c.decodeIfPresent(String.self, forKey: .llmModel) ?? "gpt-4o-mini"
        llmBaseURL = try c.decodeIfPresent(String.self, forKey: .llmBaseURL) ?? ""
        setupWizardCompleted = try c.decodeIfPresent(Bool.self, forKey: .setupWizardCompleted) ?? false
        setupWizardLastStepID = try c.decodeIfPresent(String.self, forKey: .setupWizardLastStepID) ?? "welcome"
        setupWizardSkippedStepIDs = try c.decodeIfPresent([String].self, forKey: .setupWizardSkippedStepIDs) ?? []
        setupWizardSessionCount = try c.decodeIfPresent(Int.self, forKey: .setupWizardSessionCount) ?? 0
        setupWizardStartedAtISO8601 = try c.decodeIfPresent(String.self, forKey: .setupWizardStartedAtISO8601) ?? ""
        setupWizardCompletedAtISO8601 = try c.decodeIfPresent(String.self, forKey: .setupWizardCompletedAtISO8601) ?? ""
        setupWizardStepCompletedCounts = try c.decodeIfPresent([String: Int].self, forKey: .setupWizardStepCompletedCounts) ?? [:]
        setupWizardStepSkippedCounts = try c.decodeIfPresent([String: Int].self, forKey: .setupWizardStepSkippedCounts) ?? [:]
        githubFeedbackRepository = try c.decodeIfPresent(String.self, forKey: .githubFeedbackRepository) ?? "athompson36/fs-cos-vis"
        githubFeedbackToken = try c.decodeIfPresent(String.self, forKey: .githubFeedbackToken) ?? ""
        githubFeedbackRelayURL = try c.decodeIfPresent(String.self, forKey: .githubFeedbackRelayURL) ?? ""
        githubFeedbackRelayToken = try c.decodeIfPresent(String.self, forKey: .githubFeedbackRelayToken) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(remoteControlEnabled, forKey: .remoteControlEnabled)
        try c.encode(remoteControlPort, forKey: .remoteControlPort)
        try c.encode(oscControlEnabled, forKey: .oscControlEnabled)
        try c.encode(oscControlPort, forKey: .oscControlPort)
        try c.encode(bindLAN, forKey: .bindLAN)
        try c.encode(oscBindLAN, forKey: .oscBindLAN)
        try c.encode(authToken, forKey: .authToken)
        try c.encode(oscAuthToken, forKey: .oscAuthToken)
        try c.encode(midiInputUID, forKey: .midiInputUID)
        try c.encode(audioInputDeviceUID, forKey: .audioInputDeviceUID)
        try c.encode(audioInputChannelIndex, forKey: .audioInputChannelIndex)
        try c.encode(audioInputChannelMode, forKey: .audioInputChannelMode)
        try c.encode(audioInputChannelStartIndex, forKey: .audioInputChannelStartIndex)
        try c.encode(obsAudioForwardEnabled, forKey: .obsAudioForwardEnabled)
        try c.encode(obsAudioForwardOutputDeviceUID, forKey: .obsAudioForwardOutputDeviceUID)
        try c.encode(dmxSerialDevicePath, forKey: .dmxSerialDevicePath)
        try c.encode(dmxOutputEnabled, forKey: .dmxOutputEnabled)
        try c.encode(dmxOutputMode, forKey: .dmxOutputMode)
        try c.encode(dmxSimulatedInterface, forKey: .dmxSimulatedInterface)
        try c.encode(dmxArtNetHost, forKey: .dmxArtNetHost)
        try c.encode(dmxNetworkUniverse, forKey: .dmxNetworkUniverse)
        try c.encode(dmxSACNHost, forKey: .dmxSACNHost)
        try c.encode(dmxInboundEnabled, forKey: .dmxInboundEnabled)
        try c.encode(dmxInboundMode, forKey: .dmxInboundMode)
        try c.encode(dmxInboundUniverse, forKey: .dmxInboundUniverse)
        try c.encode(dmxInboundUniverseCount, forKey: .dmxInboundUniverseCount)
        try c.encode(dmxInboundMergeMode, forKey: .dmxInboundMergeMode)
        try c.encode(rdmDiscoveryEnabled, forKey: .rdmDiscoveryEnabled)
        try c.encode(rdmDiscoveryTransportMode, forKey: .rdmDiscoveryTransportMode)
        try c.encode(rdmDiscoveryUniverse, forKey: .rdmDiscoveryUniverse)
        try c.encode(previewAspectRatioSelection, forKey: .previewAspectRatioSelection)
        try c.encode(sceneStudioPreviewScale, forKey: .sceneStudioPreviewScale)
        try c.encode(obsSyphonStreamEnabled, forKey: .obsSyphonStreamEnabled)
        try c.encode(obsStreamAspectRatioSelection, forKey: .obsStreamAspectRatioSelection)
        try c.encode(lightingPerformanceStripEnabled, forKey: .lightingPerformanceStripEnabled)
        try c.encode(backdropPerformanceStripEnabled, forKey: .backdropPerformanceStripEnabled)
        try c.encode(hybridAIAssistantEnabled, forKey: .hybridAIAssistantEnabled)
        try c.encode(llmProvider, forKey: .llmProvider)
        try c.encode(llmModel, forKey: .llmModel)
        try c.encode(llmBaseURL, forKey: .llmBaseURL)
        try c.encode(setupWizardCompleted, forKey: .setupWizardCompleted)
        try c.encode(setupWizardLastStepID, forKey: .setupWizardLastStepID)
        try c.encode(setupWizardSkippedStepIDs, forKey: .setupWizardSkippedStepIDs)
        try c.encode(setupWizardSessionCount, forKey: .setupWizardSessionCount)
        try c.encode(setupWizardStartedAtISO8601, forKey: .setupWizardStartedAtISO8601)
        try c.encode(setupWizardCompletedAtISO8601, forKey: .setupWizardCompletedAtISO8601)
        try c.encode(setupWizardStepCompletedCounts, forKey: .setupWizardStepCompletedCounts)
        try c.encode(setupWizardStepSkippedCounts, forKey: .setupWizardStepSkippedCounts)
        try c.encode(githubFeedbackRepository, forKey: .githubFeedbackRepository)
        try c.encode(githubFeedbackToken, forKey: .githubFeedbackToken)
        try c.encode(githubFeedbackRelayURL, forKey: .githubFeedbackRelayURL)
        try c.encode(githubFeedbackRelayToken, forKey: .githubFeedbackRelayToken)
    }
}

enum RemoteControlSettingsStore {
    private static let key = "CosmicVisualizer.RemoteControlSettings.v1"

    static func load() -> RemoteControlSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(RemoteControlSettings.self, from: data)
        else {
            return RemoteControlSettings()
        }
        return s
    }

    static func save(_ settings: RemoteControlSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
