# Windows playback

Windows x64 playback uses a project renderer override and the pinned AnimeJaNai
mpv fork. AI inference is documented in [inference/README.md](inference/README.md).

## Integration

`video_output.*` and `angle_surface_manager.*` derive from `media_kit_video` 2.0.1
under its [MIT license](LICENSE).
[playback_renderer.cmake](../cmake/playback_renderer.cmake) checks the plugin
version and source hashes, copies its native sources into the build directory,
and substitutes these files and the project helper headers. Review the override
when upgrading the plugin; the shared Pub cache is not modified.

[playback_runtime.cmake](../cmake/playback_runtime.cmake) pins libmpv and uses
headers, import library and DLL from the same archive. The current binary is a
GPL build; sources and licensing are listed in the
[libmpv notice](../licenses/libmpv/NOTICE.md).

## Renderer behavior

- `render_queue.h` coalesces callbacks while allowing resize and disposal work
  between frames. Updates run with the correct GL context; dimensions arrive
  through `SetSize`, without synchronous mpv property reads on the render worker.
- `frame_scheduler.h` derives each frame's deadline headroom from the observed
  cadence and recent render cost. A slightly late frame still displays when it
  can finish before its successor; frames that cannot are skipped, at most eight
  in a row. Cadence changes, including playback-rate switches, recalibrate
  immediately, and pause/seek discontinuities reset the estimate. First frames,
  forced changes, redraws and repeats still render. Deadlines from the pinned
  runtime use nanoseconds.
- Each rendered frame is copied into an immutable shared D3D snapshot. The
  snapshot for a new size is allocated before that size's first frame, and the
  next snapshot is allocated after each publish, so driver allocation spikes
  overlap presentation instead of extending the frame deadline. Allocation on
  the frame path remains only a fallback. A one-shot 1x1 copy during player
  creation initializes the copy/query path. An event query confirms GPU
  completion before publication; Flutter texture callbacks return completed
  snapshots without GPU work or waits. Resizes retain the old frame until
  Flutter samples the replacement.
- `gpu_copy_wait.h` uses a private high-resolution timer, falling back to
  a bounded sleep. It waits for either the completion event or a query recheck
  within 2 ms, so a delayed `Flush1` batch event cannot hide an already completed
  copy for a whole frame budget. Publication still requires `GetData` success.
  Whole-frame timeouts remain 1000 ms on the shared ANGLE context and 100 ms on
  the legacy path; failures retain the last published frame and wait for the
  copy before reusing its source. `_HAS_EXCEPTIONS=1` lets queued tasks capture
  recoverable failures.
- Device removal or `EGL_CONTEXT_LOST` replaces the failed render context on the
  worker, removes the AI filter asynchronously, and switches to CPU decoding
  and software output capped at 1080p. Ordinary copy timeouts do not trigger this
  recovery.
- Disposal closes the queue and texture callbacks, drains accepted work, frees
  the mpv render context even after device loss, and waits for texture
  unregistration before releasing ANGLE.

The Dart supersampling adapter uses a separate weak mpv client with asynchronous
replies. Native wakeup callbacks post replies to the Dart isolate instead of
polling every 16 ms. Mutations await completion in order, reads coalesce, and
disposal drains accepted replies and unregisters the callback before destroying
the client.

## Diagnostics and caches

Logs are in `Documents/BangumiToday/log`, accessible from settings:

- Logs are grouped in `YYYY-MM-DD/`. Each filename starts with the process
  creation time and PID (`YYYYMMDD-HHmmss-SSS-pid`), shared by Dart engines and
  native DLLs. Main logs end in `-main.log`, player logs in
  `-playback-<window-id>.log`, and native logs in `-native.log`. Dart logs rotate
  at midnight while retaining that identity; native logs stay in the startup
  day's directory. PID reuse cannot append a new run to the previous log.
- Dart logs record player state, mpv metrics and supersampling changes. Use
  `native_handle`, media revision and configuration generation to correlate them
  with native records. Playback flyouts log open/close times, panel kind,
  configured upscale mode and open duration to correlate visible overlays with
  rendering stalls and fallback.
- Native logs record ANGLE/D3D errors and render timing. Stage times are
  CPU wall times; deadline skips and render failures are separate counters.
  The periodic summary also reports `prefetch_count`, `prefetch_avg_ms` and
  `prefetch_max_ms`, so snapshot allocation cost can be checked independently
  from on-frame render time. `first frame ready` confirms snapshot publication,
  before Flutter presentation.
- Native crashes produce triage/full dumps and a matching text report through a
  separate helper process, stored in the startup day's `crashes/` directory.
  Filenames include the run identity and actual crash timestamp.
- Zero-byte running/unclean markers live in `state/`. A leftover marker means
  normal shutdown did not finish; it does not by itself prove a crash.
- Normal logs are retained for 7 days; crash-related logs, reports and dumps for
  30 days. Active runs are protected. Legacy flat files are still recognized by
  cleanup and shutdown checks; unknown files and linked directories are skipped.

Writable shader and demuxer caches are configured under
`Documents/BangumiToday/cache/playback`. Shader caches can be cleared in settings;
automatic pruning expires entries after 30 days and limits them to 128 MiB.

Full Flutter playback, sustained playback rates, fullscreen/episode transitions,
device recovery and clean Windows/MSIX installation still need manual acceptance.
Isolated native and logic checks do not establish end-to-end playback performance.
