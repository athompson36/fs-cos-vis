import Metal

/// Fractal full-screen pass (Julia) — owns its pipeline state only.
final class FractalRenderer {
    let pipelineState: MTLRenderPipelineState

    init(device: MTLDevice, library: MTLLibrary) throws {
        guard let vfn = library.makeFunction(name: "cosmicFullscreenVertex"),
              let ffn = library.makeFunction(name: "fractalFragment")
        else {
            throw NSError(domain: "FractalRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing fractal shader symbols"])
        }
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vfn
        desc.fragmentFunction = ffn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try device.makeRenderPipelineState(descriptor: desc)
    }

    func encodeFullScreen(encoder: MTLRenderCommandEncoder, uniformBuffer: MTLBuffer) {
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }

    static func offscreenPass(to texture: MTLTexture) -> MTLRenderPassDescriptor {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        return pass
    }
}
