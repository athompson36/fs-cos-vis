import AppKit
import CoreAudio
import SwiftUI

struct LiveShowView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var previewScale: CGFloat = 1
    @State private var sceneCueScale: CGFloat = 1
    @State private var showCueScale: CGFloat = 1

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if !appModel.performanceMode {
                    Text("Cosmic Visualizer")
                        .font(.largeTitle.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.95), Color.pink.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                if let err = appModel.audioError {
                    HStack(spacing: 8) {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                        if appModel.isMicrophonePermissionDenied {
                            Button("Open Microphone Settings") {
                                appModel.openMicrophonePrivacySettings()
                            }
                            .controlSize(.small)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Toggle("Performance", isOn: $appModel.performanceMode)
                        .toggleStyle(.switch)
                }

                devicePicker
                audioLevelAndBeatPulseRow
                liveContextSummaryStrip

                fogHazeEmergencyRow

                if let renderer = appModel.metalRenderer {
                    scalablePanel(scale: $previewScale) {
                        AspectFitLivePreviewContainer(renderer: renderer, minHeight: 280 * previewScale)
                    }

                    if !appModel.performanceMode {
                        scalablePanel(scale: $sceneCueScale) {
                            SceneCueStripView(cardScale: sceneCueScale)
                                .onAppear {
                                    appModel.refreshScenePreviewPool()
                                }
                        }
                        scalablePanel(scale: $showCueScale) {
                            LiveShowCueStripsView(chipScale: showCueScale)
                        }
                    } else if appModel.remoteSettings.lightingPerformanceStripEnabled
                        || appModel.remoteSettings.backdropPerformanceStripEnabled {
                        scalablePanel(scale: $showCueScale) {
                            LiveShowCueStripsView(chipScale: showCueScale)
                        }
                    }
                } else {
                    Text("Metal could not be initialized on this Mac.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }

                performanceSceneActionsRow
                quickPaletteControls
                recordingControls
                overlayAndLiquidToggles
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .onChange(of: appModel.selectedPaletteID) { _, _ in
            appModel.syncRendererFromScene()
        }
    }

    private func scalablePanel<Content: View>(scale: Binding<CGFloat>, @ViewBuilder content: () -> Content) -> some View {
        content()
            .overlay(alignment: .topTrailing) {
                HoverScaleButtons(scale: scale, range: 0.7 ... 1.8, step: 0.1)
                    .padding(6)
            }
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audio input")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Device", selection: appModel.selectedInputDeviceBinding) {
                Text("System default").tag(Optional<AudioDeviceID>.none)
                ForEach(appModel.audioEngine.availableInputDevices) { dev in
                    Text(dev.name).tag(Optional<AudioDeviceID>.some(dev.id))
                }
            }
            .labelsHidden()
            Picker("Channel", selection: appModel.selectedInputChannelBinding) {
                ForEach(appModel.availableInputChannelChoices) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .pickerStyle(.menu)
        }
    }

    /// Visible RMS level + beat-phase ring (`AppModel.tempoClock`).
    private var audioLevelAndBeatPulseRow: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Input level")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    GeometryReader { geo in
                        let rms = Double(appModel.audioEngine.features.rms)
                        let width = max(4, geo.size.width * min(1, rms * 4.2))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.85), Color.purple.opacity(0.75)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: width)
                        }
                    }
                    .frame(height: 10)
                    Text(String(format: "Peak %.0f%% · RMS %.0f%%", appModel.audioEngine.features.peak * 100, appModel.audioEngine.features.rms * 100))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 4) {
                    Text("Beat")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ZStack {
                        Circle()
                            .stroke(Color.pink.opacity(0.25), lineWidth: 3)
                            .frame(width: 46, height: 46)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(1, max(0, appModel.tempoClock.beatPhase))))
                            .stroke(
                                AngularGradient(colors: [Color.pink, Color.orange, Color.pink], center: .center),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 46, height: 46)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.08), value: appModel.tempoClock.beatPhase)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var liveContextSummaryStrip: some View {
        let sceneName: String = {
            guard appModel.sceneManager.scenes.indices.contains(appModel.sceneManager.currentIndex) else { return "—" }
            return appModel.sceneManager.scenes[appModel.sceneManager.currentIndex].name
        }()
        let paletteName: String = {
            guard let id = appModel.selectedPaletteID,
                  let p = appModel.palettes.first(where: { $0.id == id }) else { return "—" }
            return p.name
        }()
        let cueName: String = {
            guard let idx = appModel.lightingCueDocument.activeCueIndex,
                  appModel.lightingCueDocument.cues.indices.contains(idx) else { return "—" }
            return appModel.lightingCueDocument.cues[idx].name
        }()
        return GroupBox("Active") {
            HStack(alignment: .top, spacing: 20) {
                summaryLabeledColumn(title: "Scene", value: sceneName)
                summaryLabeledColumn(title: "Palette", value: paletteName)
                summaryLabeledColumn(title: "Lighting cue", value: cueName)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summaryLabeledColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: 200, alignment: .leading)
    }

    private var fogHazeEmergencyRow: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "cloud.fog.fill")
                    .foregroundStyle(appModel.hazeEmergencyKillActive ? Color.orange : Color.secondary)
                if appModel.hazeEmergencyKillActive {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fog / haze emergency OFF")
                            .font(.headline)
                        Text("Hazer output and pump are forced to 0 until you resume. Fan follows the cue/patch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button("Resume hazer from cue") {
                        appModel.setHazeEmergencyKill(false)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fog / haze")
                            .font(.headline)
                        Text("Latch kills hazer output and pump on the next DMX frames.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button("Fog / haze OFF") {
                        appModel.setHazeEmergencyKill(true)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Performance: scene transport, tempo readout, tap; overlay file tools tucked into a menu.
    private var performanceSceneActionsRow: some View {
        GroupBox("Performance") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button("Previous") {
                        appModel.previousScene()
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    Button("Next") {
                        appModel.nextScene()
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [])

                    Button("Random") {
                        appModel.randomScene()
                    }

                    Button("Fullscreen this window") {
                        appModel.toggleMainWindowFullscreen()
                    }
                    .keyboardShortcut("f", modifiers: [.command, .shift])

                    Button("Tap tempo") {
                        appModel.applyRemoteCommand(RemoteControlCommand(type: "TapTempo"))
                    }
                    .buttonStyle(.bordered)

                    Menu {
                        Button("Import overlay…") {
                            appModel.importOverlayAsset()
                        }
                        Button("Remove black → PNG…") {
                            appModel.exportBlackBackgroundRemovedCopy()
                        }
                    } label: {
                        Label("Overlay file tools…", systemImage: "ellipsis.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.45, green: 0.2, blue: 0.75))

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(appModel.bpm.rounded()))")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color(red: 0.4, green: 0.95, blue: 0.95))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Beat confidence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", appModel.beatConfidence * 100))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(Color.pink.opacity(0.9))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MIDI clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(appModel.tempoClock.midiClockRunning ? "Running" : "Idle")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text("Full tempo source / BPM on Controller tab.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var quickPaletteControls: some View {
        GroupBox("Look / palette") {
            VStack(alignment: .leading, spacing: 8) {
                if appModel.palettes.isEmpty {
                    Text("No palettes available. Add palettes in Scene Studio.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Palette", selection: Binding(
                        get: { appModel.selectedPaletteID ?? appModel.palettes.first?.id },
                        set: { newID in
                            appModel.selectedPaletteID = newID
                        }
                    )) {
                        ForEach(appModel.palettes) { palette in
                            Text(palette.name).tag(Optional(palette.id))
                        }
                    }
                    .pickerStyle(.menu)
                    HStack(spacing: 8) {
                        Button("Previous palette") {
                            guard !appModel.palettes.isEmpty else { return }
                            let current = appModel.selectedPaletteID ?? appModel.palettes.first!.id
                            guard let idx = appModel.palettes.firstIndex(where: { $0.id == current }) else { return }
                            let prev = idx > 0 ? idx - 1 : appModel.palettes.count - 1
                            appModel.selectedPaletteID = appModel.palettes[prev].id
                        }
                        .controlSize(.small)
                        Button("Next palette") {
                            guard !appModel.palettes.isEmpty else { return }
                            let current = appModel.selectedPaletteID ?? appModel.palettes.first!.id
                            guard let idx = appModel.palettes.firstIndex(where: { $0.id == current }) else { return }
                            let next = (idx + 1) % appModel.palettes.count
                            appModel.selectedPaletteID = appModel.palettes[next].id
                        }
                        .controlSize(.small)
                    }
                    Text("For full palette and overlay authoring, use Scene Studio (intentional consolidation).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var overlayAndLiquidToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Toggle("Logo overlay (GPU + fractal fusion)", isOn: Binding(
                    get: { appModel.overlayEnabled },
                    set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetOverlayEnabled", enabled: $0)) }
                ))
                .foregroundStyle(.secondary)
                Toggle("Liquid light", isOn: Binding(
                    get: {
                        guard appModel.sceneManager.scenes.indices.contains(appModel.sceneManager.currentIndex) else { return false }
                        return appModel.sceneManager.scenes[appModel.sceneManager.currentIndex].liquidLightEnabled
                    },
                    set: { on in
                        appModel.applyRemoteCommand(RemoteControlCommand(type: "SetLiquidLightEnabled", enabled: on))
                    }
                ))
            }
            if appModel.overlayEnabled {
                HStack(spacing: 12) {
                    Toggle("Adjust placement (drag / pinch on preview)", isOn: Binding(
                        get: { appModel.overlayPlacementInteractionEnabled },
                        set: { appModel.overlayPlacementInteractionEnabled = $0 }
                    ))
                    Button("Reset logo frame") {
                        appModel.resetOverlayRectToFullFrame()
                    }
                }
            }
        }
        .font(.subheadline)
    }

    private var recordingControls: some View {
        GroupBox("Capture / output") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Video source", selection: $appModel.liveOutputRecordingSource) {
                    ForEach(AppModel.LiveOutputRecordingSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.menu)
                .disabled(appModel.isLiveOutputRecording)
                Picker("Quality", selection: $appModel.liveOutputRecordingQualityPreset) {
                    ForEach(AppModel.LiveOutputRecordingQualityPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .disabled(appModel.isLiveOutputRecording)
                let healthItems = appModel.liveOutputRecorderHealthItems(
                    preferredMainWindowNumber: NSApp.keyWindow?.windowNumber
                )
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(healthItems) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(item.isHealthy ? Color.green : Color.orange)
                            Text(item.message)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 10) {
                    if appModel.isLiveOutputRecording {
                        Button("Stop recording") {
                            appModel.stopLiveOutputRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button("Start recording") {
                            appModel.startLiveOutputRecording(preferredMainWindowNumber: NSApp.keyWindow?.windowNumber)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if let url = appModel.lastRecordingURL {
                        ShareLink(item: url) {
                            Label("Share…", systemImage: "square.and.arrow.up")
                        }
                        .controlSize(.small)
                        Button("Reveal in Finder") {
                            appModel.revealLastRecordingInFinder()
                        }
                        .controlSize(.small)
                    }
                }
                if appModel.isLiveOutputRecording {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("Recording \(recordingDurationString())")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.red)
                    }
                }
                if !appModel.liveOutputRecordingStatus.isEmpty {
                    Text(appModel.liveOutputRecordingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !appModel.liveOutputRecordingAudioDiagnostic.isEmpty {
                    Text(appModel.liveOutputRecordingAudioDiagnostic)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func recordingDurationString() -> String {
        guard let started = appModel.liveOutputRecordingStartedAt else { return "00:00" }
        let elapsed = max(0, Int(Date().timeIntervalSince(started)))
        let mins = elapsed / 60
        let secs = elapsed % 60
        return String(format: "%02d:%02d", mins, secs)
    }

}

private struct HoverScaleButtons: View {
    @Binding var scale: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    @State private var hoveringContainer = false
    @State private var hoveringButton: Int?

    var body: some View {
        HStack(spacing: 4) {
            button(icon: "minus", tag: 0) {
                scale = max(range.lowerBound, scale - step)
            }
            button(icon: "plus", tag: 1) {
                scale = min(range.upperBound, scale + step)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(hoveringContainer ? 1 : 0.2)
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveringContainer = inside
            }
        }
    }

    private func button(icon: String, tag: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 18, height: 18)
                .background(
                    (hoveringButton == tag ? Color.accentColor.opacity(0.35) : Color.clear),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .onHover { inside in
            hoveringButton = inside ? tag : nil
        }
    }
}
