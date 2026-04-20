import Combine
import Metal
import MetalKit
import QuartzCore
import simd

/// Matches `LiquidSplatUniform` in `DyeAccumulate.metal` (32 bytes).
struct LiquidSplatUniform {
    var uvX: Float
    var uvY: Float
    var colorR: Float
    var colorG: Float
    var colorB: Float
    var layerIndex: UInt32
    var radius: Float
    var alpha: Float
}

/// Orchestrates liquid + fractal offscreen passes and a final composite to the view drawable.
final class CompositeRenderer: NSObject, MTKViewDelegate, ObservableObject, @unchecked Sendable {
    private static let maxDyeLayers = SceneEditState.LayerControls.maxDropperLayers
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let fractal: FractalRenderer
    private let liquid: LiquidLightRenderer
    private let compositePipeline: MTLRenderPipelineState
    private let dyePipelineState: MTLRenderPipelineState
    private let dyeCompositePipelineState: MTLRenderPipelineState
    private let dyeEmptyTexture: MTLTexture
    private let dyeCompositeUniformBuffer: MTLBuffer

    private var fractalTexture: MTLTexture?
    private var liquidTexture: MTLTexture?
    private var dyeTexturesByLayer: [[MTLTexture]] = []
    private var dyeReadIndexByLayer: [Int] = []
    private var dyeCompositeTexture: MTLTexture?
    private let emptyOverlayTexture: MTLTexture

    private let splatLock = NSLock()
    private var pendingSplats: [LiquidSplatUniform] = []

    /// Logo / image layer (premultiplied BGRA). When nil, an empty texture is bound.
    var overlayTexture: MTLTexture?

    private var startTime = CACurrentMediaTime()
    private var lastFrameWallTime: CFTimeInterval?
    /// Invoked once per drawn frame with estimated wall-clock delta (seconds).
    var onFrame: ((TimeInterval) -> Void)?

    /// If set, called after the composite pass and before `present` (e.g. Syphon publish to OBS).
    var onBeforePresent: ((MTLTexture, MTLCommandBuffer, CGSize) -> Void)?

    /// Backing store read synchronously in `draw(in:)`; SwiftUI is notified on the next main run-loop turn to avoid publishing during view/display updates.
    private var _parameters = RenderParameters()
    var parameters: RenderParameters {
        get { _parameters }
        set {
            _parameters = newValue
            scheduleObservableUpdate()
        }
    }

    func updateParameters(_ update: (inout RenderParameters) -> Void) {
        var next = _parameters
        update(&next)
        _parameters = next
        scheduleObservableUpdate()
    }

    private func scheduleObservableUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    /// Thread-safe: splats are applied on the next `draw(in:)`.
    func enqueueLiquidSplat(uv: SIMD2<Float>, color: SIMD3<Float>, viscosity: Float, layerIndex: Int) {
        let vis = max(0, min(1, viscosity))
        let radius = Self.lerp(0.045, 0.012, vis)
        let alpha = Self.lerp(0.42, 0.92, 1 - vis)
        let safeLayer = UInt32(max(0, min(Self.maxDyeLayers - 1, layerIndex)))
        let s = LiquidSplatUniform(
            uvX: uv.x,
            uvY: uv.y,
            colorR: color.x,
            colorG: color.y,
            colorB: color.z,
            layerIndex: safeLayer,
            radius: radius,
            alpha: alpha
        )
        splatLock.lock()
        if pendingSplats.count < 400 {
            pendingSplats.append(s)
        }
        splatLock.unlock()
    }

    func clearLiquidDye() {
        splatLock.lock()
        pendingSplats.removeAll()
        splatLock.unlock()
        dyeTexturesByLayer.removeAll()
        dyeReadIndexByLayer.removeAll()
        dyeCompositeTexture = nil
    }

