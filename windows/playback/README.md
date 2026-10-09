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
- `frame_scheduler.h` skips timed frames more than 5 ms late, with at most eight
  consecutive skips. First frames, forced changes, redraws and repeats still
  render. Deadlines from the pinned runtime use nanoseconds.
- Each rendered frame is copied into an immutable shared D3D snapshot. An event
  query confirms GPU completion before publication; Flutter texture callbacks
  return completed snapshots without GPU work or waits. Resizes retain the old
  frame until Flutter samples the replacement.
- `gpu_copy_wait.h` uses a private high-resolution timer, falling back to
  `Sleep(1)`. A 100 ms copy timeout preserves the last published frame and waits
  for the copy before reusing its source. `_HAS_EXCEPTIONS=1` lets queued tasks
  capture recoverable failures.
- Device removal or `EGL_CONTEXT_LOST` replaces the failed render context on the
  worker, removes the AI filter asynchronously, and switches to CPU decoding
  and software output capped at 1080p. Ordinary copy timeouts do not trigger this
  recovery.
- Disposal closes the queue and texture callbacks, drains accepted work, frees
  the mpv render context even after device loss, and waits for texture
  unregistration before releasing ANGLE.

The Dart supersampling adapter uses a separate weak mpv client with asynchronous
replies. Mutations await completion in order, reads coalesce, and disposal drains
accepted replies before destroying the client.

## Diagnostics and caches

Logs are in `Documents/BangumiToday/log`, accessible from settings:

- Dart logs record player state, mpv metrics and supersampling changes. Use
  `native_handle`, media revision and configuration generation to correlate them
  with native records.
- `native-<pid>.log` records ANGLE/D3D errors and render timing. Stage times are
  CPU wall times; deadline skips and render failures are separate counters.
  `first frame ready` confirms snapshot publication, before Flutter presentation.
- Native crashes produce triage/full dumps and a matching text report through a
  separate helper process. Normal logs are retained for 7 days; crash-related
  logs, reports and dumps for 30 days.

Writable shader and demuxer caches are configured under
`Documents/BangumiToday/cache/playback`. Shader caches can be cleared in settings;
automatic pruning expires entries after 30 days and limits them to 128 MiB.

Full Flutter playback, sustained playback rates, fullscreen/episode transitions,
device recovery and clean Windows/MSIX installation still need manual acceptance.
Isolated native and logic checks do not establish end-to-end playback performance.
