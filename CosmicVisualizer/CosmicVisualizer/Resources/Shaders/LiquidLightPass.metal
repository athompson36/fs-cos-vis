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

static float blobField(float2 p, float turb, float t, float2 tilt, float focus) {
    float tx = tilt.x * 2.5f;
    float ty = tilt.y * 2.5f;
    float freq = mix(2.4f, 7.5f, focus);
    float w1 = freq * turb;
    float w2 = w1 * 0.48f;
    float bSharp = sin(w1 * p.x + tx + t) + sin(w1 * p.y + ty - t * 0.8f)
        + sin(0.65f * w1 * (p.x + p.y) + t * 0.5f);
    float bSoft = sin(w2 * p.x + tx + t * 0.9f) + sin(w2 * p.y + ty - t * 0.6f);
    return mix(bSoft * 0.55f + bSharp * 0.45f, bSharp, focus);
}

static float bubbleField(float2 p, float t, float rate) {
    float phase = t * (0.75f + rate * 1.85f);
    return 0.5f + 0.5f * (
        sin((p.x + phase) * 18.0f) *
        cos((p.y - phase * 0.8f) * 20.0f) +
        0.45f * sin((p.x + p.y + phase * 1.2f) * 14.0f)
    );
}

fragment float4 liquidLightFragment(VertexOut in [[stage_in]],
                                    constant CosmicUniforms& u [[buffer(0)]],
                                    texture2d<float> dyeTex [[texture(0)]]) {
    constexpr sampler samp(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = in.uv;
    float2 p = uv * 2.0f - 1.0f;
    float turb = max(0.2f, u.liquidTurbulence);
    float focus = clamp(u.liquidFocus, 0.0f, 1.0f);
    float2 tilt = float2(u.liquidTiltX, u.liquidTiltY);
    float t = u.time * (0.35f + 0.002f * u.bpm) * turb;
    t += tilt.x * 0.4f + tilt.y * 0.35f;

    float blob = blobField(p, turb, t, tilt, focus);

    float2 e = float2(0.006f / max(u.resolution.x / max(u.resolution.y, 1.0f), 0.5f), 0.006f);
    float2 px = p + float2(e.x, 0.0f);
    float2 py = p + float2(0.0f, e.y);
    float bx = blobField(px, turb, t, tilt, focus) - blobField(p - float2(e.x, 0.0f), turb, t, tilt, focus);
    float by = blobField(py, turb, t, tilt, focus) - blobField(p - float2(0.0f, e.y), turb, t, tilt, focus);
    float3 N = normalize(float3(-bx, -by, 1.4f));
    float3 L = normalize(float3(0.35f, 0.65f, 0.55f));
    float3 V = float3(0.0f, 0.0f, 1.0f);
    float3 H = normalize(L + V);
    float specAmt = focus * focus * (0.35f + 0.65f * focus);
    float spec = pow(saturate(dot(N, H)), mix(24.0f, 96.0f, focus)) * specAmt;
    float fres = pow(1.0f - saturate(dot(N, V)), 3.0f) * 0.35f * focus;

    float fuzz = mix(0.55f, 0.92f, focus);
    blob *= fuzz * (0.5f + 0.5f * u.audioLevel);
    float3 cool = mix(u.palettePrimary.xyz, u.paletteSecondary.xyz, 0.45f + 0.25f * sin(t * 0.2f));
    float3 warm = mix(u.paletteAccent.xyz, u.paletteGlow.xyz, 0.5f + 0.5f * sin(blob * 0.3f));
    float3 col = mix(cool, warm, 0.5f + 0.5f * sin(blob + u.beatPulse));
    col = mix(col, col * 0.65f + warm * 0.35f, (1.0f - focus) * 0.55f);
    col = mix(col, float3(1.0f, 0.92f, 0.55f), 0.12f * u.beatPulse);

    float3 lightCol = float3(1.0f, 0.98f, 0.92f);
    col += lightCol * (spec + fres) * (0.4f + 0.6f * focus);

    float4 dye = dyeTex.sample(samp, uv);
    float reconAmt = clamp(u.liquidReconstituteAmount, 0.0f, 1.0f);
    if (reconAmt > 0.0001f) {
        float rate = u.liquidReconstituteBPMSync > 0.5f
            ? max(0.08f, u.bpm / 60.0f)
            : max(0.05f, u.liquidReconstituteRate);
        float bub = bubbleField(p, u.time, rate);
        float dens = smoothstep(0.36f, 0.82f, bub + 0.18f * sin((u.time * rate + p.x - p.y) * 6.0f));
        float bubbleAlpha = mix(dye.a, dye.a * dens, reconAmt);
        float3 bubbleRGB = mix(dye.rgb, dye.rgb * (0.84f + 0.32f * dens), reconAmt);
        dye = float4(bubbleRGB, bubbleAlpha);
    }
    float dm = clamp(u.dyeMix, 0.0f, 1.0f);
    col = mix(col, col * 0.65f + dye.rgb * 1.15f, dm * saturate(dye.a) * 0.85f);

    return float4(col * u.liquidMix, 0.85f);
}
