import AppKit
import SwiftUI

/// Lightweight 2.5D-style floor preview: colored pools and beam cones from fixture poses.
struct LightingPreview25DView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        GroupBox("2.5D preview (approximation)") {
            Canvas { context, size in
                let floor = CGRect(origin: .zero, size: size)
                context.fill(Path(floor), with: .color(.black.opacity(0.9)))

                for inst in appModel.dmxPatchDocument.instances {
                    guard let profile = appModel.dmxPatchDocument.profile(id: inst.profileID) else { continue }
                    let place = appModel.stageLayoutDocument.placements[inst.id.uuidString] ?? StagePlacement()
                    let color = fixtureColor(profile: profile, instance: inst)
                    let cx = CGFloat(place.x) * size.width
                    let cy = CGFloat(1 - place.y) * size.height
                    let beamLen = min(size.width, size.height) * 0.22
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
                }
            }
            .frame(height: 200)
            Text("Beams and pools are stylized; IES accuracy is not modeled.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func fixtureColor(profile: FixtureProfile, instance: FixtureInstance) -> Color {
        func idx(_ role: FixtureChannelRole) -> Int? {
            profile.channels.firstIndex { $0.role == role }
        }
        if let ir = idx(.red), let ig = idx(.green), let ib = idx(.blue) {
            let r = Double(instance.manual(forChannelIndex: ir)) / 255
            let g = Double(instance.manual(forChannelIndex: ig)) / 255
            let b = Double(instance.manual(forChannelIndex: ib)) / 255
            return Color(red: r, green: g, blue: b)
        }
        return Color.accentColor
    }
}
