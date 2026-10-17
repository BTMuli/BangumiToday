#include <d3d11_4.h>
#include <d3d12.h>
#include <dxgi1_4.h>

#include <chrono>
#include <future>
#include <iostream>
#include <thread>

#include "angle_surface_manager.h"
#include "gpu_test_support.h"

// The native GPU checks target Windows 10+ and do not link the Flutter runner.
bool Utils::IsWindows10RTMOrGreater() { return true; }

namespace {
using namespace playback_gpu_test;

ComPtr<ID3D11Device> AngleDevice(ANGLESurfaceManager& surface) {
  surface.MakeCurrent(true);
  const auto query_display = reinterpret_cast<PFNEGLQUERYDISPLAYATTRIBEXTPROC>(
      eglGetProcAddress("eglQueryDisplayAttribEXT"));
  const auto query_device = reinterpret_cast<PFNEGLQUERYDEVICEATTRIBEXTPROC>(
      eglGetProcAddress("eglQueryDeviceAttribEXT"));
  EGLAttrib egl_device = 0, native = 0;
  const bool found = query_display && query_device &&
      query_display(eglGetCurrentDisplay(), EGL_DEVICE_EXT, &egl_device) &&
      query_device(reinterpret_cast<EGLDeviceEXT>(egl_device),
                   EGL_D3D11_DEVICE_ANGLE, &native);
  surface.MakeCurrent(false);
  Require(found && native, "ANGLE D3D11 device is unavailable");
  return reinterpret_cast<ID3D11Device*>(native);
}

struct Pattern {
  GLuint program = 0, buffer = 0;
  GLint position = -1, cut = -1, flip = -1;

  explicit Pattern(ANGLESurfaceManager& surface) {
    surface.MakeCurrent(true);
    const auto compile = [](GLenum type, const char* source) {
      const auto shader = glCreateShader(type);
      glShaderSource(shader, 1, &source, nullptr);
      glCompileShader(shader);
      GLint compiled = 0;
      glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
      Require(compiled != 0, "Pattern shader compilation failed");
      return shader;
    };
    const auto vertex = compile(GL_VERTEX_SHADER,
        "attribute vec2 p; void main(){gl_Position=vec4(p,0.,1.);}");
    const auto fragment = compile(GL_FRAGMENT_SHADER,
        "precision highp float; uniform vec2 cut; uniform float flip;"
        "void main(){float r=step(cut.x,gl_FragCoord.x);"
        "float g=step(cut.y,gl_FragCoord.y);"
        "gl_FragColor=vec4(abs(r-flip),g,0.,1.);}");
    program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    glLinkProgram(program);
    glDeleteShader(vertex);
    glDeleteShader(fragment);
    GLint linked = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    Require(linked != 0, "Pattern program linking failed");
    position = glGetAttribLocation(program, "p");
    cut = glGetUniformLocation(program, "cut");
    flip = glGetUniformLocation(program, "flip");
    const float triangle[]{-1, -1, 3, -1, -1, 3};
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(triangle), triangle, GL_STATIC_DRAW);
    surface.MakeCurrent(false);
  }

