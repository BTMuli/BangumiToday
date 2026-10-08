// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#include "frame_pipeline.h"

#include <d3d11_4.h>
#include <d3d12.h>
#include <dxgi1_4.h>

#include <chrono>
#include <stdexcept>
#include <string>
#include <unordered_map>

#include "dml_session.h"
#include "frame_converter.h"
#include "interop.h"
#include "gpu_capabilities.h"
#include "trt_session.h"

namespace bangumi::inference {
namespace {

using Microsoft::WRL::ComPtr;
using Clock = std::chrono::steady_clock;

class ScopedContextLock final {
 public:
  explicit ScopedContextLock(ID3D11Multithread* multithread)
      : multithread_(multithread) {
    multithread_->Enter();
  }
  ~ScopedContextLock() { multithread_->Leave(); }
  ScopedContextLock(const ScopedContextLock&) = delete;
  ScopedContextLock& operator=(const ScopedContextLock&) = delete;

 private:
  ID3D11Multithread* multithread_;
};

double Milliseconds(Clock::time_point from, Clock::time_point to) {
  return std::chrono::duration<double, std::milli>(to - from).count();
}

void Check(HRESULT result, const char* operation) {
  if (FAILED(result)) {
    throw std::runtime_error(std::string(operation) + ": HRESULT=" +
                             std::to_string(static_cast<uint32_t>(result)));
  }
}

ComPtr<ID3D12Resource> OpenSharedTexture(ID3D11Texture2D* texture,
                                         ID3D12Device* device) {
  ComPtr<IDXGIResource1> resource;
  Check(texture->QueryInterface(IID_PPV_ARGS(&resource)),
        "Shared texture resource");
  HANDLE handle = nullptr;
  Check(resource->CreateSharedHandle(
            nullptr, DXGI_SHARED_RESOURCE_READ | DXGI_SHARED_RESOURCE_WRITE,
            nullptr, &handle),
        "Share a conversion texture");
  ComPtr<ID3D12Resource> opened;
  const HRESULT result =
      device->OpenSharedHandle(handle, IID_PPV_ARGS(&opened));
  CloseHandle(handle);
  Check(result, "Open a conversion texture on D3D12");
  return opened;
}

ComPtr<ID3D11Texture2D> CreateOutputFrame(ID3D11Device* device,
                                          DXGI_FORMAT format, uint32_t width,
                                          uint32_t height) {
  D3D11_TEXTURE2D_DESC description{};
  description.Width = width;
  description.Height = height;
  description.MipLevels = 1;
  description.ArraySize = 1;
  description.Format = format;
  description.SampleDesc.Count = 1;
  description.Usage = D3D11_USAGE_DEFAULT;
  // The renderer both samples and reuses these frames; D3D12 only copies into
  // their plane subresources, which needs no unordered-access flag.
  description.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
  description.MiscFlags =
      D3D11_RESOURCE_MISC_SHARED | D3D11_RESOURCE_MISC_SHARED_NTHANDLE;
  ComPtr<ID3D11Texture2D> texture;
  Check(device->CreateTexture2D(&description, nullptr, &texture),
        "Create the upscaled output frame");
  return texture;
}

D3D12_TEXTURE_COPY_LOCATION Subresource(ID3D12Resource* resource, UINT index) {
  D3D12_TEXTURE_COPY_LOCATION location{};
  location.pResource = resource;
  location.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
  location.SubresourceIndex = index;
  return location;
}

D3D12_TEXTURE_COPY_LOCATION Footprint(ID3D12Resource* resource,
                                      DXGI_FORMAT format, uint32_t width,
                                      uint32_t height, uint32_t row_pitch) {
  D3D12_TEXTURE_COPY_LOCATION location{};
  location.pResource = resource;
  location.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
  location.PlacedFootprint.Offset = 0;
  location.PlacedFootprint.Footprint.Format = format;
  location.PlacedFootprint.Footprint.Width = width;
  location.PlacedFootprint.Footprint.Height = height;
  location.PlacedFootprint.Footprint.Depth = 1;
  location.PlacedFootprint.Footprint.RowPitch = row_pitch;
  return location;
}

}  // namespace

struct FramePipeline::State {
  // Declared first so the session and converter are released before the
  // D3D12 device and fence they borrow.
  std::unique_ptr<InteropContext> interop;
  std::unique_ptr<DmlSession> session;
  std::unique_ptr<TrtSession> trt_session;
  std::unique_ptr<FrameConverter> converter;
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext4> context4;
  ComPtr<ID3D11Multithread> multithread;
  ID3D11DeviceContext* context4_source = nullptr;
  ComPtr<ID3D11Texture2D> output;
  ComPtr<ID3D12Resource> planar_rgb;
  ComPtr<ID3D12Resource> model_output_rgb;
  ComPtr<ID3D12Resource> out_luma;
  ComPtr<ID3D12Resource> out_chroma;
  ComPtr<ID3D12Resource> output_d3d12;
  // Frames handed in by the caller (mpv's hw frame pool) are opened once and
  // kept in the copy-target state; the pool rotates through a few textures.
  struct ExternalFrame {
    ComPtr<ID3D11Texture2D> texture;
    ComPtr<ID3D12Resource> resource;
  };
  std::vector<ExternalFrame> external_frames;
  FramePlan plan;
  FrameDescription frame;
  // D3D12-only state tracking for the textures we own on both APIs. D3D11 does
  // not participate in D3D12 state tracking, so the fences above carry the
  // cross-API ordering.
  std::unordered_map<ID3D12Resource*, D3D12_RESOURCE_STATES> states;
  uint64_t previous_ticket = 0;
  uint64_t frames = 0;
  Timing timing;
  FrameBudgetMonitor budget;
  Clock::time_point measured_at;
  // Deferred GPU measurement: the last frame whose timestamps were resolved.
  struct Measurement {
    uint32_t buffer = 0;
    uint64_t ticket = 0;
    bool pending = false;
  } measurement;

