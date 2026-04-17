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
    /// When false, HTTP server binds to loopback only.
    var bindLAN: Bool = false
    var authToken: String = ""
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
    /// `hardware` or `simulated`.
    var dmxOutputMode: String = "hardware"
    /// Simulated adapter profile for offline workflow.
    var dmxSimulatedInterface: String = "enttec_open_dmx"
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
    var githubFeedbackRepository: String = "athompson36/fs-cos-vis"
    var githubFeedbackToken: String = ""
}

extension RemoteControlSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case remoteControlEnabled
        case remoteControlPort
        case bindLAN
        case authToken
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
        case githubFeedbackRepository
        case githubFeedbackToken
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remoteControlEnabled = try c.decodeIfPresent(Bool.self, forKey: .remoteControlEnabled) ?? false
        remoteControlPort = try c.decodeIfPresent(Int.self, forKey: .remoteControlPort) ?? 8765
        bindLAN = try c.decodeIfPresent(Bool.self, forKey: .bindLAN) ?? false
        authToken = try c.decodeIfPresent(String.self, forKey: .authToken) ?? ""
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
        githubFeedbackRepository = try c.decodeIfPresent(String.self, forKey: .githubFeedbackRepository) ?? "athompson36/fs-cos-vis"
        githubFeedbackToken = try c.decodeIfPresent(String.self, forKey: .githubFeedbackToken) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(remoteControlEnabled, forKey: .remoteControlEnabled)
        try c.encode(remoteControlPort, forKey: .remoteControlPort)
        try c.encode(bindLAN, forKey: .bindLAN)
        try c.encode(authToken, forKey: .authToken)
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
        try c.encode(githubFeedbackRepository, forKey: .githubFeedbackRepository)
        try c.encode(githubFeedbackToken, forKey: .githubFeedbackToken)
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
