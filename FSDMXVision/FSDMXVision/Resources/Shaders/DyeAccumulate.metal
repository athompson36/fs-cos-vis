#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct LiquidSplatUniform {
    float uvX;
    float uvY;
    float colorR;
    float colorG;
    float colorB;
    uint layerIndex;
    float radius;
    float alpha;
};

vertex VertexOut dyeFullscreenVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}

fragment float4 dyeAccumulateFragment(VertexOut in [[stage_in]],
                                      texture2d<float> prevDye [[texture(0)]],
                                      constant int& splatCount [[buffer(1)]],
                                      constant LiquidSplatUniform* splats [[buffer(2)]],
                                      constant float& decay [[buffer(3)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = in.uv;
    float4 prev = prevDye.sample(s, uv) * clamp(decay, 0.7f, 0.9999f);
    float4 add = float4(0.0f);
    int n = min(splatCount, 48);
    for (int i = 0; i < n; i++) {
        float2 cuv = float2(splats[i].uvX, splats[i].uvY);
        float d = distance(uv, cuv);
        float r = max(0.0012f, splats[i].radius);
        float g = exp(-(d * d) / (r * r));
        float3 rgb = float3(splats[i].colorR, splats[i].colorG, splats[i].colorB);
        float a = splats[i].alpha * g;
        add += float4(rgb * a, a);
    }
    return saturate(prev + add);
}

fragment float4 dyeCompositeFragment(
    VertexOut in [[stage_in]],
    texture2d<float> dye0 [[texture(0)]],
    texture2d<float> dye1 [[texture(1)]],
    texture2d<float> dye2 [[texture(2)]],
    texture2d<float> dye3 [[texture(3)]],
    texture2d<float> dye4 [[texture(4)]],
    texture2d<float> dye5 [[texture(5)]],
    texture2d<float> dye6 [[texture(6)]],
    texture2d<float> dye7 [[texture(7)]],
    constant float* metadata [[buffer(0)]]
) {
    constexpr sampler samp(coord::normalized, address::clamp_to_edge, filter::linear);
    const int layerCount = min(8, max(0, int(metadata[0])));
    if (layerCount < 1) {
        return float4(0.0f);
    }
    texture2d<float> layers[8] = { dye0, dye1, dye2, dye3, dye4, dye5, dye6, dye7 };
    float focus = clamp(metadata[9], 0.0f, 1.0f);

    float strength[8];
    float3 colors[8];
    float alph[8];
    for (int i = 0; i < 8; i++) {
        strength[i] = 0.0f;
        colors[i] = float3(0.0f);
        alph[i] = 0.0f;
    }
    for (int i = 0; i < layerCount; i++) {
        float4 L = layers[i].sample(samp, in.uv);
        float vis = clamp(metadata[1 + i], 0.0f, 1.0f);
        // s_i ≈ pow(a, exp(viscosity)) — higher viscosity → sharper competition between layers.
        float boosted = pow(saturate(L.a), mix(0.85f, 1.4f, vis));
        strength[i] = boosted;
        colors[i] = L.rgb;
        alph[i] = L.a;
    }

    int best = 0;
    int second = -1;
    float sb = strength[0];
    float ss = -1.0f;
    for (int j = 1; j < layerCount; j++) {
        float st = strength[j];
        if (st > sb) {
            second = best;
            ss = sb;
            best = j;
            sb = st;
        } else if (st > ss) {
            second = j;
            ss = st;
        }
    }

    float edgeW = mix(0.16f, 0.025f, focus);
    if (second >= 0) {
        float dv = abs(metadata[1 + best] - metadata[1 + second]);
        edgeW *= mix(0.88f, 1.12f, saturate(dv));
    }
    float gap = sb - max(ss, 0.0f);
    float t = smoothstep(0.0f, max(1e-4f, edgeW), gap);
    // Dominant layer supplies RGB; meniscus is carried by alpha (and smoothstep on strength gap).
    float3 outRgb = colors[best];
    float outA = alph[best];
    if (second >= 0) {
        outA = mix(alph[second], alph[best], t);
    }
    return float4(outRgb, saturate(outA));
}
