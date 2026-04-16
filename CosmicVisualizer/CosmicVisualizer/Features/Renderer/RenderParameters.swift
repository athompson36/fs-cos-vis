import Foundation
import simd

/// GPU uniform block — must match `CosmicUniforms` in `ShaderTypes.h` / `.metal`.
struct CosmicUniforms {
    var resolution: SIMD2<Float>
    var time: Float
    var audioLevel: Float
    var bpm: Float
    var beatPulse: Float
    var liquidMix: Float
    var fractalMix: Float
    var fractalKind: Float
    var fractalZoom: Float
    var liquidTurbulence: Float
    var compositeBlend: Float
    var palettePrimary: SIMD4<Float>
    var paletteSecondary: SIMD4<Float>
    var paletteAccent: SIMD4<Float>
    var paletteGlow: SIMD4<Float>
    var liquidFocus: Float
    var fractalAppearance: Float
    var overlayFractalFusion: Float
    var overlayOpacity: Float
}

/// Authoring-time render controls from scenes and audio (Swift-only).
struct RenderParameters {
    var time: TimeInterval = 0
    var audioLevel: Float = 0
    var bpm: Float = 0
    /// Retained for diagnostics / UI; GPU pulse uses `beatPulse`.
    var beatConfidence: Float = 0
    var beatPulse: Float = 0
    var liquidMix: Float = 1
    var fractalMix: Float = 1
    var liquidLightEnabled: Bool = true
    /// 0 = Julia, 1 = Mandelbrot (maps to GPU `fractalKind`).
    var fractalKind: Float = 0
    var fractalZoom: Float = 1
    var liquidTurbulence: Float = 1
    var compositeBlend: Float = 0.65
    /// 0 = soft blended colors, 1 = sharper, more “liquid glass” blobs.
    var liquidFocus: Float = 0.78
    /// 0 = full-spectrum palette-driven fractal, 1 = deep field + neon wireframe look.
    var fractalAppearance: Float = 0
    /// 0 = overlay reads as a flat layer; 1 = logo alpha is carved by fractal luminance (seamless dissolve).
    var overlayFractalFusion: Float = 0.4
    var overlayOpacity: Float = 1
    var palettePrimary: SIMD4<Float> = SIMD4(0.04, 0.01, 0.09, 0)
    var paletteSecondary: SIMD4<Float> = SIMD4(0.1, 0.04, 0.2, 0)
    var paletteAccent: SIMD4<Float> = SIMD4(0, 0.9, 1, 0)
    var paletteGlow: SIMD4<Float> = SIMD4(1, 0.18, 0.9, 0)

    func uniforms(drawableSize: CGSize) -> CosmicUniforms {
        CosmicUniforms(
            resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height)),
            time: Float(time),
            audioLevel: audioLevel,
            bpm: bpm,
            beatPulse: beatPulse,
            liquidMix: liquidLightEnabled ? liquidMix : 0,
            fractalMix: fractalMix,
            fractalKind: fractalKind,
            fractalZoom: fractalZoom,
            liquidTurbulence: liquidTurbulence,
            compositeBlend: compositeBlend,
            palettePrimary: palettePrimary,
            paletteSecondary: paletteSecondary,
            paletteAccent: paletteAccent,
            paletteGlow: paletteGlow,
            liquidFocus: liquidFocus,
            fractalAppearance: fractalAppearance,
            overlayFractalFusion: overlayFractalFusion,
            overlayOpacity: overlayOpacity
        )
    }
}
