// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#include "frame_contract.h"

#include <algorithm>
#include <stdexcept>

namespace bangumi::inference {
namespace {

uint32_t AlignUp(uint32_t value, uint32_t granularity) {
  return ((value + granularity - 1) / granularity) * granularity;
}

}  // namespace

std::string ValidateFrameDescription(const FrameDescription& frame) {
  if (frame.format == PixelFormat::kNone)
    return "Unsupported pixel format";
  if (frame.matrix != ColorMatrix::kBt709)
    return "Only BT.709 video is supported";
  if (frame.range != ColorRange::kLimited)
    return "Only limited-range video is supported";
  if (frame.hdr) return "HDR video is not supported";
  if (frame.rotated) return "Rotated video is not supported";
  if (frame.non_square_pixels) return "Non-square pixels are not supported";
  if (frame.visible_width == 0 || frame.visible_height == 0)
    return "Unknown video dimensions";
  if (frame.coded_width < frame.visible_width ||
      frame.coded_height < frame.visible_height)
    return "Coded size is smaller than the visible size";
  if (frame.coded_width > 8192 || frame.coded_height > 8192)
    return "Video dimensions exceed the verified range";
  if (frame.visible_width * 2 > kMaxOutputWidth ||
      frame.visible_height * 2 > kMaxOutputHeight)
    return "Video is larger than the supported 2x output budget";
  if (!(frame.chroma_x_offset >= 0.0f && frame.chroma_x_offset < 1.0f) ||
      !(frame.chroma_y_offset >= 0.0f && frame.chroma_y_offset < 1.0f))
    return "Unsupported chroma sample location";
  return {};
}

FramePlan MakeFramePlan(const FrameDescription& frame) {
  const std::string reason = ValidateFrameDescription(frame);
  if (!reason.empty()) throw std::invalid_argument(reason);
  FramePlan plan;
  plan.visible_width = frame.visible_width;
  plan.visible_height = frame.visible_height;
  plan.model_width = AlignUp(frame.visible_width, kModelWidthGranularity);
  plan.model_height = AlignUp(frame.visible_height, kModelHeightGranularity);
  plan.model_output_width = plan.model_width * 2;
  plan.model_output_height = plan.model_height * 2;
  if (plan.model_output_width > kMaxOutputWidth ||
      plan.model_output_height > kMaxOutputHeight) {
    throw std::invalid_argument(
        "Padded model output exceeds the verified 2x budget");
  }
  plan.model_input_bytes =
      static_cast<uint64_t>(plan.model_width) * plan.model_height * 3 * 2;
  plan.model_output_bytes = plan.model_input_bytes * 4;
  return plan;
}

ColorConversion MakeColorConversion(const FrameDescription& frame) {
  ColorConversion conversion;
  conversion.chroma_x_offset = frame.chroma_x_offset;
  conversion.chroma_y_offset = frame.chroma_y_offset;
  switch (frame.format) {
    case PixelFormat::kNv12:
      conversion.max_code = 255.0f;
      conversion.y_offset = 16.0f;
      conversion.y_scale = 219.0f;
      conversion.c_offset = 128.0f;
      conversion.c_scale = 224.0f;
      conversion.ten_bit_output = false;
      break;
    case PixelFormat::kP010:
      // P010 stores 10-bit codes in the high bits, so the raw value is the
      // code multiplied by 64 and offsets scale with the same factor.
      conversion.max_code = 65535.0f;
      conversion.y_offset = 16.0f * 256.0f;
      conversion.y_scale = 219.0f * 256.0f;
      conversion.c_offset = 128.0f * 256.0f;
      conversion.c_scale = 224.0f * 256.0f;
      conversion.ten_bit_output = true;
      break;
    case PixelFormat::kNone:
      throw std::invalid_argument("No pixel format for the color conversion");
  }
  return conversion;
}

}  // namespace bangumi::inference
