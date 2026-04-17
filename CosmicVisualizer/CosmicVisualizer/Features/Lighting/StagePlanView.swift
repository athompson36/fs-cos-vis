import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Normalized 0…1 stage coordinates with drag repositioning.
struct StagePlanView: View {
    private struct StageObjectTemplate: Identifiable {
        var id: String
        var name: String
        var footprintWidthMeters: Double
        var footprintDepthMeters: Double
    }

    private static let stageObjectTemplates: [StageObjectTemplate] = [
        StageObjectTemplate(id: "drum_kit", name: "Drum kit", footprintWidthMeters: 2.2, footprintDepthMeters: 1.8),
        StageObjectTemplate(id: "keyboard_rig", name: "Keyboard rig", footprintWidthMeters: 1.8, footprintDepthMeters: 1.1),
        StageObjectTemplate(id: "guitar_amp", name: "Guitar amp", footprintWidthMeters: 0.8, footprintDepthMeters: 0.6),
        StageObjectTemplate(id: "bass_amp", name: "Bass amp", footprintWidthMeters: 0.9, footprintDepthMeters: 0.7),
        StageObjectTemplate(id: "vocal_mic", name: "Vocal mic stand", footprintWidthMeters: 0.6, footprintDepthMeters: 0.6),
        StageObjectTemplate(id: "dj_booth", name: "DJ booth", footprintWidthMeters: 2.0, footprintDepthMeters: 1.0),
        StageObjectTemplate(id: "monitor_wedge", name: "Monitor wedge", footprintWidthMeters: 0.6, footprintDepthMeters: 0.5),
        StageObjectTemplate(id: "fogger_cart", name: "Fogger/hazer cart", footprintWidthMeters: 0.8, footprintDepthMeters: 0.8),
    ]

    @EnvironmentObject private var appModel: AppModel
    @State private var dragKey: String?
    @State private var dragStart: StagePlacement?
    @State private var selectedFixtureKey: String?
    @State private var selectedPlotObjectID: UUID?
    @State private var plotObjectDragStart: StagePlotObject?
    @State private var cameraDragKey: String?
    @State private var cameraDragStart: StageScanCameraPlacement?
    @State private var backdropDragStart: StageBackdropPlacement?
    @State private var backdropImportError: String?
    @State private var selectedTemplateID = stageObjectTemplates.first?.id ?? ""
    @State private var snapToGridEnabled = true
    @State private var snapGridDivisions = 24

