// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#pragma once
#include <atomic>
#include <filesystem>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "gpu_capabilities.h"
#include "trusted_assets.h"

namespace bangumi::inference {
struct TrtResources {
  std::filesystem::path directory;
  std::vector<std::unique_ptr<LockedAsset>> leases;
  int sm = 0;
  // Checks architecture and driver before locking every file from the compiled
  // manifest. installed.json is never a source of expected hashes.
  static std::shared_ptr<TrtResources> Open(const std::filesystem::path& root,
                                            const GpuCapabilities& gpu);
};

class TrtEngineBuild final {
 public:
  enum class Phase { kPreparing, kReady, kFailed };
  struct Result {
    Phase phase = Phase::kPreparing;
    std::filesystem::path engine;
    std::string reason;
    std::shared_ptr<TrtResources> resources;
    std::shared_ptr<LockedAsset> engine_lease;
    std::filesystem::path log;
  };
  TrtEngineBuild(std::filesystem::path runtime, std::filesystem::path cache,
                 std::filesystem::path model, GpuCapabilities gpu,
                 uint32_t width, uint32_t height);
  ~TrtEngineBuild();
  TrtEngineBuild(const TrtEngineBuild&) = delete;
  TrtEngineBuild& operator=(const TrtEngineBuild&) = delete;
  Result snapshot() const;

 private:
  void Work(const std::filesystem::path& runtime,
            const std::filesystem::path& cache,
            const std::filesystem::path& model, const GpuCapabilities& gpu,
            uint32_t width, uint32_t height) noexcept;
  std::atomic<bool> cancel_{false};
  mutable std::mutex mutex_;
  Result result_;
  std::thread worker_;
};
}  // namespace bangumi::inference
