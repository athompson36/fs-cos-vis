#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut cosmicFullscreenVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}

fragment float4 fractalFragment(VertexOut in [[stage_in]],
                                constant CosmicUniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = u.resolution.x / max(u.resolution.y, 1.0f);
    float2 p = float2((uv.x - 0.5) * 2.0 * aspect, (uv.y - 0.5) * 2.0);
    float zoom = clamp(u.fractalZoom, 0.35f, 2.25f);
    p /= zoom;
    float pulse = u.beatPulse * 0.15f;
    float2 cJulia = float2(-0.8f + 0.05f * sin(u.time * 0.3f + pulse),
                           0.156f + 0.05f * cos(u.time * 0.27f));
    cJulia += float2(0.02f * u.audioLevel, -0.01f * u.audioLevel);

    int maxIter = 48 + int(24.0f * clamp(u.audioLevel, 0.0f, 1.0f));
    int i = 0;
    float2 z;
    float2 c;
    if (u.fractalKind > 0.5f) {
        c = p + float2(0.35f * sin(u.time * 0.11f), 0.0f);
        z = float2(0.0f, 0.0f);
    } else {
        c = cJulia;
        z = p;
    }

    for (; i < maxIter; i++) {
        if (dot(z, z) > 4.0f) { break; }
        float x = z.x * z.x - z.y * z.y;
        float y = 2.0f * z.x * z.y;
        z = float2(x, y) + c;
    }

    float t = float(i) / float(maxIter);
    float hue = t + u.time * 0.05f * clamp(u.fractalZoom, 0.5f, 2.0f) + u.bpm * 0.001f;

    float3 col;
    if (u.fractalAppearance > 0.5f) {
        float3 bg = u.palettePrimary.xyz * 0.14f + u.paletteSecondary.xyz * 0.06f;
        float band = pow(0.5f + 0.5f * sin(float(i) * 0.85f + u.time * 1.4f + hue * 3.0f), 18.0f);
        float rim = smoothstep(0.15f, 0.95f, t) * (0.35f + 0.65f * band);
        float3 neon = mix(u.paletteAccent.xyz, u.paletteGlow.xyz, t);
        neon *= 1.15f;
        col = mix(bg, neon * rim + bg * (1.0f - rim), min(1.0f, t * 2.2f));
        col += neon * 0.08f * band;
    } else {
        float3 a = mix(u.palettePrimary.xyz, u.paletteSecondary.xyz, 0.5f + 0.5f * sin(hue * 6.28f));
        float3 b = mix(u.paletteAccent.xyz, u.paletteGlow.xyz, 0.5f + 0.5f * sin(hue * 6.28f + 2.1f));
        col = mix(a, b, t);
        col *= (0.35f + 0.65f * t);
    }
    return float4(col * u.fractalMix, 1.0f);
}
