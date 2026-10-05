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
  15 seconds. Five-second mpv samples include hardware decoding, output/decoder
  drops, A/V sync and cache duration. Three-second position stalls, prolonged
  buffering and delayed Dart event-loop ticks produce warnings; pauses and
  completed playback are excluded from position-stall detection.
- `native-<pid>.log` records ANGLE/D3D errors, renderer initialization/disposal
  and aggregate render timing. GPU errors and slow-frame reports are limited
  to one report per five seconds, with normal timing reports every ten seconds.
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
  - Only the latest successfully captured crash is retained, including its full
    dump, triage dump and text report. Once the new triage dump is published,
    older sets are removed before the new full-memory capture starts. If both
    captures fail, the previous usable set remains. Startup retries cleanup and
    removes abandoned partial files; files belonging to an active capture or
    held open by a reader are preserved for a later cleanup. Legacy dump names
    are supported. Native logs, running markers and manual analysis files are
    excluded from retention cleanup.
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
- [Flutter 3.48.0-0.4.pre: shared-handle import and descriptor release](https://github.com/flutter/flutter/blob/3.48.0-0.4.pre/engine/src/flutter/shell/platform/windows/external_texture_d3d.cc).

Verification performed without starting the app or building the project:

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
