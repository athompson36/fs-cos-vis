import Combine
import Metal
import MetalKit
import QuartzCore

/// Orchestrates liquid + fractal offscreen passes and a final composite to the view drawable.
final class CompositeRenderer: NSObject, MTKViewDelegate, ObservableObject {
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let fractal: FractalRenderer
    private let liquid: LiquidLightRenderer
    private let compositePipeline: MTLRenderPipelineState

    private var fractalTexture: MTLTexture?
    private var liquidTexture: MTLTexture?
    private let emptyOverlayTexture: MTLTexture

    /// Logo / image layer (premultiplied BGRA). When nil, an empty texture is bound.
    var overlayTexture: MTLTexture?

    private var startTime = CACurrentMediaTime()
    private var lastFrameWallTime: CFTimeInterval?
    /// Invoked once per drawn frame with estimated wall-clock delta (seconds).
    var onFrame: ((TimeInterval) -> Void)?

    @Published var parameters = RenderParameters()

    func updateParameters(_ update: (inout RenderParameters) -> Void) {
        var next = parameters
        update(&next)
        parameters = next
    }

    private static var uniformBufferSize: Int {
        let s = MemoryLayout<CosmicUniforms>.stride
        return (s + 255) / 256 * 256
    }

    private init(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        fractal: FractalRenderer,
        liquid: LiquidLightRenderer,
        compositePipeline: MTLRenderPipelineState
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.fractal = fractal
        self.liquid = liquid
        self.compositePipeline = compositePipeline
        let emptyDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        emptyDesc.usage = [.shaderRead]
        guard let empty = device.makeTexture(descriptor: emptyDesc) else {
            fatalError("CosmicVisualizer: could not create empty overlay texture")
        }
        var transparent: [UInt8] = [0, 0, 0, 0]
        empty.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: &transparent,
            bytesPerRow: 4
        )
        self.emptyOverlayTexture = empty
        super.init()
    }

    /// Returns nil when Metal or shader setup fails.
    static func create() -> CompositeRenderer? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let fractal = try? FractalRenderer(device: device, library: library),
              let liquid = try? LiquidLightRenderer(device: device, library: library)
        else { return nil }

        guard let vfn = library.makeFunction(name: "compositeFullscreenVertex"),
              let ffn = library.makeFunction(name: "compositeFragment")
        else { return nil }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vfn
        desc.fragmentFunction = ffn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let compositePipeline = try? device.makeRenderPipelineState(descriptor: desc) else { return nil }
        return CompositeRenderer(
            device: device,
            commandQueue: queue,
            fractal: fractal,
            liquid: liquid,
            compositePipeline: compositePipeline
        )
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        fractalTexture = Self.makeTexture(device: device, size: size)
        liquidTexture = Self.makeTexture(device: device, size: size)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let buffer = commandQueue.makeCommandBuffer(),
              let compositePass = view.currentRenderPassDescriptor
        else { return }

        let wall = CACurrentMediaTime()
        if let last = lastFrameWallTime {
            onFrame?(wall - last)
        }
        lastFrameWallTime = wall

        let size = view.drawableSize
        if fractalTexture == nil || liquidTexture == nil {
            mtkView(view, drawableSizeWillChange: size)
        }
        guard var liquidTex = liquidTexture, var fractalTex = fractalTexture else { return }

        let w = max(1, Int(size.width))
        let h = max(1, Int(size.height))
        if liquidTex.width != w || liquidTex.height != h {
            mtkView(view, drawableSizeWillChange: size)
            liquidTex = liquidTexture!
            fractalTex = fractalTexture!
        }

        var uniforms = parameters.uniforms(drawableSize: size)
        uniforms.time = Float(CACurrentMediaTime() - startTime)

        var copy = uniforms
        guard let uniformBuffer = device.makeBuffer(
            bytes: &copy,
            length: Self.uniformBufferSize,
            options: .storageModeShared
        ) else { return }

        if let enc = buffer.makeRenderCommandEncoder(descriptor: FractalRenderer.offscreenPass(to: fractalTex)) {
            fractal.encodeFullScreen(encoder: enc, uniformBuffer: uniformBuffer)
            enc.endEncoding()
        }

        if let enc = buffer.makeRenderCommandEncoder(descriptor: LiquidLightRenderer.offscreenPass(to: liquidTex)) {
            liquid.encodeFullScreen(encoder: enc, uniformBuffer: uniformBuffer)
            enc.endEncoding()
        }

        compositePass.colorAttachments[0].loadAction = .clear
        compositePass.colorAttachments[0].clearColor = MTLClearColor(red: 0.02, green: 0.01, blue: 0.06, alpha: 1)
        compositePass.colorAttachments[0].storeAction = .store

        if let enc = buffer.makeRenderCommandEncoder(descriptor: compositePass) {
            enc.setRenderPipelineState(compositePipeline)
            enc.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            enc.setFragmentTexture(liquidTex, index: 0)
            enc.setFragmentTexture(fractalTex, index: 1)
            enc.setFragmentTexture(overlayTexture ?? emptyOverlayTexture, index: 2)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
        }

        buffer.present(drawable)
        buffer.commit()
    }

    private static func makeTexture(device: MTLDevice, size: CGSize) -> MTLTexture? {
        let w = max(1, Int(size.width))
        let h = max(1, Int(size.height))
        let d = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: w,
            height: h,
            mipmapped: false
        )
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        return device.makeTexture(descriptor: d)
    }
}
