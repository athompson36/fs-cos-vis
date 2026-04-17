import simd
import SwiftUI

/// Main-window live preview: optional drag (move) + magnification (resize) for the logo when overlay placement is enabled;
/// optional liquid dye pour when Scene Studio arms the dropper.
struct LivePreviewWithOverlayInteraction: View {
    @EnvironmentObject private var appModel: AppModel
    let renderer: CompositeRenderer
    /// Minimum height for the Metal view (Live Show uses a taller default; Scene Studio can pass a smaller value).
    var minPreviewHeight: CGFloat = 280

    @State private var dragBoxStart: SIMD4<Float>?
    @State private var pinchBoxStart: SIMD4<Float>?
    @State private var pourPressStart: Date?
    @State private var pourLastEmit: Date?

    private var canPourLiquid: Bool {
        guard appModel.liquidDropperArmed,
              appModel.sceneManager.scenes.indices.contains(appModel.sceneManager.currentIndex)
        else { return false }
        return appModel.sceneManager.scenes[appModel.sceneManager.currentIndex].liquidLightEnabled
    }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            ZStack {
                VisualizationMetalView(renderer: renderer)
                    .frame(width: geo.size.width, height: geo.size.height)

                if appModel.overlayEnabled && appModel.overlayPlacementInteractionEnabled && !appModel.liquidDropperArmed {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(0.4), lineWidth: 1.5)
                        .allowsHitTesting(false)

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { g in
                                    if dragBoxStart == nil {
                                        dragBoxStart = appModel.currentOverlayRectNorm()
                                    }
                                    guard let o = dragBoxStart else { return }
                                    let dx = Float(g.translation.width / w)
                                    let dy = Float(-g.translation.height / h)
                                    appModel.applyOverlayDragFromStart(o, translation: SIMD2(dx, dy))
                                }
                                .onEnded { _ in
                                    dragBoxStart = nil
                                }
                        )
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { scale in
                                    if pinchBoxStart == nil {
                                        pinchBoxStart = appModel.currentOverlayRectNorm()
                                    }
                                    guard let o = pinchBoxStart else { return }
                                    appModel.applyOverlayPinchFromStart(o, scale: scale)
                                }
                                .onEnded { _ in
                                    pinchBoxStart = nil
                                }
                        )
                }

                if canPourLiquid {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    let pt = CGPoint(x: g.location.x, y: g.location.y)
                                    let size = CGSize(width: w, height: h)
                                    if pourPressStart == nil {
                                        pourPressStart = Date()
                                        appModel.enqueueLiquidPour(atViewPoint: pt, viewSize: size)
                                        pourLastEmit = Date()
                                    } else if let t0 = pourPressStart {
                                        if Date().timeIntervalSince(t0) > 0.14 {
                                            let last = pourLastEmit ?? .distantPast
                                            if Date().timeIntervalSince(last) > 0.055 {
                                                pourLastEmit = Date()
                                                appModel.enqueueLiquidPour(atViewPoint: pt, viewSize: size)
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    pourPressStart = nil
                                    pourLastEmit = nil
                                }
                        )
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.45), lineWidth: 1.5)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.purple.opacity(0.35), radius: 18, y: 6)
        }
        .frame(minHeight: minPreviewHeight)
    }
}
