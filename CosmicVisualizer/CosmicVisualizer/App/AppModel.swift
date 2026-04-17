import AppKit
import Combine
import CoreAudio
import Foundation
import MetalKit
import simd
import SwiftUI
import Syphon
import UniformTypeIdentifiers

final class AppModel: ObservableObject, @unchecked Sendable {
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
            syncOBSStreamPipeline()
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

    @Published var remoteSettings: RemoteControlSettings = RemoteControlSettingsStore.load() {
        didSet {
            RemoteControlSettingsStore.save(remoteSettings)
            refreshAuxiliaryServices()
        }
    }

    /// USB DMX universe composition (fixtures, legacy slots, cues, modulation). Mutate via `apply*` helpers for thread safety with the DMX timer.
    @Published private(set) var dmxPatchDocument = DMXPatchDocument.default()
    @Published private(set) var lightingCueDocument = LightingCueDocument.default()
    @Published private(set) var modulationDocument = ModulationDocument.default()
    @Published private(set) var stageLayoutDocument = StageLayoutDocument()

    private let lightingDMXLock = NSLock()
    private var lightingCueCrossfade: LightingCueCrossfade?

    let lightingCopilotService = LightingCopilotService()

    @Published private(set) var sceneEditStates: [UUID: SceneEditState] = [:]

    /// Live Metal previews for the main-window scene cue strip (not used on external projection).
    @Published private(set) var scenePreviewRenderers: [UUID: CompositeRenderer] = [:]
    private var overlayTextureCache: [String: MTLTexture] = [:]

    lazy var commandHub: ControlCommandHub = ControlCommandHub(model: self)

    private var midiControl: MIDIControlService?
    private var dmxService: DMXOutputService?
    /// Published so Controller UI can show current MIDI assignments.
    @Published private(set) var midiMapping: MIDIMapping = MIDIMappingStore.loadOrDefault()

    /// Controller: arm “learn next CC” for the selected layer parameter (MIDI only in v1).
    @Published var controlLearnMode: ControlLearnMode = .off
    @Published var midiLearnTarget: LayerControlParameter?

    private var cancellables = Set<AnyCancellable>()

    var selectedInputDeviceBinding: Binding<AudioDeviceID?> {
        Binding(
            get: { self.audioEngine.selectedInputDeviceID },
            set: { self.audioEngine.selectedInputDeviceID = $0 }
        )
    }

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

        wireRendererFrameLoop(metalRenderer)
        webControl.bind(appModel: self)
        refreshAuxiliaryServices()
        refreshScenePreviewPool()

        sceneManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        sceneManager.$scenes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshScenePreviewPool()
            }
            .store(in: &cancellables)

        audioEngine.$features
            .receive(on: DispatchQueue.main)
            .sink { [weak self] features in
                guard let self else { return }
                self.tempoClock.ingestAudioDetection(bpm: features.estimatedBPM, confidence: features.beatConfidence)
                self.bpm = self.tempoClock.effectiveBPM
                self.beatConfidence = self.tempoClock.displayConfidence
                self.refreshDeviceLabel()
                self.updateAllVisualizationRenderers { p in
                    p.audioLevel = min(1, features.rms * 4)
                    p.bpm = Float(self.tempoClock.effectiveBPM)
                    p.beatConfidence = features.beatConfidence
                    p.beatPulse = self.tempoClock.shaderBeatPulse(audioConfidence: features.beatConfidence)
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
    }

    deinit {
        teardownOBSStream()
        webControl.stop()
        midiControl?.stop()
        dmxService?.stop()
        stopExternalVisualizationSession()
    }

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
            lightingPatchFixtureCount: patchInstCount,
            lightingCueCount: lcSnap.cues.count,
            lightingActiveCueIndex: lcSnap.activeCueIndex,
            lightingActiveCueName: activeCueName,
            lightingModulatorCount: modSnapCount
        )
        return (try? JSONEncoder().encode(dto)) ?? Data()
    }

    func makeScenesDocumentData() throws -> Data {
        let doc = SceneLibraryStore.Document(scenes: sceneManager.scenes)
        return try JSONEncoder().encode(doc)
    }

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

    /// Single mutation path for remote/MIDI/web; always runs on the main thread for `AppModel` + SwiftUI.
    func applyRemoteCommand(_ command: RemoteControlCommand) {
        if Thread.isMainThread {
            applyRemoteCommandOnMainThread(command)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyRemoteCommandOnMainThread(command)
            }
        }
    }

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

    private func performJumpToScene(id: UUID) {
        if let idx = sceneManager.scenes.firstIndex(where: { $0.id == id }) {
            performJumpToScene(index: idx)
        }
    }

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
            self.tickTempoAndBeatPulse(deltaTime: dt)
            self.syncScenePreviewRenderers()
        }
    }

    private func clearRendererFrameLoop(_ renderer: CompositeRenderer?) {
        renderer?.onFrame = nil
    }

    private func tickTempoAndBeatPulse(deltaTime: TimeInterval) {
        tempoClock.advanceBeatPhaseIfNeeded(deltaTime: deltaTime)
        let conf = Float(audioEngine.features.beatConfidence)
        updateAllVisualizationRenderers { p in
            p.beatPulse = tempoClock.shaderBeatPulse(audioConfidence: conf)
        }
    }

    private func refreshAuxiliaryServices() {
        webControl.applySettings(remoteSettings)
        configureMIDIService()
        midiControl?.start()
        configureDMXService()
        syncOBSStreamPipeline()
    }

    // MARK: - OBS (Syphon) stream

    private func syncOBSStreamPipeline() {
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
            obsSyphonServer = SyphonMetalServer(name: "Cosmic Visualizer", device: renderer.device, options: nil)
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
        obsStreamRenderer?.onBeforePresent = nil
        obsStreamMTKView?.removeFromSuperview()
        obsStreamMTKView = nil
        obsStreamRenderer = nil
        obsSyphonServer?.stop()
        obsSyphonServer = nil
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

    func refreshDeviceLabel() {
        if let id = audioEngine.selectedInputDeviceID,
           let match = audioEngine.availableInputDevices.first(where: { $0.id == id }) {
            selectedAudioDeviceName = match.name
        } else if let def = AudioDeviceEnumerator.defaultInputDeviceID(),
                  let match = audioEngine.availableInputDevices.first(where: { $0.id == def }) {
            selectedAudioDeviceName = match.name
        }
    }

    func syncRendererFromScene() {
        guard sceneManager.scenes.indices.contains(sceneManager.currentIndex) else { return }
        let scene = sceneManager.scenes[sceneManager.currentIndex]
        selectedSceneID = scene.id
        updateAllVisualizationRenderers { p in
            applySceneVisualState(scene: scene, to: &p)
        }
        syncOverlayGPUResources()
    }

    /// Full parameters for a scene using current live audio/beat state (used for cue-strip previews).
    private func makeRenderParameters(for scene: VisualizationScene) -> RenderParameters {
        var p = RenderParameters()
        let conf = Float(audioEngine.features.beatConfidence)
        p.audioLevel = min(1, audioEngine.features.rms * 4)
        p.bpm = Float(tempoClock.effectiveBPM)
        p.beatConfidence = conf
        p.beatPulse = tempoClock.shaderBeatPulse(audioConfidence: conf)
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
        p.fractalGeometryIndex = geometry
        p.fractalKind = geometry < 2 ? geometry : 0
        p.fractalExplore = edit.layer.fractalExplore
        p.fractalExploreSpeed = edit.layer.fractalExploreSpeed
        p.fractalPan = SIMD2(edit.layer.fractalPanX, edit.layer.fractalPanY)
        p.fractalIterBoost = max(0.25, min(3, edit.layer.fractalIterBoost))
        p.zoomEffectType = max(0, min(2, edit.layer.zoomEffectType))
        p.liquidTilt = SIMD2(edit.layer.liquidTiltX, edit.layer.liquidTiltY)
        p.dyeMix = scene.liquidLightEnabled ? 1 : 0
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

    func addPalette(_ palette: ThemePalette) {
        palettes.append(palette)
        try? PaletteLibraryStore.save(palettes)
        syncRendererFromScene()
    }

    func updatePalette(id: UUID, with palette: ThemePalette) {
        guard let idx = palettes.firstIndex(where: { $0.id == id }) else { return }
        palettes[idx] = palette
        try? PaletteLibraryStore.save(palettes)
        syncRendererFromScene()
    }

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

    func resetOverlayRectToFullFrame() {
        mutateCurrentEdit {
            $0.layer.overlayRectMinX = 0
            $0.layer.overlayRectMinY = 0
            $0.layer.overlayRectWidth = 1
            $0.layer.overlayRectHeight = 1
        }
    }

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

    func applyOverlayPinchFromStart(_ start: SIMD4<Float>, scale: CGFloat) {
        let s = Float(scale)
        let cx = start.x + start.z * 0.5
        let cy = start.y + start.w * 0.5
        var nw = start.z * s
        var nh = start.w * s
        nw = min(max(nw, 0.05), 1)
        nh = min(max(nh, 0.05), 1)
        var nx = cx - nw * 0.5
        var ny = cy - nh * 0.5
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
    func toggleMainWindowFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }

    /// Borderless edge-to-edge visualization on the chosen display. Main window stays put for controls.
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

    func closeExternalVisualization() {
        stopExternalVisualizationSession()
    }

    private func stopExternalVisualizationSession() {
        externalOutputWindow?.orderOut(nil)
        externalOutputWindow?.contentView = nil
        externalOutputWindow = nil
        externalOutputRenderer = nil
        isExternalVisualizationOpen = false
    }

    func startAudio() {
        audioEngine.refreshDevices()
        do {
            try audioEngine.start()
            audioError = nil
        } catch {
            audioError = error.localizedDescription
        }
    }

    func stopAudio() {
        audioEngine.stop()
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
    func dmxOutputDiagnostics() -> (lastError: String?, running: Bool, nominalHz: Double) {
        dmxService?.extendedDiagnostics() ?? (nil, false, 44.0)
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
        let bpm = tempoClock.effectiveBPM
        let beatPhase = tempoClock.beatPhase
        let audio = audioEngine.features
        lightingDMXLock.unlock()

        let cueMap = LightingCueResolver.resolveChannelMap(document: cueDoc, crossfade: xf, now: time)
        let offsets = ModulationRuntime.offsets(
            document: modDoc,
            time: time,
            bpm: bpm,
            beatPhase: beatPhase,
            audio: audio,
            lastSmoothed: &lastSmoothed
        )
        return DMXUniverseBuilder.build(model: self, patch: patch, cueChannelMap: cueMap, modulationOffsets: offsets)
    }

    func applyDMXPatchDocument(_ doc: DMXPatchDocument) {
        lightingDMXLock.lock()
        dmxPatchDocument = doc
        lightingDMXLock.unlock()
        try? DMXPatchStore.save(doc)
        objectWillChange.send()
    }

    func applyLightingCueDocument(_ doc: LightingCueDocument) {
        lightingDMXLock.lock()
        lightingCueDocument = doc
        lightingDMXLock.unlock()
        try? LightingCueStore.save(doc)
        objectWillChange.send()
    }

    func setActiveLightingCueIndex(_ newIndex: Int?) {
        lightingDMXLock.lock()
        var doc = lightingCueDocument
        let old = doc.activeCueIndex
        doc.activeCueIndex = newIndex
        lightingCueDocument = doc
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
        try? LightingCueStore.save(lightingCueDocument)
        objectWillChange.send()
    }

    func applyModulationDocument(_ doc: ModulationDocument) {
        lightingDMXLock.lock()
        modulationDocument = doc
        lightingDMXLock.unlock()
        try? ModulationStore.save(doc)
        objectWillChange.send()
    }

    func applyStageLayoutDocument(_ doc: StageLayoutDocument) {
        lightingDMXLock.lock()
        stageLayoutDocument = doc
        lightingDMXLock.unlock()
        try? StageLayoutStore.save(doc)
        objectWillChange.send()
    }
}