    private static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a * (1 - t) + b * t }

    private static var uniformBufferSize: Int {
        let s = MemoryLayout<CosmicUniforms>.stride
        return (s + 255) / 256 * 256
    }

    private init(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        fractal: FractalRenderer,
        liquid: LiquidLightRenderer,
        compositePipeline: MTLRenderPipelineState,
        dyePipelineState: MTLRenderPipelineState,
        dyeCompositePipelineState: MTLRenderPipelineState,
        dyeEmptyTexture: MTLTexture,
        dyeCompositeUniformBuffer: MTLBuffer
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.fractal = fractal
        self.liquid = liquid
        self.compositePipeline = compositePipeline
        self.dyePipelineState = dyePipelineState
        self.dyeCompositePipelineState = dyeCompositePipelineState
        self.dyeEmptyTexture = dyeEmptyTexture
        self.dyeCompositeUniformBuffer = dyeCompositeUniformBuffer
        let emptyDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        emptyDesc.usage = [.shaderRead]
        guard let empty = device.makeTexture(descriptor: emptyDesc) else {
            fatalError("FSDMXVision: could not create empty overlay texture")
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

        guard let dvfn = library.makeFunction(name: "dyeFullscreenVertex"),
              let dffn = library.makeFunction(name: "dyeAccumulateFragment")
        else { return nil }
        let dyeDesc = MTLRenderPipelineDescriptor()
        dyeDesc.vertexFunction = dvfn
        dyeDesc.fragmentFunction = dffn
        dyeDesc.colorAttachments[0].pixelFormat = .rgba16Float
        guard let dyePS = try? device.makeRenderPipelineState(descriptor: dyeDesc) else { return nil }
        guard let dcfn = library.makeFunction(name: "dyeCompositeFragment") else { return nil }
        let dyeCompositeDesc = MTLRenderPipelineDescriptor()
        dyeCompositeDesc.vertexFunction = dvfn
        dyeCompositeDesc.fragmentFunction = dcfn
        dyeCompositeDesc.colorAttachments[0].pixelFormat = .rgba16Float
        guard let dyeCompositePS = try? device.makeRenderPipelineState(descriptor: dyeCompositeDesc) else { return nil }

        let emptyDyeDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: 1,
            height: 1,
            mipmapped: false
        )
        emptyDyeDesc.usage = [.shaderRead]
        guard let emptyDye = device.makeTexture(descriptor: emptyDyeDesc) else { return nil }
        var z16 = [UInt16](repeating: 0, count: 4)
        emptyDye.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: &z16,
            bytesPerRow: 8
        )
        // metadata: layerCount, 8 viscosities, liquidFocus (sharp meniscus width driver).
        let dyeCompositeUniformSize = MemoryLayout<Float>.stride * (1 + Self.maxDyeLayers + 1)
        guard let dyeCompositeUniformBuffer = device.makeBuffer(
            length: dyeCompositeUniformSize,
            options: .storageModeShared
        ) else { return nil }

        return CompositeRenderer(
            device: device,
            commandQueue: queue,
            fractal: fractal,
            liquid: liquid,
            compositePipeline: compositePipeline,
            dyePipelineState: dyePS,
            dyeCompositePipelineState: dyeCompositePS,
            dyeEmptyTexture: emptyDye,
            dyeCompositeUniformBuffer: dyeCompositeUniformBuffer
        )
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        fractalTexture = Self.makeTexture(device: device, size: size)
        liquidTexture = Self.makeTexture(device: device, size: size)
        dyeTexturesByLayer.removeAll()
        dyeReadIndexByLayer.removeAll()
        dyeCompositeTexture = nil
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

        ensureDyeTextures(width: w, height: h)
        let dyeForLiquid: MTLTexture
        if !dyeTexturesByLayer.isEmpty, let dyeCompositeTexture {
            encodeDyeAccumulate(into: buffer, width: w, height: h)
            encodeDyeComposite(into: buffer, target: dyeCompositeTexture)
            dyeForLiquid = dyeCompositeTexture
        } else {
            dyeForLiquid = dyeEmptyTexture
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
            liquid.encodeFullScreen(encoder: enc, uniformBuffer: uniformBuffer, dyeTexture: dyeForLiquid)
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

        onBeforePresent?(drawable.texture, buffer, size)
        buffer.present(drawable)
        buffer.commit()
    }

    private func ensureDyeTextures(width: Int, height: Int) {
        if !dyeTexturesByLayer.isEmpty,
           let sample = dyeTexturesByLayer.first?.first,
           sample.width == width,
           sample.height == height,
           dyeCompositeTexture?.width == width,
           dyeCompositeTexture?.height == height
        {
            return
        }
        var nextLayers: [[MTLTexture]] = []
        for _ in 0 ..< Self.maxDyeLayers {
            let pair = [
                Self.makeDyeTexture(device: device, width: width, height: height),
                Self.makeDyeTexture(device: device, width: width, height: height),
            ].compactMap { $0 }
            if pair.count == 2 {
                nextLayers.append(pair)
            }
        }
        dyeTexturesByLayer = nextLayers
        dyeReadIndexByLayer = Array(repeating: 0, count: dyeTexturesByLayer.count)
        for pair in dyeTexturesByLayer {
            for texture in pair {
                Self.clearDyeTexture(texture)
            }
        }
        dyeCompositeTexture = Self.makeDyeTexture(device: device, width: width, height: height)
    }

    private func encodeDyeAccumulate(into buffer: MTLCommandBuffer, width: Int, height: Int) {
        guard !dyeTexturesByLayer.isEmpty else { return }
        let decay = Self.lerp(0.88, 0.9985, max(0, min(1, parameters.liquidDissolveHold)))
        splatLock.lock()
        let n = min(48, pendingSplats.count)
        let batch = Array(pendingSplats.prefix(n))
        if n > 0 {
            pendingSplats.removeFirst(n)
        }
        splatLock.unlock()

        for layerIndex in dyeTexturesByLayer.indices {
            let layerBatch = batch.filter { Int($0.layerIndex) == layerIndex }
            var count = Int32(layerBatch.count)
            let stride = MemoryLayout<LiquidSplatUniform>.stride
            let bufLen = max(stride, layerBatch.count * stride)
            guard let splatBuffer = device.makeBuffer(
                length: bufLen,
                options: .storageModeShared
            ) else { continue }
            if !layerBatch.isEmpty {
                layerBatch.withUnsafeBytes { src in
                    splatBuffer.contents().copyMemory(from: src.baseAddress!, byteCount: layerBatch.count * stride)
                }
            }
            guard let countBuf = device.makeBuffer(
                bytes: &count,
                length: MemoryLayout<Int32>.stride,
                options: .storageModeShared
            ) else { continue }
            var decayCopy = decay
            guard let decayBuf = device.makeBuffer(
                bytes: &decayCopy,
                length: MemoryLayout<Float>.stride,
                options: .storageModeShared
            ) else { continue }

            let readIndex = dyeReadIndexByLayer[layerIndex]
            let read = dyeTexturesByLayer[layerIndex][readIndex]
            let write = dyeTexturesByLayer[layerIndex][1 - readIndex]

            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = write
            pass.colorAttachments[0].loadAction = .dontCare
            pass.colorAttachments[0].storeAction = .store

            guard let enc = buffer.makeRenderCommandEncoder(descriptor: pass) else { continue }
            enc.setRenderPipelineState(dyePipelineState)
            enc.setFragmentTexture(read, index: 0)
            enc.setFragmentBuffer(countBuf, offset: 0, index: 1)
            enc.setFragmentBuffer(splatBuffer, offset: 0, index: 2)
            enc.setFragmentBuffer(decayBuf, offset: 0, index: 3)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()

            dyeReadIndexByLayer[layerIndex] = 1 - readIndex
        }
    }

    private func encodeDyeComposite(into buffer: MTLCommandBuffer, target: MTLTexture) {
        guard !dyeTexturesByLayer.isEmpty else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let enc = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        let ptr = dyeCompositeUniformBuffer.contents().assumingMemoryBound(to: Float.self)
        ptr[0] = Float(dyeTexturesByLayer.count)
        let visc = parameters.dyeLayerViscosity
        ptr[1] = visc[0]
        ptr[2] = visc[1]
        ptr[3] = visc[2]
        ptr[4] = visc[3]
        ptr[5] = visc[4]
        ptr[6] = visc[5]
        ptr[7] = visc[6]
        ptr[8] = visc[7]
        ptr[9] = parameters.liquidFocus
        enc.setRenderPipelineState(dyeCompositePipelineState)
        for layerIndex in dyeTexturesByLayer.indices {
            let readIndex = dyeReadIndexByLayer[layerIndex]
            enc.setFragmentTexture(dyeTexturesByLayer[layerIndex][readIndex], index: layerIndex)
        }
        enc.setFragmentBuffer(dyeCompositeUniformBuffer, offset: 0, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
    }

    private static func clearDyeTexture(_ texture: MTLTexture) {
        let w = texture.width
        let h = texture.height
        var zeros = [UInt16](repeating: 0, count: w * h * 4)
        texture.replace(
            region: MTLRegionMake2D(0, 0, w, h),
            mipmapLevel: 0,
            withBytes: &zeros,
            bytesPerRow: w * 8
        )
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

    private static func makeDyeTexture(device: MTLDevice, width: Int, height: Int) -> MTLTexture? {
        let d = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        d.usage = [.shaderRead, .renderTarget]
        d.storageMode = .shared
        guard let t = device.makeTexture(descriptor: d) else { return nil }
        clearDyeTexture(t)
        return t
    }
}
