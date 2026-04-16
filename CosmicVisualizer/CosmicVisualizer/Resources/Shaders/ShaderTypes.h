#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef struct {
    vector_float2 resolution;
    float time;
    float audioLevel;
    float bpm;
    float beatPulse;
    float liquidMix;
    float fractalMix;
    float fractalKind; // 0 = Julia, 1 = Mandelbrot
    float fractalZoom;
    float liquidTurbulence;
    float compositeBlend;
    vector_float4 palettePrimary;   // rgb + unused
    vector_float4 paletteSecondary;
    vector_float4 paletteAccent;
    vector_float4 paletteGlow;
    float liquidFocus;              // 0 = soft / fuzzy, 1 = sharp liquid blobs
    float fractalAppearance;        // 0 = palette gradient, 1 = dark cosmic + neon wireframe
    float overlayFractalFusion;       // 0 = logo as imported, 1 = dissolve into fractal structure
    float overlayOpacity;
} CosmicUniforms;

#endif
