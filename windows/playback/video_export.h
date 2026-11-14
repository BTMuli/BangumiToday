#pragma once

#include <cstdint>

// All strings are UTF-8 and copied by start. The job owns its two private mpv
// cores; no playback handle or Flutter texture is used by the export worker.
struct PlaybackExportRequest {
  const char* source;
  const char* target;
  const char* shaders;
  const char* filter;
  const char* format;
  int32_t width;
  int32_t height;
  double fps;
};

extern "C" {
__declspec(dllexport) void* bt_video_export_start(
    const PlaybackExportRequest* request);
// 0 running, 1 complete, 2 cancelled, 3 failed. Progress is processed seconds.
__declspec(dllexport) int bt_video_export_state(void* job);
__declspec(dllexport) double bt_video_export_progress(void* job);
__declspec(dllexport) const char* bt_video_export_error(void* job);
__declspec(dllexport) void bt_video_export_cancel(void* job);
__declspec(dllexport) void bt_video_export_close(void* job);
}
