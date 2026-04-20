#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut compositeFullscreenVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}

static float spectrum16At(int i, constant CosmicUniforms& u) {
    switch (i) {
        case 0: return u.spectrum0.x;
        case 1: return u.spectrum0.y;
        case 2: return u.spectrum0.z;
        case 3: return u.spectrum0.w;
        case 4: return u.spectrum1.x;
        case 5: return u.spectrum1.y;
        case 6: return u.spectrum1.z;
        case 7: return u.spectrum1.w;
        case 8: return u.spectrum2.x;
        case 9: return u.spectrum2.y;
        case 10: return u.spectrum2.z;
        case 11: return u.spectrum2.w;
        case 12: return u.spectrum3.x;
        case 13: return u.spectrum3.y;
        case 14: return u.spectrum3.z;
        default: return u.spectrum3.w;
    }
}

fragment float4 compositeFragment(VertexOut in [[stage_in]],
                                    constant CosmicUniforms& u [[buffer(0)]],
                                    texture2d<float> liquidTex [[texture(0)]],
                                    texture2d<float> fractalTex [[texture(1)]],
                                    texture2d<float> overlayTex [[texture(2)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = in.uv;
    float warpAmt = clamp(u.spectrumWarp.x, 0.0f, 1.0f);
    float2 uvW = uv;
    if (warpAmt > 0.0005f) {
        float2 c = uv - float2(0.5f, 0.5f);
        float r = length(c);
        float2 dir = r > 1e-4f ? c / r : float2(1.0f, 0.0f);
        float ang = atan2(c.y, c.x);
        float ang01 = (ang + 3.14159265f) / (2.0f * 3.14159265f);
        float idxF = ang01 * 15.0f;
        int i0 = clamp(int(floor(idxF)), 0, 14);
        float ft = idxF - float(i0);
        float mag = mix(spectrum16At(i0, u), spectrum16At(i0 + 1, u), ft);
        mag *= warpAmt * (0.5f + 0.5f * u.beatPulse);
        float bass = (u.spectrum0.x + u.spectrum0.y + u.spectrum0.z) * (1.0f / 3.0f);
        float2 disp = dir * mag * 0.11f;
        disp.y += (bass - 0.33f) * 0.035f * warpAmt;
        uvW = saturate(uv + disp);
    }
    float4 L = liquidTex.sample(s, uvW);
    float4 F = fractalTex.sample(s, uvW);
    float3 screen = 1.0f - (1.0f - F.rgb) * (1.0f - L.rgb);
    float3 add = F.rgb * 0.35f + L.rgb * 0.45f;
    float blend = clamp(u.compositeBlend, 0.0f, 1.0f);
    float3 outRgb = mix(screen, add, blend * (0.55f + 0.45f * u.audioLevel));
    outRgb += float3(0.02f, 0.01f, 0.04f) * u.beatPulse;

    float ox = u.overlayRectMinX;
    float oy = u.overlayRectMinY;
    float ow = max(u.overlayRectW, 1e-4f);
    float oh = max(u.overlayRectH, 1e-4f);
    float2 local = (uvW - float2(ox, oy)) / float2(ow, oh);
    bool inLogo = (local.x >= 0.0f) && (local.x <= 1.0f) && (local.y >= 0.0f) && (local.y <= 1.0f);
    // PNG rows vs Metal: flip V inside the logo quad so imports match matte exports.
    float2 texSt = float2(local.x, 1.0f - local.y);
    float4 O = inLogo ? overlayTex.sample(s, texSt) : float4(0.0f);
    float fusion = clamp(u.overlayFractalFusion, 0.0f, 1.0f);
    float op = clamp(u.overlayOpacity, 0.0f, 1.0f);
    float fractalSig = saturate(dot(F.rgb, float3(0.33f, 0.45f, 0.22f)) * 1.35f);
    float liq = saturate(dot(L.rgb, float3(0.3f, 0.4f, 0.3f)));
    float carve = fractalSig * (0.55f + 0.45f * liq);
    float logoA = O.a * op;
    float dissolve = mix(logoA, logoA * (0.12f + 0.88f * pow(carve, 1.6f)), fusion);
    float3 logoRgb = O.rgb;
    outRgb = mix(outRgb, logoRgb, dissolve);

    float hi = max(max(outRgb.r, outRgb.g), outRgb.b);
    outRgb += hi * hi * clamp(u.compositeBloomStrength, 0.0f, 1.0f);

    float2 q = uv * 2.0f - 1.0f;
    float vig = 1.0f - dot(q, q) * clamp(u.compositeVignetteStrength, 0.0f, 1.0f);
    outRgb *= max(vig, 0.12f);

    return float4(outRgb, 1.0f);
}
