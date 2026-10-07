// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#pragma once
#include <Windows.h>

#include <filesystem>
#include <memory>

namespace bangumi::inference {
// Holds a read-only file handle without write/delete sharing through loading.
// The expected digest comes from the compiled lock, never an installed
// manifest.
class LockedAsset final {
 public:
  ~LockedAsset();
  LockedAsset(const LockedAsset&) = delete;
  LockedAsset& operator=(const LockedAsset&) = delete;
  static std::unique_ptr<LockedAsset> Runtime(
      const std::filesystem::path& path);
  static std::unique_ptr<LockedAsset> Model(const std::filesystem::path& path);

 private:
  explicit LockedAsset(HANDLE file) : file_(file) {}
  HANDLE file_;
};
}  // namespace bangumi::inference
