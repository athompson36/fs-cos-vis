import Metal

/// Liquid-light full-screen pass — owns its pipeline state only.
final class LiquidLightRenderer {
    let pipelineState: MTLRenderPipelineState

    init(device: MTLDevice, library: MTLLibrary) throws {
        guard let vfn = library.makeFunction(name: "liquidFullscreenVertex"),
              let ffn = library.makeFunction(name: "liquidLightFragment")
        else {
            throw NSError(domain: "LiquidLightRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing liquid shader symbols"])
        }
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vfn
        desc.fragmentFunction = ffn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try device.makeRenderPipelineState(descriptor: desc)
    }

    func encodeFullScreen(encoder: MTLRenderCommandEncoder, uniformBuffer: MTLBuffer, dyeTexture: MTLTexture) {
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(dyeTexture, index: 0)
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
