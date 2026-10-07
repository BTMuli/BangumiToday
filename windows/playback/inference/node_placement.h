// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
//
// Node placement check: the plan requires that core operators (convolutions in
// particular) really run on DirectML and never silently fall back to the CPU
// execution provider. ONNX Runtime can write a profiling JSON that records the
// execution provider of every node; this scans it without a JSON dependency.
#pragma once

#include <cstdint>
#include <filesystem>
#include <string>

namespace bangumi::inference {

struct NodePlacement {
  uint64_t dml_nodes = 0;
  uint64_t cpu_nodes = 0;
  uint64_t other_nodes = 0;
  // Empty when every profiled node ran on DirectML.
  std::string reason;
};

// Reads an ONNX Runtime profiling JSON and counts the providers used. Pure
// file/std::string work, so the acceptance rule is testable without a GPU.
NodePlacement AnalyzePlacementProfile(const std::filesystem::path& profile);

}  // namespace bangumi::inference
