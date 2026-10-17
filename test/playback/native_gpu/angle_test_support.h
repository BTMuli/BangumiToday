#pragma once
// Standalone checks must not write into the application's logging directory.
#define BANGUMI_NATIVE_LOG_H_
inline void BangumiNativeLog(const char*, bool = false) noexcept {}
inline void BangumiNativeGraphicsError(const char*) noexcept {}

#ifdef ANGLE_TEST_DISABLE_DEVICE_CREATION
#include <EGL/egl.h>
#include <cstring>
inline __eglMustCastToProperFunctionPointerType EGLAPIENTRY
TestGetProcAddress(const char* name) {
  if (std::strcmp(name, "eglCreateDeviceANGLE") == 0) return nullptr;
  return eglGetProcAddress(name);
}
#define eglGetProcAddress TestGetProcAddress
#endif
