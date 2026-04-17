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
    float overlayRectMinX;
    float overlayRectMinY;
    float overlayRectW;
    float overlayRectH;               // normalized quad, bottom-left origin, y up
    // Fractal universe (0=Julia,1=Mandelbrot,2=BurningShip,3=Tricorn)
    float fractalGeometryIndex;
    float fractalExplore;             // 0…1 explore strength
    float fractalExploreSpeed;
    float fractalPanX;
    float fractalPanY;
    float fractalIterBoost;           // scales iteration budget
    float zoomEffectType;             // 0 drift, 1 pulse, 2 breathe
    float liquidTiltX;                // tray tilt → phase shift
    float liquidTiltY;
    float dyeMix;                     // dye contribution in liquid pass
    float liquidReconstituteAmount;   // 0..1 dissolve-reform bubbly motion
    float liquidReconstituteRate;     // free-running rate when bpm sync off
    float liquidReconstituteBPMSync;  // 0/1
} CosmicUniforms;

#endif