  void Draw(UINT width, UINT height, bool inverted) const {
    glViewport(0, 0, width, height);
    glUseProgram(program);
    glUniform2f(cut, width * 0.5f, height * 0.5f);
    glUniform1f(flip, inverted ? 1.0f : 0.0f);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glEnableVertexAttribArray(position);
    glVertexAttribPointer(position, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glDisableVertexAttribArray(position);
  }

  void Destroy(ANGLESurfaceManager& surface) const {
    surface.MakeCurrent(true);
    glDeleteBuffers(1, &buffer);
    glDeleteProgram(program);
    surface.MakeCurrent(false);
  }
};

void CheckPattern(ID3D11Device* device, ID3D11DeviceContext* context,
                   ID3D11Texture2D* texture, bool inverted) {
  D3D11_TEXTURE2D_DESC size{};
  texture->GetDesc(&size);
  CheckPixels(device, context, texture, [size, inverted](UINT x, UINT y) {
    const bool red = ((x + 0.5f) >= size.Width * 0.5f) != inverted;
    const bool green = (y + 0.5f) >= size.Height * 0.5f;
    return 0xff000000U | (red ? 0x00ff0000U : 0) |
           (green ? 0x0000ff00U : 0);
  });
}

void CheckFrames(ANGLESurfaceManager& surface, bool inverted) {
  const auto angle_device = AngleDevice(surface);
  ComPtr<IDXGIDevice> dxgi;
  ComPtr<IDXGIAdapter> adapter;
  Check(angle_device.As(&dxgi));
  Check(dxgi->GetAdapter(&adapter));
  ComPtr<ID3D11Device> consumer;
  ComPtr<ID3D11DeviceContext> consumer_context;
  Check(D3D11CreateDevice(adapter.Get(), D3D_DRIVER_TYPE_UNKNOWN, nullptr, 0,
                          nullptr, 0, D3D11_SDK_VERSION, &consumer, nullptr,
                          &consumer_context));
  Pattern pattern(surface);
  ComPtr<ID3D11Texture2D> first;
  ComPtr<ID3D11Device> copy_device;
  ComPtr<ID3D11DeviceContext> copy_context;
  for (int frame = 0; frame < 24; ++frame) {
    const UINT width = frame % 3 == 0 ? 257 : 64;
    const UINT height = frame % 3 == 0 ? 129 : 48;
    surface.SetSize(width, height);
    const bool flip = (frame % 2 != 0) != inverted;
    surface.Draw([&] { pattern.Draw(width, height, flip); });
    surface.Read();
    const auto snapshot = surface.texture();
    snapshot->GetDevice(&copy_device);
    copy_device->GetImmediateContext(&copy_context);
#ifdef ANGLE_TEST_DISABLE_DEVICE_CREATION
    constexpr bool shared_device = false;
#else
    constexpr bool shared_device = true;
#endif
    Require((copy_device.Get() == angle_device.Get()) == shared_device,
            "Rendering and copying did not use the same device");
    try {
      CheckPattern(copy_device.Get(), copy_context.Get(), snapshot.Get(), flip);
    } catch (const std::exception& error) {
      throw std::runtime_error("Producer frame " + std::to_string(frame) +
                               ": " + error.what());
    }
    // Simulate Flutter importing the completed snapshot on an independent
    // device. Its content must already be ready without a producer-side wait.
    ComPtr<ID3D11Texture2D> imported;
    Check(consumer->OpenSharedResource(surface.handle(), IID_PPV_ARGS(&imported)));
    try {
      CheckPattern(consumer.Get(), consumer_context.Get(), imported.Get(), flip);
    } catch (const std::exception& error) {
      throw std::runtime_error("Consumer frame " + std::to_string(frame) +
                               ": " + error.what());
    }
    if (frame == 0) first = snapshot;
  }
  try {
    CheckPattern(copy_device.Get(), copy_context.Get(), first.Get(), inverted);
  } catch (const std::exception& error) {
    throw std::runtime_error(std::string("Old frame: ") + error.what());
  }
  pattern.Destroy(surface);
}

void CheckLongRender(ANGLESurfaceManager& surface) {
  const auto device = AngleDevice(surface);
  ComPtr<ID3D11DeviceContext> context;
  device->GetImmediateContext(&context);
  ComPtr<ID3D11Device5> device5;
  ComPtr<ID3D11DeviceContext4> context4;
  Check(device.As(&device5));
  Check(context.As(&context4));
  ComPtr<ID3D11Fence> fence;
  Check(device5->CreateFence(0, D3D11_FENCE_FLAG_SHARED, IID_PPV_ARGS(&fence)));
  ComPtr<IDXGIDevice> dxgi;
  ComPtr<IDXGIAdapter> adapter;
  Check(device.As(&dxgi));
  Check(dxgi->GetAdapter(&adapter));
  ComPtr<ID3D12Device> device12;
  Check(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0,
                          IID_PPV_ARGS(&device12)));
  HANDLE shared = nullptr;
  Check(fence->CreateSharedHandle(nullptr, GENERIC_ALL, nullptr, &shared));
  ComPtr<ID3D12Fence> cpu_fence;
  const auto opened = device12->OpenSharedHandle(shared, IID_PPV_ARGS(&cpu_fence));
  CloseHandle(shared);
  Check(opened);
  auto release = std::async(std::launch::async, [&] {
    std::this_thread::sleep_for(std::chrono::milliseconds(150));
    Check(cpu_fence->Signal(1));
  });
  Check(context4->Wait(fence.Get(), 1));
  surface.Draw([] { glClearColor(1, 0, 0, 1); glClear(GL_COLOR_BUFFER_BIT); });
  surface.Read();
  release.get();
  ComPtr<ID3D11Device> copy_device;
  ComPtr<ID3D11DeviceContext> copy_context;
  const auto snapshot = surface.texture();
  snapshot->GetDevice(&copy_device);
  copy_device->GetImmediateContext(&copy_context);
  CheckPixels(copy_device.Get(), copy_context.Get(), snapshot.Get(), 0xffff0000U);
}
}  // namespace

int main() {
  try {
    ANGLESurfaceManager first(64, 48);
    playback_gpu_test::ComPtr<ID3D11Texture2D> retired;
    {
      ANGLESurfaceManager second(64, 48);
      second.MakeCurrent(false);
#ifdef ANGLE_TEST_DISABLE_DEVICE_CREATION
      CheckFrames(first, false);
      CheckFrames(second, true);
#else
      auto a = std::async(std::launch::async, [&] { CheckFrames(first, false); });
      auto b = std::async(std::launch::async, [&] { CheckFrames(second, true); });
      a.get();
      b.get();
#endif
      retired = second.texture();
    }
    // Flutter may retain a published frame after its producer has closed.
    playback_gpu_test::ComPtr<ID3D11Device> retired_device;
    playback_gpu_test::ComPtr<ID3D11DeviceContext> retired_context;
    retired->GetDevice(&retired_device);
    retired_device->GetImmediateContext(&retired_context);
    CheckPattern(retired_device.Get(), retired_context.Get(), retired.Get(), false);
    // Disposing another player must not terminate this player's EGL display.
    CheckFrames(first, false);
    // Failed construction must not tear down an existing player's display.
    bool rejected = false;
    try {
      ANGLESurfaceManager invalid(0, 0);
    } catch (const std::exception&) {
      rejected = true;
    }
    playback_gpu_test::Require(rejected, "Invalid dimensions were accepted");
    CheckLongRender(first);
#ifdef ANGLE_TEST_DISABLE_DEVICE_CREATION
    std::cout << "PASS: legacy device fallback, ";
#else
    std::cout << "PASS: shared device and concurrent players, ";
#endif
    std::cout << "shader order, resize, consumer import, old frame, "
                 "lifecycle and GPU backlog\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
