import AppKit
import Combine
import CoreAudio
import Foundation
import MetalKit
import simd
import SwiftUI

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

    @Published private(set) var isExternalVisualizationOpen = false
    /// Picks which `NSScreen.screens[index]` receives the fullscreen visualization.
    @Published var externalOutputScreenIndex: Int = 0

    @Published var overlays: [OverlayAsset] = []
    @Published var transitionState: TransitionState = .idle

    @Published var selectedSceneID: UUID?
    @Published var bpm: Double = 0
    @Published var beatConfidence: Double = 0
    @Published var selectedAudioDeviceName: String = "Default Input"
    @Published var palettes: [ThemePalette] = PaletteLibraryStore.loadOrDefault()
    @Published var selectedPaletteID: UUID?
    @Published var performanceMode = false
    @Published var overlayEnabled = false
    @Published var audioError: String?

    @Published var remoteSettings: RemoteControlSettings = RemoteControlSettingsStore.load() {
        didSet {
            RemoteControlSettingsStore.save(remoteSettings)
            refreshAuxiliaryServices()
        }
    }

    @Published private(set) var sceneEditStates: [UUID: SceneEditState] = [:]

    lazy var commandHub: ControlCommandHub = ControlCommandHub(model: self)

    private var midiControl: MIDIControlService?
    private var dmxService: DMXOutputService?
    private var midiMapping = MIDIMappingStore.loadOrDefault()

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

        wireRendererFrameLoop(metalRenderer)
        webControl.bind(appModel: self)
        refreshAuxiliaryServices()

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
            selectedPaletteID: selectedPaletteID
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

    func makeMIDIMappingData() throws -> Data {
        try JSONEncoder().encode(midiMapping)
    }

    func applyMIDIMappingDocument(_ data: Data) throws {
        let m = try JSONDecoder().decode(MIDIMapping.self, from: data)
        midiMapping = m
        try MIDIMappingStore.save(m)
        configureMIDIService()
        midiControl?.start()
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

    private func wireRendererFrameLoop(_ renderer: CompositeRenderer?) {
        renderer?.onFrame = { [weak self] dt in
            self?.tickTempoAndBeatPulse(deltaTime: dt)
        }
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
                guard let self else { return }
                if let cmd = self.midiMapping.command(forChannel: ch, controller: cc) {
                    self.applyRemoteCommand(cmd)
                }
                if ch == 0, cc == 1 {
                    let z = 0.35 + Float(val) / 127 * 1.9
                    self.applyRemoteCommand(RemoteControlCommand(type: "SetFractalZoom", fractalZoom: z))
                }
                if ch == 0, cc == 2 {
                    let z = 0.2 + Float(val) / 127 * 2.3
                    self.applyRemoteCommand(RemoteControlCommand(type: "SetLiquidTurbulence", liquidTurbulence: z))
                }
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
        updateAllVisualizationRenderers { p in
            p.liquidLightEnabled = scene.liquidLightEnabled
            p.liquidMix = scene.liquidLightEnabled ? 1 : 0
            if scene.name.contains("Liquid Only") {
                p.fractalMix = 0.12
            } else {
                p.fractalMix = 1
            }
            let mode = scene.fractalMode.lowercased()
            p.fractalKind = mode.contains("mandel") ? 1 : 0
            p.fractalZoom = edit.layer.fractalZoom
            p.liquidTurbulence = edit.layer.liquidTurbulence
            p.compositeBlend = edit.layer.compositeBlend
            p.liquidFocus = edit.layer.liquidFocus
            p.fractalAppearance = edit.layer.fractalAppearance
            p.overlayFractalFusion = edit.layer.overlayFractalFusion
            p.overlayOpacity = overlayOpacity
            p.palettePrimary = c0
            p.paletteSecondary = c1
            p.paletteAccent = c2
            p.paletteGlow = c3
        }
        syncOverlayGPUResources()
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
            return
        }
        let scene = sceneManager.scenes[sceneManager.currentIndex]
        guard let oid = scene.overlayIDs.first,
              let asset = overlays.first(where: { $0.id == oid })
        else {
            main.overlayTexture = nil
            externalOutputRenderer?.overlayTexture = nil
            return
        }
        let url = URL(fileURLWithPath: asset.filePath)
        let loader = MTKTextureLoader(device: device)
        do {
            let tex = try loader.newTexture(URL: url, options: [.SRGB: false])
            main.overlayTexture = tex
            externalOutputRenderer?.overlayTexture = tex
        } catch {
            main.overlayTexture = nil
            externalOutputRenderer?.overlayTexture = nil
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

    private func updateAllVisualizationRenderers(_ update: (inout RenderParameters) -> Void) {
        metalRenderer?.updateParameters(update)
        externalOutputRenderer?.updateParameters(update)
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
        wireRendererFrameLoop(renderer)

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
        guard let asset = overlayLibrary.importOverlayViaOpenPanel() else { return }
        overlays.append(asset)
        try? persistOverlays()
        if sceneManager.scenes.indices.contains(sceneManager.currentIndex) {
            var s = sceneManager.scenes[sceneManager.currentIndex]
            if !s.overlayIDs.contains(asset.id) {
                s.overlayIDs.append(asset.id)
                sceneManager.scenes[sceneManager.currentIndex] = s
                try? persistScenes()
            }
        }
        syncRendererFromScene()
    }

    func advanceTransition(by delta: Float) {
        transitionState.advance(by: delta)
    }
}
