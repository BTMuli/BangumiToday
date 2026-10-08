// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#pragma once
#include <Windows.h>

#include <filesystem>
#include <memory>
#include <cstdint>
#include <string>

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
  // Expected values must come from the compiled component lock. Keeps the
  // file immutable through DLL loading or child-process execution.
  static std::unique_ptr<LockedAsset> File(const std::filesystem::path& path,
                                          uint64_t bytes,
                                          const std::string& sha256);
  static std::string Sha256(const std::filesystem::path& path);
  static std::string HashText(const std::string& text);

 private:
  explicit LockedAsset(HANDLE file) : file_(file) {}
  HANDLE file_;
};
}  // namespace bangumi::inference
