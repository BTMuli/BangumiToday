# Windows playback renderer override

The four `video_output.*` and `angle_surface_manager.*` files derive from
`media_kit_video` 2.0.1 under its MIT license (see `LICENSE`).

`../cmake/playback_renderer.cmake` checks the upstream version and source hashes,
then copies the plugin's native sources into the build directory and substitutes
these files. All translation units use the substituted headers. The Pub cache,
generated plugin registration, Dart API and macOS backend remain untouched.
Review and rebase this override when upgrading the dependency.

Playback diagnostics are saved in the application's `BangumiToday/log` directory
under Documents, accessible through the settings page's log-directory action:

- Main and child Dart engines write separate daily files, including Debug builds.
  Records are appended synchronously; warnings/errors also flush to disk.
- Each Player records media opens, state changes, errors and a snapshot every
  15 seconds. Batched asynchronous mpv samples run every five seconds during
  playback/buffering and every thirty seconds while paused. They include
  hardware decoding, output/decoder drops, A/V sync and cache duration;
  the stable mpv version is cached. Three-second position stalls, prolonged
  buffering and delayed Dart event-loop ticks produce warnings; pauses and
  completed playback are excluded from position-stall detection.
- `native-<pid>.log` records ANGLE/D3D errors, renderer initialization/disposal
  and aggregate render timing. GPU errors and slow-frame reports are limited
  to one report per five seconds, with normal timing reports every ten seconds.
  Timing includes failed attempts: `attempts = frames + failures`, while
  `errors_total` is cumulative for the player. `over_20ms`, `over_33ms` and
  `slow_frames` count attempts taking at least 20, 33 and 50 ms respectively;
  they are overlapping thresholds, not mpv's dropped-frame counters.
  Stage averages/maxima separate retired-texture cleanup, update, resize,
  surface lock/context/recreation, mpv rendering, swap (`glFinish` completion
  wait, not a window presentation), snapshot allocation,
  handle sharing, copy submission, previous-copy wait, GPU completion wait
  and frame storage/publication. Nested resize/recreation and update/context
  times overlap.
  These are CPU wall times, not GPU timestamp measurements.
  Each aggregate also records its worst attempt, including sequence, dimensions,
  size request, queue delay, coalesced request count, failure stage and age at
  logging. Subtract `age_ms` and `render_ms` from the record time to locate it.
  A separate worst-queue record identifies significant scheduling delays when
  they occurred in a different attempt. Disposal flushes the remaining interval.
  Resize begin/completion records link old/new dimensions and texture IDs;
  completion still awaits the first frame, rather than proving publication.
  The matching `first frame ready` record confirms its completed snapshot and
  texture notification, before Flutter's subsequent sampling/presentation.
- Dart diagnostics include the matching `native_handle`, media revision, actual
  texture dimensions, installed shader mode, FPS/rate frame budget and cached
  metric age. mpv warnings/errors carry this snapshot; rate/loudness changes
  are recorded. `metric_issues` distinguishes unavailable properties, native
  errors and timeouts from successful empty values. Sampling warnings use
  errors or a single read taking at least 400 ms, with a thirty-second limit;
  batch wall time alone is not treated as a blocked UI isolate. Cached metrics
  are published together only for the current media revision.
  Supersampling logs use a generation to link configuration steps, shader lists,
  output requests, observed dimensions, confirmation timeouts, superseded work
  and recovery. Step completion confirms command acceptance/configuration;
  observed output and native publication timing establish frame availability.
  Routine supersampling step records keep only correlation fields; apply,
  output observations and failures retain full playback snapshots. Repeated
  informational mpv messages remain informational when summarized.