  void Transition(ID3D12GraphicsCommandList* list, ID3D12Resource* resource,
                  D3D12_RESOURCE_STATES target) {
    D3D12_RESOURCE_STATES& known = states[resource];
    if (known == target) return;
    D3D12_RESOURCE_BARRIER barrier{};
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = resource;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barrier.Transition.StateBefore = known;
    barrier.Transition.StateAfter = target;
    list->ResourceBarrier(1, &barrier);
    known = target;
  }
};

std::unique_ptr<FramePipeline> FramePipeline::Create(
    ID3D11Device* playback_device, const Config& config, std::string* reason) {
  auto report = [reason](const std::string& message) {
    if (reason) *reason = message;
    return nullptr;
  };
  if (!playback_device)
    throw std::invalid_argument("Missing playback device for JaNai");
  if (config.require_tensorrt &&
      (!config.trt_resources || config.trt_engine.empty())) {
    return report("AI 实时超分需要 NVIDIA 显卡和已配置的 TensorRT");
  }
  const std::string validation = ValidateFrameDescription(config.frame);
  if (!validation.empty()) return report(validation);
  FramePlan plan;
  ColorConversion color;
  try {
    plan = MakeFramePlan(config.frame);
    color = MakeColorConversion(config.frame);
  } catch (const std::exception& error) {
    return report(error.what());
  }

  auto pipeline = std::unique_ptr<FramePipeline>(new FramePipeline());
  pipeline->state_ = std::make_unique<State>();
  auto& state = *pipeline->state_;
  state.plan = plan;
  state.frame = config.frame;
  state.device = playback_device;
  state.interop = InteropContext::Create(playback_device);

  std::string converter_reason;
  state.converter =
      FrameConverter::Create(playback_device, plan, color, &converter_reason);
  if (!state.converter) return report(converter_reason);

  const DXGI_FORMAT output_format = config.frame.format == PixelFormat::kP010
                                        ? DXGI_FORMAT_P010
                                        : DXGI_FORMAT_NV12;
  state.output =
      CreateOutputFrame(playback_device, output_format, plan.visible_width * 2,
                        plan.visible_height * 2);
  state.planar_rgb =
      OpenSharedTexture(state.converter->planar_rgb(), state.interop->device());
  state.model_output_rgb = OpenSharedTexture(
      state.converter->model_output_rgb(), state.interop->device());
  state.out_luma =
      OpenSharedTexture(state.converter->out_luma(), state.interop->device());
  state.out_chroma =
      OpenSharedTexture(state.converter->out_chroma(), state.interop->device());
  state.output_d3d12 =
      OpenSharedTexture(state.output.Get(), state.interop->device());

  try {
    if (config.trt_resources && !config.trt_engine.empty()) {
      state.trt_session = std::make_unique<TrtSession>(config.trt_resources,
          config.trt_engine, QueryGpuCapabilities(playback_device),
          plan.model_width, plan.model_height);
      state.trt_session->Attach(state.converter->planar_rgb(),
                                 state.converter->model_output_rgb());
    } else {
      DmlSession::Options session_options;
      session_options.placement_profile = config.placement_profile;
      session_options.log_severity = config.log_severity;
      state.session = std::make_unique<DmlSession>(
          *state.interop, config.runtime_directory, config.model,
          plan.model_width, plan.model_height, session_options);
    }
  } catch (const std::exception& error) {
    return report(std::string("The upscaling model could not be prepared: ") +
                  error.what());
  }
  return pipeline;
}

FramePipeline::~FramePipeline() {
  if (!state_) return;
  const uint64_t ticket = state_->previous_ticket;
  if (!ticket) return;
  try {
    if (state_->interop->Complete(ticket)) return;
    // Retire the last frame so shared textures are not released while the GPU
    // still reads them. A hung or removed device is handled by the D3D12
    // runtime, which defers destruction until the work finishes.
    state_->interop->Wait(ticket, 5000);
  } catch (...) {
  }
}

ID3D11Texture2D* FramePipeline::output_texture() const {
  return state_->output.Get();
}

ID3D11Texture2D* FramePipeline::model_input_texture() const {
  return state_->converter->planar_rgb();
}

ID3D11Texture2D* FramePipeline::model_output_texture() const {
  return state_->converter->model_output_rgb();
}

ID3D12Device* FramePipeline::diagnostics_device() const {
  return state_->interop->device();
}

const FramePlan& FramePipeline::plan() const { return state_->plan; }

bool FramePipeline::Complete(uint64_t ticket) const {
  return state_->interop->Complete(ticket);
}

void FramePipeline::Wait(uint64_t ticket, uint32_t timeout_ms) const {
  state_->interop->Wait(ticket, timeout_ms);
}

FramePipeline::Timing FramePipeline::last_timing() const {
  return state_->timing;
}

uint64_t FramePipeline::submitted_frames() const { return state_->frames; }

void FramePipeline::ConfigureFrameRate(double frames_per_second) {
  state_->budget.Configure(frames_per_second);
}

void FramePipeline::ReportDropRate(double percent) {
  state_->budget.ReportDropRate(percent);
}

FrameBudgetMonitor::Snapshot FramePipeline::performance() const {
  return state_->budget.snapshot();
}

bool FramePipeline::fallback_recommended() const {
  return state_->budget.snapshot().fallback_recommended;
}
bool FramePipeline::uses_tensorrt() const { return state_->trt_session != nullptr; }

std::filesystem::path FramePipeline::EndPlacementProfiling() {
  return state_->session ? state_->session->EndPlacementProfiling()
                          : std::filesystem::path();
}

uint64_t FramePipeline::Submit(ID3D11DeviceContext* context,
                               ID3D11ShaderResourceView* luma,
                               ID3D11ShaderResourceView* chroma,
                               ID3D11Texture2D* output) {
  if (!context || !luma || !chroma)
    throw std::invalid_argument("Missing decoded frame planes");
  auto& state = *state_;
  auto& plan = state.plan;
  if (state.context4_source != context) {
    // The shared fence needs the ID3D11DeviceContext4 signal/wait entry points.
    ComPtr<ID3D11DeviceContext4> context4;
    Check(context->QueryInterface(IID_PPV_ARGS(&context4)),
          "ID3D11DeviceContext4 is required for the JaNai bridge");
    ComPtr<ID3D11Multithread> multithread;
    Check(context->QueryInterface(IID_PPV_ARGS(&multithread)),
          "ID3D11Multithread is required for the JaNai bridge");
    multithread->SetMultithreadProtected(TRUE);
    state.context4 = context4;
    state.multithread = multithread;
    state.context4_source = context;
  }

  // Retire an earlier GPU measurement when its fence completed. This is what
  // feeds the performance gate; it never blocks.
  if (state.measurement.pending) {
    std::vector<uint64_t> ticks;
    if (state.interop->ReadTimestamps(state.measurement.ticket,
                                      state.measurement.buffer, 4, &ticks)) {
      state.measurement.pending = false;
      state.timing.gpu_input_copy_ms =
          state.interop->MillisecondsBetween(ticks[0], ticks[1]);
      state.timing.gpu_inference_ms =
          state.interop->MillisecondsBetween(ticks[1], ticks[2]);
      state.timing.gpu_output_copy_ms =
          state.interop->MillisecondsBetween(ticks[2], ticks[3]);
      state.timing.gpu_total_ms =
          state.interop->MillisecondsBetween(ticks[0], ticks[3]);
      if (state.trt_session) {
        state.timing.gpu_inference_ms = state.trt_session->last_gpu_ms();
        state.timing.gpu_total_ms += state.timing.gpu_inference_ms;
      }
      state.timing.gpu_measured = state.timing.gpu_total_ms > 0.0;
      const Clock::time_point now = Clock::now();
      if (state.measured_at != Clock::time_point{}) {
        const double wall_ms = Milliseconds(state.measured_at, now);
        if (wall_ms > 0.0)
          state.budget.AddFrame(state.timing.gpu_total_ms, wall_ms);
      }
      state.measured_at = now;
    }
  }

  bool measuring = state.interop->timestamps_supported();
  const uint32_t measurement_buffer =
      static_cast<uint32_t>(state.frames % InteropContext::kTimestampBuffers);
  if (measuring && state.measurement.pending &&
      state.measurement.buffer == measurement_buffer) {
    // The ring slot is still owned by an unfinished measurement; skip this
    // frame's GPU timing instead of overwriting it.
    measuring = false;
  }
  const uint32_t measurement_base = measuring ? measurement_buffer * 4 : 0;

  // Resolve the copy target: the pipeline's own frame unless the caller
  // supplied one from its own pool.
  ID3D12Resource* target = state.output_d3d12.Get();
  if (output && output != state.output.Get()) {
    State::ExternalFrame* frame = nullptr;
    for (auto& candidate : state.external_frames) {
      if (candidate.texture.Get() == output) {
        frame = &candidate;
        break;
      }
    }
    if (!frame) {
      D3D11_TEXTURE2D_DESC description{};
      output->GetDesc(&description);
      const DXGI_FORMAT expected = state.frame.format == PixelFormat::kP010
                                       ? DXGI_FORMAT_P010
                                       : DXGI_FORMAT_NV12;
      if (description.Format != expected ||
          description.Width != plan.visible_width * 2 ||
          description.Height != plan.visible_height * 2 ||
          (description.MiscFlags & D3D11_RESOURCE_MISC_SHARED_NTHANDLE) == 0) {
        throw std::invalid_argument(
            "The supplied output frame does not match the planned NV12/P010 "
            "frame");
      }
      state.external_frames.emplace_back();
      State::ExternalFrame& created = state.external_frames.back();
      created.texture = output;
      created.resource = OpenSharedTexture(output, state.interop->device());
      frame = &created;
    }
    target = frame->resource.Get();
  }

  const Clock::time_point start = Clock::now();

  // ANGLE, the decoder and CUDA graphics interop use this same immediate
  // context. Per-call protection does not keep shader/view bindings together
  // with their dispatch, or protect CUDA's internal context access. Hold the
  // device's shared critical section through the complete graphics hand-off;
  // a private pipeline mutex would not synchronize with the other users.
  const ScopedContextLock context_lock(state.multithread.Get());

  // Depth one: the previous frame's copies are finished before its shared
  // textures are rewritten. This is a GPU-side wait, so the caller never
  // blocks on inference.
  if (state.previous_ticket)
    state.interop->WaitOnD3D11(state.context4.Get(), state.previous_ticket);

  state.converter->ConvertToPlanarRgb(context, luma, chroma);
  const uint64_t input_ready =
      state.interop->SignalFromD3D11(state.context4.Get());
  context->Flush();
  const Clock::time_point after_input = Clock::now();

  if (state.trt_session) {
    state.trt_session->Run(context);
  } else {
    state.interop->Submit(input_ready, [&](ID3D12GraphicsCommandList* list) {
      if (measuring) state.interop->WriteTimestamp(list, measurement_base);
      state.Transition(list, state.planar_rgb.Get(),
                       D3D12_RESOURCE_STATE_COPY_SOURCE);
      state.Transition(list, state.session->input(),
                       D3D12_RESOURCE_STATE_COPY_DEST);
      D3D12_TEXTURE_COPY_LOCATION source =
          Subresource(state.planar_rgb.Get(), 0);
      D3D12_TEXTURE_COPY_LOCATION destination = Footprint(
          state.session->input(), DXGI_FORMAT_R16_FLOAT, plan.model_width,
          plan.model_height * 3, plan.model_width * 2);
      list->CopyTextureRegion(&destination, 0, 0, 0, &source, nullptr);
      // DirectML expects the tensors in the common state.
      state.Transition(list, state.session->input(),
                       D3D12_RESOURCE_STATE_COMMON);
      if (measuring) state.interop->WriteTimestamp(list, measurement_base + 1);
    });

    const uint64_t inference_done = state.session->Run();

    const uint64_t model_output_ready = state.interop->Submit(
        inference_done, [&](ID3D12GraphicsCommandList* list) {
          if (measuring)
            state.interop->WriteTimestamp(list, measurement_base + 2);
          state.Transition(list, state.session->output(),
                           D3D12_RESOURCE_STATE_COPY_SOURCE);
          state.Transition(list, state.model_output_rgb.Get(),
                           D3D12_RESOURCE_STATE_COPY_DEST);
          D3D12_TEXTURE_COPY_LOCATION source =
              Footprint(state.session->output(), DXGI_FORMAT_R16_FLOAT,
                        plan.model_output_width, plan.model_output_height * 3,
                        plan.model_output_width * 2);
          D3D12_TEXTURE_COPY_LOCATION destination =
              Subresource(state.model_output_rgb.Get(), 0);
          list->CopyTextureRegion(&destination, 0, 0, 0, &source, nullptr);
          state.Transition(list, state.session->output(),
                           D3D12_RESOURCE_STATE_COMMON);
        });
    state.interop->WaitOnD3D11(state.context4.Get(), model_output_ready);
  }
  const Clock::time_point after_copy_out = Clock::now();
  state.converter->ConvertFromPlanarRgb(context);
  const uint64_t planes_ready =
      state.interop->SignalFromD3D11(state.context4.Get());
  context->Flush();
  const Clock::time_point after_planes = Clock::now();

  const uint64_t ticket =
      state.interop->Submit(planes_ready, [&](ID3D12GraphicsCommandList* list) {
        if (measuring && state.trt_session) {
          // CUDA event timings cover packing/inference/unpacking. These D3D12
          // timestamps add the final YUV plane copies without pretending the
          // DirectML queue can time CUDA work.
          state.interop->WriteTimestamp(list, measurement_base);
          state.interop->WriteTimestamp(list, measurement_base + 1);
          state.interop->WriteTimestamp(list, measurement_base + 2);
        }
        state.Transition(list, state.out_luma.Get(),
                         D3D12_RESOURCE_STATE_COPY_SOURCE);
        state.Transition(list, state.out_chroma.Get(),
                         D3D12_RESOURCE_STATE_COPY_SOURCE);
        state.Transition(list, target, D3D12_RESOURCE_STATE_COPY_DEST);
        D3D12_TEXTURE_COPY_LOCATION luma_source =
            Subresource(state.out_luma.Get(), 0);
        D3D12_TEXTURE_COPY_LOCATION luma_destination = Subresource(target, 0);
        list->CopyTextureRegion(&luma_destination, 0, 0, 0, &luma_source,
                                nullptr);
        D3D12_TEXTURE_COPY_LOCATION chroma_source =
            Subresource(state.out_chroma.Get(), 0);
        D3D12_TEXTURE_COPY_LOCATION chroma_destination = Subresource(target, 1);
        list->CopyTextureRegion(&chroma_destination, 0, 0, 0, &chroma_source,
                                nullptr);
        if (measuring) {
          state.interop->WriteTimestamp(list, measurement_base + 3);
          state.interop->ResolveTimestamps(list, measurement_base, 4,
                                           measurement_buffer);
        }
      });
  const Clock::time_point end = Clock::now();

  state.previous_ticket = ticket;
  ++state.frames;
  if (measuring) {
    state.measurement.buffer = measurement_buffer;
    state.measurement.ticket = ticket;
    state.measurement.pending = true;
  }
  state.timing.to_model_input_ms = Milliseconds(start, after_input);
  state.timing.to_model_output_ms = Milliseconds(start, after_copy_out);
  state.timing.to_output_planes_ms = Milliseconds(start, after_planes);
  state.timing.to_frame_ms = Milliseconds(start, end);
  return ticket;
}

}  // namespace bangumi::inference
