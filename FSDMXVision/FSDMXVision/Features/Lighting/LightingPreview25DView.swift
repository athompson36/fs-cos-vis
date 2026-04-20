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
                    "Colors follow the built DMX universe (patch, cues, crossfade, modulation). Moving heads use pan/tilt channels; dimmer scales RGB/RGBW; hazers contribute a global fog layer. Not photometric / IES truth."
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
            .frame(height: 220)
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

        let backdropPlacement = appModel.stageLayoutDocument.backdropPlacement
        if backdropPlacement.isVisible,
           let path = appModel.stageLayoutDocument.backdropAssetPath,
           let img = NSImage(contentsOfFile: path) {
            let scale = CGFloat(max(0.2, backdropPlacement.scale))
            let width = floor.width * scale
            let height = floor.height * scale
            let centerX = floor.width * CGFloat(backdropPlacement.centerX)
            let centerY = floor.height * CGFloat(1 - backdropPlacement.centerY)
            let drawRect = CGRect(
                x: centerX - width / 2,
                y: centerY - height / 2,
                width: width,
                height: height
            )
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: .degrees(backdropPlacement.rotation))
            context.translateBy(x: -centerX, y: -centerY)
            context.draw(Image(nsImage: img), in: drawRect)
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: .degrees(-backdropPlacement.rotation))
            context.translateBy(x: -centerX, y: -centerY)
        } else {
            context.fill(Path(floor), with: .color(.black.opacity(0.92)))
        }

        let fog = aggregateFogLevel(universe: universe)
        if fog > 0.02 {
            let haze = Color.white.opacity(0.06 + fog * 0.42)
            context.fill(Path(floor), with: .color(haze))
        }

        for inst in appModel.dmxPatchDocument.instances {
            guard let profile = appModel.dmxPatchDocument.profile(id: inst.profileID) else { continue }
            let place = appModel.stageLayoutDocument.placements[inst.id.uuidString] ?? StagePlacement()
            let sample = fixtureAppearance(profile: profile, instance: inst, universe: universe)
            if sample.isFogOnly { continue }

            let cx = CGFloat(place.x) * size.width
            let cy = CGFloat(1 - place.y) * size.height
            let baseLen = min(size.width, size.height) * 0.22
            let beamLen = baseLen * CGFloat(sample.beamTiltScale)

            let panRad = CGFloat((sample.panDeg / 180) * .pi)
            let orient = CGAffineTransform(translationX: cx, y: cy)
                .rotated(by: CGFloat(place.rotation * .pi / 180) + panRad)
                .translatedBy(x: -cx, y: -cy)
            context.concatenate(orient)

            let beamTint = sample.beamColor.opacity(sample.intensity * (1 - fog * 0.35))
            var beam = Path()
            beam.move(to: CGPoint(x: cx, y: cy - beamLen))
            beam.addLine(to: CGPoint(x: cx - beamLen * 0.35, y: cy))
            beam.addLine(to: CGPoint(x: cx + beamLen * 0.35, y: cy))
            beam.closeSubpath()
            context.fill(beam, with: .color(beamTint.opacity(0.38)))

            let pool = CGRect(x: cx - 40, y: cy - 20, width: 80, height: 40)
            context.fill(
                Path(ellipseIn: pool),
                with: .color(sample.poolColor.opacity(sample.intensity * 0.58))
            )
            context.stroke(
                Path(ellipseIn: pool),
                with: .color(.white.opacity(0.22)),
                lineWidth: 1
            )
            context.concatenate(orient.inverted())
        }
    }

    private struct FixtureColorSample {
        var beamColor: Color
        var poolColor: Color
        var intensity: Double
        var panDeg: Double
        var tiltNorm: Double
        var beamTiltScale: Double
        var isFogOnly: Bool

        static let fogOnly = FixtureColorSample(
            beamColor: .clear,
            poolColor: .clear,
            intensity: 0,
            panDeg: 0,
            tiltNorm: 0,
            beamTiltScale: 1,
            isFogOnly: true
        )
    }

    private func aggregateFogLevel(universe: [UInt8]) -> Double {
        var maxHaze: Double = 0
        for inst in appModel.dmxPatchDocument.instances {
            guard let profile = appModel.dmxPatchDocument.profile(id: inst.profileID) else { continue }
            guard profile.channels.contains(where: { $0.role == .hazeOutput }) else { continue }
            let fanIdx = profile.channels.firstIndex { $0.role == .hazeFan }
            let pumpIdx = profile.channels.firstIndex { $0.role == .hazePump }
            let hazeIdx = profile.channels.firstIndex { $0.role == .hazeOutput } ?? 0
            let h = Double(byte(hazeIdx, inst: inst, universe: universe)) / 255
            let fan = fanIdx.map { Double(byte($0, inst: inst, universe: universe)) / 255 } ?? 0.75
            let pump = pumpIdx.map { Double(byte($0, inst: inst, universe: universe)) / 255 } ?? 0.75
            let v = h * (0.45 + 0.35 * fan + 0.2 * pump)
            maxHaze = max(maxHaze, min(1, v))
        }
        return maxHaze
    }

    private func byte(_ channelIndex: Int, inst: FixtureInstance, universe: [UInt8]) -> UInt8 {
        let dmx = inst.startAddress + channelIndex
        guard dmx >= 1, dmx <= 512, universe.count == 512 else { return inst.manual(forChannelIndex: channelIndex) }
        return universe[dmx - 1]
    }

    private func fixtureAppearance(profile: FixtureProfile, instance: FixtureInstance, universe: [UInt8]) -> FixtureColorSample {
        func idx(_ role: FixtureChannelRole) -> Int? {
            profile.channels.firstIndex { $0.role == role }
        }

        let rgbRoles: Set<FixtureChannelRole> = [.red, .green, .blue]
        let hasRGB = profile.channels.contains { rgbRoles.contains($0.role) }
        if profile.channels.contains(where: { $0.role == .hazeOutput }), !hasRGB {
            return .fogOnly
        }

        let ir = idx(.red)
        let ig = idx(.green)
        let ib = idx(.blue)
        let iw = idx(.white)
        let ia = idx(.amber)
        let iuv = idx(.uv)
        let idim = idx(.intensity)
        let ipan = idx(.pan)
        let itilt = idx(.tilt)

        let dim = idim.map { Double(byte($0, inst: instance, universe: universe)) / 255 } ?? 1
        let strobe = idx(.strobe).map { Double(byte($0, inst: instance, universe: universe)) / 255 } ?? 0
        let strobeGate = strobe > 0.92 ? 0.35 : 1

        if let ir, let ig, let ib {
            var r = Double(byte(ir, inst: instance, universe: universe)) / 255
            var g = Double(byte(ig, inst: instance, universe: universe)) / 255
            var b = Double(byte(ib, inst: instance, universe: universe)) / 255
            if let iw {
                let w = Double(byte(iw, inst: instance, universe: universe)) / 255
                r = min(1, r + w * 0.85)
                g = min(1, g + w * 0.85)
                b = min(1, b + w * 0.85)
            }
            if let ia {
                let a = Double(byte(ia, inst: instance, universe: universe)) / 255
                r = min(1, r + a * 0.9)
                g = min(1, g + a * 0.55)
                b = min(1, b + a * 0.1)
            }
            if let iuv {
                let uvv = Double(byte(iuv, inst: instance, universe: universe)) / 255
                r = min(1, r + uvv * 0.35)
                g = min(1, g + uvv * 0.15)
                b = min(1, b + uvv * 0.95)
            }
            let intensity = max(0.08, dim * strobeGate)
            let c = Color(red: r, green: g, blue: b)
            let panDeg = ipan.map { (Double(byte($0, inst: instance, universe: universe)) / 255) * 540 - 270 } ?? 0
            let tiltNorm = itilt.map { Double(byte($0, inst: instance, universe: universe)) / 255 } ?? 0.5
            let beamScale = 0.45 + (1 - tiltNorm) * 0.65
            return FixtureColorSample(
                beamColor: c,
                poolColor: c,
                intensity: intensity,
                panDeg: panDeg,
                tiltNorm: tiltNorm,
                beamTiltScale: beamScale,
                isFogOnly: false
            )
        }

        if idim != nil {
            let d = idim.map { Double(byte($0, inst: instance, universe: universe)) / 255 } ?? 0
            let c = Color(white: max(0.15, d))
            return FixtureColorSample(
                beamColor: c,
                poolColor: c,
                intensity: max(0.1, d * strobeGate),
                panDeg: ipan.map { (Double(byte($0, inst: instance, universe: universe)) / 255) * 540 - 270 } ?? 0,
                tiltNorm: itilt.map { Double(byte($0, inst: instance, universe: universe)) / 255 } ?? 0.5,
                beamTiltScale: 0.55 + (1 - (itilt.map { Double(byte($0, inst: instance, universe: universe)) / 255 } ?? 0.5)) * 0.55,
                isFogOnly: false
            )
        }

        return FixtureColorSample(
            beamColor: .accentColor,
            poolColor: .accentColor,
            intensity: 0.55,
            panDeg: 0,
            tiltNorm: 0.5,
            beamTiltScale: 1,
            isFogOnly: false
        )
    }
}
