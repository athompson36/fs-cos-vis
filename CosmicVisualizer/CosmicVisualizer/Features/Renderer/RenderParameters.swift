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
    var overlayRectMinX: Float
    var overlayRectMinY: Float
    var overlayRectW: Float
    var overlayRectH: Float
    var fractalGeometryIndex: Float
    var fractalExplore: Float
    var fractalExploreSpeed: Float
    var fractalPanX: Float
    var fractalPanY: Float
    var fractalIterBoost: Float
    var zoomEffectType: Float
    var liquidTiltX: Float
    var liquidTiltY: Float
    var dyeMix: Float
    var liquidReconstituteAmount: Float
    var liquidReconstituteRate: Float
    var liquidReconstituteBPMSync: Float
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
    /// Bottom-left origin, y up; default full frame.
    var overlayRectNorm: SIMD4<Float> = SIMD4(0, 0, 1, 1)
    /// 0 = Julia, 1 = Mandelbrot, 2 = Burning Ship, 3 = Tricorn.
    var fractalGeometryIndex: Float = 0
    /// Animated zoom/pan exploration amount (0 = off).
    var fractalExplore: Float = 0
    var fractalExploreSpeed: Float = 0.35
    var fractalPan: SIMD2<Float> = .zero
    var fractalIterBoost: Float = 1
    /// 0 = drift, 1 = pulse, 2 = breathe (affects explore animation).
    var zoomEffectType: Float = 0
    var liquidTilt: SIMD2<Float> = .zero
    /// How strongly the dye texture tints the liquid (0…1).
    var dyeMix: Float = 1
    var liquidDissolveHold: Float = 0.65
    var liquidReconstituteAmount: Float = 0
    var liquidReconstituteRate: Float = 0.55
    var liquidReconstituteBPMSync: Bool = false
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
            overlayOpacity: overlayOpacity,
            overlayRectMinX: overlayRectNorm.x,
            overlayRectMinY: overlayRectNorm.y,
            overlayRectW: overlayRectNorm.z,
            overlayRectH: overlayRectNorm.w,
            fractalGeometryIndex: fractalGeometryIndex,
            fractalExplore: fractalExplore,
            fractalExploreSpeed: fractalExploreSpeed,
            fractalPanX: fractalPan.x,
            fractalPanY: fractalPan.y,
            fractalIterBoost: fractalIterBoost,
            zoomEffectType: zoomEffectType,
            liquidTiltX: liquidTilt.x,
            liquidTiltY: liquidTilt.y,
            dyeMix: dyeMix,
            liquidReconstituteAmount: liquidReconstituteAmount,
            liquidReconstituteRate: liquidReconstituteRate,
            liquidReconstituteBPMSync: liquidReconstituteBPMSync ? 1 : 0
        )
    }
}