    var body: some View {
        GroupBox("Stage layout (2D)") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Import backdrop image…") { importBackdrop() }
                    if appModel.stageLayoutDocument.backdropAssetPath != nil {
                        Button("Clear backdrop") {
                            var s = appModel.stageLayoutDocument
                            s.backdropAssetPath = nil
                            appModel.applyStageLayoutDocument(s)
                        }
                    }
                    if selectedFixtureKey != nil {
                        Button("Clear selection") { selectedFixtureKey = nil }
                    }
                    if selectedPlotObjectID != nil {
                        Button("Clear object selection") { selectedPlotObjectID = nil }
                    }
                }
                stageDimensionsControls
                stageObjectControls
                scanCameraControls
                backdropEditorControls
                if let backdropImportError {
                    Text(backdropImportError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        backdropLayer(size: geo.size)
                        ForEach(Array(appModel.dmxPatchDocument.instances.enumerated()), id: \.element.id) { pair in
                            let inst = pair.element
                            let key = inst.id.uuidString
                            let place = appModel.stageLayoutDocument.placements[key] ?? StagePlacement()
                            let profileName = appModel.dmxPatchDocument.profile(id: inst.profileID)?.name ?? "?"
                            fixtureOrb(
                                instanceID: key,
                                fixtureIndex: pair.offset + 1,
                                profileName: profileName,
                                place: place,
                                size: geo.size,
                                isSelected: selectedFixtureKey == key
                            )
                            .onTapGesture { selectedFixtureKey = key }
                        }
                        ForEach(appModel.stageLayoutDocument.plotObjects) { object in
                            stageObjectView(object: object, canvasSize: geo.size, isSelected: selectedPlotObjectID == object.id)
                                .onTapGesture {
                                    selectedPlotObjectID = object.id
                                    selectedFixtureKey = nil
                                }
                        }
                        scanCameraView(kind: "primary", camera: appModel.stageLayoutDocument.primaryScanCamera, canvasSize: geo.size)
                        scanCameraView(kind: "secondary", camera: appModel.stageLayoutDocument.secondaryScanCamera, canvasSize: geo.size)
                    }
                    .background(Color.black.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 220)
                if let key = selectedFixtureKey,
                   appModel.dmxPatchDocument.instances.contains(where: { $0.id.uuidString == key }) {
                    let label = appModel.dmxPatchDocument.instances.first(where: { $0.id.uuidString == key })
                        .flatMap { appModel.dmxPatchDocument.profile(id: $0.profileID)?.name } ?? "Fixture"
                    let rot = appModel.stageLayoutDocument.placements[key]?.rotation ?? 0
                    Text(label)
                        .font(.caption.weight(.semibold))
                    HStack {
                        Text("Rotation")
                            .font(.caption2)
                        Slider(value: stageRotationBinding(fixtureKey: key), in: -180 ... 180)
                        Text("\(Int(rot))°")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                if let selectedPlotObjectID,
                   let object = appModel.stageLayoutDocument.plotObjects.first(where: { $0.id == selectedPlotObjectID }) {
                    Text(object.templateID.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption.weight(.semibold))
                    TextField(
                        "Object label",
                        text: Binding(
                            get: { object.label },
                            set: { newValue in
                                var s = appModel.stageLayoutDocument
                                guard let idx = s.plotObjects.firstIndex(where: { $0.id == selectedPlotObjectID }) else { return }
                                s.plotObjects[idx].label = newValue
                                appModel.applyStageLayoutDocument(s)
                            }
                        )
                    )
                    HStack {
                        Text("Scale")
                            .font(.caption2)
                        Slider(
                            value: Binding(
                                get: { object.scale },
                                set: { newValue in
                                    guard !object.isLocked else { return }
                                    var s = appModel.stageLayoutDocument
                                    guard let idx = s.plotObjects.firstIndex(where: { $0.id == selectedPlotObjectID }) else { return }
                                    s.plotObjects[idx].scale = max(0.3, min(3.0, newValue))
                                    appModel.applyStageLayoutDocument(s)
                                }
                            ),
                            in: 0.3 ... 3.0
                        )
                        Text(String(format: "%.2fx", object.scale))
                            .font(.caption2.monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text("Rotation")
                            .font(.caption2)
                        Slider(
                            value: Binding(
                                get: { object.rotation },
                                set: { newValue in
                                    guard !object.isLocked else { return }
                                    var s = appModel.stageLayoutDocument
                                    guard let idx = s.plotObjects.firstIndex(where: { $0.id == selectedPlotObjectID }) else { return }
                                    s.plotObjects[idx].rotation = newValue
                                    appModel.applyStageLayoutDocument(s)
                                }
                            ),
                            in: -180 ... 180
                        )
                        Text("\(Int(object.rotation))°")
                            .font(.caption2.monospacedDigit())
                            .frame(width: 40, alignment: .trailing)
                    }
                    Toggle(
                        "Lock object (disable drag/scale/rotation)",
                        isOn: Binding(
                            get: { object.isLocked },
                            set: { locked in
                                var s = appModel.stageLayoutDocument
                                guard let idx = s.plotObjects.firstIndex(where: { $0.id == selectedPlotObjectID }) else { return }
                                s.plotObjects[idx].isLocked = locked
                                appModel.applyStageLayoutDocument(s)
                            }
                        )
                    )
                    .controlSize(.small)
                    HStack {
                        Button("Duplicate") { duplicateSelectedObject() }
                            .controlSize(.small)
                        Button("Send backward") { sendSelectedObjectBackward() }
                            .controlSize(.small)
                        Button("Bring forward") { bringSelectedObjectForward() }
                            .controlSize(.small)
                    }
                    Button("Remove selected object", role: .destructive) {
                        var s = appModel.stageLayoutDocument
                        s.plotObjects.removeAll { $0.id == selectedPlotObjectID }
                        appModel.applyStageLayoutDocument(s)
                        self.selectedPlotObjectID = nil
                    }
                    .controlSize(.small)
                }
                Text("Tap a fixture to edit rotation; drag to move. Positions persist to Application Support.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Scan wedges show required camera angles for fixture-learning passes. Position cameras, then resume scan from Fixture verification.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stageRotationBinding(fixtureKey: String) -> Binding<Double> {
        Binding(
            get: {
                appModel.stageLayoutDocument.placements[fixtureKey]?.rotation ?? 0
            },
            set: { v in
                var s = appModel.stageLayoutDocument
                var p = s.placements[fixtureKey] ?? StagePlacement()
                p.rotation = v
                s.placements[fixtureKey] = p
                appModel.applyStageLayoutDocument(s)
            }
        )
    }

    @ViewBuilder
    private func backdropLayer(size: CGSize) -> some View {
        if let path = appModel.stageLayoutDocument.backdropAssetPath,
           let img = NSImage(contentsOfFile: path) {
            let bp = appModel.stageLayoutDocument.backdropPlacement
            if bp.isVisible {
                let width = size.width * CGFloat(max(0.2, bp.scale))
                let height = size.height * CGFloat(max(0.2, bp.scale))
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .rotationEffect(.degrees(bp.rotation))
                    .position(
                        x: CGFloat(bp.centerX) * size.width,
                        y: CGFloat(1 - bp.centerY) * size.height
                    )
                    .clipped()
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if backdropDragStart == nil {
                                    backdropDragStart = bp
                                }
                                guard let start = backdropDragStart else { return }
                                var next = appModel.stageLayoutDocument
                                let nx = start.centerX + Double(gesture.translation.width / max(size.width, 1))
                                let ny = start.centerY - Double(gesture.translation.height / max(size.height, 1))
                                next.backdropPlacement.centerX = min(max(nx, 0), 1)
                                next.backdropPlacement.centerY = min(max(ny, 0), 1)
                                appModel.applyStageLayoutDocument(next)
                            }
                            .onEnded { _ in
                                backdropDragStart = nil
                            }
                    )
            }
        }
    }

    private var backdropEditorControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            let hasBackdrop = appModel.stageLayoutDocument.backdropAssetPath != nil
            Toggle(
                "Backdrop visible in stage + 2.5D preview",
                isOn: Binding(
                    get: { appModel.stageLayoutDocument.backdropPlacement.isVisible },
                    set: { visible in
                        var s = appModel.stageLayoutDocument
                        s.backdropPlacement.isVisible = visible
                        appModel.applyStageLayoutDocument(s)
                    }
                )
            )
            .disabled(!hasBackdrop)

            HStack {
                Text("Backdrop scale")
                    .font(.caption2)
                Slider(
                    value: Binding(
                        get: { appModel.stageLayoutDocument.backdropPlacement.scale },
                        set: { value in
                            var s = appModel.stageLayoutDocument
                            s.backdropPlacement.scale = max(0.2, min(3.0, value))
                            appModel.applyStageLayoutDocument(s)
                        }
                    ),
                    in: 0.2 ... 3.0
                )
                Text(String(format: "%.2fx", appModel.stageLayoutDocument.backdropPlacement.scale))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
                Button("-") { nudgeBackdropScale(by: -0.1) }
                    .controlSize(.small)
                Button("+") { nudgeBackdropScale(by: 0.1) }
                    .controlSize(.small)
            }
            .disabled(!hasBackdrop)

            Text("Drag the backdrop image in the stage map to reposition it.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var stageDimensionsControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stage dimensions (meters)")
                .font(.caption.weight(.semibold))
            HStack {
                Text("Width")
                    .font(.caption2)
                Slider(
                    value: Binding(
                        get: { appModel.stageLayoutDocument.dimensions.widthMeters },
                        set: { v in
                            var s = appModel.stageLayoutDocument
                            s.dimensions.widthMeters = max(1, min(100, v))
                            appModel.applyStageLayoutDocument(s)
                        }
                    ),
                    in: 1 ... 100
                )
                Text(String(format: "%.1fm", appModel.stageLayoutDocument.dimensions.widthMeters))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 56, alignment: .trailing)
            }
            HStack {
                Text("Depth")
                    .font(.caption2)
                Slider(
                    value: Binding(
                        get: { appModel.stageLayoutDocument.dimensions.depthMeters },
                        set: { v in
                            var s = appModel.stageLayoutDocument
                            s.dimensions.depthMeters = max(1, min(100, v))
                            appModel.applyStageLayoutDocument(s)
                        }
                    ),
                    in: 1 ... 100
                )
                Text(String(format: "%.1fm", appModel.stageLayoutDocument.dimensions.depthMeters))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }

    private var stageObjectControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Common instruments and gear")
                .font(.caption.weight(.semibold))
            HStack {
                Picker("Object", selection: $selectedTemplateID) {
                    ForEach(Self.stageObjectTemplates) { template in
                        Text(template.name).tag(template.id)
                    }
                }
                .pickerStyle(.menu)
                Button("Add object") { addStageObject() }
                    .controlSize(.small)
            }
            HStack {
                Toggle("Snap-to-grid", isOn: $snapToGridEnabled)
                    .controlSize(.small)
                Text("Grid")
                    .font(.caption2)
                Stepper(
                    value: $snapGridDivisions,
                    in: 8 ... 64,
                    step: 4
                ) {
                    Text("\(snapGridDivisions)x\(snapGridDivisions)")
                        .font(.caption2.monospacedDigit())
                        .frame(minWidth: 62, alignment: .leading)
                }
                .controlSize(.small)
            }
            Text("Objects auto-scale to stage dimensions using real footprint size and can be dragged/scaled/rotated with labels.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var scanCameraControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fixture scan cameras")
                .font(.caption.weight(.semibold))
            Toggle(
                "Enable primary scan camera overlay",
                isOn: Binding(
                    get: { appModel.stageLayoutDocument.primaryScanCamera.isEnabled },
                    set: { on in
                        var s = appModel.stageLayoutDocument
                        s.primaryScanCamera.isEnabled = on
                        appModel.applyStageLayoutDocument(s)
                    }
                )
            )
            Toggle(
                "Enable secondary iOS continuity camera overlay",
                isOn: Binding(
                    get: { appModel.stageLayoutDocument.secondaryScanCamera.isEnabled },
                    set: { on in
                        var s = appModel.stageLayoutDocument
                        s.secondaryScanCamera.isEnabled = on
                        appModel.applyStageLayoutDocument(s)
                    }
                )
            )
            .controlSize(.small)
            HStack {
                Text("Secondary angle")
                    .font(.caption2)
                Slider(
                    value: Binding(
                        get: { appModel.stageLayoutDocument.secondaryScanCamera.angleDeg },
                        set: { angle in
                            var s = appModel.stageLayoutDocument
                            s.secondaryScanCamera.angleDeg = angle
                            appModel.applyStageLayoutDocument(s)
                        }
                    ),
                    in: -180 ... 180
                )
                Text("\(Int(appModel.stageLayoutDocument.secondaryScanCamera.angleDeg))°")
                    .font(.caption2.monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
            }
            .disabled(!appModel.stageLayoutDocument.secondaryScanCamera.isEnabled)
        }
    }

