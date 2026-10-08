// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
//
// GPU frame conversion for the AnimeJaNai bridge. The shaders are compiled to
// DXBC at build time (see cmake/embed_frame_shaders.cmake) and used by D3D11
// only; the D3D12 side never runs a shader, it copies between the shared
// textures below and the DirectML tensors.
//
// Stage 1 (`YuvToPlanarRgb`): decoder plane views -> planar FP16 RGB stored in
// a texture of (model_width, 3 * model_height), where row block p holds
// channel p. Stage 2 (`PlanarRgbToYuv`): the model's 2x output, stacked the
// same way in (2 * model_width, 6 * model_height), -> limited-range luma and
// 4:2:0 chroma planes at the visible output size.
//
// Row pitches are kept 256-byte aligned by the model width padding so the
// D3D12 placed-footprint copies are aligned on every vendor.

cbuffer FrameParams : register(b0)
{
    uint g_visible_width;
    uint g_visible_height;
    uint g_model_width;
    uint g_model_height;
    uint g_ten_bit_container;  // 1: P010-style R16/R16G16 planes in and out
    uint g_padding0;
    uint g_padding1;
    uint g_padding2;
    float g_max_code;       // 255 or 65535: raw code multiplier for sampling
    float g_y_offset;
    float g_y_scale;
    float g_c_offset;
    float g_c_scale;
    float g_kr;
    float g_kg;
    float g_kb;
    float g_chroma_x_offset;  // luma sample units
    float g_chroma_y_offset;
    float g_padding3;
    float g_padding4;
};

Texture2D<float> g_luma : register(t0);
Texture2D<float2> g_chroma : register(t1);
RWTexture2D<float> g_planar_rgb : register(u0);
Texture2D<float> g_model_rgb : register(t0);
RWTexture2D<float> g_luma_out : register(u0);
RWTexture2D<float2> g_chroma_out : register(u1);

// Round half away from zero, matching the CPU reference exactly. Quantisation
// ties are practically unreachable in 8/10-bit code space, but both sides must
// agree on the rule.
float RoundHalfUp(float value) { return floor(value + 0.5f); }

// Catmull-Rom weights for taps at -1, 0, 1, 2 around floor(position).
void CubicWeights(float fraction, out float4 weights)
{
    const float t = fraction;
    const float t2 = t * t;
    const float t3 = t2 * t;
    weights.x = 0.5f * (-t3 + 2.0f * t2 - t);
    weights.y = 0.5f * (3.0f * t3 - 5.0f * t2 + 2.0f);
    weights.z = 0.5f * (-3.0f * t3 + 4.0f * t2 + t);
    weights.w = 0.5f * (t3 - t2);
}

// Separable cubic chroma interpolation at the sample location described by the
// frame's chroma offsets, with edge replication outside the coded texture.
float2 SampleChroma(int2 position)
{
    uint chroma_width = 0;
    uint chroma_height = 0;
    g_chroma.GetDimensions(chroma_width, chroma_height);
    const float x = (float(position.x) - g_chroma_x_offset) * 0.5f;
    const float y = (float(position.y) - g_chroma_y_offset) * 0.5f;
    const float base_x = floor(x);
    const float base_y = floor(y);
    float4 weights_x = 0;
    float4 weights_y = 0;
    CubicWeights(x - base_x, weights_x);
    CubicWeights(y - base_y, weights_y);
    const int2 origin = int2(base_x, base_y) - 1;
    float2 result = 0;
    [unroll] for (int row = 0; row < 4; ++row)
    {
        const int sample_y = clamp(origin.y + row, 0, (int)chroma_height - 1);
        [unroll] for (int column = 0; column < 4; ++column)
        {
            const int sample_x = clamp(origin.x + column, 0, (int)chroma_width - 1);
            result += g_chroma.Load(int3(sample_x, sample_y, 0)).rg *
                      (weights_x[column] * weights_y[row]);
        }
    }
    return result;
}

float3 PlanarRgbAt(uint2 position)
{
    uint width = 0;
    uint height = 0;
    g_model_rgb.GetDimensions(width, height);
    const uint plane_height = height / 3;
    return float3(g_model_rgb.Load(int3(position.x, position.y, 0)).r,
                  g_model_rgb.Load(int3(position.x, position.y + plane_height, 0)).r,
                  g_model_rgb.Load(int3(position.x, position.y + 2 * plane_height, 0)).r);
}

