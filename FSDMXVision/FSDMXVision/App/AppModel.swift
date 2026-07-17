import AppKit
import AVFoundation
import Combine
import CoreAudio
import Foundation
import MetalKit
import simd
import SwiftUI
import Syphon
import UniformTypeIdentifiers

enum ShowDirectorRuntimeStatus: Equatable, Sendable {
    case unconfigured
    case loading
    case ready
    case failed(message: String)
}

final class AppModel: ObservableObject {
    struct SetupWizardDiagnosticsSnapshot: Codable, Sendable {
        var exportedAt: Date
        var sessionCount: Int
        var startedAtISO8601: String
        var completedAtISO8601: String
        var lastStepID: String
        var skippedStepIDs: [String]
        var stepCompletedCounts: [String: Int]
        var stepSkippedCounts: [String: Int]
        var setupWizardCompleted: Bool
    }

    enum LiveOutputRecordingSource: String, CaseIterable, Identifiable {
        case mainLivePreview
        case externalOutput

        var id: String { rawValue }
        var title: String {
            switch self {
            case .mainLivePreview: "Main live preview"
            case .externalOutput: "External fullscreen output"
            }
        }
    }
    struct LiveOutputRecorderHealthItem: Identifiable, Equatable {
        var id: String { message }
        var message: String
        var isHealthy: Bool
    }
    enum LiveOutputRecordingQualityPreset: String, CaseIterable, Identifiable {
        case performance
        case balanced
        case archival

        var id: String { rawValue }
        var title: String {
            switch self {
            case .performance: "Performance (24fps · 5 Mbps)"
            case .balanced: "Balanced (30fps · 8 Mbps)"
            case .archival: "Archival (60fps · 16 Mbps)"
            }
        }

        var captureQuality: CaptureSession.RecordingQuality {
            switch self {
            case .performance:
                return .init(framesPerSecond: 24, videoBitrate: 5_000_000)
            case .balanced:
                return .init(framesPerSecond: 30, videoBitrate: 8_000_000)
            case .archival:
                return .init(framesPerSecond: 60, videoBitrate: 16_000_000)
            }
        }
    }
    struct AudioInputChannelChoice: Hashable, Identifiable {
        enum Kind: Hashable {
            case stereoPair(startIndex: Int)
            case mono(index: Int)
            case mixAll
        }
        let kind: Kind
        var id: String {
            switch kind {
            case let .stereoPair(start): return "st-\(start)"
            case let .mono(idx): return "m-\(idx)"
            case .mixAll: return "all"
            }
        }
        var label: String {
            switch kind {
            case let .stereoPair(start): return "Stereo \(start + 1)/\(start + 2)"
            case let .mono(idx): return "Mono \(idx + 1)"
            case .mixAll: return "Mix all channels"
            }
        }
    }

    let sceneManager = SceneManager()
    let audioEngine = AudioEngine()
    let tempoClock = TempoClockService()
    var metalRenderer: CompositeRenderer?
    private let sceneLibrary = SceneLibraryStore()
    private let overlayLibrary = OverlayLibraryStore()
    private let sceneControlStore = SceneControlStore()
    private let webControl = WebControlServer()

    /// Separate GPU pipeline for the external fullscreen presentation window.
    private var externalOutputRenderer: CompositeRenderer?
    private var externalOutputWindow: NSWindow?

    /// Offscreen Metal view + Syphon server for OBS (**Syphon Client** source).
    private var obsStreamRenderer: CompositeRenderer?
    private var obsStreamMTKView: MTKView?
    private var obsSyphonServer: SyphonMetalServer?

    @Published private(set) var isExternalVisualizationOpen = false
    /// Picks which `NSScreen.screens[index]` receives the fullscreen visualization.
    @Published var externalOutputScreenIndex: Int = 0 {
        didSet {
            Task { @MainActor [weak self] in
                self?.syncOBSStreamPipeline()
            }
        }
    }

    @Published var overlays: [OverlayAsset] = []
    @Published var transitionState: TransitionState = .idle

    @Published var selectedSceneID: UUID?
    @Published var bpm: Double = 0
    @Published var beatConfidence: Double = 0
    @Published var selectedAudioDeviceName: String = "Default Input"
    @Published var palettes: [ThemePalette] = PaletteLibraryStore.loadOrDefault()
    @Published var liquidPalettes: [LiquidDropperPalette] = LiquidPaletteLibraryStore.loadOrDefault()
    @Published var selectedPaletteID: UUID?
    @Published var performanceMode = false
    @Published var overlayEnabled = false
    /// When true, drag / pinch on the main preview adjusts logo placement (main window only).
    @Published var overlayPlacementInteractionEnabled = false
    /// Scene Studio: pour liquid dye onto the preview (tap / hold).
    @Published var liquidDropperArmed = false
    @Published var audioError: String?

    /// When true, `remoteSettings` mutations do not re-run `refreshAuxiliaryServices()` (avoids feedback loops when persisting auto-shifted control ports).
    private var suppressAuxiliaryServiceRefresh = false

    @Published var remoteSettings: RemoteControlSettings = RemoteControlSettingsStore.load() {
        didSet {
            RemoteControlSettingsStore.save(remoteSettings)
            guard !suppressAuxiliaryServiceRefresh else { return }
            Task { @MainActor [weak self] in
                self?.refreshAuxiliaryServices()
            }
        }
    }

    /// USB DMX universe composition (fixtures, legacy slots, cues, modulation). Mutate via `apply*` helpers for thread safety with the DMX timer.
    @Published private(set) var dmxPatchDocument = DMXPatchDocument.default()
    @Published private(set) var lightingCueDocument = LightingCueDocument.default()
    @Published private(set) var modulationDocument = ModulationDocument.default()
    @Published private(set) var stageLayoutDocument = StageLayoutDocument()
    @Published private(set) var backdropCueDocument = BackdropCueDocument.default()
    @Published private(set) var overlayCardDocument = OverlayCardDocument.default()
    @Published private(set) var overlayElementActivatedAt: [UUID: Date] = [:]
    @Published var showProjectMetadata = ShowProjectDocument()
    @Published private(set) var currentShowProjectFolder: URL?
    /// Optional Show Director graph loaded from `show-director/` inside the package.
    @Published private(set) var showDirectorGraph: ShowDirectorGraph?
    @Published private(set) var showDirectorValidationWarnings: [ShowDirectorValidationIssue] = []
    @Published private(set) var showDirectorRuntimeStatus: ShowDirectorRuntimeStatus = .unconfigured
    private(set) var showDirectorEngine: ShowDirectorEngine?
    private var showDirectorConfigurationTask: Task<Void, Never>?
    private var showDirectorConfigurationGeneration: UInt64 = 0
    var showDirectorGraphLoader:
        @Sendable (ShowDirectorEngine, ShowDirectorGraph, String) async -> ShowDirectorSubmitResult = {
            engine, graph, commandID in
            await engine.submit(.loadShow(commandID: commandID, graph: graph))
        }
    @Published var aiAssistantLastMessage: String = ""
    @Published var liveOutputRecordingSource: LiveOutputRecordingSource = .mainLivePreview
    @Published var liveOutputRecordingQualityPreset: LiveOutputRecordingQualityPreset = .balanced
    @Published private(set) var liveOutputRecordingStatus: String = ""
    @Published private(set) var liveOutputRecordingAudioDiagnostic: String = ""
    @Published private(set) var isLiveOutputRecording = false
    @Published private(set) var liveOutputRecordingStartedAt: Date?
    @Published private(set) var lastRecordingURL: URL?

    private var contextRefreshTask: Task<Void, Never>?
    private let captureSession = CaptureSession()

    private let lightingDMXLock = NSLock()
    private var lightingCueCrossfade: LightingCueCrossfade?
    /// Start time for open-loop hazer envelope on the active cue (`nil` when no active cue).
    private var hazeEnvelopeStartedAt: CFAbsoluteTime?

    let lightingCopilotService = LightingCopilotService()
    let appUpdateService = AppUpdateService()

    /// Latched fog/haze emergency off (final override in DMX build).
    @Published var hazeEmergencyKillActive = false
    /// Fog/haze learn status line for the Lighting workspace.
    @Published private(set) var fogHazeLearnPhase: String = ""
    private var fogHazeLearnTask: Task<Void, Never>?
    @Published private(set) var fixtureVerificationPhase: String = ""
    @Published private(set) var fixtureVerificationReport: FixtureVerificationDocument?
    /// Latest exposure / contrast hint from the current or last fixture step (Verify tab banner).
    @Published private(set) var fixtureVerificationExposureHint: String?
    private var fixtureVerificationTask: Task<Void, Never>?
    @Published private(set) var feedbackStatus: String = ""
    @Published private(set) var appUpdateStatus: String = ""
    @Published private(set) var setupWizardDiagnosticsStatus: String = ""
    @Published private(set) var dmxInboundStatus: String = ""
    @Published private(set) var rdmDiscoveryStatus: String = ""
    @Published private(set) var rdmDiscoveryResult: RDMDiscoveryResult?
    @Published private(set) var oscControlStatus: String = ""
    /// HTTP / WebSocket remote listener status (includes auto-shift notes when the requested TCP port was busy).
    @Published private(set) var remoteHTTPControlStatus: String = ""

    @Published private(set) var sceneEditStates: [UUID: SceneEditState] = [:]

    /// Live Metal previews for the main-window scene cue strip (not used on external projection).
    @Published private(set) var scenePreviewRenderers: [UUID: CompositeRenderer] = [:]
    private var overlayTextureCache: [String: MTLTexture] = [:]

    lazy var commandHub: ControlCommandHub = ControlCommandHub(model: self)

    private var midiControl: MIDIControlService?
    private var oscControl: OSCControlService?
    private var dmxService: DMXOutputService?
    private var dmxInputService: DMXInputService?
    private var dmxOpenDMXInputService: OpenDMXUSBInputService?
    private let rdmDiscoveryService = RDMDiscoveryService()
    /// Latest inbound frame per wire universe (Art-Net / sACN / OpenDMX USB serial), with receive time for merge staleness.
    private var inboundDMXByUniverse: [Int: (frame: [UInt8], receivedAt: CFAbsoluteTime, priority: UInt8)] = [:]
    /// Published so Controller UI can show current MIDI assignments.
    @Published private(set) var midiMapping: MIDIMapping = MIDIMappingStore.loadOrDefault()

    /// Controller: arm “learn next CC” for the selected layer parameter (MIDI only in v1).
    @Published var controlLearnMode: ControlLearnMode = .off
    @Published var midiLearnTarget: LayerControlParameter?

    private var cancellables = Set<AnyCancellable>()

    var selectedInputDeviceBinding: Binding<AudioDeviceID?> {
        Binding(
            get: { self.audioEngine.selectedInputDeviceID },
            set: { id in
                self.audioEngine.selectedInputDeviceID = id
                var s = self.remoteSettings
                s.audioInputDeviceUID = id.flatMap { did in
                    self.audioEngine.availableInputDevices.first(where: { $0.id == did })?.uid
                } ?? ""
                self.remoteSettings = s
            }
        )
    }

    var selectedInputChannelBinding: Binding<AudioInputChannelChoice> {
        Binding(
            get: {
                switch self.audioEngine.selectedInputChannelSelection {
                case let .stereoPair(start): return AudioInputChannelChoice(kind: .stereoPair(startIndex: start))
                case let .mono(index): return AudioInputChannelChoice(kind: .mono(index: index))
                case .mixAll: return AudioInputChannelChoice(kind: .mixAll)
                }
            },
            set: { choice in
                switch choice.kind {
                case let .stereoPair(start):
                    self.audioEngine.selectedInputChannelSelection = .stereoPair(startIndex: start)
                case let .mono(index):
                    self.audioEngine.selectedInputChannelSelection = .mono(index: index)
                case .mixAll:
                    self.audioEngine.selectedInputChannelSelection = .mixAll
                }
                var s = self.remoteSettings
                switch choice.kind {
                case let .stereoPair(start):
                    s.audioInputChannelMode = "stereo_pair"
                    s.audioInputChannelStartIndex = start
                case let .mono(index):
                    s.audioInputChannelMode = "mono"
                    s.audioInputChannelStartIndex = index
                case .mixAll:
                    s.audioInputChannelMode = "mix_all"
                    s.audioInputChannelStartIndex = 0
                }
                self.remoteSettings = s
            }
        )
    }

    var availableInputChannelChoices: [AudioInputChannelChoice] {
        let channelCount = audioEngine.selectedInputDeviceID
            .flatMap { id in audioEngine.availableInputDevices.first(where: { $0.id == id })?.inputChannelCount } ?? 0
        var out: [AudioInputChannelChoice] = []
        if channelCount >= 2 {
            var i = 0
            while i + 1 < channelCount {
                out.append(AudioInputChannelChoice(kind: .stereoPair(startIndex: i)))
                i += 2
            }
        }
        for i in 0 ..< channelCount {
            out.append(AudioInputChannelChoice(kind: .mono(index: i)))
        }
        out.append(AudioInputChannelChoice(kind: .mixAll))
        return out
    }

