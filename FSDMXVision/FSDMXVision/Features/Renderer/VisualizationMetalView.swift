import MetalKit
import SwiftUI

/// SwiftUI bridge to an `MTKView` driven by `CompositeRenderer`.
struct VisualizationMetalView: NSViewRepresentable {
    @ObservedObject var renderer: CompositeRenderer
    var preferredFramesPerSecond: Int = 60

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = preferredFramesPerSecond
        view.delegate = renderer
        renderer.mtkView(view, drawableSizeWillChange: view.drawableSize)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.device = renderer.device
        nsView.delegate = renderer
        nsView.preferredFramesPerSecond = preferredFramesPerSecond
    }
}
