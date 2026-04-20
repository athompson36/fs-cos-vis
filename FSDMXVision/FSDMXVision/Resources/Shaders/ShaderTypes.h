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
    float overlayRectMinX;
    float overlayRectMinY;
    float overlayRectW;
    float overlayRectH;               // normalized quad, bottom-left origin, y up
    // Fractal universe (0–6: Julia, Mandelbrot, Burning Ship, Tricorn, Multibrot, Newton, orbit trap)
    float fractalGeometryIndex;
    float fractalExplore;             // 0…1 explore strength
    float fractalExploreSpeed;
    float fractalPanX;
    float fractalPanY;
    float fractalIterBoost;           // scales iteration budget
    float zoomEffectType;             // 0 standard, 1 infinite tunnel, 2 event horizon
    float liquidTiltX;                // tray tilt → phase shift
    float liquidTiltY;
    float dyeMix;                     // dye contribution in liquid pass
    float liquidReconstituteAmount;   // 0..1 dissolve-reform bubbly motion
    float liquidReconstituteRate;     // free-running rate when bpm sync off
    float liquidReconstituteBPMSync;  // 0/1
    float compositeBloomStrength;     // additive highlight in composite pass
    float compositeVignetteStrength;  // edge darkening 0…1
    float fractalSmoothShading;       // 0 = discrete bands, 1 = smooth iteration
    // 16-bin spectrum (FFT) for composite UV warp; four float4 chunks
    vector_float4 spectrum0;
    vector_float4 spectrum1;
    vector_float4 spectrum2;
    vector_float4 spectrum3;
    vector_float4 spectrumWarp;       // .x = warp amount 0…1; .yzw unused
    vector_float4 dyeViscosity0;      // layers 0–3 viscosity 0…1
    vector_float4 dyeViscosity1;      // layers 4–7 viscosity 0…1
} CosmicUniforms;

#endif
