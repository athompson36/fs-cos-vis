import AppKit
import CoreAudio
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var newPalettePresented = false
    @State private var paletteDraftName = "Custom nebula"
    @State private var paletteDraftPrimary = "#0B0118"
    @State private var paletteDraftSecondary = "#1A0A33"
    @State private var paletteDraftAccent = "#00E5FF"
    @State private var paletteDraftGlow = "#FF2EE6"

    var body: some View {
        NavigationSplitView {
            List {
                Section("Performance") {
                    Label("Live View", systemImage: "sparkles.tv")
                    Label("Scenes", systemImage: "square.stack.3d.up")
                    Label("Overlays", systemImage: "photo.on.rectangle")
                    Label("Themes", systemImage: "paintpalette")
                }
            }
            .navigationTitle("Cosmic Visualizer")
        } detail: {
            performanceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.02, blue: 0.12),
                            Color(red: 0.08, green: 0.03, blue: 0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var performanceContent: some View {
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
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(appModel.bpm.rounded()))")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 0.4, green: 0.95, blue: 0.95))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Beat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", appModel.beatConfidence * 100))
                        .font(.title3.monospacedDigit())
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
                Spacer()
                Toggle("Performance", isOn: $appModel.performanceMode)
                    .toggleStyle(.switch)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tempo source")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Source", selection: Binding(
                        get: { appModel.tempoClock.syncSource },
                        set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetTempoSource", source: $0.rawValue)) }
                    )) {
                        Text("Audio detect").tag(TempoClockService.SyncSource.audioDetection)
                        Text("Manual").tag(TempoClockService.SyncSource.manual)
                        Text("Tap").tag(TempoClockService.SyncSource.tapTempo)
                        Text("MIDI clock").tag(TempoClockService.SyncSource.midiClock)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 280)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Manual BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("120", value: Binding(
                        get: { appModel.tempoClock.manualBPM },
                        set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetManualBPM", bpm: $0)) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                }
                Button("Tap tempo") {
                    appModel.applyRemoteCommand(RemoteControlCommand(type: "TapTempo"))
                }
                .buttonStyle(.bordered)
                Spacer()
            }

            remoteControlSettings

            devicePicker

            externalOutputControls

            if let renderer = appModel.metalRenderer {
                LivePreviewWithOverlayInteraction(renderer: renderer)

                if !appModel.performanceMode {
                    SceneCueStripView()
                        .onAppear {
                            appModel.refreshScenePreviewPool()
                        }
                }
            } else {
                Text("Metal could not be initialized on this Mac.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            }

            sceneControls

            if !appModel.performanceMode {
                sceneLookControls
                paletteStrip
            }

            overlayAndLiquidToggles
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .onAppear { appModel.startAudio() }
        .onDisappear { appModel.stopAudio() }
        .onChange(of: appModel.selectedPaletteID) { _, _ in
            appModel.syncRendererFromScene()
        }
        .sheet(isPresented: $newPalettePresented) {
            NavigationStack {
                Form {
                    TextField("Name", text: $paletteDraftName)
                    TextField("Primary #RRGGBB", text: $paletteDraftPrimary)
                    TextField("Secondary #RRGGBB", text: $paletteDraftSecondary)
                    TextField("Accent #RRGGBB", text: $paletteDraftAccent)
                    TextField("Glow #RRGGBB", text: $paletteDraftGlow)
                }
                .formStyle(.grouped)
                .navigationTitle("New palette")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { newPalettePresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let pal = ThemePalette(
                                name: paletteDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "Custom" : paletteDraftName,
                                primaryHex: RootView.normalizedHex(paletteDraftPrimary),
                                secondaryHex: RootView.normalizedHex(paletteDraftSecondary),
                                accentHex: RootView.normalizedHex(paletteDraftAccent),
                                glowHex: RootView.normalizedHex(paletteDraftGlow)
                            )
                            appModel.addPalette(pal)
                            appModel.selectedPaletteID = pal.id
                            newPalettePresented = false
                        }
                    }
                }
            }
            .frame(minWidth: 380, minHeight: 280)
        }
    }

    private var sceneLookControls: some View {
        let defaults = SceneEditState.LayerControls()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Scene look (current scene)")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Liquid focus — fuzzy colors → sharp blobs")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Slider(value: liquidFocusSliderBinding(defaults: defaults), in: 0 ... 1)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Fractal — palette gradient → deep cosmic + neon wireframe")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Slider(value: fractalAppearanceSliderBinding(defaults: defaults), in: 0 ... 1)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Logo ↔ fractal fusion (needs overlay on scene)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Slider(value: overlayFusionSliderBinding(defaults: defaults), in: 0 ... 1)
            }
        }
    }

    private func liquidFocusSliderBinding(defaults: SceneEditState.LayerControls) -> Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return defaults.liquidFocus }
                return appModel.sceneEditStates[id]?.layer.liquidFocus ?? defaults.liquidFocus
            },
            set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetLiquidFocus", liquidFocus: $0)) }
        )
    }

    private func fractalAppearanceSliderBinding(defaults: SceneEditState.LayerControls) -> Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return defaults.fractalAppearance }
                return appModel.sceneEditStates[id]?.layer.fractalAppearance ?? defaults.fractalAppearance
            },
            set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetFractalAppearance", fractalAppearance: $0)) }
        )
    }

    private func overlayFusionSliderBinding(defaults: SceneEditState.LayerControls) -> Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return defaults.overlayFractalFusion }
                return appModel.sceneEditStates[id]?.layer.overlayFractalFusion ?? defaults.overlayFractalFusion
            },
            set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetOverlayFractalFusion", overlayFractalFusion: $0)) }
        )
    }

    private static func normalizedHex(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !s.hasPrefix("#") { s = "#" + s }
        return s
    }

    private var externalOutputControls: some View {
        let screens = ExternalDisplayRouter.screens
        return VStack(alignment: .leading, spacing: 8) {
            Text("Presentation display")
                .font(.caption)
                .foregroundStyle(.secondary)
            if screens.count < 2 {
                Text("Connect an external monitor or projector to send fullscreen visuals while keeping this window for controls.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Picker("Output screen", selection: $appModel.externalOutputScreenIndex) {
                ForEach(Array(screens.enumerated()), id: \.offset) { pair in
                    Text(ExternalDisplayRouter.displayName(for: pair.element, index: pair.offset))
                        .tag(pair.offset)
                }
            }
            .labelsHidden()
            .disabled(screens.isEmpty)
            HStack(spacing: 12) {
                Button("Open visualization on display") {
                    appModel.openExternalVisualizationFullscreen()
                }
                .disabled(screens.count < 2 || appModel.isExternalVisualizationOpen)

                if appModel.isExternalVisualizationOpen {
                    Button("Close presentation") {
                        appModel.closeExternalVisualization()
                    }
                }
            }
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
        }
    }

    private var sceneControls: some View {
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

            Button("Save scenes") {
                try? appModel.persistScenes()
            }

            Button("Import overlay…") {
                appModel.importOverlayAsset()
            }
            Button("Remove black → PNG…") {
                appModel.exportBlackBackgroundRemovedCopy()
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.45, green: 0.2, blue: 0.75))
    }

    private var paletteStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Palettes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("New palette…") {
                    newPalettePresented = true
                }
                .font(.caption)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(appModel.palettes) { pal in
                        paletteSwatch(pal)
                    }
                }
            }
        }
    }

    private func paletteSwatch(_ pal: ThemePalette) -> some View {
        let selected = appModel.selectedPaletteID == pal.id
        return Button {
            appModel.selectedPaletteID = pal.id
            appModel.syncRendererFromScene()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    swatchDot(pal.primaryHex)
                    swatchDot(pal.accentHex)
                    swatchDot(pal.glowHex)
                }
                Text(pal.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Color.cyan : Color.white.opacity(0.15), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if appModel.palettes.count > 1 {
                Button("Delete", role: .destructive) {
                    appModel.deletePalette(id: pal.id)
                }
            }
        }
    }

    private func swatchDot(_ hex: String) -> some View {
        Circle()
            .fill(Color(nsColor: NSColor(hexRGB: hex) ?? .gray))
            .frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
    }

    private var remoteControlSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Remote control (HTTP + WebSocket)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Enable server (off by default · use token for LAN)", isOn: Binding(
                get: { appModel.remoteSettings.remoteControlEnabled },
                set: { v in
                    var s = appModel.remoteSettings
                    s.remoteControlEnabled = v
                    appModel.remoteSettings = s
                }
            ))
            HStack {
                Text("Port")
                    .foregroundStyle(.secondary)
                TextField("8765", value: Binding(
                    get: { appModel.remoteSettings.remoteControlPort },
                    set: { v in
                        var s = appModel.remoteSettings
                        s.remoteControlPort = v
                        appModel.remoteSettings = s
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                Toggle("Bind LAN", isOn: Binding(
                    get: { appModel.remoteSettings.bindLAN },
                    set: { v in
                        var s = appModel.remoteSettings
                        s.bindLAN = v
                        appModel.remoteSettings = s
                    }
                ))
            }
            TextField("Auth token (optional)", text: Binding(
                get: { appModel.remoteSettings.authToken },
                set: { v in
                    var s = appModel.remoteSettings
                    s.authToken = v
                    appModel.remoteSettings = s
                }
            ))
            .textFieldStyle(.roundedBorder)
            Text("Open http://127.0.0.1:<port>/ when enabled. Bundle serves WebControl assets.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Divider().padding(.vertical, 4)
            Text("MIDI source UID (empty = all)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", text: Binding(
                get: { appModel.remoteSettings.midiInputUID },
                set: { v in
                    var s = appModel.remoteSettings
                    s.midiInputUID = v
                    appModel.remoteSettings = s
                }
            ))
            .textFieldStyle(.roundedBorder)
            Text("DMX serial path (e.g. /dev/cu.usbserial-*)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("/dev/cu.usbserial-", text: Binding(
                get: { appModel.remoteSettings.dmxSerialDevicePath },
                set: { v in
                    var s = appModel.remoteSettings
                    s.dmxSerialDevicePath = v
                    appModel.remoteSettings = s
                }
            ))
            .textFieldStyle(.roundedBorder)
            Toggle("DMX output enabled", isOn: Binding(
                get: { appModel.remoteSettings.dmxOutputEnabled },
                set: { v in
                    var s = appModel.remoteSettings
                    s.dmxOutputEnabled = v
                    appModel.remoteSettings = s
                }
            ))
        }
        .font(.subheadline)
    }

    private var overlayAndLiquidToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Logo overlay (GPU + fractal fusion)", isOn: Binding(
                    get: { appModel.overlayEnabled },
                    set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetOverlayEnabled", enabled: $0)) }
                ))
                .foregroundStyle(.secondary)
                Spacer()
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
}

private extension NSColor {
    convenience init?(hexRGB: String) {
        var s = hexRGB.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xFF) / 255
        let g = CGFloat((v >> 8) & 0xFF) / 255
        let b = CGFloat(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
