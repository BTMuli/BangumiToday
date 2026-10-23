// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#pragma once

// App-only API, independent of the mpv filter's aji ABI. All work, including
// device discovery, runs off the calling thread. Paths are absolute UTF-16.
// Poll returns UTF-8 JSON, valid until the next poll or close on this handle.
// Close cancels and joins; callers must do that on their background isolate.
// sm selects the architecture whose components the application installed.
struct bt_trt_precompile;
extern "C" {
__declspec(dllexport) bt_trt_precompile* bt_trt_precompile_start(
    const wchar_t* bundle, const wchar_t* runtime, const wchar_t* cache, int sm);
// Prepare just the requested playback model/size, using the renderer's adapter.
__declspec(dllexport) bt_trt_precompile* bt_trt_precompile_target_start(
    const wchar_t* bundle, const wchar_t* runtime, const wchar_t* cache, int sm,
    int slot, int width, int height, const wchar_t* renderer);
__declspec(dllexport) const char* bt_trt_precompile_poll(bt_trt_precompile* job);
__declspec(dllexport) void bt_trt_precompile_cancel(bt_trt_precompile* job);
__declspec(dllexport) void bt_trt_precompile_close(bt_trt_precompile* job);
// Release idle sessions/file leases before Settings removes cached engines.
__declspec(dllexport) void bt_trt_precompile_clear_cache();
}
