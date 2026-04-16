#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut liquidFullscreenVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}

fragment float4 liquidLightFragment(VertexOut in [[stage_in]],
                                    constant CosmicUniforms& u [[buffer(0)]]) {
    float2 p = in.uv * 2.0f - 1.0f;
    float turb = max(0.2f, u.liquidTurbulence);
    float focus = clamp(u.liquidFocus, 0.0f, 1.0f);
    float freq = mix(2.4f, 7.5f, focus);
    float t = u.time * (0.35f + 0.002f * u.bpm) * turb;
    float w1 = freq * turb;
    float w2 = w1 * 0.48f;
    float bSharp = sin(w1 * p.x + t) + sin(w1 * p.y - t * 0.8f) + sin(0.65f * w1 * (p.x + p.y) + t * 0.5f);
    float bSoft = sin(w2 * p.x + t * 0.9f) + sin(w2 * p.y - t * 0.6f);
    float blob = mix(bSoft * 0.55f + bSharp * 0.45f, bSharp, focus);
    float fuzz = mix(0.55f, 0.92f, focus);
    blob *= fuzz * (0.5f + 0.5f * u.audioLevel);
    float3 cool = mix(u.palettePrimary.xyz, u.paletteSecondary.xyz, 0.45f + 0.25f * sin(t * 0.2f));
    float3 warm = mix(u.paletteAccent.xyz, u.paletteGlow.xyz, 0.5f + 0.5f * sin(blob * 0.3f));
    float3 col = mix(cool, warm, 0.5f + 0.5f * sin(blob + u.beatPulse));
    col = mix(col, col * 0.65f + warm * 0.35f, (1.0f - focus) * 0.55f);
    col = mix(col, float3(1.0f, 0.92f, 0.55f), 0.12f * u.beatPulse);
    return float4(col * u.liquidMix, 0.85f);
}