float Luma(float3 rgb) { return g_kr * rgb.r + g_kg * rgb.g + g_kb * rgb.b; }

// Stores a limited-range code into an 8-bit UNORM or P010 container. The
// output constants are the usual limited-range definitions (10-bit values are
// the 8-bit ones scaled by four: 64/876 and 512/896).
float StoreLuma(float normalized)
{
    if (g_ten_bit_container)
    {
        const float code = clamp(RoundHalfUp(normalized * 876.0f + 64.0f), 0.0f, 1023.0f);
        return (code * 64.0f) / 65535.0f;
    }
    const float code = clamp(RoundHalfUp(normalized * 219.0f + 16.0f), 0.0f, 255.0f);
    return code / 255.0f;
}

float StoreChroma(float normalized)
{
    if (g_ten_bit_container)
    {
        const float code = clamp(RoundHalfUp(normalized * 896.0f + 512.0f), 0.0f, 1023.0f);
        return (code * 64.0f) / 65535.0f;
    }
    const float code = clamp(RoundHalfUp(normalized * 224.0f + 128.0f), 0.0f, 255.0f);
    return code / 255.0f;
}

[numthreads(8, 8, 1)]
void YuvToPlanarRgb(uint3 id : SV_DispatchThreadID)
{
    if (id.x >= g_model_width || id.y >= g_model_height)
        return;
    // Padding replicates the last visible sample so the model never sees a
    // hard edge at the padded border.
    const int x = min((int)id.x, (int)g_visible_width - 1);
    const int y = min((int)id.y, (int)g_visible_height - 1);
    const float luma_raw = g_luma.Load(int3(x, y, 0)).r * g_max_code;
    const float luminance = (luma_raw - g_y_offset) / g_y_scale;
    const float2 chroma_raw = SampleChroma(int2(x, y)) * g_max_code;
    const float cb = (chroma_raw.x - g_c_offset) / g_c_scale;
    const float cr = (chroma_raw.y - g_c_offset) / g_c_scale;
    const float red = luminance + 2.0f * (1.0f - g_kr) * cr;
    const float blue = luminance + 2.0f * (1.0f - g_kb) * cb;
    const float green = luminance -
                        (2.0f * g_kb * (1.0f - g_kb) * cb + 2.0f * g_kr * (1.0f - g_kr) * cr) / g_kg;
    const float3 rgb = saturate(float3(red, green, blue));
    g_planar_rgb[uint2(id.x, id.y)] = rgb.r;
    g_planar_rgb[uint2(id.x, id.y + g_model_height)] = rgb.g;
    g_planar_rgb[uint2(id.x, id.y + 2 * g_model_height)] = rgb.b;
}

[numthreads(8, 8, 1)]
void PlanarRgbToYuv(uint3 id : SV_DispatchThreadID)
{
    if (id.x >= g_visible_width || id.y >= g_visible_height)
        return;
    // Each thread reads one 2x2 quad once, writes its four luma samples and
    // reuses those RGB values for the same box-filtered chroma sample.
    const uint2 origin = id.xy * 2;
    const float3 rgb00 = PlanarRgbAt(origin);
    const float3 rgb10 = PlanarRgbAt(origin + uint2(1, 0));
    const float3 rgb01 = PlanarRgbAt(origin + uint2(0, 1));
    const float3 rgb11 = PlanarRgbAt(origin + uint2(1, 1));
    g_luma_out[origin] = StoreLuma(Luma(rgb00));
    g_luma_out[origin + uint2(1, 0)] = StoreLuma(Luma(rgb10));
    g_luma_out[origin + uint2(0, 1)] = StoreLuma(Luma(rgb01));
    g_luma_out[origin + uint2(1, 1)] = StoreLuma(Luma(rgb11));
    const float3 rgb = (rgb00 + rgb10 + rgb01 + rgb11) * 0.25f;
    const float luminance = Luma(rgb);
    const float cb = (rgb.b - luminance) / (2.0f * (1.0f - g_kb));
    const float cr = (rgb.r - luminance) / (2.0f * (1.0f - g_kr));
    g_chroma_out[id.xy] = float2(StoreChroma(cb), StoreChroma(cr));
}
