// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#include "frame_converter.h"

#include <d3d11_4.h>

#include <cstdint>
#include <stdexcept>
#include <string>

#include "frame_shaders_data.h"

namespace bangumi::inference {
namespace {

constexpr DXGI_FORMAT kRgbFormat = DXGI_FORMAT_R16_FLOAT;

// Mirrors the cbuffer in shaders/frame_shaders.hlsl.
struct FrameShaderParams {
  uint32_t visible_width;
  uint32_t visible_height;
  uint32_t model_width;
  uint32_t model_height;
  uint32_t ten_bit_container;
  uint32_t padding0;
  uint32_t padding1;
  uint32_t padding2;
  float max_code;
  float y_offset;
  float y_scale;
  float c_offset;
  float c_scale;
  float kr;
  float kg;
  float kb;
  float chroma_x_offset;
  float chroma_y_offset;
  float padding3;
  float padding4;
};
static_assert(sizeof(FrameShaderParams) == 80, "Unexpected shader constants");

uint32_t Groups(uint32_t extent) { return (extent + 7) / 8; }

void Check(HRESULT result, const char* operation) {
  if (FAILED(result)) {
    throw std::runtime_error(std::string(operation) + ": HRESULT=" +
                             std::to_string(static_cast<uint32_t>(result)));
  }
}

bool SupportsTypedUav(ID3D11Device* device, DXGI_FORMAT format) {
  UINT support = 0;
  if (FAILED(device->CheckFormatSupport(format, &support))) return false;
  return (support & D3D11_FORMAT_SUPPORT_TYPED_UNORDERED_ACCESS_VIEW) != 0;
}

Microsoft::WRL::ComPtr<ID3D11Texture2D> CreateTexture(
    ID3D11Device* device, uint32_t width, uint32_t height, DXGI_FORMAT format,
    UINT bind_flags, bool shared = true) {
  D3D11_TEXTURE2D_DESC description{};
  description.Width = width;
  description.Height = height;
  description.MipLevels = 1;
  description.ArraySize = 1;
  description.Format = format;
  description.SampleDesc.Count = 1;
  description.Usage = D3D11_USAGE_DEFAULT;
  description.BindFlags = bind_flags;
  if (shared)
    description.MiscFlags =
        D3D11_RESOURCE_MISC_SHARED | D3D11_RESOURCE_MISC_SHARED_NTHANDLE;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
  Check(device->CreateTexture2D(&description, nullptr, &texture),
        "Create a conversion texture");
  return texture;
}

Microsoft::WRL::ComPtr<ID3D11ComputeShader> CreateShader(
    ID3D11Device* device, const EmbeddedShader& shader) {
  Microsoft::WRL::ComPtr<ID3D11ComputeShader> result;
  Check(device->CreateComputeShader(shader.data, shader.size, nullptr, &result),
        "Create a frame conversion shader");
  return result;
}

}  // namespace

struct FrameConverter::State {
  Microsoft::WRL::ComPtr<ID3D11Device> device;
  Microsoft::WRL::ComPtr<ID3D11ComputeShader> yuv_to_rgb;
  Microsoft::WRL::ComPtr<ID3D11ComputeShader> rgb_to_yuv;
  Microsoft::WRL::ComPtr<ID3D11Buffer> constants;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> planar_rgb;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> model_output_rgb;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> out_luma;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> out_chroma;
  Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> planar_rgb_uav;
  Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> out_luma_uav;
  Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> out_chroma_uav;
  Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> model_output_srv;
  FrameShaderParams params{};
  FramePlan plan;
};

std::unique_ptr<FrameConverter> FrameConverter::Create(
    ID3D11Device* device, const FramePlan& plan, const ColorConversion& color,
    std::string* reason, bool share_model_textures) {
  auto report = [reason](const char* message) {
    if (reason) *reason = message;
    return nullptr;
  };
  if (!device) throw std::invalid_argument("Missing device for the converter");
  const DXGI_FORMAT luma_format =
      color.ten_bit_output ? DXGI_FORMAT_R16_UNORM : DXGI_FORMAT_R8_UNORM;
  const DXGI_FORMAT chroma_format = color.ten_bit_output
                                        ? DXGI_FORMAT_R16G16_UNORM
                                        : DXGI_FORMAT_R8G8_UNORM;
  if (!SupportsTypedUav(device, luma_format) ||
      !SupportsTypedUav(device, chroma_format)) {
    return report("This GPU cannot store the upscaled frames");
  }

  auto converter = std::unique_ptr<FrameConverter>(new FrameConverter());
  converter->state_ = std::make_unique<State>();
  auto& state = *converter->state_;
  state.device = device;
  state.plan = plan;
  state.yuv_to_rgb = CreateShader(device, kFrameShaderYuvToPlanarRgb);
  state.rgb_to_yuv = CreateShader(device, kFrameShaderPlanarRgbToYuv);

  state.planar_rgb = CreateTexture(
      device, plan.model_width, plan.model_height * 3, kRgbFormat,
      D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE,
      share_model_textures);
  state.model_output_rgb = CreateTexture(
      device, plan.model_output_width, plan.model_output_height * 3, kRgbFormat,
      D3D11_BIND_SHADER_RESOURCE, share_model_textures);
  state.out_luma = CreateTexture(
      device, plan.visible_width * 2, plan.visible_height * 2, luma_format,
      D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE);
  state.out_chroma = CreateTexture(
      device, plan.visible_width, plan.visible_height, chroma_format,
      D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE);

  D3D11_UNORDERED_ACCESS_VIEW_DESC uav_description{};
  uav_description.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2D;
  uav_description.Format = kRgbFormat;
  Check(device->CreateUnorderedAccessView(state.planar_rgb.Get(),
                                          &uav_description,
                                          &state.planar_rgb_uav),
        "Create the planar RGB UAV");
  uav_description.Format = luma_format;
  Check(device->CreateUnorderedAccessView(state.out_luma.Get(),
                                          &uav_description,
                                          &state.out_luma_uav),
        "Create the luma output UAV");
  uav_description.Format = chroma_format;
  Check(device->CreateUnorderedAccessView(state.out_chroma.Get(),
                                          &uav_description,
                                          &state.out_chroma_uav),
        "Create the chroma output UAV");
  D3D11_SHADER_RESOURCE_VIEW_DESC srv_description{};
  srv_description.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
  srv_description.Format = kRgbFormat;
  srv_description.Texture2D.MipLevels = 1;
  Check(device->CreateShaderResourceView(state.model_output_rgb.Get(),
                                         &srv_description,
                                         &state.model_output_srv),
        "Create the model output view");

  state.params.visible_width = plan.visible_width;
  state.params.visible_height = plan.visible_height;
  state.params.model_width = plan.model_width;
  state.params.model_height = plan.model_height;
  state.params.ten_bit_container = color.ten_bit_output ? 1u : 0u;
  state.params.max_code = color.max_code;
  state.params.y_offset = color.y_offset;
  state.params.y_scale = color.y_scale;
  state.params.c_offset = color.c_offset;
  state.params.c_scale = color.c_scale;
  state.params.kr = color.kr;
  state.params.kg = color.kg;
  state.params.kb = color.kb;
  state.params.chroma_x_offset = color.chroma_x_offset;
  state.params.chroma_y_offset = color.chroma_y_offset;
  // Geometry and colour constants never change during this converter's
  // lifetime. Upload them once instead of mapping twice on every frame.
  D3D11_BUFFER_DESC buffer_description{};
  buffer_description.ByteWidth = sizeof(FrameShaderParams);
  buffer_description.Usage = D3D11_USAGE_IMMUTABLE;
  buffer_description.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
  D3D11_SUBRESOURCE_DATA initial_data{};
  initial_data.pSysMem = &state.params;
  Check(device->CreateBuffer(&buffer_description, &initial_data,
                            &state.constants),
        "Create the conversion constant buffer");
  return converter;
}

FrameConverter::~FrameConverter() = default;

ID3D11Texture2D* FrameConverter::planar_rgb() const {
  return state_->planar_rgb.Get();
}
ID3D11Texture2D* FrameConverter::model_output_rgb() const {
  return state_->model_output_rgb.Get();
}
ID3D11Texture2D* FrameConverter::out_luma() const {
  return state_->out_luma.Get();
}
ID3D11Texture2D* FrameConverter::out_chroma() const {
  return state_->out_chroma.Get();
}

void FrameConverter::ConvertToPlanarRgb(ID3D11DeviceContext* context,
                                        ID3D11ShaderResourceView* luma,
                                        ID3D11ShaderResourceView* chroma) {
  if (!context || !luma || !chroma)
    throw std::invalid_argument("Missing conversion inputs");
  auto& state = *state_;
  ID3D11ShaderResourceView* views[] = {luma, chroma};
  ID3D11UnorderedAccessView* uavs[] = {state.planar_rgb_uav.Get()};
  ID3D11Buffer* buffers[] = {state.constants.Get()};
  context->CSSetShader(state.yuv_to_rgb.Get(), nullptr, 0);
  context->CSSetConstantBuffers(0, 1, buffers);
  context->CSSetShaderResources(0, 2, views);
  context->CSSetUnorderedAccessViews(0, 1, uavs, nullptr);
  context->Dispatch(Groups(state.plan.model_width),
                    Groups(state.plan.model_height), 1);
  ID3D11ShaderResourceView* no_views[] = {nullptr, nullptr};
  ID3D11UnorderedAccessView* no_uavs[] = {nullptr};
  context->CSSetShaderResources(0, 2, no_views);
  context->CSSetUnorderedAccessViews(0, 1, no_uavs, nullptr);
  context->CSSetShader(nullptr, nullptr, 0);
}

void FrameConverter::ConvertFromPlanarRgb(ID3D11DeviceContext* context) {
  if (!context) throw std::invalid_argument("Missing conversion context");
  auto& state = *state_;
  ID3D11ShaderResourceView* views[] = {state.model_output_srv.Get()};
  ID3D11Buffer* buffers[] = {state.constants.Get()};
  context->CSSetConstantBuffers(0, 1, buffers);

  ID3D11UnorderedAccessView* uavs[] = {state.out_luma_uav.Get(),
                                    state.out_chroma_uav.Get()};
  context->CSSetShader(state.rgb_to_yuv.Get(), nullptr, 0);
  context->CSSetShaderResources(0, 1, views);
  context->CSSetUnorderedAccessViews(0, 2, uavs, nullptr);
  context->Dispatch(Groups(state.plan.visible_width),
                    Groups(state.plan.visible_height), 1);

  ID3D11ShaderResourceView* no_views[] = {nullptr};
  ID3D11UnorderedAccessView* no_uavs[] = {nullptr, nullptr};
  context->CSSetShaderResources(0, 1, no_views);
  context->CSSetUnorderedAccessViews(0, 2, no_uavs, nullptr);
  context->CSSetShader(nullptr, nullptr, 0);
}

}  // namespace bangumi::inference
