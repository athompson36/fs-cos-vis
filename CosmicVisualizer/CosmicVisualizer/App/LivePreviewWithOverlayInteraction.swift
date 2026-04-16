import simd
import SwiftUI

/// Main-window live preview: optional drag (move) + magnification (resize) for the logo when overlay placement is enabled.
struct LivePreviewWithOverlayInteraction: View {
    @EnvironmentObject private var appModel: AppModel
    let renderer: CompositeRenderer

    @State private var dragBoxStart: SIMD4<Float>?
    @State private var pinchBoxStart: SIMD4<Float>?

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            ZStack {
                VisualizationMetalView(renderer: renderer)
                    .frame(width: geo.size.width, height: geo.size.height)

                if appModel.overlayEnabled && appModel.overlayPlacementInteractionEnabled {
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
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.purple.opacity(0.35), radius: 18, y: 6)
        }
        .frame(minHeight: 280)
    }
}
