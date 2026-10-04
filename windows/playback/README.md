# Windows playback renderer override

The four `video_output.*` and `angle_surface_manager.*` files derive from
`media_kit_video` 2.0.1 under its MIT license (see `LICENSE`).

`../cmake/playback_renderer.cmake` checks the upstream version and source hashes,
then copies the plugin's native sources into the build directory and substitutes
these files. All translation units use the substituted headers. The Pub cache,
generated plugin registration, Dart API and macOS backend remain untouched.
Review and rebase this override when upgrading the dependency.

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
- Each Flutter callback owns its texture descriptor and retains the matching
  D3D resource. A resized texture is published after its first completed frame
  is copied; the old IDs are retired after Flutter samples the replacement.
  The initial ID is sent with a zero-size rectangle to bootstrap playback.
- Texture reads use the synchronized surface copy, including the first frame
  after resize. `glFinish` and the D3D context flush are retained; each completed
  frame is copied only once. Skipping a busy read was removed because a new
  shared texture has no previous completed image.
- Disposal closes the queue and texture callbacks, drains accepted render work,
  detaches/frees mpv, waits for all active and retired texture unregistrations,
  then releases ANGLE. Unregister callbacks own their state without the player.

This bounds callback backlog and fixes identified render/core wait and texture
handoff hazards. It does not interpolate frames or change the 24 fps cadence.
Actual RTX 4070 playback and fullscreen episode switching still require runtime
verification; headless checks cannot establish that intermittent freezes are
fully resolved.

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
