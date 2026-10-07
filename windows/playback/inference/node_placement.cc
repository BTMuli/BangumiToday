// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#include "node_placement.h"

#include <fstream>
#include <iterator>
#include <stdexcept>

namespace bangumi::inference {
namespace {
// Each profiling event carries `"args" : {"provider" : "<name>", ...}`. ONNX
// Runtime has written both compact and spaced JSON, so the value is located by
// scanning from the key rather than by matching one exact byte sequence.
constexpr char kProviderKey[] = "\"provider\"";
// A profiling file for one frame is small; anything larger is not ours.
constexpr uint64_t kMaximumProfileBytes = 64ull * 1024 * 1024;
}  // namespace

NodePlacement AnalyzePlacementProfile(const std::filesystem::path& profile) {
  if (!profile.is_absolute())
    throw std::invalid_argument("Placement profile path is relative");
  NodePlacement result;
  std::ifstream stream(profile, std::ios::binary);
  if (!stream) {
    result.reason = "The placement profile could not be read";
    return result;
  }
  std::string text((std::istreambuf_iterator<char>(stream)),
                   std::istreambuf_iterator<char>());
  if (text.size() > kMaximumProfileBytes) {
    result.reason = "The placement profile is unexpectedly large";
    return result;
  }
  size_t position = 0;
  while ((position = text.find(kProviderKey, position)) != std::string::npos) {
    position += sizeof(kProviderKey) - 1;
    const size_t colon = text.find(':', position);
    if (colon == std::string::npos) {
      result.reason = "The placement profile is truncated";
      return result;
    }
    const size_t open = text.find('"', colon);
    if (open == std::string::npos) {
      result.reason = "The placement profile is truncated";
      return result;
    }
    const size_t close = text.find('"', open + 1);
    if (close == std::string::npos) {
      result.reason = "The placement profile is truncated";
      return result;
    }
    const std::string provider = text.substr(open + 1, close - open - 1);
    if (provider.rfind("Dml", 0) == 0)
      ++result.dml_nodes;
    else if (provider == "CPUExecutionProvider")
      ++result.cpu_nodes;
    else
      ++result.other_nodes;
    position = close + 1;
  }
  if (result.dml_nodes == 0 && result.cpu_nodes == 0 && result.other_nodes == 0)
    result.reason = "The placement profile recorded no node events";
  else if (result.cpu_nodes > 0)
    result.reason = "Some operators ran on the CPU execution provider";
  else if (result.dml_nodes == 0)
    result.reason = "No operator ran on DirectML";
  return result;
}

}  // namespace bangumi::inference
