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
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    const int layerCount = min(8, max(0, int(metadata[0])));
    float4 acc = float4(0.0f);
    texture2d<float> layers[8] = { dye0, dye1, dye2, dye3, dye4, dye5, dye6, dye7 };
    for (int i = 0; i < layerCount; i++) {
        float4 layer = layers[i].sample(s, in.uv);
        float w = metadata[i + 1];
        float a = saturate(layer.a * w);
        acc.rgb = mix(acc.rgb, layer.rgb, a);
        acc.a = saturate(acc.a + a * (1.0f - acc.a));
    }
    return acc;
}
