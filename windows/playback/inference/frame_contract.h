// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
//
// Validated frame contract for the AnimeJaNai bridge: which decoded frames may
// enter the model, which tensor sizes they map to, and the color rules the
// conversion shaders implement. Everything here is pure logic so the acceptance
// rules can be checked without a GPU.
#pragma once

#include <cstdint>
#include <string>

namespace bangumi::inference {

// Only the formats verified for the first release. Anything else must keep
// normal playback.
enum class PixelFormat {
  kNone,
  kNv12,  // 8-bit 4:2:0, NV12 texture with R8 / R8G8 plane views.
  kP010,  // 10-bit 4:2:0 in 16-bit containers, R16 / R16G16 plane views.
};

enum class ColorMatrix { kNone, kBt709 };
enum class ColorRange { kNone, kLimited };

// Input descriptions as read from the decoder's video parameters. The bridge
// deliberately refuses anything it has not verified instead of guessing.
struct FrameDescription {
  PixelFormat format = PixelFormat::kNone;
  ColorMatrix matrix = ColorMatrix::kNone;
  ColorRange range = ColorRange::kNone;
  // Unrotated decoded texture size in luma samples.
  uint32_t coded_width = 0;
  uint32_t coded_height = 0;
  // Unrotated visible size after cropping the coded padding (for example 1088
  // coded against 1080 visible).
  uint32_t visible_width = 0;
  uint32_t visible_height = 0;
  // Anything that would make the model input differ from the visible luma grid.
  bool rotated = false;
  bool non_square_pixels = false;
  bool hdr = false;
  // Chroma sample location in luma sample units: horizontal offset of chroma
  // sample i (2i + x_offset) and vertical position of chroma row j
  // (2j + y_offset). (0, 0.5) is the H.264 4:2:0 default ("left").
  float chroma_x_offset = 0.0f;
  float chroma_y_offset = 0.5f;
};

// Model input/output sizes. The model input is padded so every row pitch the
// D3D12 placed-footprint copies use is 256-byte aligned, which is what the
// pinned bridge relies on across vendors.
struct FramePlan {
  uint32_t visible_width = 0;   // luma samples entering the model
  uint32_t visible_height = 0;
  uint32_t model_width = 0;     // padded model input width
  uint32_t model_height = 0;    // padded model input height
  uint32_t model_output_width = 0;   // always 2x
  uint32_t model_output_height = 0;
  uint64_t model_input_bytes = 0;    // FP16 NCHW, batch 1
  uint64_t model_output_bytes = 0;
};

// First-release budget: SDR BT.709 limited 4:2:0, output within 3840x2160.
inline constexpr uint32_t kMaxOutputWidth = 3840;
inline constexpr uint32_t kMaxOutputHeight = 2160;
// 128 luma samples keep FP16 row pitches 256-byte aligned after the model's
// 2x upscale (4 bytes per output texel pair).
inline constexpr uint32_t kModelWidthGranularity = 128;
inline constexpr uint32_t kModelHeightGranularity = 2;

// Returns an empty string when the frame may enter the model, otherwise a
// short reason that is safe to show in the UI.
std::string ValidateFrameDescription(const FrameDescription& frame);

// Computes the tensor plan for a validated description. Throws
// std::invalid_argument when the description or the budget does not hold.
FramePlan MakeFramePlan(const FrameDescription& frame);

// Constants handed to the conversion shaders. Code values follow the usual
// limited-range definitions in the container's number of codes.
struct ColorConversion {
  float max_code = 255.0f;   // 255 for 8-bit, 65535 for 16-bit containers
  float y_offset = 16.0f;
  float y_scale = 219.0f;
  float c_offset = 128.0f;
  float c_scale = 224.0f;
  float kr = 0.2126f;        // BT.709
  float kg = 0.7152f;
  float kb = 0.0722f;
  float chroma_x_offset = 0.0f;
  float chroma_y_offset = 0.5f;
  // Output storage: 8-bit NV12 planes or 10-bit codes shifted into a P010
  // container.
  bool ten_bit_output = false;
};

ColorConversion MakeColorConversion(const FrameDescription& frame);

}  // namespace bangumi::inference