    @MainActor
    init() {
        metalRenderer = CompositeRenderer.create()
        if let doc = try? sceneLibrary.load(), !doc.scenes.isEmpty {
            sceneManager.scenes = doc.scenes
        } else {
            sceneManager.scenes = SceneBootstrap.starterScenes
        }
        if sceneManager.scenes.isEmpty {
            sceneManager.scenes = SceneBootstrap.starterScenes
        }
        sceneManager.currentIndex = min(sceneManager.currentIndex, max(0, sceneManager.scenes.count - 1))
        if let controls = try? sceneControlStore.load() {
            sceneEditStates = controls.states
        }
        if let o = try? overlayLibrary.load() {
            overlays = o.overlays
        }
        selectedSceneID = sceneManager.scenes.first?.id
        selectedPaletteID = palettes.first?.id
        externalOutputScreenIndex = ExternalDisplayRouter.defaultPreferredScreenIndex()
        clampExternalScreenIndex()
        syncRendererFromScene()

        dmxPatchDocument = DMXPatchStore.loadOrDefault()
        lightingCueDocument = LightingCueStore.loadOrDefault()
        modulationDocument = ModulationStore.loadOrDefault()
        stageLayoutDocument = StageLayoutStore.loadOrDefault()
        backdropCueDocument = BackdropCueStore.loadOrDefault()
        overlayCardDocument = OverlayCardStore.loadOrDefault()
        resetOverlayElementTimers()

        wireRendererFrameLoop(metalRenderer)
        webControl.bind(appModel: self)
        refreshAuxiliaryServices()
        refreshScenePreviewPool()

        if let last = LastShowProjectBookmark.load(),
           FileManager.default.fileExists(atPath: last.path) {
            try? loadShowProject(from: last)
        }

        sceneManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        sceneManager.$scenes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.refreshScenePreviewPool()
                }
            }
            .store(in: &cancellables)

        audioEngine.$features
            .receive(on: DispatchQueue.main)
            .sink { [weak self] features in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.tempoClock.ingestAudioDetection(bpm: features.estimatedBPM, confidence: features.beatConfidence)
                    self.bpm = self.tempoClock.effectiveBPM
                    self.beatConfidence = self.tempoClock.displayConfidence
                    self.refreshDeviceLabel()
                    self.updateAllVisualizationRenderers { p in
                        p.audioLevel = min(1, features.rms * 4)
                        p.bpm = Float(self.tempoClock.effectiveBPM)
                        p.beatConfidence = features.beatConfidence
                        p.beatPulse = self.tempoClock.shaderBeatPulse(audioConfidence: features.beatConfidence)
                        p.spectrum16 = features.spectrum16
                    }
                }
            }
            .store(in: &cancellables)

        audioEngine.$availableInputDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDeviceLabel()
            }
            .store(in: &cancellables)

        audioEngine.$selectedInputDeviceID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDeviceLabel()
            }
            .store(in: &cancellables)

        audioEngine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        tempoClock.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActiveForMicrophonePermission()
            }
            .store(in: &cancellables)

        scheduleAIContextRefresh()
    }

    deinit {
        teardownOBSStream()
        webControl.stop()
        midiControl?.stop()
        oscControl?.stop()
        dmxService?.stop()
        dmxInputService?.stop()
        if let w = externalOutputWindow {
            externalOutputWindow = nil
            externalOutputRenderer = nil
            DispatchQueue.main.async {
                w.orderOut(nil)
                w.contentView = nil
            }
        } else {
            externalOutputRenderer = nil
        }
    }

    @MainActor
    func makeWebStateSnapshotData() -> Data {
        let scenes = sceneManager.scenes.map { WebControlStateDTO.SceneSummary(id: $0.id, name: $0.name) }
        let audioDevs = audioEngine.availableInputDevices.map {
            WebControlStateDTO.AudioDeviceSummary(id: $0.id, name: $0.name)
        }
        let pal = palettes.map { WebControlStateDTO.PaletteSummary(id: $0.id, name: $0.name) }
        let dmxD = dmxService?.extendedDiagnostics()
        lightingDMXLock.lock()
        let lcSnap = lightingCueDocument
        let patchInstCount = dmxPatchDocument.instances.count
        let modSnapCount = modulationDocument.modulators.count
        lightingDMXLock.unlock()
        let activeCueName: String? = lcSnap.activeCueIndex.flatMap { i in
            lcSnap.cues.indices.contains(i) ? lcSnap.cues[i].name : nil
        }
        let lightingCueNames = lcSnap.cues.map(\.name)
        let bookmarkPairs: [(Int, String)] = lcSnap.bookmarkedCueIds.compactMap { bid in
            guard let idx = lcSnap.cues.firstIndex(where: { $0.id == bid }) else { return nil }
            return (idx, lcSnap.cues[idx].name)
        }
        let lightingBookmarkCueIndices = bookmarkPairs.map(\.0)
        let lightingBookmarkCueNames = bookmarkPairs.map(\.1)
        let perf = dmxPerformanceDiagnostics()
        let dmxPerf = WebControlStateDTO.DMXPerformanceSummary(
            frameCount: perf.frameCount,
            overBudgetFrameCount: perf.overBudgetFrameCount,
            avgBuildMS: perf.avgBuildMS,
            avgSendMS: perf.avgSendMS,
            avgTotalMS: perf.avgTotalMS,
            maxBuildMS: perf.maxBuildMS,
            maxSendMS: perf.maxSendMS,
            maxTotalMS: perf.maxTotalMS,
            exactMedianTotalMS: perf.exactMedianTotalMS,
            exactP95TotalMS: perf.exactP95TotalMS,
            exactMedianBuildMS: perf.exactMedianBuildMS,
            exactP95BuildMS: perf.exactP95BuildMS,
            exactMedianSendMS: perf.exactMedianSendMS,
            exactP95SendMS: perf.exactP95SendMS
        )
        let (inboundDiags, inboundStatusLine) = dmxInboundDiagnostics()
        let inboundTel = DMXInboundTelemetry(inboundDiags)
        let rs = remoteSettings
        let dto = WebControlStateDTO(
            bpm: tempoClock.effectiveBPM,
            beatPhase: tempoClock.beatPhase,
            beatConfidence: beatConfidence,
            syncSource: tempoClock.syncSource.rawValue,
            midiClockRunning: tempoClock.midiClockRunning,
            sceneIndex: sceneManager.currentIndex,
            sceneCount: sceneManager.scenes.count,
            scenes: scenes,
            currentSceneID: selectedSceneID,
            performanceMode: performanceMode,
            overlayEnabled: overlayEnabled,
            audioRMS: audioEngine.features.rms,
            audioPeak: audioEngine.features.peak,
            audioError: audioError,
            audioInputDevices: audioDevs,
            selectedAudioDeviceID: audioEngine.selectedInputDeviceID,
            remoteControlEnabled: remoteSettings.remoteControlEnabled,
            remotePort: remoteSettings.remoteControlPort,
            bindLAN: remoteSettings.bindLAN,
            dmxEnabled: remoteSettings.dmxOutputEnabled,
            dmxSerialPath: remoteSettings.dmxSerialDevicePath,
            dmxLastError: dmxD?.0,
            dmxNominalHz: dmxD?.2 ?? 0,
            externalScreenCount: ExternalDisplayRouter.screens.count,
            externalPresentationOpen: isExternalVisualizationOpen,
            externalOutputScreenIndex: externalOutputScreenIndex,
            palettes: pal,
            selectedPaletteID: selectedPaletteID,
            liveOutputRecording: isLiveOutputRecording,
            liveOutputRecordingSource: liveOutputRecordingSource.rawValue,
            liveOutputRecordingQualityPreset: liveOutputRecordingQualityPreset.rawValue,
            liveOutputRecordingStatus: liveOutputRecordingStatus,
            liveOutputRecordingAudioDiagnostic: liveOutputRecordingAudioDiagnostic,
            liveOutputLastRecordingPath: lastRecordingURL?.path,
            lightingPatchFixtureCount: patchInstCount,
            lightingCueCount: lcSnap.cues.count,
            lightingActiveCueIndex: lcSnap.activeCueIndex,
            lightingActiveCueName: activeCueName,
            lightingModulatorCount: modSnapCount,
            lightingCueNames: lightingCueNames,
            lightingBookmarkCueIndices: lightingBookmarkCueIndices.isEmpty ? nil : lightingBookmarkCueIndices,
            lightingBookmarkCueNames: lightingBookmarkCueNames.isEmpty ? nil : lightingBookmarkCueNames,
            dmxPerformance: dmxPerf,
            dmxInboundEnabled: rs.dmxInboundEnabled,
            dmxInboundMode: rs.dmxInboundMode,
            dmxInboundUniverse: rs.dmxInboundUniverse,
            dmxInboundUniverseCount: rs.dmxInboundUniverseCount,
            dmxInboundMergeMode: rs.dmxInboundMergeMode,
            dmxInboundOpenDMXEnabled: rs.dmxInboundOpenDMXEnabled,
            dmxInboundOpenDMXPath: rs.dmxInboundOpenDMXPath,
            dmxInboundStatus: inboundStatusLine,
            dmxInboundTelemetry: inboundTel
        )
        return (try? JSONEncoder().encode(dto)) ?? Data()
    }

    func makeScenesDocumentData() throws -> Data {
        let doc = SceneLibraryStore.Document(scenes: sceneManager.scenes)
        return try JSONEncoder().encode(doc)
    }

    func makeSceneControlsDocumentData() throws -> Data {
        let doc = SceneControlStore.Document(states: sceneEditStates)
        return try JSONEncoder().encode(doc)
    }

    @MainActor
    func applyScenesDocument(_ data: Data) throws {
        let doc = try JSONDecoder().decode(SceneLibraryStore.Document.self, from: data)
        guard !doc.scenes.isEmpty else { return }
        let validIDs = Set(doc.scenes.map(\.id))
        sceneEditStates = sceneEditStates.filter { validIDs.contains($0.key) }
        sceneManager.scenes = doc.scenes
        sceneManager.currentIndex = min(sceneManager.currentIndex, max(0, doc.scenes.count - 1))
        selectedSceneID = sceneManager.scenes[sceneManager.currentIndex].id
        syncRendererFromScene()
        try persistScenes()
    }

    func makeSettingsData() throws -> Data {
        try JSONEncoder().encode(remoteSettings)
    }

    func applySettingsDocument(_ data: Data) throws {
        let s = try JSONDecoder().decode(RemoteControlSettings.self, from: data)
        remoteSettings = s
    }

    /// Aspect ratio (width ÷ height) for letterboxed Metal previews, from Settings → preview aspect.
    func resolvedPreviewAspectRatio() -> CGFloat {
        remoteSettings.previewAspectRatioSelection.resolvedAspect(externalScreenIndex: externalOutputScreenIndex)
    }

    func makeMIDIMappingData() throws -> Data {
        try JSONEncoder().encode(midiMapping)
    }

    func applyMIDIMappingDocument(_ data: Data) throws {
        var m = try JSONDecoder().decode(MIDIMapping.self, from: data)
        if m.continuousCC.isEmpty {
            m.continuousCC = MIDIMapping.defaultContinuousPresets()
        }
        midiMapping = m
        try MIDIMappingStore.save(m)
        configureMIDIService()
        midiControl?.start()
    }

    func midiAssignmentLabel(for parameter: LayerControlParameter) -> String? {
        guard let hit = midiMapping.continuousCC.first(where: { $0.parameterID == parameter.rawValue }) else { return nil }
        return "Ch \(hit.channel + 1) · CC \(hit.controller)"
    }

    /// Single mutation path for remote/MIDI/web; hops to the main actor for `AppModel` + SwiftUI.
    func applyRemoteCommand(_ command: RemoteControlCommand) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                applyRemoteCommandOnMainThread(command)
            }
        } else {
            Task { @MainActor [weak self] in
                self?.applyRemoteCommandOnMainThread(command)
            }
        }
    }

    @MainActor
    private func applyRemoteCommandOnMainThread(_ command: RemoteControlCommand) {
        let kind = command.type.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case "NextScene":
            performNextScene()
        case "PreviousScene":
            performPreviousScene()
        case "RandomScene":
            performRandomScene()
        case "TapTempo":
            tempoClock.tapTempoFromLiveControl()
        case "SetManualBPM":
            if let v = command.bpm {
                tempoClock.manualBPM = min(220, max(40, v))
                tempoClock.setSyncSource(.manual)
            }
        case "SetTempoSource":
            if let s = command.source.flatMap({ TempoClockService.SyncSource(rawValue: $0) }) {
                tempoClock.setSyncSource(s)
            }
        case "CueSceneIndex", "JumpToSceneIndex":
            if let idx = command.index {
                performJumpToScene(index: idx)
            }
        case "CueScene", "JumpToScene":
            if let id = command.sceneID {
                performJumpToScene(id: id)
            }
        case "SetLiquidLightEnabled":
            sceneManager.setLiquidLightEnabled(command.enabled ?? true)
            syncRendererFromScene()
            try? persistScenes()
        case "SetFractalZoom":
            if let z = command.fractalZoom { mutateCurrentEdit { $0.layer.fractalZoom = z } }
        case "SetLiquidTurbulence":
            if let z = command.liquidTurbulence { mutateCurrentEdit { $0.layer.liquidTurbulence = z } }
        case "SetCompositeBlend":
            if let z = command.compositeBlend { mutateCurrentEdit { $0.layer.compositeBlend = z } }
        case "SetLiquidFocus":
            if let z = command.liquidFocus { mutateCurrentEdit { $0.layer.liquidFocus = z } }
        case "SetFractalAppearance":
            if let z = command.fractalAppearance { mutateCurrentEdit { $0.layer.fractalAppearance = z } }
        case "SetOverlayFractalFusion":
            if let z = command.overlayFractalFusion { mutateCurrentEdit { $0.layer.overlayFractalFusion = z } }
        case "SetFractalExplore":
            if let z = command.fractalExplore { mutateCurrentEdit { $0.layer.fractalExplore = max(0, min(1, z)) } }
        case "SetFractalExploreSpeed":
            if let z = command.fractalExploreSpeed { mutateCurrentEdit { $0.layer.fractalExploreSpeed = max(0.05, min(6, z)) } }
        case "SetFractalIterBoost":
            if let z = command.fractalIterBoost { mutateCurrentEdit { $0.layer.fractalIterBoost = max(0.25, min(3, z)) } }
        case "SetZoomEffectType":
            if let i = command.index {
                mutateCurrentEdit { $0.layer.zoomEffectType = Float(max(0, min(2, i))) }
            }
        case "SetLiquidReconstituteAmount":
            if let z = command.liquidReconstituteAmount { mutateCurrentEdit { $0.layer.liquidReconstituteAmount = max(0, min(1, z)) } }
        case "SetLiquidReconstituteRate":
            if let z = command.liquidReconstituteRate { mutateCurrentEdit { $0.layer.liquidReconstituteRate = max(0.05, min(3, z)) } }
        case "SetLiquidReconstituteBPMSync":
            if let e = command.enabled { mutateCurrentEdit { $0.layer.liquidReconstituteBPMSync = e } }
        case "SetDyeMix":
            if let z = command.dyeMix { mutateCurrentEdit { $0.layer.dyeMix = max(0, min(1, z)) } }
        case "SetFractalSmoothShading":
            if let z = command.fractalSmoothShading { mutateCurrentEdit { $0.layer.fractalSmoothShading = max(0, min(1, z)) } }
        case "SetCompositeBloomStrength":
            if let z = command.compositeBloomStrength { mutateCurrentEdit { $0.layer.compositeBloomStrength = max(0, min(0.85, z)) } }
        case "SetCompositeVignetteStrength":
            if let z = command.compositeVignetteStrength { mutateCurrentEdit { $0.layer.compositeVignetteStrength = max(0, min(1, z)) } }
        case "SetSpectrumWarpAmount":
            if let z = command.spectrumWarpAmount {
                mutateCurrentEdit { $0.layer.spectrumWarpAmount = max(0, min(1, z)) }
            }
        case "SetFractalGeometryIndex":
            if let i = command.index {
                let g = max(0, min(6, i))
                mutateCurrentEdit { $0.layer.fractalGeometryIndex = Float(g) }
            }
        case "PersistScenes":
            try? persistScenes()
        case "PersistSceneControls":
            try? persistSceneControls()
        case "SetPerformanceMode":
            if let e = command.enabled { performanceMode = e }
        case "SetOverlayEnabled":
            if let e = command.enabled { overlayEnabled = e }
            syncRendererFromScene()
        case "ReorderScenes":
            if let order = command.sceneOrder { performReorderScenes(order) }
        case "SetRemoteControlEnabled":
            if let e = command.enabled {
                var s = remoteSettings
                s.remoteControlEnabled = e
                remoteSettings = s
            }
        case "SetRemotePort":
            if let p = command.port {
                var s = remoteSettings
                s.remoteControlPort = max(1024, min(65535, p))
                remoteSettings = s
            }
        case "SetBindLAN":
            if let v = command.bindLAN {
                var s = remoteSettings
                s.bindLAN = v
                remoteSettings = s
            }
        case "SetAuthToken":
            if let t = command.authToken {
                var s = remoteSettings
                s.authToken = t
                remoteSettings = s
            }
        case "SetMIDIPortUID":
            if let u = command.midiInputUID {
                var s = remoteSettings
                s.midiInputUID = u
                remoteSettings = s
            }
        case "SetDMXSerialPath":
            if let p = command.serialPath {
                var s = remoteSettings
                s.dmxSerialDevicePath = p
                remoteSettings = s
            }
        case "SetDMXEnabled":
            if let e = command.enabled {
                var s = remoteSettings
                s.dmxOutputEnabled = e
                remoteSettings = s
            }
        case "OpenExternalVisualization":
            openExternalVisualizationFullscreen()
        case "CloseExternalVisualization":
            closeExternalVisualization()
        case "SetExternalScreenIndex":
            if let i = command.index {
                externalOutputScreenIndex = i
                clampExternalScreenIndex()
            }
        case "DuplicateScene":
            if let id = command.sceneID {
                performDuplicateScene(sourceID: id)
            } else if sceneManager.scenes.indices.contains(sceneManager.currentIndex) {
                performDuplicateScene(sourceID: sceneManager.scenes[sceneManager.currentIndex].id)
            }
        case "DeleteScene":
            if let id = command.sceneID {
                performDeleteScene(id: id)
            }
        case "SetSelectedPalette":
            if let p = command.paletteID {
                selectedPaletteID = p
                syncRendererFromScene()
            }
        case "SetAudioInputIndex":
            if let i = command.index,
               audioEngine.availableInputDevices.indices.contains(i) {
                audioEngine.selectedInputDeviceID = audioEngine.availableInputDevices[i].id
                refreshDeviceLabel()
            }
        case "ToggleMainWindowFullscreen":
            toggleMainWindowFullscreen()
        case "RefreshAudioDevices":
            audioEngine.refreshDevices()
            refreshDeviceLabel()
        case "SetLiveOutputRecordingSource":
            if let raw = command.source,
               let source = LiveOutputRecordingSource(rawValue: raw) {
                liveOutputRecordingSource = source
            }
        case "SetLiveOutputRecordingQualityPreset":
            if let raw = command.source,
               let preset = LiveOutputRecordingQualityPreset(rawValue: raw) {
                liveOutputRecordingQualityPreset = preset
            }
        case "StartLiveOutputRecording":
            startLiveOutputRecording(preferredMainWindowNumber: nil)
        case "StopLiveOutputRecording":
            stopLiveOutputRecording()
        case "SetActiveLightingCueIndex":
            if let i = command.index {
                lightingDMXLock.lock()
                let count = lightingCueDocument.cues.count
                lightingDMXLock.unlock()
                guard count > 0 else { break }
                if i >= 0, i < count {
                    setActiveLightingCueIndex(i)
                }
            } else {
                setActiveLightingCueIndex(nil)
            }
        case "NextLightingCue":
            lightingDMXLock.lock()
            let cues = lightingCueDocument.cues
            let current = lightingCueDocument.activeCueIndex
            lightingDMXLock.unlock()
            guard !cues.isEmpty else { break }
            let nextIdx: Int = {
                guard let c = current else { return 0 }
                let n = c + 1
                return n < cues.count ? n : 0
            }()
            setActiveLightingCueIndex(nextIdx)
        case "PreviousLightingCue":
            lightingDMXLock.lock()
            let cues = lightingCueDocument.cues
            let current = lightingCueDocument.activeCueIndex
            lightingDMXLock.unlock()
            guard !cues.isEmpty else { break }
            let prevIdx: Int = {
                guard let c = current else { return cues.count - 1 }
                let n = c - 1
                return n >= 0 ? n : cues.count - 1
            }()
            setActiveLightingCueIndex(prevIdx)
        default:
            break
        }
        bpm = tempoClock.effectiveBPM
        beatConfidence = tempoClock.displayConfidence
    }

    @MainActor
    private func mutateCurrentEdit(_ body: (inout SceneEditState) -> Void) {
        guard sceneManager.scenes.indices.contains(sceneManager.currentIndex) else { return }
        let id = sceneManager.scenes[sceneManager.currentIndex].id
        var edit = sceneEditStates[id] ?? SceneEditState()
        body(&edit)
        sceneEditStates[id] = edit
        try? persistSceneControls()
        syncRendererFromScene()
    }

    /// Public hook for SwiftUI bindings that edit `SceneEditState.layer` for the current scene.
    @MainActor
    func applyCurrentLayerEdit(_ body: (inout SceneEditState.LayerControls) -> Void) {
        mutateCurrentEdit { edit in body(&edit.layer) }
    }

    /// Normalized UV (bottom-left origin, y up) for dye splats; matches overlay / composite space.
    func normalizedDyeUV(viewPoint: CGPoint, viewSize: CGSize) -> SIMD2<Float> {
        let w = max(viewSize.width, 1)
        let h = max(viewSize.height, 1)
        let u = Float(viewPoint.x / w)
        let v = Float(1 - viewPoint.y / h)
        return SIMD2(u, v)
    }

    func enqueueLiquidPour(atViewPoint: CGPoint, viewSize: CGSize) {
        guard liquidDropperArmed,
              sceneManager.scenes.indices.contains(sceneManager.currentIndex)
        else { return }
        let scene = sceneManager.scenes[sceneManager.currentIndex]
        guard scene.liquidLightEnabled else { return }
        let uv = normalizedDyeUV(viewPoint: atViewPoint, viewSize: viewSize)
        let edit = sceneEditStates[scene.id] ?? SceneEditState()
        let l = edit.layer
        guard !l.liquidDropperLayers.isEmpty else { return }
        let activeLayerIndex = max(0, min(l.liquidDropperLayers.count - 1, l.activeDropperLayerIndex))
        let activeLayer = l.liquidDropperLayers[activeLayerIndex]
        let color = SIMD3(activeLayer.colorR, activeLayer.colorG, activeLayer.colorB)
        let visc = activeLayer.viscosity
        let pour: (CompositeRenderer) -> Void = { renderer in
            renderer.enqueueLiquidSplat(uv: uv, color: color, viscosity: visc, layerIndex: activeLayerIndex)
        }
        if let main = metalRenderer { pour(main) }
        for (_, r) in scenePreviewRenderers {
            pour(r)
        }
    }

    func clearLiquidDyeOnAllRenderers() {
        metalRenderer?.clearLiquidDye()
        for (_, r) in scenePreviewRenderers {
            r.clearLiquidDye()
        }
    }

    func disarmLiquidDropper() {
        liquidDropperArmed = false
    }

    @MainActor
    private func performReorderScenes(_ order: [UUID]) {
        var map = Dictionary(uniqueKeysWithValues: sceneManager.scenes.map { ($0.id, $0) })
        var next: [VisualizationScene] = []
        for id in order {
            if let s = map.removeValue(forKey: id) { next.append(s) }
        }
        let remainingIDs = sceneManager.scenes.map(\.id).filter { map[$0] != nil }
        for id in remainingIDs {
            if let s = map.removeValue(forKey: id) { next.append(s) }
        }
        guard !next.isEmpty else { return }
        sceneManager.scenes = next
        sceneManager.currentIndex = min(sceneManager.currentIndex, next.count - 1)
        syncRendererFromScene()
        try? persistScenes()
    }

    @MainActor
    private func performDuplicateScene(sourceID: UUID) {
        guard let idx = sceneManager.scenes.firstIndex(where: { $0.id == sourceID }) else { return }
        let s = sceneManager.scenes[idx]
        let copy = VisualizationScene(
            name: "\(s.name) Copy",
            fractalMode: s.fractalMode,
            liquidLightEnabled: s.liquidLightEnabled,
            paletteID: s.paletteID,
            overlayIDs: s.overlayIDs
        )
        sceneManager.scenes.insert(copy, at: idx + 1)
        if let edit = sceneEditStates[sourceID] {
            sceneEditStates[copy.id] = edit
        }
        try? persistScenes()
        try? persistSceneControls()
    }

    @MainActor
    private func performDeleteScene(id: UUID) {
        guard sceneManager.scenes.count > 1,
              let idx = sceneManager.scenes.firstIndex(where: { $0.id == id }) else { return }
        let oldCur = sceneManager.currentIndex
        sceneManager.scenes.remove(at: idx)
        sceneEditStates[id] = nil
        if idx < oldCur {
            sceneManager.currentIndex = oldCur - 1
        } else if idx == oldCur {
            sceneManager.currentIndex = min(idx, max(0, sceneManager.scenes.count - 1))
        }
        syncRendererFromScene()
        try? persistScenes()
        try? persistSceneControls()
    }

    @MainActor
    private func performJumpToScene(index: Int) {
        guard sceneManager.scenes.indices.contains(index) else { return }
        let fromID = sceneManager.scenes[sceneManager.currentIndex].id
        sceneManager.currentIndex = index
        let toID = sceneManager.scenes[sceneManager.currentIndex].id
        if fromID != toID {
            transitionState = .transitioning(fromSceneID: fromID, toSceneID: toID, progress: 0)
        }
        syncRendererFromScene()
        try? persistScenes()
    }

    @MainActor
    private func performJumpToScene(id: UUID) {
        if let idx = sceneManager.scenes.firstIndex(where: { $0.id == id }) {
            performJumpToScene(index: idx)
        }
    }

    @MainActor
    private func performNextScene() {
        let fromID = sceneManager.scenes.indices.contains(sceneManager.currentIndex)
            ? sceneManager.scenes[sceneManager.currentIndex].id
            : nil
        sceneManager.goToNextScene()
        if let fromID, sceneManager.scenes.indices.contains(sceneManager.currentIndex) {
            let toID = sceneManager.scenes[sceneManager.currentIndex].id
            if fromID != toID {
                transitionState = .transitioning(fromSceneID: fromID, toSceneID: toID, progress: 0)
            }
        }
        syncRendererFromScene()
        try? persistScenes()
    }

    @MainActor
    private func performPreviousScene() {
        let fromID = sceneManager.scenes.indices.contains(sceneManager.currentIndex)
            ? sceneManager.scenes[sceneManager.currentIndex].id
            : nil
        sceneManager.goToPreviousScene()
        if let fromID, sceneManager.scenes.indices.contains(sceneManager.currentIndex) {
            let toID = sceneManager.scenes[sceneManager.currentIndex].id
            if fromID != toID {
                transitionState = .transitioning(fromSceneID: fromID, toSceneID: toID, progress: 0)
            }
        }
        syncRendererFromScene()
        try? persistScenes()
    }

    @MainActor
    private func performRandomScene() {
        let fromID = sceneManager.scenes.indices.contains(sceneManager.currentIndex)
            ? sceneManager.scenes[sceneManager.currentIndex].id
            : nil
        sceneManager.goToRandomScene()
        if let fromID, sceneManager.scenes.indices.contains(sceneManager.currentIndex) {
            let toID = sceneManager.scenes[sceneManager.currentIndex].id
            if fromID != toID {
                transitionState = .transitioning(fromSceneID: fromID, toSceneID: toID, progress: 0)
            }
        }
        syncRendererFromScene()
        try? persistScenes()
    }

    /// Only the **main** window’s renderer should drive tempo + cue-strip sync; external projection uses its own `CompositeRenderer` without this callback.
    private func wireRendererFrameLoop(_ renderer: CompositeRenderer?) {
        renderer?.onFrame = { [weak self] dt in
            guard let self else { return }
            self.runFrameLoopTickOnMainActor(deltaTime: dt)
        }
    }

    /// `MTKView.draw(in:)` runs off the main thread; avoid `Task { @MainActor }` per frame (floods the main actor and can hang the UI).
    private nonisolated func runFrameLoopTickOnMainActor(deltaTime: TimeInterval) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.tickTempoAndBeatPulse(deltaTime: deltaTime)
                self.syncScenePreviewRenderers()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.tickTempoAndBeatPulse(deltaTime: deltaTime)
                    self.syncScenePreviewRenderers()
                }
            }
        }
    }

    private func clearRendererFrameLoop(_ renderer: CompositeRenderer?) {
        renderer?.onFrame = nil
    }

    @MainActor
    private func tickTempoAndBeatPulse(deltaTime: TimeInterval) {
        tempoClock.advanceBeatPhaseIfNeeded(deltaTime: deltaTime)
        let conf = Float(audioEngine.features.beatConfidence)
        updateAllVisualizationRenderers { p in
            p.beatPulse = tempoClock.shaderBeatPulse(audioConfidence: conf)
        }
    }

    @MainActor
    private func refreshAuxiliaryServices() {
        applyAudioSettingsFromRemote()
        if remoteSettings.remoteControlEnabled {
            webControl.applySettings(remoteSettings) { [weak self] effectivePort, requestedPort in
                guard let self else { return }
                guard let eff = effectivePort else {
                    self.remoteHTTPControlStatus =
                        "HTTP control: could not bind TCP (scanned up to \(ControlPlanePortBinding.defaultScanAttempts) ports starting at \(requestedPort))."
                    return
                }
                if eff != requestedPort {
                    self.suppressAuxiliaryServiceRefresh = true
                    var s = self.remoteSettings
                    s.remoteControlPort = Int(eff)
                    self.remoteSettings = s
                    self.suppressAuxiliaryServiceRefresh = false
                }
                let scope = self.remoteSettings.bindLAN ? "LAN" : "localhost"
                self.remoteHTTPControlStatus =
                    "HTTP + WS on TCP \(eff) (\(scope))" + (eff != requestedPort ? " · port \(requestedPort) was busy" : "")
            }
        } else {
            remoteHTTPControlStatus = ""
            webControl.applySettings(remoteSettings)
        }
        configureMIDIService()
        midiControl?.start()
        configureOSCService()
        configureDMXService()
        configureDMXInputService()
        syncOBSStreamPipeline()
    }

    // MARK: - OBS (Syphon) stream

    @MainActor private func syncOBSStreamPipeline() {
        guard remoteSettings.obsSyphonStreamEnabled else {
            teardownOBSStream()
            return
        }
        guard let host = NSApp.mainWindow?.contentView else {
            DispatchQueue.main.async { [weak self] in
                self?.syncOBSStreamPipeline()
            }
            return
        }

        if obsStreamRenderer == nil {
            guard let renderer = CompositeRenderer.create() else { return }
            obsStreamRenderer = renderer
            let view = MTKView(frame: CGRect(x: 0, y: 0, width: 2, height: 2), device: renderer.device)
            view.delegate = renderer
            view.framebufferOnly = true
            view.colorPixelFormat = .bgra8Unorm
            view.enableSetNeedsDisplay = false
            view.isPaused = false
            view.autoResizeDrawable = false
            view.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(view)
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: 2),
                view.heightAnchor.constraint(equalToConstant: 2),
                host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            view.alphaValue = 0.02
            obsStreamMTKView = view
        }

        guard let renderer = obsStreamRenderer, let mtkView = obsStreamMTKView else { return }

        let drawableSize = remoteSettings.obsStreamAspectRatioSelection.obsStreamDrawableSize(externalScreenIndex: externalOutputScreenIndex)
        if mtkView.drawableSize != drawableSize {
            mtkView.drawableSize = drawableSize
            renderer.mtkView(mtkView, drawableSizeWillChange: drawableSize)
        }

        if obsSyphonServer == nil {
            obsSyphonServer = SyphonMetalServer(name: AppIdentity.displayName, device: renderer.device, options: nil)
        }

        renderer.onBeforePresent = { [weak self] texture, buffer, drawSize in
            guard let self, let server = self.obsSyphonServer else { return }
            server.publishFrameTexture(
                texture,
                on: buffer,
                imageRegion: NSRect(x: 0, y: 0, width: drawSize.width, height: drawSize.height),
                flipped: true
            )
        }

        syncRendererFromScene()
    }

    private func teardownOBSStream() {
        let mtk = obsStreamMTKView
        let renderer = obsStreamRenderer
        let syphon = obsSyphonServer
        obsStreamRenderer = nil
        obsStreamMTKView = nil
        obsSyphonServer = nil
        renderer?.onBeforePresent = nil
        Task { @MainActor in
            mtk?.removeFromSuperview()
            syphon?.stop()
        }
    }

    private func handleMidiControlChange(channel ch: Int, controller cc: Int, value val: Int) {
        if controlLearnMode.allowsMidiLearn, let target = midiLearnTarget {
            var m = midiMapping
            m.learnContinuous(parameter: target, channel: ch, controller: cc)
            midiMapping = m
            try? MIDIMappingStore.save(midiMapping)
            controlLearnMode = .off
            midiLearnTarget = nil
        }

        if let param = midiMapping.layerParameter(forChannel: ch, controller: cc) {
            let fv = param.value(fromMidi7: val)
            applyRemoteCommand(param.remoteCommand(with: fv))
            return
        }

        if let cmd = midiMapping.command(forChannel: ch, controller: cc) {
            applyRemoteCommand(cmd)
        }
    }

    private func configureMIDIService() {
        midiControl?.stop()
        let m = MIDIControlService()
        let trimmedUID = remoteSettings.midiInputUID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let intVal = Int(trimmedUID), let uid = Int32(exactly: intVal), uid != 0 {
            m.filterSourceUID = uid
        } else {
            m.filterSourceUID = 0
        }
        m.onClockTick = { [weak self] in
            DispatchQueue.main.async {
                self?.tempoClock.ingestMIDIClockTick()
            }
        }
        m.onTransportStart = { [weak self] in
            DispatchQueue.main.async { self?.tempoClock.midiTransportStart() }
        }
        m.onTransportStop = { [weak self] in
            DispatchQueue.main.async { self?.tempoClock.midiTransportStop() }
        }
        m.onTransportContinue = { [weak self] in
            DispatchQueue.main.async { self?.tempoClock.midiTransportContinue() }
        }
        m.onControlChange = { [weak self] ch, cc, val in
            DispatchQueue.main.async {
                self?.handleMidiControlChange(channel: ch, controller: cc, value: val)
            }
        }
        midiControl = m
    }

    private func configureOSCService() {
        guard remoteSettings.oscControlEnabled else {
            oscControl?.stop()
            oscControlStatus = "OSC disabled"
            return
        }
        if oscControl == nil {
            oscControl = OSCControlService()
        }
        guard let osc = oscControl else { return }
        let requestedOSC = remoteSettings.oscControlPort
        let (errMsg, effectiveUdp) = osc.configure(
            port: requestedOSC,
            bindLAN: remoteSettings.oscBindLAN,
            requiredToken: remoteSettings.oscAuthToken
        ) { [weak self] cmd in
            self?.applyRemoteCommand(cmd)
        } onStateQuery: { [weak self] in
            guard let self else { return "{}" }
            return MainActor.assumeIsolated {
                String(data: self.makeWebStateSnapshotData(), encoding: .utf8) ?? "{}"
            }
        }
        if let err = errMsg, !err.isEmpty {
            oscControlStatus = err
            return
        }
        if effectiveUdp != requestedOSC {
            suppressAuxiliaryServiceRefresh = true
            var s = remoteSettings
            s.oscControlPort = effectiveUdp
            remoteSettings = s
            suppressAuxiliaryServiceRefresh = false
        }
        let p = remoteSettings.oscControlPort
        oscControlStatus =
            "Listening on UDP \(p) (\(remoteSettings.oscBindLAN ? "LAN" : "localhost")) · query: /cosmic/state/get"
            + (effectiveUdp != requestedOSC ? " · port \(requestedOSC) was busy" : "")
    }

    private func configureDMXService() {
        if remoteSettings.dmxOutputEnabled {
            if dmxService == nil {
                dmxService = DMXOutputService(model: self)
            }
            dmxService?.start()
        } else {
            dmxService?.stop()
        }
    }

    private func configureDMXInputService() {
        dmxInputService?.stop()
        dmxOpenDMXInputService?.stop()
        dmxOpenDMXInputService = nil
        lightingDMXLock.lock()
        inboundDMXByUniverse.removeAll()
        lightingDMXLock.unlock()

        let net = remoteSettings.dmxInboundEnabled
        let serial = remoteSettings.dmxInboundOpenDMXEnabled
        guard net || serial else {
            dmxInboundStatus = "Inbound DMX disabled"
            return
        }

        let outPath = remoteSettings.dmxSerialDevicePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let inPath = remoteSettings.dmxInboundOpenDMXPath.trimmingCharacters(in: .whitespacesAndNewlines)

        let frameHandler: (Int, [UInt8], UInt8) -> Void = { [weak self] universe, frame, priority in
            guard let self else { return }
            let now = CFAbsoluteTimeGetCurrent()
            self.lightingDMXLock.lock()
            defer { self.lightingDMXLock.unlock() }
            if let existing = self.inboundDMXByUniverse[universe] {
                let accept = DMXInboundMergeLogic.shouldStoreNewInboundFrame(
                    existingReceivedAt: existing.receivedAt,
                    existingPriority: existing.priority,
                    newPriority: priority,
                    now: now
                )
                if !accept { return }
            }
            self.inboundDMXByUniverse[universe] = (frame: frame, receivedAt: now, priority: priority)
        }

        if net {
            if dmxInputService == nil {
                dmxInputService = DMXInputService()
            }
            dmxInputService?.stop()
            let start = remoteSettings.dmxInboundUniverse
            let count = max(1, min(64, remoteSettings.dmxInboundUniverseCount))
            dmxInputService?.configure(
                mode: remoteSettings.dmxInboundMode,
                universeStart: start,
                universeCount: count,
                onFrame: frameHandler
            )
            dmxInputService?.start()
        }

        var serialNote = ""
        if serial {
            if inPath.isEmpty {
                serialNote = "OpenDMX USB input path is empty."
            } else if remoteSettings.dmxOutputMode == "hardware", !outPath.isEmpty, inPath == outPath {
                serialNote = "OpenDMX input path must differ from the DMX output device path."
            } else {
                let svc = OpenDMXUSBInputService()
                svc.configure(path: inPath, wireUniverse: remoteSettings.dmxInboundUniverse, onFrame: frameHandler)
                svc.start()
                dmxOpenDMXInputService = svc
                if let err = svc.lastError, !err.isEmpty {
                    serialNote = err
                } else {
                    serialNote = "OpenDMX serial \(inPath) → universe \(remoteSettings.dmxInboundUniverse)"
                }
            }
        }

        if net, let d = dmxInputService?.diagnostics(), let err = d.lastError, !err.isEmpty {
            dmxInboundStatus = err + (serialNote.isEmpty ? "" : " · \(serialNote)")
            return
        }

        if net {
            let mode = remoteSettings.dmxInboundMode.uppercased()
            let start = remoteSettings.dmxInboundUniverse
            let count = max(1, min(64, remoteSettings.dmxInboundUniverseCount))
            let netStr = count <= 1
                ? "Listening for \(mode) universe \(start)"
                : "Listening for \(mode) universes \(start)–\(start + count - 1)"
            dmxInboundStatus = netStr + (serialNote.isEmpty ? "" : " · \(serialNote)")
        } else {
            dmxInboundStatus = serialNote.isEmpty ? "USB serial inbound" : serialNote
        }
    }

    @MainActor
    private func applyAudioSettingsFromRemote() {
        audioEngine.refreshDevices()
        if !remoteSettings.audioInputDeviceUID.isEmpty,
           let inDevice = audioEngine.availableInputDevices.first(where: { $0.uid == remoteSettings.audioInputDeviceUID }) {
            audioEngine.selectedInputDeviceID = inDevice.id
        }
        if remoteSettings.audioInputChannelMode == "mono" {
            audioEngine.selectedInputChannelSelection = .mono(index: remoteSettings.audioInputChannelStartIndex)
        } else if remoteSettings.audioInputChannelMode == "mix_all" {
            audioEngine.selectedInputChannelSelection = .mixAll
        } else if remoteSettings.audioInputChannelMode == "stereo_pair" {
            audioEngine.selectedInputChannelSelection = .stereoPair(startIndex: remoteSettings.audioInputChannelStartIndex)
        } else if remoteSettings.audioInputChannelIndex >= 0 {
            // backward compatibility with legacy persisted mono index
            audioEngine.selectedInputChannelSelection = .mono(index: remoteSettings.audioInputChannelIndex)
        } else {
            audioEngine.selectedInputChannelSelection = .stereoPair(startIndex: 0)
        }
        audioEngine.obsAudioForwardEnabled = remoteSettings.obsAudioForwardEnabled
        if !remoteSettings.obsAudioForwardOutputDeviceUID.isEmpty,
           let outDevice = audioEngine.availableOutputDevices.first(where: { $0.uid == remoteSettings.obsAudioForwardOutputDeviceUID }) {
            audioEngine.selectedOutputDeviceID = outDevice.id
        } else if !remoteSettings.obsAudioForwardEnabled {
            audioEngine.selectedOutputDeviceID = nil
        }
    }

    func refreshDeviceLabel() {
        if let id = audioEngine.selectedInputDeviceID,
           let match = audioEngine.availableInputDevices.first(where: { $0.id == id }) {
            selectedAudioDeviceName = match.name
        } else if let def = AudioDeviceEnumerator.defaultInputDeviceID(),
                  let match = audioEngine.availableInputDevices.first(where: { $0.id == def }) {
            selectedAudioDeviceName = match.name
        }
    }

    @MainActor
    func syncRendererFromScene() {
        guard sceneManager.scenes.indices.contains(sceneManager.currentIndex) else { return }
        let scene = sceneManager.scenes[sceneManager.currentIndex]
        selectedSceneID = scene.id
        updateAllVisualizationRenderers { p in
            p.spectrum16 = self.audioEngine.features.spectrum16
            applySceneVisualState(scene: scene, to: &p)
        }
        syncOverlayGPUResources()
    }

    private static func dyeViscositySIMD8(from layers: [SceneEditState.LayerControls.LiquidDropperLayer]) -> SIMD8<Float> {
        var v = layers.map(\.viscosity)
        while v.count < SceneEditState.LayerControls.maxDropperLayers {
            v.append(0.5)
        }
        if v.count > 8 {
            v = Array(v.prefix(8))
        }
        return SIMD8(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7])
    }

    /// Full parameters for a scene using current live audio/beat state (used for cue-strip previews).
    private func makeRenderParameters(for scene: VisualizationScene) -> RenderParameters {
        var p = RenderParameters()
        let conf = Float(audioEngine.features.beatConfidence)
        p.audioLevel = min(1, audioEngine.features.rms * 4)
        p.bpm = Float(tempoClock.effectiveBPM)
        p.beatConfidence = conf
        p.beatPulse = tempoClock.shaderBeatPulse(audioConfidence: conf)
        p.spectrum16 = audioEngine.features.spectrum16
        applySceneVisualState(scene: scene, to: &p)
        return p
    }

    private func applySceneVisualState(scene: VisualizationScene, to p: inout RenderParameters) {
        let edit = sceneEditStates[scene.id] ?? SceneEditState()
        let pal = effectivePalette(for: scene)
        let colors = pal.map { PaletteColorConversion.simdColors(from: $0) }
        let c0, c1, c2, c3: SIMD4<Float>
        if let colors {
            c0 = colors.0
            c1 = colors.1
            c2 = colors.2
            c3 = colors.3
        } else {
            c0 = SIMD4<Float>(0.05, 0, 0.12, 0)
            c1 = SIMD4<Float>(0.1, 0.04, 0.18, 0)
            c2 = SIMD4<Float>(0, 0.85, 1, 0)
            c3 = SIMD4<Float>(1, 0.25, 0.92, 0)
        }
        let overlayOpacity: Float = {
            guard overlayEnabled,
                  let oid = scene.overlayIDs.first,
                  let asset = overlays.first(where: { $0.id == oid })
            else { return 0 }
            return asset.opacity
        }()
        p.liquidLightEnabled = scene.liquidLightEnabled
        p.liquidMix = scene.liquidLightEnabled ? 1 : 0
        if scene.name.contains("Liquid Only") {
            p.fractalMix = 0.12
        } else {
            p.fractalMix = 1
        }
        let mode = scene.fractalMode.lowercased()
        var geometry = edit.layer.fractalGeometryIndex
        if geometry == 0, mode.contains("mandel") {
            geometry = 1
        }
        p.fractalGeometryIndex = max(0, min(6, geometry))
        p.fractalSmoothShading = max(0, min(1, edit.layer.fractalSmoothShading))
        p.fractalExplore = edit.layer.fractalExplore
        p.fractalExploreSpeed = edit.layer.fractalExploreSpeed
        p.fractalPan = SIMD2(edit.layer.fractalPanX, edit.layer.fractalPanY)
        p.fractalIterBoost = max(0.25, min(3, edit.layer.fractalIterBoost))
        p.zoomEffectType = max(0, min(2, edit.layer.zoomEffectType))
        p.liquidTilt = SIMD2(edit.layer.liquidTiltX, edit.layer.liquidTiltY)
        p.dyeMix = scene.liquidLightEnabled ? max(0, min(1, edit.layer.dyeMix)) : 0
        p.compositeBloomStrength = max(0, min(0.85, edit.layer.compositeBloomStrength))
        p.compositeVignetteStrength = max(0, min(1, edit.layer.compositeVignetteStrength))
        p.spectrumWarpAmount = max(0, min(1, edit.layer.spectrumWarpAmount))
        p.dyeLayerViscosity = Self.dyeViscositySIMD8(from: edit.layer.liquidDropperLayers)
        p.liquidDissolveHold = max(0, min(1, edit.layer.liquidDissolveHold))
        p.liquidReconstituteAmount = max(0, min(1, edit.layer.liquidReconstituteAmount))
        p.liquidReconstituteRate = max(0.05, min(3, edit.layer.liquidReconstituteRate))
        p.liquidReconstituteBPMSync = edit.layer.liquidReconstituteBPMSync
        p.fractalZoom = edit.layer.fractalZoom
        p.liquidTurbulence = edit.layer.liquidTurbulence
        p.compositeBlend = edit.layer.compositeBlend
        p.liquidFocus = edit.layer.liquidFocus
        p.fractalAppearance = edit.layer.fractalAppearance
        p.overlayFractalFusion = edit.layer.overlayFractalFusion
        p.overlayOpacity = overlayOpacity
        let l = edit.layer
        let rect = Self.clampedOverlayRect(
            SIMD4(l.overlayRectMinX, l.overlayRectMinY, l.overlayRectWidth, l.overlayRectHeight)
        )
        p.overlayRectNorm = rect
        p.palettePrimary = c0
        p.paletteSecondary = c1
        p.paletteAccent = c2
        p.paletteGlow = c3
    }

    @MainActor
    func refreshScenePreviewPool() {
        guard metalRenderer != nil else {
            scenePreviewRenderers = [:]
            return
        }
        var next = scenePreviewRenderers
        let active = Set(sceneManager.scenes.map(\.id))
        for id in next.keys where !active.contains(id) {
            next.removeValue(forKey: id)
        }
        for scene in sceneManager.scenes where next[scene.id] == nil {
            if let r = CompositeRenderer.create() {
                next[scene.id] = r
            }
        }
        scenePreviewRenderers = next
    }

    @MainActor
    private func syncScenePreviewRenderers() {
        guard !scenePreviewRenderers.isEmpty else { return }
        for scene in sceneManager.scenes {
            guard let r = scenePreviewRenderers[scene.id] else { continue }
            r.parameters = makeRenderParameters(for: scene)
            if overlayEnabled,
               let oid = scene.overlayIDs.first,
               let asset = overlays.first(where: { $0.id == oid }) {
                r.overlayTexture = cachedOverlayTexture(filePath: asset.filePath, device: r.device)
            } else {
                r.overlayTexture = nil
            }
        }
    }

    private func cachedOverlayTexture(filePath: String, device: MTLDevice) -> MTLTexture? {
        if let t = overlayTextureCache[filePath] { return t }
        let url = URL(fileURLWithPath: filePath)
        let loader = MTKTextureLoader(device: device)
        guard let tex = try? loader.newTexture(URL: url, options: [.SRGB: false]) else { return nil }
        overlayTextureCache[filePath] = tex
        return tex
    }

    private func effectivePalette(for scene: VisualizationScene) -> ThemePalette? {
        let pid = scene.paletteID ?? selectedPaletteID
        if let id = pid, let match = palettes.first(where: { $0.id == id }) { return match }
        return palettes.first
    }

    /// Loads the first overlay image in the current scene (if any) for GPU compositing.
    @MainActor
    func syncOverlayGPUResources() {
        guard let main = metalRenderer else { return }
        let device = main.device
        guard overlayEnabled,
              sceneManager.scenes.indices.contains(sceneManager.currentIndex)
        else {
            main.overlayTexture = nil
            externalOutputRenderer?.overlayTexture = nil
            obsStreamRenderer?.overlayTexture = nil
            return
        }
        let scene = sceneManager.scenes[sceneManager.currentIndex]
        guard let oid = scene.overlayIDs.first,
              let asset = overlays.first(where: { $0.id == oid })
        else {
            main.overlayTexture = nil
            externalOutputRenderer?.overlayTexture = nil
            obsStreamRenderer?.overlayTexture = nil
            return
        }
        let url = URL(fileURLWithPath: asset.filePath)
        let loader = MTKTextureLoader(device: device)
        do {
            let tex = try loader.newTexture(URL: url, options: [.SRGB: false])
            main.overlayTexture = tex
            externalOutputRenderer?.overlayTexture = tex
            if main.device === obsStreamRenderer?.device {
                obsStreamRenderer?.overlayTexture = tex
            }
        } catch {
            main.overlayTexture = nil
            externalOutputRenderer?.overlayTexture = nil
            obsStreamRenderer?.overlayTexture = nil
        }
    }

    @MainActor
    func addPalette(_ palette: ThemePalette) {
        palettes.append(palette)
        try? PaletteLibraryStore.save(palettes)
        syncRendererFromScene()
    }

    @MainActor
    func updatePalette(id: UUID, with palette: ThemePalette) {
        guard let idx = palettes.firstIndex(where: { $0.id == id }) else { return }
        palettes[idx] = palette
        try? PaletteLibraryStore.save(palettes)
        syncRendererFromScene()
    }

    @MainActor
    func deletePalette(id: UUID) {
        guard palettes.count > 1, let idx = palettes.firstIndex(where: { $0.id == id }) else { return }
        palettes.remove(at: idx)
        if selectedPaletteID == id {
            selectedPaletteID = palettes.first?.id
        }
        for i in sceneManager.scenes.indices where sceneManager.scenes[i].paletteID == id {
            sceneManager.scenes[i].paletteID = selectedPaletteID
        }
        try? PaletteLibraryStore.save(palettes)
        try? persistScenes()
        syncRendererFromScene()
    }

    func saveCurrentLiquidDropperPalette(name: String) {
        guard sceneManager.scenes.indices.contains(sceneManager.currentIndex) else { return }
        let sceneID = sceneManager.scenes[sceneManager.currentIndex].id
        let edit = sceneEditStates[sceneID] ?? SceneEditState()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let palette = LiquidDropperPalette(
            name: trimmedName.isEmpty ? "Liquid palette \(liquidPalettes.count + 1)" : trimmedName,
            layers: edit.layer.liquidDropperLayers
        )
        liquidPalettes.append(palette)
        try? LiquidPaletteLibraryStore.save(liquidPalettes)
    }

    @MainActor
    func applyLiquidDropperPalette(id: UUID) {
        guard let palette = liquidPalettes.first(where: { $0.id == id }) else { return }
        mutateCurrentEdit { edit in
            edit.layer.liquidDropperLayers = Array(palette.layers.prefix(SceneEditState.LayerControls.maxDropperLayers))
            if edit.layer.liquidDropperLayers.isEmpty {
                edit.layer.liquidDropperLayers = SceneEditState.LayerControls.defaultDropperLayers
            }
            edit.layer.activeDropperLayerIndex = max(
                0,
                min(edit.layer.liquidDropperLayers.count - 1, edit.layer.activeDropperLayerIndex)
            )
        }
    }

    @MainActor
    private func updateAllVisualizationRenderers(_ update: (inout RenderParameters) -> Void) {
        metalRenderer?.updateParameters(update)
        externalOutputRenderer?.updateParameters(update)
        obsStreamRenderer?.updateParameters(update)
    }

    private static func clampedOverlayRect(_ r: SIMD4<Float>) -> SIMD4<Float> {
        let minSide: Float = 0.05
        let w = min(max(r.z, minSide), 1)
        let h = min(max(r.w, minSide), 1)
        let x = min(max(r.x, 0), 1 - w)
        let y = min(max(r.y, 0), 1 - h)
        return SIMD4(x, y, w, h)
    }

    func currentOverlayRectNorm() -> SIMD4<Float> {
        guard sceneManager.scenes.indices.contains(sceneManager.currentIndex) else {
            return SIMD4(0, 0, 1, 1)
        }
        let id = sceneManager.scenes[sceneManager.currentIndex].id
        let l = (sceneEditStates[id] ?? SceneEditState()).layer
        return Self.clampedOverlayRect(SIMD4(l.overlayRectMinX, l.overlayRectMinY, l.overlayRectWidth, l.overlayRectHeight))
    }

    @MainActor
    func resetOverlayRectToFullFrame() {
        mutateCurrentEdit {
            $0.layer.overlayRectMinX = 0
            $0.layer.overlayRectMinY = 0
            $0.layer.overlayRectWidth = 1
            $0.layer.overlayRectHeight = 1
        }
    }

    @MainActor
    func applyOverlayDragFromStart(_ start: SIMD4<Float>, translation: SIMD2<Float>) {
        let x = start.x + translation.x
        let y = start.y + translation.y
        let r = Self.clampedOverlayRect(SIMD4(x, y, start.z, start.w))
        mutateCurrentEdit {
            $0.layer.overlayRectMinX = r.x
            $0.layer.overlayRectMinY = r.y
            $0.layer.overlayRectWidth = r.z
            $0.layer.overlayRectHeight = r.w
        }
    }

    @MainActor
    func applyOverlayPinchFromStart(_ start: SIMD4<Float>, scale: CGFloat) {
        let s = Float(scale)
        let cx = start.x + start.z * 0.5
        let cy = start.y + start.w * 0.5
        var nw = start.z * s
        var nh = start.w * s
        nw = min(max(nw, 0.05), 1)
        nh = min(max(nh, 0.05), 1)
        let nx = cx - nw * 0.5
        let ny = cy - nh * 0.5
        let r = Self.clampedOverlayRect(SIMD4(nx, ny, nw, nh))
        mutateCurrentEdit {
            $0.layer.overlayRectMinX = r.x
            $0.layer.overlayRectMinY = r.y
            $0.layer.overlayRectWidth = r.z
            $0.layer.overlayRectHeight = r.w
        }
    }

    private func clampExternalScreenIndex() {
        let list = ExternalDisplayRouter.screens
        guard !list.isEmpty else { return }
        if !list.indices.contains(externalOutputScreenIndex) {
            externalOutputScreenIndex = ExternalDisplayRouter.defaultPreferredScreenIndex()
        }
    }

    /// Fullscreens the **main app window** only (controls stay in this window).
    @MainActor
    func toggleMainWindowFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }

    /// Borderless edge-to-edge visualization on the chosen display. Main window stays put for controls.
    @MainActor
    func openExternalVisualizationFullscreen() {
        clampExternalScreenIndex()
        let screens = ExternalDisplayRouter.screens
        guard screens.indices.contains(externalOutputScreenIndex) else { return }
        let screen = screens[externalOutputScreenIndex]

        stopExternalVisualizationSession()

        guard let renderer = CompositeRenderer.create() else { return }
        if let previewParams = metalRenderer?.parameters {
            renderer.parameters = previewParams
        }
        clearRendererFrameLoop(renderer)

        externalOutputRenderer = renderer

        let rootView = VisualizationMetalView(renderer: renderer)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

        let hosting = NSHostingView(rootView: rootView)
        hosting.autoresizingMask = [.width, .height]

        let rect = ExternalDisplayRouter.performanceFrame(on: screen)
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = true
        window.backgroundColor = .black
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        hosting.frame = window.contentView?.bounds ?? .zero

        externalOutputWindow = window
        isExternalVisualizationOpen = true
        window.setFrame(rect, display: true, animate: false)
        syncOverlayGPUResources()
        window.orderFrontRegardless()
    }

    @MainActor
    func closeExternalVisualization() {
        stopExternalVisualizationSession()
    }

    @MainActor
    private func stopExternalVisualizationSession() {
        externalOutputWindow?.orderOut(nil)
        externalOutputWindow?.contentView = nil
        externalOutputWindow = nil
        externalOutputRenderer = nil
        isExternalVisualizationOpen = false
    }

    func startAudio() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let hasPermission = await self.ensureMicrophonePermissionForAudioStart()
            guard hasPermission else { return }
            self.audioEngine.refreshDevices()
            do {
                try self.audioEngine.start()
                self.audioError = nil
            } catch {
                self.audioError = error.localizedDescription
            }
        }
    }

    /// macOS persists microphone consent per app (bundle id) in System Settings until revoked. When the user enables access there, pick it up without requiring a manual retry.
    @MainActor
    private func handleAppDidBecomeActiveForMicrophonePermission() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        if audioError != nil {
            audioError = nil
        }
        if !audioEngine.isAudioInputRunning {
            startAudio()
        }
    }

    func stopAudio() {
        audioEngine.stop()
    }

    @MainActor
    func openMicrophonePrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    var isMicrophonePermissionDenied: Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .denied || status == .restricted
    }

    @MainActor
    private func requestMicrophoneAccessFromSystem() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    @MainActor
    private func ensureMicrophonePermissionForAudioStart() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await requestMicrophoneAccessFromSystem()
            if !granted {
                audioError = "Microphone permission is required for audio-reactive visuals. Enable access in System Settings > Privacy & Security > Microphone."
            }
            return granted
        case .denied, .restricted:
            audioError = "Microphone permission is required for audio-reactive visuals. Enable access in System Settings > Privacy & Security > Microphone."
            return false
        @unknown default:
            audioError = "Microphone permission state is unknown."
            return false
        }
    }

    func nextScene() {
        applyRemoteCommand(RemoteControlCommand(type: "NextScene"))
    }

    func previousScene() {
        applyRemoteCommand(RemoteControlCommand(type: "PreviousScene"))
    }

    func randomScene() {
        applyRemoteCommand(RemoteControlCommand(type: "RandomScene"))
    }

    func persistScenes() throws {
        try sceneLibrary.save(scenes: sceneManager.scenes)
    }

    func persistSceneControls() throws {
        try sceneControlStore.save(states: sceneEditStates)
    }

    func persistOverlays() throws {
        try overlayLibrary.save(overlays: overlays)
    }

    @MainActor
    func importOverlayAsset() {
        guard let picked = overlayLibrary.importOverlayViaOpenPanel() else { return }
        let sourceURL = URL(fileURLWithPath: picked.filePath)
        let storedURL: URL
        do {
            storedURL = try OverlayFileSupport.copyImportedOverlayToAppSupport(from: sourceURL, assetID: picked.id)
        } catch {
            storedURL = sourceURL
        }
        let asset = OverlayAsset(
            id: picked.id,
            name: picked.name,
            filePath: storedURL.path,
            opacity: picked.opacity,
            blendMode: picked.blendMode
        )
        overlays.append(asset)
        overlayTextureCache.removeAll()
        try? persistOverlays()
        if sceneManager.scenes.indices.contains(sceneManager.currentIndex) {
            var s = sceneManager.scenes[sceneManager.currentIndex]
            // GPU uses `overlayIDs.first`; replace so a new import becomes the active logo.
            s.overlayIDs = [asset.id]
            sceneManager.scenes[sceneManager.currentIndex] = s
            try? persistScenes()
        }
        resetOverlayRectToFullFrame()
        syncRendererFromScene()
    }

    /// Pick image → save PNG with black/near-black pixels removed → optionally register as current scene overlay.
    @MainActor
    func exportBlackBackgroundRemovedCopy() {
        let open = NSOpenPanel()
        open.allowedContentTypes = [.image]
        open.canChooseDirectories = false
        open.allowsMultipleSelection = false
        guard open.runModal() == .OK, let src = open.url else { return }

        let base = src.deletingPathExtension().lastPathComponent
        let save = NSSavePanel()
        save.allowedContentTypes = [.png]
        save.canCreateDirectories = true
        save.nameFieldStringValue = "\(base)-nomatte.png"
        guard save.runModal() == .OK, let destURL = save.url else { return }
        let outURL: URL = {
            if destURL.pathExtension.lowercased() == "png" { return destURL }
            return destURL.appendingPathExtension("png")
        }()

        do {
            try OverlayBlackBackgroundKnockout.knockOutBlackBackground(sourceURL: src, destinationURL: outURL)
        } catch {
            let a = NSAlert()
            a.messageText = "Could not process image"
            a.informativeText = error.localizedDescription
            a.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Saved matte PNG"
        alert.informativeText = outURL.path
        alert.addButton(withTitle: "Use as current overlay")
        alert.addButton(withTitle: "Done")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let id = UUID()
        let storedURL: URL
        do {
            storedURL = try OverlayFileSupport.copyImportedOverlayToAppSupport(from: outURL, assetID: id)
        } catch {
            storedURL = outURL
        }
        let asset = OverlayAsset(
            id: id,
            name: outURL.deletingPathExtension().lastPathComponent,
            filePath: storedURL.path,
            opacity: 1,
            blendMode: OverlayBlendMode.screen.rawValue
        )
        overlays.append(asset)
        overlayTextureCache.removeAll()
        try? persistOverlays()
        if sceneManager.scenes.indices.contains(sceneManager.currentIndex) {
            var s = sceneManager.scenes[sceneManager.currentIndex]
            s.overlayIDs = [asset.id]
            sceneManager.scenes[sceneManager.currentIndex] = s
            try? persistScenes()
        }
        resetOverlayRectToFullFrame()
        syncRendererFromScene()
    }

    func advanceTransition(by delta: Float) {
        transitionState.advance(by: delta)
    }

    // MARK: - Lighting / DMX documents

    /// USB DMX output worker status; when output is disabled in Settings the service may be stopped (`running` false).
    func dmxOutputDiagnostics() -> (lastError: String?, running: Bool, nominalHz: Double, packetsLastTimerTick: Int) {
        dmxService?.extendedDiagnostics() ?? (nil, false, 44.0, 0)
    }

    /// Returns simulated DMX transport details when running in simulation mode.
    func dmxSimulationSnapshot() -> (mode: String, info: String, universe: [UInt8])? {
        dmxService?.simulationSnapshot()
    }

    func dmxInboundDiagnostics() -> (diagnostics: DMXInboundDiagnostics, status: String) {
        var d = dmxInputService?.diagnostics() ?? .none
        if let s = dmxOpenDMXInputService {
            d.openDMXSerialRunning = s.isRunning
            d.openDMXSerialFrames = s.receivedFrameCount
            d.openDMXSerialLastError = s.lastError
        }
        return (d, dmxInboundStatus)
    }

    func dmxPerformanceDiagnostics() -> DMXPerformanceSnapshot {
        dmxService?.performanceSnapshot() ?? DMXPerformanceSnapshot(
            frameCount: 0,
            overBudgetFrameCount: 0,
            avgBuildMS: 0,
            avgSendMS: 0,
            avgTotalMS: 0,
            maxBuildMS: 0,
            maxSendMS: 0,
            maxTotalMS: 0,
            totalMSHistogramBinCounts: [UInt64](repeating: 0, count: DMXPerformanceProfiler.totalMSHistogramBinCount),
            rigFixtureInstanceCount: 0,
            rigModulatorCount: 0,
            outputLogicalUniverseCount: 0,
            approxMedianTotalMS: nil,
            approxP95TotalMS: nil,
            approxMedianBuildMS: nil,
            approxP95BuildMS: nil,
            approxMedianSendMS: nil,
            approxP95SendMS: nil,
            exactMedianTotalMS: nil,
            exactP95TotalMS: nil,
            exactMedianBuildMS: nil,
            exactP95BuildMS: nil,
            exactMedianSendMS: nil,
            exactP95SendMS: nil
        )
    }

    /// Clears DMX output frame timing accumulators (histogram, averages, maxima). No-op if `DMXOutputService` was never created (enable DMX output once to allocate it).
    func resetDMXPerformanceProfiler() {
        dmxService?.resetPerformanceProfiler()
    }

    /// Fixture / modulation counts for DMX frame profiler (call from DMX output queue).
    func dmxRigMetricsForProfiling(outputLogicalUniverseCount: Int) -> (fixtureInstances: Int, modulators: Int, outputLogicalUniverses: Int) {
        lightingDMXLock.lock()
        let fi = dmxPatchDocument.instances.count
        let mo = modulationDocument.modulators.count
        lightingDMXLock.unlock()
        return (fi, mo, outputLogicalUniverseCount)
    }

    @MainActor
    func startRDMDiscoveryProbe() {
        guard remoteSettings.rdmDiscoveryEnabled else {
            rdmDiscoveryStatus = "Enable RDM discovery scaffold in Settings first."
            return
        }
        rdmDiscoveryStatus = "Running RDM probe..."
        Task {
            let result = await rdmDiscoveryService.runProbe(
                mode: remoteSettings.rdmDiscoveryTransportMode,
                universe: remoteSettings.rdmDiscoveryUniverse,
                serialPath: remoteSettings.dmxSerialDevicePath,
                artNetHost: remoteSettings.dmxArtNetHost
            )
            await MainActor.run {
                rdmDiscoveryResult = result
                rdmDiscoveryStatus = "Probe complete: \(result.devices.count) device(s) on universe \(result.universe)."
            }
        }
    }

    /// DMX channel → value from the active cue and any in-progress crossfade (matches output timing when `time` is `CFAbsoluteTimeGetCurrent()`).
    func resolvedCueChannelMap(at time: TimeInterval) -> [Int: UInt8] {
        lightingDMXLock.lock()
        let doc = lightingCueDocument
        let xf = lightingCueCrossfade
        lightingDMXLock.unlock()
        return LightingCueResolver.resolveChannelMap(document: doc, crossfade: xf, now: time)
    }

    func buildDMXUniverse(time: TimeInterval, lastSmoothed: inout [UUID: Float]) -> [UInt8] {
        lightingDMXLock.lock()
        let patch = dmxPatchDocument
        let cueDoc = lightingCueDocument
        let modDoc = modulationDocument
        let xf = lightingCueCrossfade
        let envStart = hazeEnvelopeStartedAt
        let bpm = tempoClock.effectiveBPM
        let beatPhase = tempoClock.beatPhase
        let audio = audioEngine.features
        let inboundSnap = inboundDMXByUniverse
        lightingDMXLock.unlock()

        var cueMap = LightingCueResolver.resolveChannelMap(document: cueDoc, crossfade: xf, now: time)
        let activeCue: LightingCue? = {
            guard let ai = cueDoc.activeCueIndex, cueDoc.cues.indices.contains(ai) else { return nil }
            return cueDoc.cues[ai]
        }()
        FogHazeCueEnvelope.merge(
            cueMap: &cueMap,
            activeCue: activeCue,
            patch: patch,
            envelopeStartedAt: envStart,
            now: time
        )
        let offsets = ModulationRuntime.offsets(
            document: modDoc,
            patch: patch,
            time: time,
            bpm: bpm,
            beatPhase: beatPhase,
            audio: audio,
            lastSmoothed: &lastSmoothed
        )
        var universe = DMXUniverseBuilder.build(
            model: self,
            patch: patch,
            cueChannelMap: cueMap,
            modulationOffsets: offsets,
            hazeEmergencyKill: hazeEmergencyKillActive
        )
        // Single-universe (USB) output: merge inbound for the configured **start** universe into local universe 0.
        if remoteSettings.dmxInboundEnabled || remoteSettings.dmxInboundOpenDMXEnabled,
           let entry = inboundSnap[remoteSettings.dmxInboundUniverse],
           entry.frame.count == 512,
           remoteSettings.dmxInboundMergeMode == "htp" || remoteSettings.dmxInboundMergeMode == "lpt" {
            let now = CFAbsoluteTimeGetCurrent()
            if DMXInboundMergeLogic.isFrameFresh(receivedAt: entry.receivedAt, now: now) {
                if remoteSettings.dmxInboundMergeMode == "htp" {
                    DMXInboundMergeLogic.applyHTPMerge(software: &universe, inbound: entry.frame)
                } else {
                    DMXInboundMergeLogic.applyLTPMergeReplaceUniverse(software: &universe, inbound: entry.frame)
                }
            }
        }
        return universe
    }

    /// Multiple logical universes for Art-Net / sACN (one UDP packet per universe). Inbound merge applies per logical universe when a matching wire universe was received.
    func buildDMXUniversesForNetwork(time: TimeInterval, lastSmoothed: inout [UUID: Float]) -> [Int: [UInt8]] {
        lightingDMXLock.lock()
        let patch = dmxPatchDocument
        let cueDoc = lightingCueDocument
        let modDoc = modulationDocument
        let xf = lightingCueCrossfade
        let envStart = hazeEnvelopeStartedAt
        let bpm = tempoClock.effectiveBPM
        let beatPhase = tempoClock.beatPhase
        let audio = audioEngine.features
        let inboundSnap = inboundDMXByUniverse
        lightingDMXLock.unlock()

        var cueMap = LightingCueResolver.resolveChannelMap(document: cueDoc, crossfade: xf, now: time)
        let activeCue: LightingCue? = {
            guard let ai = cueDoc.activeCueIndex, cueDoc.cues.indices.contains(ai) else { return nil }
            return cueDoc.cues[ai]
        }()
        FogHazeCueEnvelope.merge(
            cueMap: &cueMap,
            activeCue: activeCue,
            patch: patch,
            envelopeStartedAt: envStart,
            now: time
        )
        let offsets = ModulationRuntime.offsets(
            document: modDoc,
            patch: patch,
            time: time,
            bpm: bpm,
            beatPhase: beatPhase,
            audio: audio,
            lastSmoothed: &lastSmoothed
        )
        var perU = DMXUniverseBuilder.buildPerUniverse(
            model: self,
            patch: patch,
            cueChannelMap: cueMap,
            modulationOffsets: offsets,
            hazeEmergencyKill: hazeEmergencyKillActive
        )
        if remoteSettings.dmxInboundEnabled || remoteSettings.dmxInboundOpenDMXEnabled,
           remoteSettings.dmxInboundMergeMode == "htp" || remoteSettings.dmxInboundMergeMode == "lpt" {
            let now = CFAbsoluteTimeGetCurrent()
            for logicalID in perU.keys {
                guard var buf = perU[logicalID] else { continue }
                guard let entry = inboundSnap[logicalID], entry.frame.count == 512 else { continue }
                guard DMXInboundMergeLogic.isFrameFresh(receivedAt: entry.receivedAt, now: now) else { continue }
                if remoteSettings.dmxInboundMergeMode == "htp" {
                    DMXInboundMergeLogic.applyHTPMerge(software: &buf, inbound: entry.frame)
                } else {
                    DMXInboundMergeLogic.applyLTPMergeReplaceUniverse(software: &buf, inbound: entry.frame)
                }
                perU[logicalID] = buf
            }
        }
        return perU
    }

    func applyDMXPatchDocument(_ doc: DMXPatchDocument) {
        lightingDMXLock.lock()
        dmxPatchDocument = doc
        lightingDMXLock.unlock()
        try? DMXPatchStore.save(doc)
        objectWillChange.send()
        scheduleAIContextRefresh()
    }

    func applyLightingCueDocument(_ doc: LightingCueDocument) {
        lightingDMXLock.lock()
        lightingCueDocument = doc
        lightingDMXLock.unlock()
        try? LightingCueStore.save(doc)
        objectWillChange.send()
        scheduleAIContextRefresh()
    }

    func setHazeEmergencyKill(_ active: Bool) {
        hazeEmergencyKillActive = active
    }

    func startFogHazeLearn(targetCueID: UUID, hazerInstanceID: UUID, webcam: WebcamCaptureService) {
        fogHazeLearnTask?.cancel()
        fogHazeLearnPhase = ""
        fogHazeLearnTask = Task { @MainActor in
            defer { fogHazeLearnTask = nil }
            do {
                try await FogHazeLearnService.run(
                    app: self,
                    webcam: webcam,
                    targetCueID: targetCueID,
                    hazerInstanceID: hazerInstanceID
                ) { msg in
                    self.fogHazeLearnPhase = msg
                }
            } catch {
                if error is CancellationError {
                    self.fogHazeLearnPhase = "Cancelled."
                } else {
                    self.fogHazeLearnPhase = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    func cancelFogHazeLearn() {
        fogHazeLearnTask?.cancel()
    }

    func startFixtureVerification(
        primaryWebcam: WebcamCaptureService,
        primaryDeviceUniqueID: String?,
        secondaryWebcam: WebcamCaptureService?,
        secondaryDeviceUniqueID: String?
    ) {
        if !stageLayoutDocument.primaryScanCamera.isEnabled {
            fixtureVerificationPhase = "Enable and position the primary scan camera on the stage plot, then resume scan."
            return
        }
        fixtureVerificationExposureHint = nil
        fixtureVerificationPhase = "Preparing fixture verification…"
        fixtureVerificationTask?.cancel()
        let outputFolder = contextParentFolder()
        fixtureVerificationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await primaryWebcam.startIfAuthorized(preferredDeviceUniqueID: primaryDeviceUniqueID)
            } catch {
                fixtureVerificationPhase = "Primary camera error: \(error.localizedDescription)"
                return
            }
            var usingSecondary = false
            if let secondaryWebcam,
               stageLayoutDocument.secondaryScanCamera.isEnabled {
                do {
                    try await secondaryWebcam.startIfAuthorized(preferredDeviceUniqueID: secondaryDeviceUniqueID)
                    usingSecondary = true
                } catch {
                    fixtureVerificationPhase = "Secondary camera unavailable; continuing with primary only."
                }
            }
            defer {
                primaryWebcam.stop()
                if usingSecondary {
                    secondaryWebcam?.stop()
                }
            }

            let originalPatch = dmxPatchDocument
            defer { applyDMXPatchDocument(originalPatch) }
            let fixtures = originalPatch.instances
            var results: [FixtureVerificationFixtureResult] = []
            var runStatus: FixtureVerificationRunStatus = .completed
            for (idx, inst) in fixtures.enumerated() {
                if Task.isCancelled {
                    runStatus = .cancelled
                    break
                }
                if !primaryWebcam.isRunning {
                    do {
                        try await primaryWebcam.startIfAuthorized(preferredDeviceUniqueID: primaryDeviceUniqueID)
                        fixtureVerificationPhase = "Primary camera reconnected; resuming verification…"
                    } catch {
                        runStatus = .pausedPrimaryCameraDisconnected
                        break
                    }
                }
                guard let profile = originalPatch.profile(id: inst.profileID) else { continue }
                let channelIndex = FixtureVerificationService.bestProbeChannel(profile: profile)
                let expected = stageLayoutDocument.placements[inst.id.uuidString]
                let baselinePrimary = await FixtureVerificationService.sampleLuma(webcam: primaryWebcam, seconds: 0.25)
                var secondaryReadyForThisFixture = false
                if usingSecondary, let secondaryWebcam {
                    if !secondaryWebcam.isRunning {
                        do {
                            try await secondaryWebcam.startIfAuthorized(preferredDeviceUniqueID: secondaryDeviceUniqueID)
                        } catch {
                            usingSecondary = false
                            fixtureVerificationPhase = "Secondary camera disconnected; continuing with primary camera."
                        }
                    }
                    secondaryReadyForThisFixture = usingSecondary && secondaryWebcam.isRunning
                }
                let baselineSecondary: Double = if secondaryReadyForThisFixture, let secondaryWebcam {
                    await FixtureVerificationService.sampleLuma(webcam: secondaryWebcam, seconds: 0.25)
                } else {
                    baselinePrimary
                }
                setFixtureVerificationManual(fixtureID: inst.id, channelIndex: channelIndex, value: 255)
                let litPrimary = await FixtureVerificationService.sampleLuma(webcam: primaryWebcam, seconds: 0.25)
                let litSecondary: Double = if secondaryReadyForThisFixture, let secondaryWebcam {
                    await FixtureVerificationService.sampleLuma(webcam: secondaryWebcam, seconds: 0.25)
                } else {
                    litPrimary
                }
                setFixtureVerificationManual(fixtureID: inst.id, channelIndex: channelIndex, value: 0)
                let resolved = FixtureVerificationService.resolvedProbeDelta(
                    primaryBaseline: baselinePrimary,
                    primaryLit: litPrimary,
                    secondaryBaseline: secondaryReadyForThisFixture ? baselineSecondary : nil,
                    secondaryLit: secondaryReadyForThisFixture ? litSecondary : nil
                )
                let delta = resolved.delta
                let exposureHint = FixtureVerificationEvaluator.exposureHint(
                    primaryBaseline: baselinePrimary,
                    primaryLit: litPrimary,
                    secondaryBaseline: secondaryReadyForThisFixture ? baselineSecondary : nil,
                    secondaryLit: secondaryReadyForThisFixture ? litSecondary : nil,
                    observedDelta: delta
                )
                if let exposureHint {
                    fixtureVerificationExposureHint = exposureHint
                }
                results.append(
                    FixtureVerificationFixtureResult(
                        fixtureID: inst.id,
                        fixtureName: profile.name,
                        fixtureIndex: idx + 1,
                        startAddress: inst.startAddress,
                        channelSpan: profile.channels.count,
                        expectedPlacement: expected,
                        observedLumaDelta: delta,
                        patching: FixtureVerificationEvaluator.patchingResult(lumaDelta: delta, threshold: 0.03),
                        quantity: FixtureVerificationEvaluator.quantityResult(expected: fixtures.count, scanned: idx + 1),
                        layout: FixtureVerificationEvaluator.layoutResult(expectedPlacement: expected),
                        orientation: FixtureVerificationEvaluator.orientationResult(profile: profile, placement: expected)
                    )
                )
                let baseStatus = "Verified fixture \(idx + 1)/\(fixtures.count): \(profile.name)\(usingSecondary ? " (dual camera)" : "")"
                fixtureVerificationPhase = exposureHint.map { "\(baseStatus) • \($0)" } ?? baseStatus
            }
            let report = FixtureVerificationDocument(
                fixtureCountExpected: fixtures.count,
                fixtureCountScanned: results.count,
                notes: FixtureVerificationEvaluator.notesText(status: runStatus, usedSecondary: usingSecondary),
                fixtures: results
            )
            fixtureVerificationReport = report
            FixtureVerificationService.persist(report: report, outputFolder: outputFolder)
            exportAIContextNow(targetRoot: outputFolder)
            fixtureVerificationPhase = FixtureVerificationEvaluator.phaseText(status: runStatus, scanned: results.count, expected: fixtures.count)
        }
    }

    func cancelFixtureVerification() {
        fixtureVerificationTask?.cancel()
        fixtureVerificationPhase = "Cancelled."
    }

    private func setFixtureVerificationManual(fixtureID: UUID, channelIndex: Int, value: UInt8) {
        var doc = dmxPatchDocument
        for idx in doc.instances.indices {
            guard let profile = doc.profile(id: doc.instances[idx].profileID) else { continue }
            for channel in profile.channels.indices {
                let level: UInt8 = (doc.instances[idx].id == fixtureID && channel == channelIndex) ? value : 0
                doc.instances[idx].setManual(channelIndex: channel, value: level)
            }
        }
        applyDMXPatchDocument(doc)
    }

    func setActiveLightingCueIndex(_ newIndex: Int?) {
        lightingDMXLock.lock()
        var doc = lightingCueDocument
        let old = doc.activeCueIndex
        doc.activeCueIndex = newIndex
        lightingCueDocument = doc
        if newIndex != nil {
            hazeEnvelopeStartedAt = CFAbsoluteTimeGetCurrent()
        } else {
            hazeEnvelopeStartedAt = nil
        }
        let fadeDur: Double = {
            guard let ni = newIndex, doc.cues.indices.contains(ni) else { return 0 }
            return doc.cues[ni].fadeSeconds
        }()
        if let ni = newIndex, let oi = old, oi != ni, fadeDur > 0,
           doc.cues.indices.contains(oi), doc.cues.indices.contains(ni) {
            lightingCueCrossfade = LightingCueCrossfade(
                fromIndex: oi,
                toIndex: ni,
                startedAt: CFAbsoluteTimeGetCurrent(),
                durationSeconds: fadeDur
            )
        } else {
            lightingCueCrossfade = nil
        }
        lightingDMXLock.unlock()
        if old != newIndex {
            resetOverlayElementTimers()
        }
        try? LightingCueStore.save(lightingCueDocument)
        objectWillChange.send()
        scheduleAIContextRefresh()
    }

    func applyModulationDocument(_ doc: ModulationDocument) {
        lightingDMXLock.lock()
        modulationDocument = doc
        lightingDMXLock.unlock()
        try? ModulationStore.save(doc)
        objectWillChange.send()
        scheduleAIContextRefresh()
    }

    func applyStageLayoutDocument(_ doc: StageLayoutDocument) {
        lightingDMXLock.lock()
        stageLayoutDocument = doc
        lightingDMXLock.unlock()
        try? StageLayoutStore.save(doc)
        objectWillChange.send()
        scheduleAIContextRefresh()
    }

    func applyBackdropCueDocument(_ doc: BackdropCueDocument) {
        backdropCueDocument = doc
        try? BackdropCueStore.save(doc)
        objectWillChange.send()
        scheduleAIContextRefresh()
    }

    func setActiveBackdropCueIndex(_ newIndex: Int?) {
        var doc = backdropCueDocument
        doc.activeCueIndex = newIndex
        backdropCueDocument = doc
        try? BackdropCueStore.save(backdropCueDocument)
        if let ni = newIndex, doc.cues.indices.contains(ni) {
            applyStageLayoutDocument(doc.cues[ni].layoutSnapshot)
        }
        objectWillChange.send()
        scheduleAIContextRefresh()
    }

    func applyBackdropCueIndex(_ index: Int) {
        setActiveBackdropCueIndex(index)
    }

    func applyOverlayCardDocument(_ doc: OverlayCardDocument) {
        overlayCardDocument = doc
        resetOverlayElementTimers()
        try? OverlayCardStore.save(doc)
        objectWillChange.send()
        scheduleAIContextRefresh()
    }

    func activeLightingCueID() -> UUID? {
        lightingDMXLock.lock()
        let doc = lightingCueDocument
        lightingDMXLock.unlock()
        guard let idx = doc.activeCueIndex, doc.cues.indices.contains(idx) else { return nil }
        return doc.cues[idx].id
    }

    func activeLightingCueBookmarkMetadata() -> [String: String] {
        guard let cueID = activeLightingCueID() else { return [:] }
        lightingDMXLock.lock()
        let doc = lightingCueDocument
        lightingDMXLock.unlock()
        return doc.bookmarkMetadata(cueID: cueID)
    }

    func resolvedOverlayText(for layer: OverlayCardTextLayer) -> String {
        guard let key = layer.metadataKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            return layer.text
        }
        let metadata = activeLightingCueBookmarkMetadata()
        return metadata[key] ?? layer.text
    }

    func shouldRenderOverlayElement(id: UUID, timeoutSeconds: Double?) -> Bool {
        guard let timeoutSeconds, timeoutSeconds > 0 else { return true }
        let activated = overlayElementActivatedAt[id] ?? Date()
        if overlayElementActivatedAt[id] == nil {
            overlayElementActivatedAt[id] = activated
        }
        return Date().timeIntervalSince(activated) <= timeoutSeconds
    }

    func resetOverlayElementTimers(now: Date = Date()) {
        var next: [UUID: Date] = [:]
        for shape in overlayCardDocument.shapes {
            next[shape.id] = now
        }
        for text in overlayCardDocument.texts {
            next[text.id] = now
        }
        overlayElementActivatedAt = next
    }

    func appendLightingCues(_ extra: [LightingCue]) {
        lightingDMXLock.lock()
        var doc = lightingCueDocument
        doc.cues.append(contentsOf: extra)
        lightingCueDocument = doc
        lightingDMXLock.unlock()
        try? LightingCueStore.save(lightingCueDocument)
        objectWillChange.send()
        scheduleAIContextRefresh()
    }

    // MARK: - Show project + AI context

    func scheduleAIContextRefresh() {
        contextRefreshTask?.cancel()
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, !Task.isCancelled else { return }
            self.exportAIContextNow()
        }
        contextRefreshTask = task
    }

    func exportAIContextNow(targetRoot: URL? = nil) {
        let parent = targetRoot ?? contextParentFolder()
        do {
            let snap = makeContextSnapshot()
            let (json, md) = try ShowContextGenerator.generate(snap: snap)
            try ShowContextDiskLayout.write(json: json, markdown: md, into: parent)
        } catch {
            aiAssistantLastMessage = "Context export failed: \(error.localizedDescription)"
        }
    }

    private func contextParentFolder() -> URL {
        if let currentShowProjectFolder { return currentShowProjectFolder }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
    }

    func projectRecordingsFolderURL() -> URL {
        let base = contextParentFolder()
        let out = base
            .appendingPathComponent("Media", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        return out
    }

    func projectArtifactsFolderURL() -> URL {
        let base = contextParentFolder()
        let out = base.appendingPathComponent("Artifacts", isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        return out
    }

    func projectBackupsFolderURL() -> URL {
        let base = contextParentFolder()
        let out = base.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        return out
    }

    @MainActor
    func startLiveOutputRecording(preferredMainWindowNumber: Int?) {
        guard !isLiveOutputRecording else { return }
        let source = liveOutputRecordingSource
        let qualityPreset = liveOutputRecordingQualityPreset
        let windowNumber: Int?
        switch source {
        case .mainLivePreview:
            windowNumber = preferredMainWindowNumber ?? NSApp.mainWindow?.windowNumber
        case .externalOutput:
            windowNumber = externalOutputWindow?.windowNumber
        }
        guard let windowNumber else {
            liveOutputRecordingStatus = "Recording source is unavailable."
            liveOutputRecordingAudioDiagnostic = "Audio source is not evaluated until recording starts."
            return
        }
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let fileName = "live-output-\(source.rawValue)-\(timestamp).mov"
        let outURL = projectRecordingsFolderURL().appendingPathComponent(fileName)
        let preferredAudioName = audioEngine.selectedInputDeviceID
            .flatMap { did in audioEngine.availableInputDevices.first(where: { $0.id == did })?.name }
        let channelModeLabel: String = {
            switch audioEngine.selectedInputChannelSelection {
            case .mixAll: "mix-all"
            case let .mono(index): "mono-\(index + 1)"
            case let .stereoPair(startIndex): "stereo-\(startIndex + 1)/\(startIndex + 2)"
            }
        }()
        do {
            try captureSession.begin(
                windowNumber: CGWindowID(windowNumber),
                outputURL: outURL,
                preferredAudioDeviceName: preferredAudioName,
                quality: qualityPreset.captureQuality
            )
            isLiveOutputRecording = true
            liveOutputRecordingStartedAt = Date()
            liveOutputRecordingAudioDiagnostic = captureSession.audioDiagnosticMessage
            liveOutputRecordingStatus = "Recording… \(qualityPreset.title), audio input mode: \(channelModeLabel)"
        } catch {
            liveOutputRecordingStatus = "Recording failed to start: \(error.localizedDescription)"
            liveOutputRecordingAudioDiagnostic = captureSession.audioDiagnosticMessage
        }
    }

    @MainActor
    func liveOutputRecorderHealthItems(preferredMainWindowNumber: Int?) -> [LiveOutputRecorderHealthItem] {
        var items: [LiveOutputRecorderHealthItem] = []
        let windowAvailable: Bool = {
            switch liveOutputRecordingSource {
            case .mainLivePreview:
                return (preferredMainWindowNumber ?? NSApp.mainWindow?.windowNumber) != nil
            case .externalOutput:
                return externalOutputWindow?.windowNumber != nil
            }
        }()
        items.append(
            LiveOutputRecorderHealthItem(
                message: windowAvailable
                    ? "Video source available."
                    : "Selected video source unavailable. Open the target output first.",
                isHealthy: windowAvailable
            )
        )

        let screenAllowed: Bool = {
            if #available(macOS 10.15, *) {
                return CGPreflightScreenCaptureAccess()
            }
            return true
        }()
        if let screenMessage = Self.screenCapturePermissionHealthMessage(isGranted: screenAllowed) {
            items.append(
                LiveOutputRecorderHealthItem(
                    message: screenMessage,
                    isHealthy: screenAllowed
                )
            )
        }

        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if let audioMessage = Self.audioPermissionHealthMessage(status: audioStatus) {
            items.append(
                LiveOutputRecorderHealthItem(
                    message: audioMessage,
                    isHealthy: audioStatus == .authorized
                )
            )
        }
        return items
    }

    static func screenCapturePermissionHealthMessage(isGranted: Bool) -> String? {
        isGranted
            ? "Screen recording permission granted."
            : "Screen recording permission missing. Enable it in System Settings > Privacy & Security > Screen Recording."
    }

    static func audioPermissionHealthMessage(status: AVAuthorizationStatus) -> String? {
        switch status {
        case .authorized:
            return "Microphone permission granted."
        case .notDetermined:
            return "Microphone permission not determined. Starting recording will prompt for access."
        case .denied, .restricted:
            return "Microphone permission denied/restricted. Enable access in System Settings > Privacy & Security > Microphone."
        @unknown default:
            return "Microphone permission state is unknown."
        }
    }

    func stopLiveOutputRecording() {
        guard isLiveOutputRecording else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await captureSession.end()
            isLiveOutputRecording = false
            liveOutputRecordingStartedAt = nil
            lastRecordingURL = captureSession.outputURL
            liveOutputRecordingAudioDiagnostic = captureSession.audioDiagnosticMessage
            if let lastRecordingURL {
                liveOutputRecordingStatus = "Saved recording: \(lastRecordingURL.lastPathComponent)"
            } else {
                liveOutputRecordingStatus = "Recording stopped."
            }
        }
    }

    @MainActor
    func revealLastRecordingInFinder() {
        guard let lastRecordingURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
    }

    @MainActor
    func shareLastRecording() {
        guard let lastRecordingURL,
              let contentView = NSApp.keyWindow?.contentView
        else { return }
        let picker = NSSharingServicePicker(items: [lastRecordingURL])
        picker.show(relativeTo: .init(x: 32, y: 32, width: 1, height: 1), of: contentView, preferredEdge: .minY)
    }

    private func makeContextSnapshot() -> ShowContextSnapshot {
        lightingDMXLock.lock()
        let patch = dmxPatchDocument
        let lc = lightingCueDocument
        let mod = modulationDocument
        let stage = stageLayoutDocument
        let bd = backdropCueDocument
        lightingDMXLock.unlock()
        let flags = MachinePerformanceFlags(
            lightingStripEnabled: remoteSettings.lightingPerformanceStripEnabled,
            backdropStripEnabled: remoteSettings.backdropPerformanceStripEnabled,
            hybridAIEnabled: remoteSettings.hybridAIAssistantEnabled
        )
        let calURL: URL? = {
            if let folder = currentShowProjectFolder {
                let u = folder.appendingPathComponent("context").appendingPathComponent(ShowContextDiskLayout.calibrationFilename)
                return FileManager.default.fileExists(atPath: u.path) ? u : nil
            }
            let u = ShowContextDiskLayout.defaultContextDirectory().appendingPathComponent(ShowContextDiskLayout.calibrationFilename)
            return FileManager.default.fileExists(atPath: u.path) ? u : nil
        }()
        let calRel = calURL != nil ? "context/\(ShowContextDiskLayout.calibrationFilename)" : nil
        let sceneName: String = {
            guard sceneManager.scenes.indices.contains(sceneManager.currentIndex) else { return "—" }
            return sceneManager.scenes[sceneManager.currentIndex].name
        }()
        return ShowContextSnapshot(
            projectMeta: showProjectMetadata,
            dmxPatch: patch,
            lightingCues: lc,
            backdropCues: bd,
            modulation: mod,
            stageLayout: stage,
            sceneIndex: sceneManager.currentIndex,
            sceneName: sceneName,
            sceneCount: sceneManager.scenes.count,
            selectedPaletteID: selectedPaletteID,
            overlayEnabled: overlayEnabled,
            overlays: overlays,
            performanceFlags: flags,
            calibrationRelativePath: calRel
        )
    }

    func makeContextSnapshotForFeedback() -> ShowContextSnapshot {
        makeContextSnapshot()
    }

    func markSetupWizardStep(_ stepID: String, skipped: Bool) {
        var s = remoteSettings
        if s.setupWizardStartedAtISO8601.isEmpty {
            s.setupWizardSessionCount += 1
            s.setupWizardStartedAtISO8601 = ISO8601DateFormatter().string(from: Date())
        }
        s.setupWizardLastStepID = stepID
        var skippedSet = Set(s.setupWizardSkippedStepIDs)
        if skipped {
            skippedSet.insert(stepID)
            s.setupWizardStepSkippedCounts[stepID, default: 0] += 1
        } else {
            skippedSet.remove(stepID)
            s.setupWizardStepCompletedCounts[stepID, default: 0] += 1
        }
        s.setupWizardSkippedStepIDs = Array(skippedSet).sorted()
        remoteSettings = s
    }

    func beginSetupWizardSessionIfNeeded() {
        var s = remoteSettings
        if s.setupWizardStartedAtISO8601.isEmpty {
            s.setupWizardSessionCount += 1
            s.setupWizardStartedAtISO8601 = ISO8601DateFormatter().string(from: Date())
            remoteSettings = s
        }
    }

    func completeSetupWizard() {
        var s = remoteSettings
        s.setupWizardCompleted = true
        s.setupWizardCompletedAtISO8601 = ISO8601DateFormatter().string(from: Date())
        remoteSettings = s
    }

    func resetSetupWizard() {
        var s = remoteSettings
        s.setupWizardCompleted = false
        s.setupWizardLastStepID = "welcome"
        s.setupWizardSkippedStepIDs = []
        s.setupWizardStartedAtISO8601 = ""
        s.setupWizardCompletedAtISO8601 = ""
        remoteSettings = s
    }

    func exportSetupWizardDiagnostics() {
        let s = remoteSettings
        let snapshot = SetupWizardDiagnosticsSnapshot(
            exportedAt: Date(),
            sessionCount: s.setupWizardSessionCount,
            startedAtISO8601: s.setupWizardStartedAtISO8601,
            completedAtISO8601: s.setupWizardCompletedAtISO8601,
            lastStepID: s.setupWizardLastStepID,
            skippedStepIDs: s.setupWizardSkippedStepIDs,
            stepCompletedCounts: s.setupWizardStepCompletedCounts,
            stepSkippedCounts: s.setupWizardStepSkippedCounts,
            setupWizardCompleted: s.setupWizardCompleted
        )
        let root = projectArtifactsFolderURL().appendingPathComponent("Onboarding", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let fileURL = root.appendingPathComponent("setup-wizard-diagnostics-\(stamp).json")
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            setupWizardDiagnosticsStatus = "Exported onboarding diagnostics: \(fileURL.lastPathComponent)"
        } catch {
            setupWizardDiagnosticsStatus = "Diagnostics export failed: \(error.localizedDescription)"
        }
    }

    func createFeedbackBundle(message: String) {
        let root = projectArtifactsFolderURL().appendingPathComponent("Feedback", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let result = try FeedbackAndLogsService.createBundle(outputFolder: root, message: message, appModel: self)
            feedbackStatus = result.summary
        } catch {
            feedbackStatus = "Feedback bundle failed: \(error.localizedDescription)"
        }
    }

    func submitFeedbackIssue(title: String, body: String) {
        let settings = remoteSettings
        let relayBearer = FeedbackSecretsKeychain.load(account: FeedbackSecretsKeychain.relayBearerAccount)
        let githubToken = FeedbackSecretsKeychain.load(account: FeedbackSecretsKeychain.githubTokenAccount)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await FeedbackAndLogsService.submitFeedbackIssue(
                    relayURL: settings.githubFeedbackRelayURL,
                    relayBearer: relayBearer,
                    repository: settings.githubFeedbackRepository,
                    githubToken: githubToken,
                    title: title,
                    body: body
                )
                let relayConfigured = !settings.githubFeedbackRelayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                feedbackStatus = relayConfigured ? "Submitted feedback via relay." : "Submitted GitHub issue."
            } catch {
                feedbackStatus = "Issue submission failed: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    func checkForAppUpdates() {
        appUpdateService.checkForUpdates()
        appUpdateStatus = appUpdateService.status
    }

    func saveShowProject(to folder: URL) throws {
        try backupProjectFilesIfPresent(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let scenesData = try makeScenesDocumentData()
        let controlsData = try makeSceneControlsDocumentData()
        lightingDMXLock.lock()
        let patchData = try JSONEncoder().encode(dmxPatchDocument)
        let lcData = try JSONEncoder().encode(lightingCueDocument)
        let bdData = try JSONEncoder().encode(backdropCueDocument)
        let modData = try JSONEncoder().encode(modulationDocument)
        let stageData = try JSONEncoder().encode(stageLayoutDocument)
        let overlayData = try JSONEncoder().encode(overlayCardDocument)
        lightingDMXLock.unlock()
        var meta = showProjectMetadata
        meta.updatedAt = Date()
        showProjectMetadata = meta
        try ShowProjectPackage.save(
            to: folder,
            project: meta,
            scenesData: scenesData,
            sceneControlsData: controlsData,
            dmxPatchData: patchData,
            lightingCuesData: lcData,
            backdropCuesData: bdData,
            modulationData: modData,
            stageLayoutData: stageData,
            overlayCardsData: overlayData
        )
        if let graph = showDirectorGraph {
            try ShowDirectorPackageStore.save(graph, to: folder)
        } else {
            try ShowDirectorPackageStore.ensureMediaLayout(in: folder)
        }
        try persistProjectConfigSnapshot(projectFolder: folder)
        exportAIContextNow(targetRoot: folder)
        LastShowProjectBookmark.save(folder)
        currentShowProjectFolder = folder
    }

    private func persistProjectConfigSnapshot(projectFolder: URL) throws {
        let root = projectFolder.appendingPathComponent("Artifacts", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let out = root.appendingPathComponent("config_snapshot.json")
        struct ConfigSnapshot: Codable {
            var capturedAt: Date
            var remoteSettings: RemoteControlSettings
            var projectMetadata: ShowProjectDocument
        }
        let snap = ConfigSnapshot(capturedAt: Date(), remoteSettings: remoteSettings, projectMetadata: showProjectMetadata)
        let data = try JSONEncoder().encode(snap)
        try data.write(to: out, options: .atomic)
    }

    private func backupProjectFilesIfPresent(at folder: URL) throws {
        let fm = FileManager.default
        let marker = folder.appendingPathComponent("project.json")
        guard fm.fileExists(atPath: marker.path) else { return }
        let ts = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupsRoot = folder.appendingPathComponent("Backups", isDirectory: true)
        let backupFolder = backupsRoot.appendingPathComponent("backup-\(ts)", isDirectory: true)
        try fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        let filenames = [
            "project.json",
            "scenes.json",
            "scene_controls.json",
            "dmx_patch.json",
            "lighting_cues.json",
            "backdrop_cues.json",
            "modulation.json",
            "stage_layout.json",
            "overlay_cards.json",
        ]
        for filename in filenames {
            let src = folder.appendingPathComponent(filename)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = backupFolder.appendingPathComponent(filename)
            if fm.fileExists(atPath: dst.path) {
                try fm.removeItem(at: dst)
            }
            try fm.copyItem(at: src, to: dst)
        }
    }

    @MainActor
    func loadShowProject(from folder: URL) throws {
        showProjectMetadata = try ShowProjectPackage.loadProject(from: folder)
        try applyScenesDocument(try ShowProjectPackage.loadScenes(from: folder))
        let ctrl = try JSONDecoder().decode(SceneControlStore.Document.self, from: try ShowProjectPackage.loadSceneControls(from: folder))
        sceneEditStates = ctrl.states
        try persistSceneControls()
        let patch = try JSONDecoder().decode(DMXPatchDocument.self, from: try ShowProjectPackage.loadDMXPatch(from: folder))
        let cues = try JSONDecoder().decode(LightingCueDocument.self, from: try ShowProjectPackage.loadLightingCues(from: folder))
        let backs = try JSONDecoder().decode(BackdropCueDocument.self, from: try ShowProjectPackage.loadBackdropCues(from: folder))
        let modu = try JSONDecoder().decode(ModulationDocument.self, from: try ShowProjectPackage.loadModulation(from: folder))
        let stage = try JSONDecoder().decode(StageLayoutDocument.self, from: try ShowProjectPackage.loadStageLayout(from: folder))
        let ovl = try JSONDecoder().decode(OverlayCardDocument.self, from: try ShowProjectPackage.loadOverlayCards(from: folder))
        applyDMXPatchDocument(patch)
        applyLightingCueDocument(cues)
        applyBackdropCueDocument(backs)
        applyModulationDocument(modu)
        applyStageLayoutDocument(stage)
        applyOverlayCardDocument(ovl)
        if let ni = backdropCueDocument.activeCueIndex, backdropCueDocument.cues.indices.contains(ni) {
            applyStageLayoutDocument(backdropCueDocument.cues[ni].layoutSnapshot)
        }
        do {
            let showDirectorLoad = try ShowDirectorPackageStore.load(from: folder)
            showDirectorGraph = showDirectorLoad.graph
            showDirectorValidationWarnings = showDirectorLoad.validation.warnings
            configureShowDirectorRuntime(graph: showDirectorLoad.graph, packageRoot: folder)
        } catch {
            // Do not install a partial/invalid graph; keep authored project payloads loaded.
            showDirectorGraph = nil
            showDirectorValidationWarnings = [
                ShowDirectorValidationIssue(
                    severity: .error,
                    code: "show_director_load_failed",
                    path: "show-director",
                    message: error.localizedDescription
                ),
            ]
            failShowDirectorRuntime(message: error.localizedDescription)
        }
        LastShowProjectBookmark.save(folder)
        currentShowProjectFolder = folder
        refreshScenePreviewPool()
        syncRendererFromScene()
        exportAIContextNow(targetRoot: folder)
    }

    @MainActor
    func replaceShowDirectorGraph(_ graph: ShowDirectorGraph?) {
        showDirectorGraph = graph
        showDirectorValidationWarnings = []
        configureShowDirectorRuntime(graph: graph, packageRoot: currentShowProjectFolder)
    }

    @MainActor
    func configureShowDirectorRuntime(graph: ShowDirectorGraph?, packageRoot: URL?) {
        showDirectorConfigurationTask?.cancel()
        showDirectorConfigurationGeneration &+= 1
        let generation = showDirectorConfigurationGeneration

        guard let graph else {
            showDirectorEngine = nil
            showDirectorRuntimeStatus = .unconfigured
            showDirectorConfigurationTask = nil
            return
        }

        showDirectorRuntimeStatus = .loading
        showDirectorConfigurationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let adapters: [ShowEndpointAdapter] = [
                VisualSceneEndpointAdapter(controller: self),
                PaletteEndpointAdapter(controller: self),
                LightingCueEndpointAdapter(controller: self),
            ]
            let engine = ShowDirectorEngine(
                adapters: adapters,
                packageRoot: packageRoot
            )
            let commandID = "app_load_\(generation)"
            let result = await self.showDirectorGraphLoader(engine, graph, commandID)

            guard !Task.isCancelled else { return }
            guard generation == self.showDirectorConfigurationGeneration else { return }

            switch result.disposition {
            case .accepted:
                self.showDirectorEngine = engine
                self.showDirectorRuntimeStatus = .ready
            case .rejected(let reason), .noOp(let reason):
                self.showDirectorEngine = nil
                self.showDirectorRuntimeStatus = .failed(message: reason)
            }
        }
    }

    @MainActor
    private func failShowDirectorRuntime(message: String) {
        showDirectorConfigurationTask?.cancel()
        showDirectorConfigurationGeneration &+= 1
        showDirectorConfigurationTask = nil
        showDirectorEngine = nil
        showDirectorRuntimeStatus = .failed(message: message)
    }

    @MainActor
    func presentSaveShowProjectPanel() {
        let p = NSSavePanel()
        p.title = "Save show project"
        p.canCreateDirectories = true
        p.showsTagField = false
        p.nameFieldStringValue = showProjectMetadata.show.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            try saveShowProject(to: url)
        } catch {
            let a = NSAlert()
            a.messageText = "Could not save project"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
    }

    @MainActor
    func presentOpenShowProjectPanel() {
        let o = NSOpenPanel()
        o.canChooseFiles = false
        o.canChooseDirectories = true
        o.allowsMultipleSelection = false
        guard o.runModal() == .OK, let url = o.url else { return }
        do {
            try loadShowProject(from: url)
        } catch {
            let a = NSAlert()
            a.messageText = "Could not open project"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
    }

    @MainActor
    func presentExportShowProjectArchivePanel() {
        guard let folder = currentShowProjectFolder else {
            let a = NSAlert()
            a.messageText = "No active project folder"
            a.informativeText = "Save a show project folder first, then export its archive."
            a.runModal()
            return
        }
        let panel = NSSavePanel()
        panel.title = "Export show package archive"
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.nameFieldStringValue = ShowProjectPackage.suggestedArchiveFilename(for: showProjectMetadata)
        guard panel.runModal() == .OK, let archiveURL = panel.url else { return }
        do {
            try ShowProjectPackage.exportArchive(from: folder, to: archiveURL)
        } catch {
            let a = NSAlert()
            a.messageText = "Could not export show package"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
    }

    @MainActor
    func presentImportShowProjectArchivePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.zip]
        guard panel.runModal() == .OK, let archiveURL = panel.url else { return }
        do {
            let extractionRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("cosmic-import-\(UUID().uuidString)", isDirectory: true)
            let packageRoot = try ShowProjectPackage.importArchive(from: archiveURL, to: extractionRoot)
            try loadShowProject(from: packageRoot)
        } catch {
            let a = NSAlert()
            a.messageText = "Could not import show package"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
    }

    func sendHybridAIPrompt(_ prompt: String) async {
        guard remoteSettings.hybridAIAssistantEnabled else {
            aiAssistantLastMessage = "Enable hybrid AI in Settings first."
            return
        }
        guard let key = LLMKeychain.loadAPIKey(), !key.isEmpty else {
            aiAssistantLastMessage = "Add an API key in Settings."
            return
        }
        let client = LLMChatClient()
        let baseTrim = remoteSettings.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let settings = LLMChatClient.Settings(
            provider: remoteSettings.llmProvider,
            model: remoteSettings.llmModel,
            baseURL: baseTrim.isEmpty ? nil : baseTrim
        )
        let parent = currentShowProjectFolder
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppIdentity.applicationSupportFolderName, isDirectory: true)
        let ctxDir = parent.appendingPathComponent("context", isDirectory: true)
        var files: [(String, String)] = []
        if let m = try? String(contentsOf: ctxDir.appendingPathComponent(ShowContextDiskLayout.machineFilename), encoding: .utf8) {
            files.append(("machine.json", m))
        }
        if let md = try? String(contentsOf: ctxDir.appendingPathComponent(ShowContextDiskLayout.markdownFilename), encoding: .utf8) {
            files.append(("dmx_universe.md", md))
        }
        let system = """
        You control \(AppIdentity.displayName) via JSON tool calls only. Reply with a single JSON object:
        {"tool_calls":[{"name":"tool_name","arguments":{...}}]}
        Tools: refresh_context; set_active_lighting_cue_index {index:number|null}; set_active_backdrop_cue_index {index:number|null}; \
        apply_dmx_patch_document {patch_json:string}; append_lighting_cues_json {cues_json:string}; export_fixture_ofl_stub {ofl_key:string}.
        Prefer refresh_context after patch changes. Do not include prose outside JSON.
        """
        do {
            let text = try await client.complete(
                userPrompt: prompt,
                systemPrompt: system,
                contextFiles: files,
                apiKey: key,
                settings: settings
            )
            let calls = try AIToolRegistry.parseToolCalls(from: text)
            var log: [String] = []
            for c in calls {
                let r = try AIToolRegistry.execute(
                    name: c.name,
                    argumentsJSON: c.argumentsJSON,
                    model: self
                )
                log.append("\(c.name): \(r)")
            }
            aiAssistantLastMessage = log.joined(separator: "\n")
        } catch let err as AIToolExecutionError {
            aiAssistantLastMessage = err.errorDescription ?? String(describing: err)
        } catch {
            aiAssistantLastMessage = "Assistant request failed: \(error.localizedDescription)"
        }
    }
}

extension AppModel: VisualSceneControlling, PaletteControlling, LightingCueControlling {
    func visualSceneIDs() -> [UUID] {
        sceneManager.scenes.map(\.id)
    }

    func activeVisualSceneID() -> UUID? {
        guard sceneManager.scenes.indices.contains(sceneManager.currentIndex) else { return nil }
        return sceneManager.scenes[sceneManager.currentIndex].id
    }

    func recallVisualScene(id: UUID) throws {
        guard let targetIndex = sceneManager.scenes.firstIndex(where: { $0.id == id }) else {
            throw ShowDirectorEndpointControlError.targetNotFound(endpoint: .visuals, id: id)
        }
        let fromID = activeVisualSceneID()
        sceneManager.currentIndex = targetIndex
        if let fromID, fromID != id {
            transitionState = .transitioning(fromSceneID: fromID, toSceneID: id, progress: 0)
        }
        syncRendererFromScene()
        do {
            try persistScenes()
        } catch {
            throw ShowDirectorEndpointControlError.persistenceFailed(
                endpoint: .visuals,
                message: error.localizedDescription
            )
        }
        guard activeVisualSceneID() == id else {
            throw ShowDirectorEndpointControlError.verificationFailed(endpoint: .visuals, id: id)
        }
    }

    func paletteIDs() -> [UUID] {
        palettes.map(\.id)
    }

    func activePaletteID() -> UUID? {
        selectedPaletteID
    }

    func selectPalette(id: UUID) throws {
        guard palettes.contains(where: { $0.id == id }) else {
            throw ShowDirectorEndpointControlError.targetNotFound(endpoint: .palette, id: id)
        }
        selectedPaletteID = id
        syncRendererFromScene()
        guard activePaletteID() == id else {
            throw ShowDirectorEndpointControlError.verificationFailed(endpoint: .palette, id: id)
        }
    }

    func lightingCueIDs() -> [UUID] {
        lightingDMXLock.lock()
        defer { lightingDMXLock.unlock() }
        return lightingCueDocument.cues.map(\.id)
    }

    func recallLightingCue(id: UUID) throws {
        lightingDMXLock.lock()
        let cues = lightingCueDocument.cues
        lightingDMXLock.unlock()
        let targetIndex = cues.firstIndex(where: { $0.id == id })
        guard let targetIndex else {
            throw ShowDirectorEndpointControlError.targetNotFound(endpoint: .lighting, id: id)
        }
        setActiveLightingCueIndex(targetIndex)
        guard activeLightingCueID() == id else {
            throw ShowDirectorEndpointControlError.verificationFailed(endpoint: .lighting, id: id)
        }
    }

    func lightingCueFadeSeconds(id: UUID) -> Double? {
        lightingDMXLock.lock()
        defer { lightingDMXLock.unlock() }
        return lightingCueDocument.cues.first(where: { $0.id == id })?.fadeSeconds
    }
}

/// UI-thread–owned model; `@unchecked` allows `MainActor.run` / FlyingFox `@Sendable` handlers to capture a reference safely because all mutating use is coordinated on the main actor.
extension AppModel: @unchecked Sendable {}
