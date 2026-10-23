// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#pragma once
#include <atomic>
#include <chrono>
#include <filesystem>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "gpu_capabilities.h"
#include "trusted_assets.h"

namespace bangumi::inference {
class TrtSession;
struct TrtResources {
  std::filesystem::path directory;
  std::vector<std::unique_ptr<LockedAsset>> leases;
  int sm = 0;
  // Checks architecture and driver before locking every file from the compiled
  // manifest. installed.json is never a source of expected hashes.
  static std::shared_ptr<TrtResources> Open(const std::filesystem::path& root,
      const GpuCapabilities& gpu,
      const std::function<void(const std::filesystem::path&, uint64_t, uint64_t)>&
          progress = {});
};

// A checked-out preparation belongs to one job/Player. Its verified file leases
// and warmed CUDA state survive precompilation and same-shape episode changes.
struct TrtPreparedEngine {
  ~TrtPreparedEngine();
  std::filesystem::path engine;
  std::shared_ptr<TrtResources> resources;
  std::shared_ptr<LockedAsset> engine_lease;
  std::unique_ptr<LockedAsset> model_lease;
  std::unique_ptr<TrtSession> session;
  std::string metadata_identity;
  bool reusable = true;
  bool Valid() const;
  void ReturnSession(std::unique_ptr<TrtSession> value) noexcept;
  static void ClearCache();
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
    // Remains true through validation/publication after a cache miss.
    bool build_required = false;
    std::shared_ptr<TrtPreparedEngine> prepared;
  };
  TrtEngineBuild(std::filesystem::path runtime, std::filesystem::path cache,
                 std::filesystem::path model, GpuCapabilities gpu,
                 uint32_t width, uint32_t height,
                 const std::wstring& cancel_event = {});
  ~TrtEngineBuild();
  TrtEngineBuild(const TrtEngineBuild&) = delete;
  TrtEngineBuild& operator=(const TrtEngineBuild&) = delete;
  Result snapshot() const;

 private:
  bool IsCancelled() const;
  void CheckCancelled() const;
  void Work(const std::filesystem::path& runtime,
            const std::filesystem::path& cache,
            const std::filesystem::path& model, const GpuCapabilities& gpu,
            uint32_t width, uint32_t height) noexcept;
  std::atomic<bool> cancel_{false};
  HANDLE cancel_event_ = nullptr;
  mutable std::mutex mutex_;
  Result result_;
  std::chrono::steady_clock::time_point started_ =
      std::chrono::steady_clock::now();
  std::chrono::steady_clock::time_point stage_started_ = started_;
  std::thread worker_;
};
}  // namespace bangumi::inference
