import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Normalized 0…1 stage coordinates with drag repositioning.
struct StagePlanView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var dragKey: String?
    @State private var dragStart: StagePlacement?
    @State private var selectedFixtureKey: String?
    @State private var backdropImportError: String?

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
                }
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
                Text("Tap a fixture to edit rotation; drag to move. Positions persist to Application Support.")
                    .font(.caption)
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
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        }
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
