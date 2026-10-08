// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#include "trusted_assets.h"

#include <bcrypt.h>

#include <array>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

#include "trusted_assets_data.h"

namespace bangumi::inference {
namespace {
std::string Describe(const std::filesystem::path& path) {
  const std::wstring name = path.filename().wstring();
  if (name.empty()) return {};
  const int length = WideCharToMultiByte(CP_UTF8, 0, name.c_str(),
                                         static_cast<int>(name.size()), nullptr,
                                         0, nullptr, nullptr);
  if (length <= 0) return {};
  std::string result(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, name.c_str(), static_cast<int>(name.size()),
                      result.data(), length, nullptr, nullptr);
  return result;
}

class ReadFileLease final {
 public:
  explicit ReadFileLease(const std::filesystem::path& path) {
    if (!path.is_absolute())
      throw std::invalid_argument("Asset path is relative");
    handle = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                         OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
    if (handle == INVALID_HANDLE_VALUE)
      throw std::runtime_error("Cannot open locked inference asset: " +
                               Describe(path));
  }
  ~ReadFileLease() {
    if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle);
  }
  HANDLE handle = INVALID_HANDLE_VALUE;
};

std::string Digest(HANDLE file, const std::string* text = nullptr) {
  struct Hash final {
    BCRYPT_ALG_HANDLE algorithm = nullptr;
    BCRYPT_HASH_HANDLE hash = nullptr;
    ~Hash() {
      if (hash) BCryptDestroyHash(hash);
      if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    }
  } context;
  auto check = [](NTSTATUS status) {
    if (status < 0) throw std::runtime_error("Cannot hash inference asset");
  };
  check(BCryptOpenAlgorithmProvider(&context.algorithm, BCRYPT_SHA256_ALGORITHM,
                                    nullptr, 0));
  check(BCryptCreateHash(context.algorithm, &context.hash, nullptr, 0, nullptr,
                         0, 0));
  std::array<uint8_t, 65536> buffer{};
  if (text) {
    check(BCryptHashData(context.hash,
        reinterpret_cast<PUCHAR>(const_cast<char*>(text->data())),
        static_cast<ULONG>(text->size()), 0));
  }
  for (;;) {
    if (text) break;
    DWORD count = 0;
    if (!ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()),
                  &count, nullptr)) {
      throw std::runtime_error("Cannot read inference asset");
    }
    if (!count) break;
    check(BCryptHashData(context.hash, buffer.data(), count, 0));
  }
  std::array<uint8_t, 32> digest{};
  check(BCryptFinishHash(context.hash, digest.data(),
                         static_cast<ULONG>(digest.size()), 0));
  constexpr char alphabet[] = "0123456789abcdef";
  std::string result;
  for (auto byte : digest) {
    result += alphabet[byte >> 4];
    result += alphabet[byte & 15];
  }
  return result;
}

bool Match(const detail::Asset& asset, uint64_t bytes,
           const std::string& digest) {
  return asset.bytes == bytes && digest == asset.sha256;
}

HANDLE Verify(const std::filesystem::path& path, bool model) {
  ReadFileLease file(path);
  LARGE_INTEGER length{};
  if (!GetFileSizeEx(file.handle, &length) || length.QuadPart <= 0 ||
      length.QuadPart > 32 * 1024 * 1024) {
    throw std::runtime_error("Inference asset has an invalid length");
  }
  const auto digest = Digest(file.handle);
  const bool valid =
      model ? Match(detail::kPerformance, length.QuadPart, digest) ||
                  Match(detail::kBalanced, length.QuadPart, digest)
            : (path.filename() == L"onnxruntime.dll" &&
               Match(detail::kOnnxruntime, length.QuadPart, digest)) ||
                  (path.filename() == L"DirectML.dll" &&
                   Match(detail::kDirectml, length.QuadPart, digest));
  if (!valid)
    throw std::runtime_error("Inference asset failed the compiled SHA-256 "
                             "lock: " +
                             Describe(path));
  const auto handle = file.handle;
  file.handle = INVALID_HANDLE_VALUE;
  return handle;
}
}  // namespace

LockedAsset::~LockedAsset() { CloseHandle(file_); }
std::unique_ptr<LockedAsset> LockedAsset::Runtime(
    const std::filesystem::path& path) {
  return std::unique_ptr<LockedAsset>(new LockedAsset(Verify(path, false)));
}
std::unique_ptr<LockedAsset> LockedAsset::Model(
    const std::filesystem::path& path) {
  return std::unique_ptr<LockedAsset>(new LockedAsset(Verify(path, true)));
}
std::unique_ptr<LockedAsset> LockedAsset::File(
    const std::filesystem::path& path, uint64_t bytes,
    const std::string& sha256) {
  ReadFileLease file(path);
  LARGE_INTEGER length{};
  if (!GetFileSizeEx(file.handle, &length) || length.QuadPart <= 0 ||
      static_cast<uint64_t>(length.QuadPart) != bytes ||
      Digest(file.handle) != sha256) {
    throw std::runtime_error("TensorRT asset failed the compiled lock: " +
                             Describe(path));
  }
  const auto handle = file.handle;
  file.handle = INVALID_HANDLE_VALUE;
  return std::unique_ptr<LockedAsset>(new LockedAsset(handle));
}
std::string LockedAsset::Sha256(const std::filesystem::path& path) {
  ReadFileLease file(path);
  return Digest(file.handle);
}
std::string LockedAsset::HashText(const std::string& text) {
  return Digest(INVALID_HANDLE_VALUE, &text);
}
}  // namespace bangumi::inference
