// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef ANGLE_SURFACE_MANAGER_H_
#define ANGLE_SURFACE_MANAGER_H_

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <EGL/eglplatform.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <Windows.h>
#include <d3d.h>
#include <d3d11.h>
#include <wrl.h>

#include <cstdint>
#include <functional>

#include "render_diagnostics.h"
#include "utils.h"

// |ANGLESurfaceManager| provides an abstraction around ANGLE to easily draw
// OpenGL ES 2.0 content & read as D3D 11 texture using shared |HANDLE|.
// * |Draw|: Takes callback where OpenGL ES 2.0 calls can be made for rendering.
// * |Read|: Copies the drawn content to an immutable shared D3D 11 snapshot,
//           waits for GPU completion and updates |texture| and |handle|.

// A large part of implementation is inspired from Flutter.
// https://github.com/flutter/engine/blob/master/shell/platform/windows/angle_surface_manager.h

class ANGLESurfaceManager {
 public:
  const int32_t width() const { return width_; }
  const int32_t height() const { return height_; }
  const HANDLE handle() const { return handle_; }
  Microsoft::WRL::ComPtr<ID3D11Texture2D> texture() const {
    return d3d_11_texture_2D_;
  }

  ANGLESurfaceManager(int32_t width, int32_t height);

  ~ANGLESurfaceManager();

  void SetSize(int32_t width, int32_t height,
               PlaybackRenderSample* sample = nullptr);

  void Draw(std::function<void()> callback,
            PlaybackRenderSample* sample = nullptr);

  void Read(PlaybackRenderSample* sample = nullptr);

  void MakeCurrent(bool value, PlaybackRenderSample* sample = nullptr);

 private:
  void SwapBuffers();

  void WaitForCopy(PlaybackRenderSample* sample = nullptr,
                   PlaybackRenderStage stage = PlaybackRenderStage::prior_copy);

  void Create(PlaybackRenderSample* sample = nullptr);

  void CleanUp(bool release_context);

  bool CreateD3DTexture();

  bool CreateEGLDisplay();

  bool CreateAndBindEGLSurface();

  int32_t width_ = 1;
  int32_t height_ = 1;
  HANDLE internal_handle_ = nullptr;
  HANDLE handle_ = nullptr;

  // Preserve the GL/D3D handoff, including the first read after a resize.
  HANDLE mutex_ = nullptr;
  bool frame_available_ = false;
  // D3D 11
  ID3D11Device* d3d_11_device_ = nullptr;
  ID3D11DeviceContext* d3d_11_device_context_ = nullptr;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> internal_d3d_11_texture_2D_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> d3d_11_texture_2D_;
  Microsoft::WRL::ComPtr<ID3D11Query> copy_completion_;
  bool copy_pending_ = false;
  // ANGLE
  EGLSurface surface_ = EGL_NO_SURFACE;
  EGLDisplay display_ = EGL_NO_DISPLAY;
  EGLContext context_ = nullptr;
  EGLConfig config_ = nullptr;

  static constexpr EGLint kEGLConfigurationAttributes[] = {
      EGL_RED_SIZE,   8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE,    8,
      EGL_ALPHA_SIZE, 8, EGL_DEPTH_SIZE, 8, EGL_STENCIL_SIZE, 8,
      EGL_NONE,
  };
  static constexpr EGLint kEGLContextAttributes[] = {
      EGL_CONTEXT_CLIENT_VERSION,
      2,
      EGL_NONE,
  };
  static constexpr EGLint kD3D11DisplayAttributes[] = {
      EGL_PLATFORM_ANGLE_TYPE_ANGLE,
      EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE,
      EGL_PLATFORM_ANGLE_ENABLE_AUTOMATIC_TRIM_ANGLE,
      EGL_TRUE,
      EGL_NONE,
  };
  static constexpr EGLint kD3D11_9_3DisplayAttributes[] = {
      EGL_PLATFORM_ANGLE_TYPE_ANGLE,
      EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE,
      EGL_PLATFORM_ANGLE_MAX_VERSION_MAJOR_ANGLE,
      9,
      EGL_PLATFORM_ANGLE_MAX_VERSION_MINOR_ANGLE,
      3,
      EGL_PLATFORM_ANGLE_ENABLE_AUTOMATIC_TRIM_ANGLE,
      EGL_TRUE,
      EGL_NONE,
  };
  static constexpr EGLint kD3D9DisplayAttributes[] = {
      EGL_PLATFORM_ANGLE_TYPE_ANGLE,
      EGL_PLATFORM_ANGLE_TYPE_D3D9_ANGLE,
      EGL_PLATFORM_ANGLE_DEVICE_TYPE_ANGLE,
      EGL_PLATFORM_ANGLE_DEVICE_TYPE_HARDWARE_ANGLE,
      EGL_NONE,
  };
  static constexpr EGLint kWrapDisplayAttributes[] = {
      EGL_PLATFORM_ANGLE_TYPE_ANGLE,
      EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE,
      EGL_PLATFORM_ANGLE_ENABLE_AUTOMATIC_TRIM_ANGLE,
      EGL_TRUE,
      EGL_NONE,
  };

  // Number of active instances of ANGLESurfaceManager.
  static int32_t instance_count_;
};

#endif  // ANGLE_SURFACE_MANAGER_H_
