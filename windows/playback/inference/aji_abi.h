// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
//
// Interface exposed by the project's AnimeJaNai shim DLL and loaded at runtime
// by the LGPL mpv filter (`video/filter/vf_animejanai.c` in the pinned
// the-database/mpv commit). The function names, enum values and struct layouts
// follow what that filter resolves and passes, so the two agree at run time.
// This header is written by this project; no source or header from the
// unlicensed `animejanai-inference` project was copied.
//
// The shim runs the project's own frame bridge (frame_pipeline.*) and supports
// only what the first release verified: DirectML, NV12/P010, BT.709 limited
// range, SDR, unrotated, 2x output within 3840x2160. `aji_configure` reports
// passthrough (0) for geometry outside that budget and `aji_infer` reports
// AJI_ERR_FORMAT for colour contracts the bridge has not verified; the
// coordinator is expected to keep the filter disabled for such media.
#ifndef BANGUMI_PLAYBACK_AJI_ABI_H
#define BANGUMI_PLAYBACK_AJI_ABI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define AJI_EXPORT __declspec(dllexport)
#else
#define AJI_EXPORT __attribute__((visibility("default")))
#endif

#define AJI_API_VERSION 8

typedef struct aji_ctx aji_ctx;

enum aji_format {
  AJI_FMT_NV12 = 1,
  AJI_FMT_P010 = 2,
  AJI_FMT_YUV444P16 = 3,
  AJI_FMT_RGB10A2 = 4,
};

enum aji_matrix {
  AJI_MATRIX_BT601 = 1,
  AJI_MATRIX_BT709 = 2,
  AJI_MATRIX_BT2020 = 3,
};

enum aji_range {
  AJI_RANGE_LIMITED = 1,
  AJI_RANGE_FULL = 2,
};

enum aji_siting {
  AJI_SITING_LEFT = 1,
  AJI_SITING_CENTER = 2,
  AJI_SITING_TOPLEFT = 3,
};

enum aji_status {
  AJI_OK = 0,
  AJI_SCENE = 1,
  AJI_ERR = -1,
  AJI_ERR_SHAPE = -2,
  AJI_ERR_FORMAT = -3,
  AJI_ERR_CUDA = -4,
  AJI_ERR_ENGINE = -5,
  AJI_ERR_CONF = -6,
};

typedef void (*aji_log_fn)(void* opaque, int level, const char* msg);

typedef struct aji_create_params {
  uint32_t api_version;
  void* cuda_context;
  const char* conf_path;   // shim configuration file (see aji_bridge.cc)
  const char* model_dir;   // directory holding the .onnx models
  const char* trtexec;
  const char* trtexec_env;
  int slot;
  const char* rife_model_dir;
  int async_build;
  void* d3d11_device;      // ID3D11Device* the frame textures live on
  const char* engine_path;
  int max_width, max_height;
  aji_log_fn log;
  void* log_opaque;
} aji_create_params;

typedef struct aji_frame {
  int width, height;
  int format;
  int matrix;
  int range;
  int siting;
  void* plane[3];          // DirectML: plane[0] = ID3D11Texture2D*,
                           // plane[1] = subresource index
  ptrdiff_t stride[3];
} aji_frame;

AJI_EXPORT aji_ctx* aji_create(const aji_create_params* params);
AJI_EXPORT int aji_set_slot(aji_ctx* c, int slot);
AJI_EXPORT int aji_configure(aji_ctx* c, int w, int h, double fps, int* out_w,
                             int* out_h);
AJI_EXPORT int aji_infer(aji_ctx* c, const aji_frame* in,
                         const aji_frame* out, void* cu_stream);
AJI_EXPORT uint64_t aji_flush(aji_ctx* c, void* cu_stream);
AJI_EXPORT int aji_done(aji_ctx* c, uint64_t ticket);
AJI_EXPORT int aji_wait(aji_ctx* c, uint64_t ticket);
AJI_EXPORT const char* aji_current_log(aji_ctx* c);
AJI_EXPORT int aji_scale_factor(aji_ctx* c);
AJI_EXPORT int aji_rife_factor(aji_ctx* c, int* num, int* den);
AJI_EXPORT int aji_rife_before_upscale(aji_ctx* c);
AJI_EXPORT int aji_pre_resize(aji_ctx* c, int* work_w, int* work_h);
AJI_EXPORT int aji_resize(aji_ctx* c, const aji_frame* in,
                          const aji_frame* out, void* cu_stream);
AJI_EXPORT int aji_poll(aji_ctx* c);
AJI_EXPORT int aji_infer_rife(aji_ctx* c, const aji_frame* a,
                              const aji_frame* b, double t,
                              const aji_frame* out, void* cu_stream);
AJI_EXPORT const char* aji_last_error(aji_ctx* c);
AJI_EXPORT void aji_destroy(aji_ctx** c);

#ifdef __cplusplus
}
#endif

#endif  // BANGUMI_PLAYBACK_AJI_ABI_H
