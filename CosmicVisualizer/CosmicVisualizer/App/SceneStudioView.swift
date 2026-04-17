import AppKit
import SwiftUI

struct SceneStudioView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var newPalettePresented = false
    @State private var paletteDraftName = "Custom nebula"
    @State private var paletteDraftPrimary = Color(nsColor: NSColor(hexRGB: "#0B0118") ?? .black)
    @State private var paletteDraftSecondary = Color(nsColor: NSColor(hexRGB: "#1A0A33") ?? .black)
    @State private var paletteDraftAccent = Color(nsColor: NSColor(hexRGB: "#00E5FF") ?? .cyan)
    @State private var paletteDraftGlow = Color(nsColor: NSColor(hexRGB: "#FF2EE6") ?? .magenta)
    @State private var paletteAIPrompt = "cosmic neon"
    @State private var fractalSectionExpanded = true
    @State private var lookSectionExpanded = true
    @State private var liquidSectionExpanded = true
    @State private var editingDropperLayerID: UUID?
    @State private var liquidPaletteDraftName = "Liquid palette"
    @State private var previewScale: CGFloat = 1.0
    private let wideLayoutMinWidth: CGFloat = 1080

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= wideLayoutMinWidth {
                HStack(alignment: .top, spacing: 10) {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 10) {
                            studioLivePreviewColumn
                            studioControlsStack(includeLiquid: true, includeFractal: false)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 280, idealWidth: 540, maxWidth: .infinity)

                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 10) {
                            sceneSectionCompact
                                .simultaneousGesture(TapGesture().onEnded { appModel.disarmLiquidDropper() })
                            fractalUniverseCard
                            paletteStripCompact
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 340, idealWidth: 460, maxWidth: 520)
                }
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 10) {
                        studioLivePreviewColumn
                        sceneSectionCompact
                            .simultaneousGesture(TapGesture().onEnded { appModel.disarmLiquidDropper() })
                        studioControlsStack(includeLiquid: true, includeFractal: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .onChange(of: appModel.selectedPaletteID) { _, _ in
            appModel.syncRendererFromScene()
        }
        .onAppear {
            previewScale = CGFloat(max(0.7, min(1.8, appModel.remoteSettings.sceneStudioPreviewScale)))
        }
        .onChange(of: previewScale) { _, v in
            var s = appModel.remoteSettings
            s.sceneStudioPreviewScale = Double(v)
            appModel.remoteSettings = s
        }
        .sheet(isPresented: $newPalettePresented) {
            NavigationStack {
                Form {
                    Section("Step 1 · Name") {
                        TextField("Name", text: $paletteDraftName)
                    }
                    Section("Step 2 · Color wheel selection") {
                        colorWheelRow(title: "Primary", color: $paletteDraftPrimary)
                        colorWheelRow(title: "Secondary", color: $paletteDraftSecondary)
                        colorWheelRow(title: "Accent", color: $paletteDraftAccent)
                        colorWheelRow(title: "Glow", color: $paletteDraftGlow)
                    }
                    Section("Step 3 · AI assist") {
                        TextField("Mood prompt (example: dreamy synthwave)", text: $paletteAIPrompt)
                        Button("AI assist palette") {
                            applyAIAssistPalette(prompt: paletteAIPrompt)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Text("AI assist proposes wheel colors from the mood prompt. You can fine-tune each wheel before saving.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("New palette wizard")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { newPalettePresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let pal = ThemePalette(
                                name: paletteDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "Custom" : paletteDraftName,
                                primaryHex: Self.hexString(from: paletteDraftPrimary),
                                secondaryHex: Self.hexString(from: paletteDraftSecondary),
                                accentHex: Self.hexString(from: paletteDraftAccent),
                                glowHex: Self.hexString(from: paletteDraftGlow)
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

    private var studioLivePreviewColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Label("Scene Studio", systemImage: "square.stack.3d.up.fill")
                    .font(.headline)
                Spacer(minLength: 8)
                Text(presentationOutputPreviewCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            if let renderer = appModel.metalRenderer {
                AspectFitLivePreviewContainer(renderer: renderer, minHeight: 320 * previewScale)
                    .layoutPriority(1)
                    .overlay(alignment: .topTrailing) {
                        SceneStudioScaleButtons(scale: $previewScale, range: 0.7 ... 1.8, step: 0.1)
                            .padding(6)
                    }
            } else {
                ContentUnavailableView(
                    "No GPU preview",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Metal could not be initialized on this Mac.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
    }

    private var presentationOutputPreviewCaption: String {
        let mode = appModel.remoteSettings.previewAspectRatioSelection
        switch mode {
        case .auto:
            let screens = NSScreen.screens
            let idx = appModel.externalOutputScreenIndex
            guard screens.indices.contains(idx) else {
                return "Live preview · Auto"
            }
            let f = screens[idx].frame
            let w = Int(f.width.rounded())
            let h = Int(f.height.rounded())
            return "Live preview · Auto · \(w)×\(h) output"
        case .applicationWindow:
            return "Live preview · Application window aspect"
        default:
            return "Live preview · \(mode.pickerLabel)"
        }
    }

    private func studioControlsStack(includeLiquid: Bool, includeFractal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if includeFractal {
                fractalUniverseCard
                paletteStripCompact
            }
            DisclosureGroup(isExpanded: $lookSectionExpanded) {
                sceneLookControlsCompact
            } label: {
                Label("Scene look", systemImage: "paintpalette.fill")
                    .font(.subheadline.weight(.medium))
            }
            .simultaneousGesture(TapGesture().onEnded { appModel.disarmLiquidDropper() })
            if includeLiquid {
                liquidControlsCard
            }
            overlayAuthoringCompact
                .simultaneousGesture(TapGesture().onEnded { appModel.disarmLiquidDropper() })
            OverlayCardAuthoringView()
            Toggle("Liquid light (current scene)", isOn: Binding(
                get: {
                    guard appModel.sceneManager.scenes.indices.contains(appModel.sceneManager.currentIndex) else { return false }
                    return appModel.sceneManager.scenes[appModel.sceneManager.currentIndex].liquidLightEnabled
                },
                set: { appModel.applyRemoteCommand(RemoteControlCommand(type: "SetLiquidLightEnabled", enabled: $0)) }
            ))
            .controlSize(.small)
            .onChange(of: currentSceneLiquidEnabled) { _, enabled in
                if !enabled {
                    appModel.disarmLiquidDropper()
                }
            }
        }
    }

    private var fractalUniverseCard: some View {
        DisclosureGroup(isExpanded: $fractalSectionExpanded) {
            fractalUniverseControlsCompact
        } label: {
            Label("Fractal universe", systemImage: "circle.hexagongrid.fill")
                .font(.subheadline.weight(.medium))
        }
        .simultaneousGesture(TapGesture().onEnded { appModel.disarmLiquidDropper() })
    }

    private var liquidControlsCard: some View {
        DisclosureGroup(isExpanded: $liquidSectionExpanded) {
            liquidPourControlsCompact
        } label: {
            Label("Liquid pour & tray", systemImage: "drop.fill")
                .font(.subheadline.weight(.medium))
        }
    }

    private var sceneSectionCompact: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button("Duplicate") {
                        appModel.applyRemoteCommand(RemoteControlCommand(type: "DuplicateScene"))
                    }
                    Button("Delete", role: .destructive) {
                        appModel.applyRemoteCommand(RemoteControlCommand(type: "DeleteScene"))
                    }
                    .disabled(appModel.sceneManager.scenes.count <= 1)
                    Spacer(minLength: 0)
                    Button("Save") {
                        try? appModel.persistScenes()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.45, green: 0.2, blue: 0.75))
                Text("Scenes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                List(selection: sceneListSelection) {
                    ForEach(appModel.sceneManager.scenes) { scene in
                        Text(scene.name)
                            .tag(scene.id as UUID?)
                    }
                }
                .frame(minHeight: 100, maxHeight: 180)
                .scrollContentBackground(.hidden)
            }
        } label: {
            Text("Scene")
                .font(.caption.weight(.semibold))
        }
    }

    private var sceneListSelection: Binding<UUID?> {
        Binding(
            get: { appModel.selectedSceneID },
            set: { id in
                guard let id else { return }
                appModel.applyRemoteCommand(RemoteControlCommand(type: "JumpToScene", sceneID: id))
            }
        )
    }

    private var fractalUniverseControlsCompact: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Geometry", selection: fractalGeometryBinding) {
                Text("Julia").tag(0)
                Text("Mandelbrot").tag(1)
                Text("Burning Ship").tag(2)
                Text("Tricorn").tag(3)
                Text("Multibrot (cubic)").tag(4)
            }
            .controlSize(.small)
            studioCaptionSlider(title: "Zoom", value: appModel.layerFloatBinding(for: .fractalZoom), in: LayerControlParameter.fractalZoom.floatRange)
            Toggle("Explore (animated zoom / pan)", isOn: fractalExploreToggleBinding)
                .controlSize(.small)
            HStack(alignment: .top, spacing: 10) {
                studioCaptionSlider(title: "Explore amt", value: fractalExploreAmountBinding, in: 0 ... 1)
                studioCaptionSlider(title: "Explore spd", value: fractalExploreSpeedBinding, in: 0.05 ... 1.2)
            }
            HStack(alignment: .top, spacing: 10) {
                studioCaptionSlider(title: "Pan X", value: fractalPanXBinding, in: -1.2 ... 1.2)
                studioCaptionSlider(title: "Pan Y", value: fractalPanYBinding, in: -1.2 ... 1.2)
            }
            studioCaptionSlider(title: "Iteration boost", value: fractalIterBoostBinding, in: 0.25 ... 3)
            Picker("Motion", selection: zoomEffectTypeBinding) {
                Text("Drift").tag(0)
                Text("Pulse").tag(1)
                Text("Breathe").tag(2)
            }
            .pickerStyle(.segmented)
            studioCaptionSlider(title: "Smooth shading", value: appModel.layerFloatBinding(for: .fractalSmoothShading), in: 0 ... 1)
            HStack(alignment: .top, spacing: 10) {
                studioCaptionSlider(title: "Bloom", value: appModel.layerFloatBinding(for: .compositeBloomStrength), in: 0 ... 0.5)
                studioCaptionSlider(title: "Vignette", value: appModel.layerFloatBinding(for: .compositeVignetteStrength), in: 0 ... 0.85)
            }
            studioCaptionSlider(title: "Dye mix", value: appModel.layerFloatBinding(for: .dyeMix), in: 0 ... 1)
        }
        .controlSize(.small)
    }

    private var fractalGeometryBinding: Binding<Int> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0 }
                return Int(appModel.sceneEditStates[id]?.layer.fractalGeometryIndex ?? 0)
            },
            set: { v in
                appModel.applyCurrentLayerEdit { $0.fractalGeometryIndex = Float(max(0, min(4, v))) }
            }
        )
    }

    private var fractalExploreToggleBinding: Binding<Bool> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return false }
                return (appModel.sceneEditStates[id]?.layer.fractalExplore ?? 0) > 0.02
            },
            set: { on in
                appModel.applyCurrentLayerEdit { $0.fractalExplore = on ? max(0.35, $0.fractalExplore) : 0 }
            }
        )
    }

    private var fractalExploreAmountBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0 }
                return appModel.sceneEditStates[id]?.layer.fractalExplore ?? 0
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.fractalExplore = v } }
        )
    }

    private var fractalExploreSpeedBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0.35 }
                return appModel.sceneEditStates[id]?.layer.fractalExploreSpeed ?? 0.35
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.fractalExploreSpeed = v } }
        )
    }

    private var fractalPanXBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0 }
                return appModel.sceneEditStates[id]?.layer.fractalPanX ?? 0
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.fractalPanX = v } }
        )
    }

    private var fractalPanYBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0 }
                return appModel.sceneEditStates[id]?.layer.fractalPanY ?? 0
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.fractalPanY = v } }
        )
    }

    private var fractalIterBoostBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 1 }
                return appModel.sceneEditStates[id]?.layer.fractalIterBoost ?? 1
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.fractalIterBoost = v } }
        )
    }

    private var zoomEffectTypeBinding: Binding<Int> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0 }
                return Int(appModel.sceneEditStates[id]?.layer.zoomEffectType ?? 0)
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.zoomEffectType = Float(max(0, min(2, v))) } }
        )
    }

    @ViewBuilder
    private func studioCaptionSlider(title: String, value: Binding<Float>, in range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Slider(
                value: value,
                in: range,
                onEditingChanged: { editing in
                    if editing {
                        appModel.disarmLiquidDropper()
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var liquidPourControlsCompact: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(currentDropperLayers) { layer in
                    Button {
                        guard currentSceneLiquidEnabled else { return }
                        setActiveDropperLayer(id: layer.id)
                        editingDropperLayerID = layer.id
                        appModel.liquidDropperArmed = true
                    } label: {
                        Circle()
                            .fill(Color(red: Double(layer.colorR), green: Double(layer.colorG), blue: Double(layer.colorB)))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isActiveDropperLayer(layer.id) ? Color.cyan : Color.white.opacity(0.25),
                                        lineWidth: isActiveDropperLayer(layer.id) ? 2 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!currentSceneLiquidEnabled)
                    .popover(isPresented: Binding(
                        get: { editingDropperLayerID == layer.id },
                        set: { if !$0 { editingDropperLayerID = nil } }
                    )) {
                        dropperLayerEditor(layerID: layer.id)
                            .padding(12)
                            .frame(width: 280)
                    }
                }
                if currentDropperLayers.count < SceneEditState.LayerControls.maxDropperLayers {
                    Button {
                        appendDropperLayer()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(!currentSceneLiquidEnabled)
                }
                Spacer()
            }

            HStack(alignment: .top, spacing: 10) {
                studioCaptionSlider(title: "Tilt X", value: liquidTiltXBinding, in: -1 ... 1)
                studioCaptionSlider(title: "Tilt Y", value: liquidTiltYBinding, in: -1 ... 1)
            }
            studioCaptionSlider(
                title: "Drop dissolve (fast → hold)",
                value: liquidDissolveHoldBinding,
                in: 0 ... 1
            )
            studioCaptionSlider(
                title: "Reconstitute bubbles",
                value: liquidReconstituteAmountBinding,
                in: 0 ... 1
            )
            Toggle("Reconstitute rate sync to BPM", isOn: liquidReconstituteBPMSyncBinding)
                .controlSize(.small)
            if !liquidReconstituteBPMSyncBinding.wrappedValue {
                studioCaptionSlider(
                    title: "Reconstitute rate",
                    value: liquidReconstituteRateBinding,
                    in: 0.05 ... 3
                )
            } else {
                Text("Rate follows BPM. Increase BPM or use Tap tempo to speed reconstitution.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 8) {
                Picker("Palette", selection: selectedLiquidPaletteID) {
                    Text("Choose palette").tag(UUID?.none)
                    ForEach(appModel.liquidPalettes) { pal in
                        Text(pal.name).tag(UUID?.some(pal.id))
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                TextField("Palette name", text: $liquidPaletteDraftName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                Button("Save palette") {
                    appModel.saveCurrentLiquidDropperPalette(name: liquidPaletteDraftName)
                }
                .controlSize(.small)
            }
            HStack(spacing: 8) {
                Text(appModel.liquidDropperArmed ? "Dropper armed from selected layer." : "Tap a color circle to arm dropper.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if appModel.liquidDropperArmed {
                    Button("Disarm") {
                        appModel.disarmLiquidDropper()
                    }
                    .controlSize(.small)
                }
            }
            Text("Use the live preview on the left: tap to splat, hold to pour. Orange border = armed.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button("Clear dye") {
                appModel.clearLiquidDyeOnAllRenderers()
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    private var overlayAuthoringCompact: some View {
        GroupBox {
            HStack(spacing: 8) {
                Button("Import overlay…") {
                    appModel.importOverlayAsset()
                }
                Button("Remove black → PNG…") {
                    appModel.exportBlackBackgroundRemovedCopy()
                }
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        } label: {
            Text("Overlays")
                .font(.caption.weight(.semibold))
        }
    }

    private var liquidTiltXBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0 }
                return appModel.sceneEditStates[id]?.layer.liquidTiltX ?? 0
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.liquidTiltX = v } }
        )
    }

    private var liquidTiltYBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0 }
                return appModel.sceneEditStates[id]?.layer.liquidTiltY ?? 0
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.liquidTiltY = v } }
        )
    }

    private var liquidDissolveHoldBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0.65 }
                return appModel.sceneEditStates[id]?.layer.liquidDissolveHold ?? 0.65
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.liquidDissolveHold = v } }
        )
    }

    private var liquidReconstituteAmountBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0 }
                return appModel.sceneEditStates[id]?.layer.liquidReconstituteAmount ?? 0
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.liquidReconstituteAmount = v } }
        )
    }

    private var liquidReconstituteRateBinding: Binding<Float> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return 0.55 }
                return appModel.sceneEditStates[id]?.layer.liquidReconstituteRate ?? 0.55
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.liquidReconstituteRate = v } }
        )
    }

    private var liquidReconstituteBPMSyncBinding: Binding<Bool> {
        Binding(
            get: {
                guard let id = appModel.selectedSceneID else { return false }
                return appModel.sceneEditStates[id]?.layer.liquidReconstituteBPMSync ?? false
            },
            set: { v in appModel.applyCurrentLayerEdit { $0.liquidReconstituteBPMSync = v } }
        )
    }

    private var currentSceneLiquidEnabled: Bool {
        guard appModel.sceneManager.scenes.indices.contains(appModel.sceneManager.currentIndex) else { return false }
        return appModel.sceneManager.scenes[appModel.sceneManager.currentIndex].liquidLightEnabled
    }

    private var currentDropperLayers: [SceneEditState.LayerControls.LiquidDropperLayer] {
        guard let id = appModel.selectedSceneID else { return SceneEditState.LayerControls.defaultDropperLayers }
        return appModel.sceneEditStates[id]?.layer.liquidDropperLayers ?? SceneEditState.LayerControls.defaultDropperLayers
    }

    private var selectedLiquidPaletteID: Binding<UUID?> {
        Binding(
            get: { nil },
            set: { id in
                guard let id else { return }
                appModel.disarmLiquidDropper()
                appModel.applyLiquidDropperPalette(id: id)
            }
        )
    }

    private func isActiveDropperLayer(_ id: UUID) -> Bool {
        guard let sceneID = appModel.selectedSceneID,
              let layerControls = appModel.sceneEditStates[sceneID]?.layer,
              layerControls.liquidDropperLayers.indices.contains(layerControls.activeDropperLayerIndex)
        else { return false }
        return layerControls.liquidDropperLayers[layerControls.activeDropperLayerIndex].id == id
    }

    private func setActiveDropperLayer(id: UUID) {
        appModel.applyCurrentLayerEdit { layer in
            guard let idx = layer.liquidDropperLayers.firstIndex(where: { $0.id == id }) else { return }
            layer.activeDropperLayerIndex = idx
        }
    }

    private func appendDropperLayer() {
        appModel.applyCurrentLayerEdit { layer in
            guard layer.liquidDropperLayers.count < SceneEditState.LayerControls.maxDropperLayers else { return }
            let nextIndex = layer.liquidDropperLayers.count
            let prevViscosity = layer.liquidDropperLayers.last?.viscosity ?? 0.85
            let next = SceneEditState.LayerControls.LiquidDropperLayer(
                name: "Layer \(nextIndex)",
                colorR: 0.25 + Float(nextIndex % 3) * 0.2,
                colorG: 0.65,
                colorB: 1.0 - Float(nextIndex % 2) * 0.25,
                viscosity: max(0.1, prevViscosity - 0.12)
            )
            layer.liquidDropperLayers.append(next)
            layer.activeDropperLayerIndex = nextIndex
            editingDropperLayerID = next.id
            appModel.liquidDropperArmed = true
        }
    }

    @ViewBuilder
    private func dropperLayerEditor(layerID: UUID) -> some View {
        if let layer = currentDropperLayers.first(where: { $0.id == layerID }) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Layer editor")
                    .font(.headline)
                ColorPicker("Color", selection: colorBinding(for: layerID))
                Picker("Layer (viscosity)", selection: layerSelectionBinding(selectedID: layerID)) {
                    ForEach(Array(currentDropperLayers.enumerated()), id: \.element.id) { pair in
                        Text(pair.offset == 0 ? "Base" : "Layer \(pair.offset)").tag(pair.element.id)
                    }
                }
                .pickerStyle(.menu)
                studioCaptionSlider(title: "Viscosity", value: viscosityBinding(for: layerID), in: 0 ... 1)
                Button("Remove layer", role: .destructive) {
                    removeDropperLayer(id: layerID)
                }
                .disabled(currentDropperLayers.count <= 1)
            }
            .onAppear {
                setActiveDropperLayer(id: layer.id)
            }
        } else {
            Text("Layer unavailable.")
        }
    }

    private func colorBinding(for layerID: UUID) -> Binding<Color> {
        Binding(
            get: {
                guard let layer = currentDropperLayers.first(where: { $0.id == layerID }) else {
                    return .cyan
                }
                return Color(red: Double(layer.colorR), green: Double(layer.colorG), blue: Double(layer.colorB))
            },
            set: { newColor in
                let ns = NSColor(newColor)
                var r: CGFloat = 0
                var g: CGFloat = 0
                var b: CGFloat = 0
                var a: CGFloat = 0
                ns.getRed(&r, green: &g, blue: &b, alpha: &a)
                appModel.applyCurrentLayerEdit { controls in
                    guard let idx = controls.liquidDropperLayers.firstIndex(where: { $0.id == layerID }) else { return }
                    controls.liquidDropperLayers[idx].colorR = Float(r)
                    controls.liquidDropperLayers[idx].colorG = Float(g)
                    controls.liquidDropperLayers[idx].colorB = Float(b)
                }
            }
        )
    }

    private func viscosityBinding(for layerID: UUID) -> Binding<Float> {
        Binding(
            get: {
                currentDropperLayers.first(where: { $0.id == layerID })?.viscosity ?? 0.5
            },
            set: { value in
                appModel.applyCurrentLayerEdit { controls in
                    guard let idx = controls.liquidDropperLayers.firstIndex(where: { $0.id == layerID }) else { return }
                    controls.liquidDropperLayers[idx].viscosity = value
                }
            }
        )
    }

    private func layerSelectionBinding(selectedID: UUID) -> Binding<UUID> {
        Binding(
            get: { selectedID },
            set: { newID in
                setActiveDropperLayer(id: newID)
                editingDropperLayerID = newID
                appModel.liquidDropperArmed = currentSceneLiquidEnabled
            }
        )
    }

    private func removeDropperLayer(id: UUID) {
        appModel.applyCurrentLayerEdit { controls in
            guard controls.liquidDropperLayers.count > 1,
                  let idx = controls.liquidDropperLayers.firstIndex(where: { $0.id == id })
            else { return }
            controls.liquidDropperLayers.remove(at: idx)
            controls.activeDropperLayerIndex = max(0, min(controls.activeDropperLayerIndex, controls.liquidDropperLayers.count - 1))
        }
        if editingDropperLayerID == id {
            editingDropperLayerID = nil
        }
    }

    private var sceneLookControlsCompact: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                studioCaptionSlider(title: "Liquid focus", value: appModel.layerFloatBinding(for: .liquidFocus), in: LayerControlParameter.liquidFocus.floatRange)
                studioCaptionSlider(title: "Fractal look", value: appModel.layerFloatBinding(for: .fractalAppearance), in: LayerControlParameter.fractalAppearance.floatRange)
            }
            HStack(alignment: .top, spacing: 10) {
                studioCaptionSlider(title: "Logo ↔ fractal", value: appModel.layerFloatBinding(for: .overlayFractalFusion), in: LayerControlParameter.overlayFractalFusion.floatRange)
                studioCaptionSlider(title: "Liquid turbulence", value: appModel.layerFloatBinding(for: .liquidTurbulence), in: LayerControlParameter.liquidTurbulence.floatRange)
            }
            studioCaptionSlider(title: "Composite blend", value: appModel.layerFloatBinding(for: .compositeBlend), in: LayerControlParameter.compositeBlend.floatRange)
        }
        .controlSize(.small)
    }

    private var paletteStripCompact: some View {
        GroupBox {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(appModel.palettes) { pal in
                        paletteSwatch(pal)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        } label: {
            HStack {
                Text("Palettes")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("New…") {
                    paletteDraftName = "Custom nebula"
                    paletteDraftPrimary = Color(nsColor: NSColor(hexRGB: "#0B0118") ?? .black)
                    paletteDraftSecondary = Color(nsColor: NSColor(hexRGB: "#1A0A33") ?? .black)
                    paletteDraftAccent = Color(nsColor: NSColor(hexRGB: "#00E5FF") ?? .cyan)
                    paletteDraftGlow = Color(nsColor: NSColor(hexRGB: "#FF2EE6") ?? .magenta)
                    paletteAIPrompt = "cosmic neon"
                    newPalettePresented = true
                }
                .font(.caption2)
                .controlSize(.mini)
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
            .padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private func colorWheelRow(title: String, color: Binding<Color>) -> some View {
        HStack {
            ColorPicker(title, selection: color, supportsOpacity: false)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color.wrappedValue)
                .frame(width: 36, height: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
                }
            Text(Self.hexString(from: color.wrappedValue))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func applyAIAssistPalette(prompt: String) {
        let seed = abs(prompt.lowercased().hashValue)
        let baseHue = Double(seed % 360) / 360.0
        let accentHue = (baseHue + 0.38).truncatingRemainder(dividingBy: 1)
        let glowHue = (baseHue + 0.82).truncatingRemainder(dividingBy: 1)
        paletteDraftPrimary = Color(hue: baseHue, saturation: 0.78, brightness: 0.16)
        paletteDraftSecondary = Color(hue: (baseHue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.72, brightness: 0.26)
        paletteDraftAccent = Color(hue: accentHue, saturation: 0.92, brightness: 0.94)
        paletteDraftGlow = Color(hue: glowHue, saturation: 0.84, brightness: 0.96)
        if paletteDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            paletteDraftName = "AI \(prompt.capitalized)"
        }
    }

    private static func hexString(from color: Color) -> String {
        let ns = NSColor(color)
        guard let rgb = ns.usingColorSpace(.deviceRGB) else { return "#808080" }
        let r = Int((max(0, min(1, rgb.redComponent)) * 255).rounded())
        let g = Int((max(0, min(1, rgb.greenComponent)) * 255).rounded())
        let b = Int((max(0, min(1, rgb.blueComponent)) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

private struct SceneStudioScaleButtons: View {
    @Binding var scale: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    @State private var hoveringContainer = false
    @State private var hoveringButton: Int?

    var body: some View {
        HStack(spacing: 4) {
            button(icon: "minus", tag: 0) { scale = max(range.lowerBound, scale - step) }
            button(icon: "plus", tag: 1) { scale = min(range.upperBound, scale + step) }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(hoveringContainer ? 1 : 0.2)
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.12)) { hoveringContainer = inside }
        }
    }

    private func button(icon: String, tag: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 18, height: 18)
                .background((hoveringButton == tag ? Color.accentColor.opacity(0.35) : Color.clear), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { inside in hoveringButton = inside ? tag : nil }
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
