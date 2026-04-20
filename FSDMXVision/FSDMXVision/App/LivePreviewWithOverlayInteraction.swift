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

                TimelineView(.animation) { _ in
                    overlayCardLayer(size: geo.size)
                }

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

    private func overlayCardLayer(size: CGSize) -> some View {
        Group {
            if appModel.overlayEnabled {
                ZStack {
                    ForEach(appModel.overlayCardDocument.shapes) { shape in
                        if appModel.shouldRenderOverlayElement(id: shape.id, timeoutSeconds: shape.timeoutSeconds) {
                            overlayShapeView(shape)
                                .frame(
                                    width: max(1, size.width * CGFloat(shape.frame.width)),
                                    height: max(1, size.height * CGFloat(shape.frame.height))
                                )
                                .position(
                                    x: size.width * CGFloat(shape.frame.x + (shape.frame.width * 0.5)),
                                    y: size.height * CGFloat(1 - shape.frame.y - (shape.frame.height * 0.5))
                                )
                        }
                    }
                    ForEach(appModel.overlayCardDocument.texts) { text in
                        if appModel.shouldRenderOverlayElement(id: text.id, timeoutSeconds: text.timeoutSeconds) {
                            Text(appModel.resolvedOverlayText(for: text))
                                .font(.custom(text.fontName, size: max(1, text.fontSize)))
                                .foregroundStyle(colorFromRGBA(text.colorRGBA))
                                .multilineTextAlignment(.center)
                                .frame(
                                    width: max(1, size.width * CGFloat(text.frame.width)),
                                    height: max(1, size.height * CGFloat(text.frame.height))
                                )
                                .position(
                                    x: size.width * CGFloat(text.frame.x + (text.frame.width * 0.5)),
                                    y: size.height * CGFloat(1 - text.frame.y - (text.frame.height * 0.5))
                                )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func overlayShapeView(_ shape: OverlayCardShape) -> some View {
        let fill = colorFromRGBA(shape.fillColorRGBA)
        let stroke = shape.strokeColorRGBA.map(colorFromRGBA)
        switch shape.kind {
        case .rect:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
                .overlay {
                    if let stroke {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(stroke, lineWidth: shape.strokeWidth)
                    }
                }
        case .ellipse:
            Ellipse()
                .fill(fill)
                .overlay {
                    if let stroke {
                        Ellipse()
                            .stroke(stroke, lineWidth: shape.strokeWidth)
                    }
                }
        case .path:
            Rectangle()
                .fill(fill)
                .overlay {
                    if let stroke {
                        Rectangle()
                            .stroke(stroke, lineWidth: shape.strokeWidth)
                    }
                }
        }
    }

    private func colorFromRGBA(_ rgba: [Double]) -> Color {
        let r = rgba.indices.contains(0) ? rgba[0] : 1
        let g = rgba.indices.contains(1) ? rgba[1] : 1
        let b = rgba.indices.contains(2) ? rgba[2] : 1
        let a = rgba.indices.contains(3) ? rgba[3] : 1
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
