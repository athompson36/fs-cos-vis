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

static float2 csquare(float2 z) {
    return float2(z.x * z.x - z.y * z.y, 2.0f * z.x * z.y);
}

static float2 cmult(float2 a, float2 b) {
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fragment float4 fractalFragment(VertexOut in [[stage_in]],
                                constant CosmicUniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = u.resolution.x / max(u.resolution.y, 1.0f);
    float2 p = float2((uv.x - 0.5f) * 2.0f * aspect, (uv.y - 0.5f) * 2.0f);

    float zoomBase = clamp(u.fractalZoom, 0.12f, 4.5f);
    float ex = clamp(u.fractalExplore, 0.0f, 1.0f);
    float spd = max(0.05f, u.fractalExploreSpeed);
    float2 drift = float2(sin(u.time * spd), cos(u.time * spd * 0.87f)) * 0.22f * ex;
    float effZoom = zoomBase;
    if (u.zoomEffectType < 0.5f) {
        effZoom *= (1.0f + 0.14f * sin(u.time * spd * 1.1f) * ex);
    } else if (u.zoomEffectType < 1.5f) {
        effZoom *= (1.0f + 0.22f * (0.5f + 0.5f * sin(u.time * spd * 2.3f)) * ex);
    } else {
        effZoom *= (1.0f + 0.1f * sin(u.time * spd * 0.55f) * ex);
    }
    p = p / effZoom + drift + float2(u.fractalPanX, u.fractalPanY) * 0.6f;

    float pulse = u.beatPulse * 0.15f;
    float2 cJulia = float2(-0.8f + 0.05f * sin(u.time * 0.3f + pulse),
                           0.156f + 0.05f * cos(u.time * 0.27f));
    cJulia += float2(0.02f * u.audioLevel, -0.01f * u.audioLevel);

    float boost = clamp(u.fractalIterBoost, 0.25f, 3.0f);
    int maxIter = int(float(48 + int(24.0f * clamp(u.audioLevel, 0.0f, 1.0f))) * boost);
    maxIter = min(maxIter, 256);

    int geo = int(u.fractalGeometryIndex + 0.25f);
    geo = clamp(geo, 0, 4);

    int i = 0;
    float2 z;
    float2 c;

    if (geo == 0) {
        c = cJulia;
        z = p;
        for (; i < maxIter; i++) {
            if (dot(z, z) > 4.0f) { break; }
            z = csquare(z) + c;
        }
    } else if (geo == 1) {
        c = p + float2(0.35f * sin(u.time * 0.11f), 0.0f);
        z = float2(0.0f, 0.0f);
        for (; i < maxIter; i++) {
            if (dot(z, z) > 4.0f) { break; }
            z = csquare(z) + c;
        }
    } else if (geo == 2) {
        c = p + float2(0.12f * sin(u.time * 0.09f), 0.0f);
        z = float2(0.0f, 0.0f);
        for (; i < maxIter; i++) {
            if (dot(z, z) > 4.0f) { break; }
            float nx = z.x * z.x - z.y * z.y + c.x;
            float ny = 2.0f * abs(z.x * z.y) + c.y;
            z = float2(nx, ny);
        }
    } else if (geo == 3) {
        c = p + float2(0.08f * cos(u.time * 0.1f), 0.0f);
        z = float2(0.0f, 0.0f);
        for (; i < maxIter; i++) {
            if (dot(z, z) > 4.0f) { break; }
            float2 w = float2(z.x, -z.y);
            z = csquare(w) + c;
        }
    } else {
        c = p + float2(0.1f * sin(u.time * 0.07f), 0.0f);
        z = float2(0.0f, 0.0f);
        for (; i < maxIter; i++) {
            if (dot(z, z) > 4.0f) { break; }
            float2 z2 = cmult(z, z);
            z = cmult(z2, z) + c;
        }
    }

    float zn2 = dot(z, z);
    float m = sqrt(max(zn2, 1e-8f));
    float tSmooth;
    if (i >= maxIter) {
        tSmooth = 1.0f;
    } else {
        float nu = log2(log2(max(m, 2.0f)));
        float smoothCount = float(i) + 1.0f - nu;
        tSmooth = clamp(smoothCount / float(max(maxIter, 1)), 0.0f, 1.0f);
    }
    float tBanded = float(i) / float(max(maxIter, 1));
    float sm = clamp(u.fractalSmoothShading, 0.0f, 1.0f);
    float t = mix(tBanded, tSmooth, sm);

    float hue = t + u.time * 0.05f * clamp(u.fractalZoom, 0.2f, 4.0f) + u.bpm * 0.001f;

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
