import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Normalized 0…1 stage coordinates with drag repositioning.
struct StagePlanView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var dragKey: String?
    @State private var dragStart: StagePlacement?

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
                }
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        backdropLayer(size: geo.size)
                        ForEach(appModel.dmxPatchDocument.instances, id: \.id) { inst in
                            let key = inst.id.uuidString
                            let place = appModel.stageLayoutDocument.placements[key] ?? StagePlacement()
                            fixtureOrb(
                                instanceID: key,
                                place: place,
                                size: geo.size
                            )
                        }
                    }
                    .background(Color.black.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 220)
                Text("Drag fixtures to position them on the plan. Positions persist to Application Support.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    private func fixtureOrb(instanceID: String, place: StagePlacement, size: CGSize) -> some View {
        let w: CGFloat = 28
        return Circle()
            .fill(Color.accentColor.opacity(0.85))
            .frame(width: w, height: w)
            .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
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
        let id = UUID()
        do {
            let path = try StageLayoutBackdropSupport.copyBackdropToAppSupport(from: url, id: id)
            var s = appModel.stageLayoutDocument
            s.backdropAssetPath = path
            appModel.applyStageLayoutDocument(s)
        } catch {
            // Silent failure; settings-style UI could surface an alert later.
        }
    }
}
