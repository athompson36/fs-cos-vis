import AppKit
import SwiftUI

/// Lightweight 2.5D-style floor preview: colored pools and beam cones from fixture poses.
struct LightingPreview25DView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        GroupBox("2.5D preview (approximation)") {
            VStack(alignment: .leading, spacing: 6) {
                LightingPreviewDMXCanvas()
                    .environmentObject(appModel)
                Text(
                    "Colors match the full built DMX universe (patch, cues, crossfade, modulation). Beams respect stage rotation; IES accuracy is not modeled."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Drives Canvas from `buildDMXUniverse` so preview matches USB output, including modulation smoothing state.
private struct LightingPreviewDMXCanvas: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var modSmoothed: [UUID: Float] = [:]
    @State private var universe: [UInt8] = Array(repeating: 0, count: 512)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                var context = context
                draw(context: &context, size: size, universe: universe)
            }
            .frame(height: 200)
            .onChange(of: timeline.date) { _, _ in
                tickUniverse()
            }
            .onAppear {
                tickUniverse()
            }
        }
    }

    private func tickUniverse() {
        var s = modSmoothed
        universe = appModel.buildDMXUniverse(time: CFAbsoluteTimeGetCurrent(), lastSmoothed: &s)
        modSmoothed = s
    }

    private func draw(context: inout GraphicsContext, size: CGSize, universe: [UInt8]) {
        let floor = CGRect(origin: .zero, size: size)
        context.fill(Path(floor), with: .color(.black.opacity(0.9)))

        for inst in appModel.dmxPatchDocument.instances {
            guard let profile = appModel.dmxPatchDocument.profile(id: inst.profileID) else { continue }
            let place = appModel.stageLayoutDocument.placements[inst.id.uuidString] ?? StagePlacement()
            let color = fixtureColor(profile: profile, instance: inst, universe: universe)
            let cx = CGFloat(place.x) * size.width
            let cy = CGFloat(1 - place.y) * size.height
            let beamLen = min(size.width, size.height) * 0.22
            let angleRad = CGFloat(place.rotation * .pi / 180)
            let orient = CGAffineTransform(translationX: cx, y: cy)
                .rotated(by: angleRad)
                .translatedBy(x: -cx, y: -cy)
            context.concatenate(orient)

            var beam = Path()
            beam.move(to: CGPoint(x: cx, y: cy - beamLen))
            beam.addLine(to: CGPoint(x: cx - beamLen * 0.35, y: cy))
            beam.addLine(to: CGPoint(x: cx + beamLen * 0.35, y: cy))
            beam.closeSubpath()
            context.fill(beam, with: .color(color.opacity(0.35)))

            let pool = CGRect(x: cx - 40, y: cy - 20, width: 80, height: 40)
            context.fill(
                Path(ellipseIn: pool),
                with: .color(color.opacity(0.55))
            )
            context.stroke(
                Path(ellipseIn: pool),
                with: .color(.white.opacity(0.25)),
                lineWidth: 1
            )
            context.concatenate(orient.inverted())
        }
    }

    private func fixtureColor(profile: FixtureProfile, instance: FixtureInstance, universe: [UInt8]) -> Color {
        func idx(_ role: FixtureChannelRole) -> Int? {
            profile.channels.firstIndex { $0.role == role }
        }
        func byte(_ channelIndex: Int) -> UInt8 {
            let dmx = instance.startAddress + channelIndex
            guard dmx >= 1, dmx <= 512, universe.count == 512 else { return instance.manual(forChannelIndex: channelIndex) }
            return universe[dmx - 1]
        }
        if let ir = idx(.red), let ig = idx(.green), let ib = idx(.blue) {
            let r = Double(byte(ir)) / 255
            let g = Double(byte(ig)) / 255
            let b = Double(byte(ib)) / 255
            return Color(red: r, green: g, blue: b)
        }
        return Color.accentColor
    }
}