- High-load catch-up uses the next frame's display deadline. A timed video
  frame more than 5 ms overdue is acknowledged with `SKIP_RENDERING`, avoiding
  GL rendering, `glFinish`, snapshot allocation and GPU copy for stale content.
  Initial/resized output, forced changes, redraws, repeats and untimed/vsync
  frames remain renderable. At most eight consecutive frames are skipped so
  persistent lateness cannot suppress every image. Callback coalescing and
  render/resize/disposal fairness remain in the same render queue.
  The pinned AnimeJaNai runtime `d6d93599d5` (the fork's build of `vo_libmpv`)
  reports nanosecond deadlines even though `render.h` retains an outdated
  microsecond comment; comparison uses `mpv_get_time_ns`. The deadline,
  skip-acknowledgement and `ao-reload` behaviours below were measured on the
  previous pinned runtime (`413ff0b1cd`) and are inherited from the same
  upstream `vo_libmpv` implementation, but they have not been re-measured
  against the new runtime yet — that re-run is part of the AnimeJaNai P0/P1
  acceptance. Headers and the import library come from the same pinned archive
  as the bundled DLL. No synchronous core property reads are added.
  Aggregate `deadline_skips`/`deadline_skips_total` and worst-frame
  `target_time_ns`/`frame_flags`/`lateness_ms` identify catch-up. The
  `output_lateness_ms` values measure completion/publication delay relative to
  the deadline, before Flutter's subsequent sampling and actual presentation.
  Skips are counted separately, preserving `attempts = frames + failures`.
  `skip_avg_ms`, `skip_max_ms`, `skip_queue_max_ms` and slow `skip_worst` /
  `skip_queue_worst` samples include the complete skip call and its scheduling
  delay, so skipped work is also visible in degraded or skip-only intervals.
- D3D completion polling uses a private high-resolution waitable timer rather
  than rounding each `Sleep(1)` to the system timer tick. It retains the 100 ms
  GPU completion timeout and publishes only completed immutable snapshots.
  Unsupported systems fall back to `Sleep(1)` without busy-spinning or changing
  global timer resolution. See Microsoft's
  [CreateWaitableTimerExW documentation](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-createwaitabletimerexw).
- The player explicitly configures writable shader and demuxer caches under
  `BangumiToday/cache/playback` before renderer creation. Compiled shader
  programs can be reused across playback sessions. Settings report shader cache
  size separately from images and support independent clearing; clearing all
  caches includes compiled shaders. The main engine prunes shader caches at
  startup and hourly: files last written at least 30 days ago are removed, then
  the oldest files are evicted until at most 128 MiB remain. Locked or changed
  files are retried later. Only SHA-256-named files in the existing shader cache
  directory are managed; shader sources, links and subdirectories are preserved.
  Supersampling first waits for the requested texture dimensions before
  installing a new shader chain,
  avoiding compilation at both the old and new sizes. A one-second viewport
  handoff grace period avoids unloading shaders for brief route/fullscreen
  transitions; persistent hiding, media reset and explicit disable still restore
  normal playback. Pending dimension waits cancel on superseding work, reset
  and disposal, and time out into normal playback after three seconds.
  Shader-cache behavior follows the [mpv manual](https://mpv.io/manual/master/#options-gpu-shader-cache).
- The Windows runner records unhandled native exceptions and asks a separate
  instance of the same executable to collect a crash before Flutter/plugin
  startup. The timestamp is the actual crash time, including milliseconds:
  - `native-<pid>-<timestamp>.dmp.triage.dmp` is saved first, with thread stacks,
    indirectly referenced memory, the complete virtual-memory map, process/thread
    information, handles and unloaded modules. Its capture budget is 15 seconds.
  - `native-<pid>-<timestamp>.dmp` then includes all accessible process memory,
    including heaps, plus the same diagnostic information. Its capture budget
    is 90 seconds. Full dumps can be several GB; retain them for investigating
    invalid pointers and heap ownership, and use the triage file for quick stack
    analysis. Inaccessible pages are skipped rather than failing the capture.
  - The matching `.dmp.txt` records the application/Flutter SDK/engine identity,
    UTC capture time, process and exception thread, process memory usage, exception
    parameters, access type/address and the faulting virtual-memory region. Each
    capture stage records its flags, result (Win32 error or DbgHelp HRESULT),
    byte count and elapsed time. SDK identity is also embedded in both dumps.
  - Dumps are written to `.partial` files and published only after writing and
    flushing succeeds. A failed or canceled full dump leaves the completed
    triage file intact and reports failure separately. The parent waits at most
    120 seconds, keeping the exception pointers alive, then stops the helper and
    removes partial files if termination is confirmed. A forced termination can
    bypass DbgHelp's cancellation callback; the flushed text report identifies
    the last capture stage reached.
  - The failing process uses a log handle opened during startup and fixed
    buffers, avoiding string allocations on a possibly corrupted heap.
  - Crash dumps and text reports are retained for 30 days. Native startup and
    successful captures clean expired sets and abandoned partial files; files
    belonging to an active capture or held open by a reader are preserved for
    a later cleanup. Legacy dump names use the file's last-write time.
  - The main Dart logger also cleans the directory at startup and hourly.
    Daily Dart logs and native logs from normal runs are retained for 7 days.
    Native logs and unclean-exit markers associated with crashes, and daily
    Dart logs from those crash dates, are retained for 30 days. Active native
    processes, subdirectories, links and manually saved analysis are excluded.
  A retained `.running` marker reports an unclean prior exit on the next launch,
  including termination paths that bypass exception handlers.

Property semantics follow the [mpv manual](https://mpv.io/manual/master/).
Dump capture follows Microsoft's recommendation to use
[MiniDumpWriteDump from a separate process](https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/nf-minidumpapiset-minidumpwritedump).

The plugin enables `_HAS_EXCEPTIONS=1` instead of Flutter's default `0` so
`std::packaged_task` can store recoverable render failures in its future. With
STL exception handling disabled, a GPU copy timeout instead escapes the task
and terminates the entire process (`0xc0000409`, fast-fail reason 7).

Changes relative to 2.0.1:

- `PlaybackRenderQueue` coalesces notifications into one scheduled render task
  per player and one pending update. Updates received during rendering cause a
  follow-up task; resize/dispose tasks can run between frames.
- `mpv_render_context_update` runs with the correct GL context. Rendering occurs
  for `MPV_RENDER_UPDATE_FRAME` or a forced size change, including paused video.
- Output dimensions come from the Dart controller's observed video parameters
  through `SetSize`. The render thread never synchronously queries mpv's core
  for dimensions during stop/open or resize.
- Rendering disables the target-time wait with `video-timing-offset=0`, so it
  does not wait for the core's presentation signal while holding the surface
  mutex. GL contexts are checked and detached before surface recreation.
- Every completed frame gets an immutable shared D3D snapshot. The render worker
  waits for a `D3D11_QUERY_EVENT` after the copy before publishing the snapshot;
  `Flush` alone only submits asynchronous GPU work. A failed copy leaves the
  previously published image intact. A timed-out copy must finish before drawing
  into or resizing its source again.
- Flutter callbacks only return completed snapshots and do no GPU work or waits.
  The sampled frame retains its descriptor and D3D resource while the worker can
  replace the latest frame independently. The engine's release callback balances
  the reference used to import the handle; it does not signal completion of GPU
  sampling. Descriptors remain valid for the engine's reads after that callback.
- A resized texture is published after its first completed snapshot; the old IDs
  retain their last frame until Flutter samples the replacement. The initial ID
  is sent with a zero-size rectangle to bootstrap playback. Each rendered frame
  is copied once; no handed-off resource is reused for a later frame.
- Disposal closes the queue and texture callbacks, drains accepted render work,
  detaches/frees mpv, waits for all active and retired texture unregistrations,
  then releases ANGLE. Unregister callbacks own their state without the player.

This bounds callback backlog and removes identified render/core waits and shared
texture read/write races. It does not interpolate frames or change the source
frame cadence. Snapshot allocation and EGL handle import now occur per rendered
frame; this trades extra allocation/import work for safe ownership across devices.
Actual RTX 4070 playback, sustained higher playback rates and fullscreen episode
switching still require runtime verification. Headless checks cannot establish
that intermittent freezes or flashes are fully resolved, or measure playback
performance on the target GPU.

Synchronization references:

- [Microsoft: Flush is asynchronous; use an event query for completion](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/nf-d3d11-id3d11devicecontext-flush).
- [Pinned mpv fork: frame deadlines and skip acknowledgement](https://github.com/the-database/mpv/blob/d6d93599d59069b715013a6e77e898056499b905/video/out/vo_libmpv.c).
- [Flutter 3.48.0-0.4.pre: shared-handle import and descriptor release](https://github.com/flutter/flutter/blob/3.48.0-0.4.pre/engine/src/flutter/shell/platform/windows/external_texture_d3d.cc).

Verification performed without starting the app or building the project:

- Shader-cache functional checks cover absent directories, the 30-day expiry
  boundary, oldest-first eviction, exact capacity, oversized entries, size
  reporting, independent clearing, preservation of sources/other caches/links,
  rejection of linked roots and occupied-file retries. The checks use temporary
  directories and are removed afterward. Changed Dart files pass static analysis.
- Frame-deadline catch-up passes MSVC `/Zs`, `/W4`, `/WX` for all six renderer
  translation units. Temporary functional checks cover the lateness boundary,
  first/forced/redraw/repeat/vsync protection, recovery and the eight-skip
  starvation bound, plus separate skip/render/error statistics. A headless
  synthetic source confirms nanosecond deadlines and skip acknowledgements
  against the pinned DLL. At 2x speed with a simulated 100 ms output delay,
  catch-up reduces median submission lateness from about 111 ms to below 1 ms
  and median completion lateness from about 211 ms to about 100 ms, by skipping
  stale frames. The remaining 100 ms is the simulated GPU cost, not eliminated
  by skipping; this check does not establish real RTX 4070 performance.
  A separate native link/clock check and isolated CMake configuration verify
  the pinned SDK include priority, import-library and bundled-DLL replacement,
  scheduler header overlay and existing exception protection. All temporary
  verification sources and artifacts are removed afterward.
- Coordinator functional checks cover size-confirmation ordering, transient and
  persistent viewport loss, repeated detach notifications, reattachment,
  cancellation on disable/reset/close, superseding and stale output observations,
  and timeout/resize-failure recovery. The bundled libmpv accepts and reads back
  both cache directories with Unicode and spaces without opening media or a
  renderer. Temporary checks are removed after verification.
- Dart analysis and format check for the changed coordinator.
- MSVC `/Zs`, `/W4`, `/WX` checks for all six overlaid plugin translation units.
- Isolated CMake configuration verifies header/source substitution and rejection
  of modified upstream sources or a changed dependency version.
- Temporary C++ functional checks cover concurrent notification bursts, updates
  during rendering, forced redraws, queue fairness and shutdown races.
- Production `VideoOutput` code and the `Read`, `Draw`, `SetSize`, `MakeCurrent`
  and `SwapBuffers` surface methods are checked with mock GPU/mpv/registrar
  objects and a real Windows mutex. Checks cover initialization, first-frame
  publication, stale IDs, reference balancing, paused resize, render failure
  recovery, busy reads, delayed unregistration, disposal and software stride.
  Temporary verification files are removed after the checks.
- The immutable-snapshot change additionally passes MSVC `/Zs`, `/W4`, `/WX` for
  all six overlaid translation units. A temporary non-UI harness runs the actual
  `Read`, `Draw`, `WaitForCopy` methods and GPU descriptor callback with two real
  D3D WARP devices. It checks all pixels of 200 shared frames, retained old frames,
  duplicate reads, allocation failure, copy timeout/source protection, query
  error recovery, descriptor lifetime after release, and stale/closed callbacks.
  The harness is removed after verification; no full build or app launch is run.
- The STL exception fix is checked with the production render queue and upstream
  thread pool. Disabled STL exception handling reproduces `0xc0000409`; enabled
  handling settles the copy-timeout exception and renders the next requested
  frame. An isolated CMake configuration verifies that only the renderer target
  changes its exception definition. MSVC `/Zs`, `/W4`, `/WX` passes for the runner
  window and all six overlaid plugin translation units. Temporary checks are
  removed; closing and reopening real playback windows remains a manual check.
- Enhanced crash capture passes MSVC `/Zs`, `/W4`, `/WX` and an isolated
  non-UI process/helper check. Both dumps contain exception, memory-map, thread,
  handle and build-identity streams; the full dump preserves the bytes of a
  known heap allocation. Checks cover full-write failure, cancellation, retained
  triage dumps, partial-file cleanup, existing-file preservation, invalid helper
  arguments, missing processes, capture budgets and the production parent/helper
  path with its pre-opened crash log. Isolated CMake configuration verifies SDK
  and engine identity definitions. These checks use a temporary directory outside
  the repository and do not build or launch the Flutter application.
- Crash retention is checked with real files and the production helper in an
  isolated non-UI harness: replacement after triage publication, full/partial
  capture failures, legacy filename ordering, modern crash-time ordering,
  active captures and reader locks, cleanup retries, orphaned partial files and
  preservation of unrelated files and directories. MSVC `/Zs`, `/W4`, `/WX`
  passes without building or starting the application.

## AnimeJaNai inference

The [DirectML inference bridge](inference/README.md) is wired through the pinned
mpv filter, the aji shim and the application's two AI modes. Build preparation
and bundle verification include its locked runtime, models and app-local CRT.
Default realtime AI requires the actual NVIDIA playback adapter and configured
TensorRT components/engine. Missing resources or TRT failures preserve ordinary
playback; DirectML is an explicit diagnostic override only.
TensorRT inference, local engine builds and SM89 component installation are now
connected. Real mpv/ANGLE/Flutter playback, device alignment and release acceptance
remain open. See the
[implementation status](../../docs/feat/animejanai-onnx.md) for scope and limits.