    private func nudgeBackdropScale(by delta: Double) {
        var s = appModel.stageLayoutDocument
        s.backdropPlacement.scale = max(0.2, min(3.0, s.backdropPlacement.scale + delta))
        appModel.applyStageLayoutDocument(s)
    }

    private func fixtureOrb(
        instanceID: String,
        fixtureIndex: Int,
        profileName: String,
        place: StagePlacement,
        size: CGSize,
        isSelected: Bool
    ) -> some View {
        let w: CGFloat = 34
        let shortName = profileName.count > 10 ? String(profileName.prefix(9)) + "…" : profileName
        return ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.85))
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.55), lineWidth: isSelected ? 2.5 : 1)
                )
            VStack(spacing: 0) {
                Text("\(fixtureIndex)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(shortName)
                    .font(.system(size: 7, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: w - 6, height: w - 6)
        }
        .frame(width: w, height: w)
        .rotationEffect(.degrees(place.rotation))
        .offset(
            x: CGFloat(place.x) * size.width - w / 2,
            y: CGFloat(1 - place.y) * size.height - w / 2
        )
        .gesture(
            DragGesture()
                .onChanged { g in
                    if dragKey != instanceID {
                        dragKey = instanceID
                        dragStart = place
                    }
                    guard let s = dragStart, dragKey == instanceID else { return }
                    let nx = s.x + Double(g.translation.width / max(size.width, 1))
                    let ny = s.y - Double(g.translation.height / max(size.height, 1))
                    var next = appModel.stageLayoutDocument
                    next.placements[instanceID] = StagePlacement(
                        x: min(max(nx, 0), 1),
                        y: min(max(ny, 0), 1),
                        rotation: s.rotation
                    )
                    appModel.applyStageLayoutDocument(next)
                }
                .onEnded { _ in
                    if dragKey == instanceID {
                        dragKey = nil
                        dragStart = nil
                    }
                }
        )
    }

    private func stageObjectView(object: StagePlotObject, canvasSize: CGSize, isSelected: Bool) -> some View {
        let normalized = object.normalizedFootprint(in: appModel.stageLayoutDocument.dimensions)
        let width = max(16, CGFloat(normalized.width) * canvasSize.width)
        let height = max(12, CGFloat(normalized.depth) * canvasSize.height)
        let centerX = CGFloat(object.centerX) * canvasSize.width
        let centerY = CGFloat(1 - object.centerY) * canvasSize.height

        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(object.isLocked ? Color.gray.opacity(0.35) : Color.orange.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white : (object.isLocked ? Color.gray.opacity(0.8) : Color.orange.opacity(0.8)), lineWidth: isSelected ? 2 : 1)
                )
            Text(object.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
            if object.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: width, height: height)
        .position(x: centerX, y: centerY)
        .rotationEffect(.degrees(object.rotation))
        .gesture(
            DragGesture()
                .onChanged { g in
                    guard !object.isLocked else { return }
                    if plotObjectDragStart == nil || plotObjectDragStart?.id != object.id {
                        plotObjectDragStart = object
                    }
                    guard let start = plotObjectDragStart else { return }
                    let nx = start.centerX + Double(g.translation.width / max(canvasSize.width, 1))
                    let ny = start.centerY - Double(g.translation.height / max(canvasSize.height, 1))
                    var s = appModel.stageLayoutDocument
                    guard let idx = s.plotObjects.firstIndex(where: { $0.id == object.id }) else { return }
                    s.plotObjects[idx].centerX = min(max(nx, 0), 1)
                    s.plotObjects[idx].centerY = min(max(ny, 0), 1)
                    appModel.applyStageLayoutDocument(s)
                }
                .onEnded { _ in
                    guard !object.isLocked else { return }
                    if snapToGridEnabled {
                        var s = appModel.stageLayoutDocument
                        guard let idx = s.plotObjects.firstIndex(where: { $0.id == object.id }) else { return }
                        s.plotObjects[idx].centerX = snapToGrid(s.plotObjects[idx].centerX)
                        s.plotObjects[idx].centerY = snapToGrid(s.plotObjects[idx].centerY)
                        appModel.applyStageLayoutDocument(s)
                    }
                    plotObjectDragStart = nil
                }
        )
    }

    @ViewBuilder
    private func scanCameraView(kind: String, camera: StageScanCameraPlacement, canvasSize: CGSize) -> some View {
        if camera.isEnabled {
            let cx = CGFloat(camera.x) * canvasSize.width
            let cy = CGFloat(1 - camera.y) * canvasSize.height
            let radius = min(canvasSize.width, canvasSize.height) * 0.34
            let toRadians = Double.pi / 180.0
            let left = CGFloat((camera.angleDeg - camera.fovDeg * 0.5) * toRadians)
            let right = CGFloat((camera.angleDeg + camera.fovDeg * 0.5) * toRadians)
            let base = CGFloat(-90.0 * toRadians)
            let start = base + left
            let end = base + right
            let p1 = CGPoint(x: cx + cos(start) * radius, y: cy + sin(start) * radius)
            let p2 = CGPoint(x: cx + cos(end) * radius, y: cy + sin(end) * radius)
            let tint: Color = kind == "primary" ? .cyan : .mint

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: cx, y: cy))
                    path.addLine(to: p1)
                    path.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: radius,
                        startAngle: .radians(Double(start)),
                        endAngle: .radians(Double(end)),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .fill(tint.opacity(0.16))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: cx, y: cy))
                        path.addLine(to: p1)
                        path.move(to: CGPoint(x: cx, y: cy))
                        path.addLine(to: p2)
                    }
                    .stroke(tint.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )

                Circle()
                    .fill(tint.opacity(0.9))
                    .frame(width: 12, height: 12)
                    .position(x: cx, y: cy)
                Text(camera.label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .position(x: cx + 40, y: cy - 10)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { g in
                        if cameraDragKey != kind {
                            cameraDragKey = kind
                            cameraDragStart = camera
                        }
                        guard let startState = cameraDragStart else { return }
                        let nx = startState.x + Double(g.translation.width / max(canvasSize.width, 1))
                        let ny = startState.y - Double(g.translation.height / max(canvasSize.height, 1))
                        var s = appModel.stageLayoutDocument
                        if kind == "primary" {
                            s.primaryScanCamera.x = min(max(nx, 0), 1)
                            s.primaryScanCamera.y = min(max(ny, 0), 1)
                        } else {
                            s.secondaryScanCamera.x = min(max(nx, 0), 1)
                            s.secondaryScanCamera.y = min(max(ny, 0), 1)
                        }
                        appModel.applyStageLayoutDocument(s)
                    }
                    .onEnded { _ in
                        cameraDragKey = nil
                        cameraDragStart = nil
                    }
            )
        }
    }

    private func addStageObject() {
        guard let template = Self.stageObjectTemplates.first(where: { $0.id == selectedTemplateID }) else { return }
        var s = appModel.stageLayoutDocument
        s.plotObjects.append(
            StagePlotObject(
                templateID: template.id,
                label: template.name,
                footprintWidthMeters: template.footprintWidthMeters,
                footprintDepthMeters: template.footprintDepthMeters
            )
        )
        appModel.applyStageLayoutDocument(s)
        selectedPlotObjectID = s.plotObjects.last?.id
    }

    private func duplicateSelectedObject() {
        guard let selectedPlotObjectID else { return }
        var s = appModel.stageLayoutDocument
        guard let idx = s.plotObjects.firstIndex(where: { $0.id == selectedPlotObjectID }) else { return }
        var copy = s.plotObjects[idx]
        copy.id = UUID()
        copy.centerX = min(max(copy.centerX + 0.03, 0), 1)
        copy.centerY = min(max(copy.centerY - 0.03, 0), 1)
        copy.label = copy.label + " Copy"
        s.plotObjects.insert(copy, at: min(idx + 1, s.plotObjects.count))
        appModel.applyStageLayoutDocument(s)
        self.selectedPlotObjectID = copy.id
    }

    private func bringSelectedObjectForward() {
        guard let selectedPlotObjectID else { return }
        var s = appModel.stageLayoutDocument
        guard let idx = s.plotObjects.firstIndex(where: { $0.id == selectedPlotObjectID }), idx < s.plotObjects.count - 1 else { return }
        s.plotObjects.swapAt(idx, idx + 1)
        appModel.applyStageLayoutDocument(s)
    }

    private func sendSelectedObjectBackward() {
        guard let selectedPlotObjectID else { return }
        var s = appModel.stageLayoutDocument
        guard let idx = s.plotObjects.firstIndex(where: { $0.id == selectedPlotObjectID }), idx > 0 else { return }
        s.plotObjects.swapAt(idx, idx - 1)
        appModel.applyStageLayoutDocument(s)
    }

    private func snapToGrid(_ value: Double) -> Double {
        let divisions = max(1, snapGridDivisions)
        let step = 1.0 / Double(divisions)
        return min(max((value / step).rounded() * step, 0), 1)
    }

    private func importBackdrop() {
        let p = NSOpenPanel()
        var types: [UTType] = [.image]
        if let svg = UTType(filenameExtension: "svg") {
            types.append(svg)
        }
        p.allowedContentTypes = types
        p.canChooseFiles = true
        p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let url = p.url else { return }
        backdropImportError = nil
        let id = UUID()
        do {
            let path = try StageLayoutBackdropSupport.copyBackdropToAppSupport(from: url, id: id)
            var s = appModel.stageLayoutDocument
            s.backdropAssetPath = path
            appModel.applyStageLayoutDocument(s)
        } catch {
            backdropImportError = error.localizedDescription
        }
    }
}
