# Windows libmpv runtime

BangumiToday bundles the Windows x64 libmpv build of the pinned AnimeJaNai mpv
fork from:

https://github.com/the-database/mpv-winbuild/releases/tag/2026-10-07-d6d93599d5

Artifact: `mpv-dev-x86_64-20261007-git-d6d93599d5.7z`

Archive SHA-256: `077cb75fed47b185428f97224e1d798e2d4c2f4063fd8cda2662b74f2892327c`

DLL SHA-256: `90de8f89fa1421eaec510e5cfe11de75846b445489864220ec811fd0f08b4649`

This is the same mpv fork build pinned by the AnimeJaNai 3.7.0
[release manifest](https://github.com/the-database/mpv-AnimeJaNai/releases/download/3.7.0/manifest.json).

This runtime is what makes the AnimeJaNai upscaling filter available: media_kit's
own libmpv build and upstream mpv do not contain `vf_animejanai`, which exists
only in `the-database/mpv`. The build also keeps the FFmpeg audio filters used
for loudness equalization. The media_kit Dart and video plugins, and their ANGLE
runtime, are retained; Windows still explicitly uses D3D11 copy-back decoding
(`d3d11va-copy`) for the embedded ANGLE renderer instead of this runtime's
automatic decoder selection.

## License

mpv's own sources are LGPL-2.1-or-later, but this build enables mpv's GPL-only
parts (rubberband, VapourSynth) and links an FFmpeg configured with
`--enable-gpl` (x264/x265), so the **combined binary is a GPL build**; mpv
documents this as its default `-Dgpl=true` configuration. Redistribution
therefore follows GPL terms: the license texts are included in this directory
(`GPL-3.0.txt`, `LGPL-3.0.txt`), the exact corresponding sources are listed
below, and the runtime can be replaced by the user (see below).

The inference shim that this runtime loads at run time is **not** part of the
libmpv build: `aji.dll` (built from `bangumi_ajishim.dll`) is BangumiToday's own
MIT-licensed code, and the DirectML runtime, the ONNX models and their licenses
are shipped as separate pinned components with their own notices.

## Corresponding sources

- mpv fork (contains `video/filter/vf_animejanai.c` and the fork-only
  `video/filter/refqueue.h` / `filters/filter.h` changes):
  https://github.com/the-database/mpv/tree/d6d93599d59069b715013a6e77e898056499b905
- FFmpeg: https://github.com/FFmpeg/FFmpeg/tree/c0c7684d0
  (the binary reports `FFmpeg version: N-127231-gc0c7684d0`)
- FFmpeg licensing: https://ffmpeg.org/legal.html
- Build recipe and toolchain:
  https://github.com/the-database/mpv-winbuild (workflow `MPV`, inputs
  `mpv_ref`, `libass_ref`, `build_target=64bit`, `compiler=clang`)
  and https://github.com/shinchiro/mpv-winbuild-cmake

The LGPL configuration of the same fork (`mpv-dev-lgpl-*`, produced by running
that workflow with `lgpl=true`, which applies `compile-lgpl-libmpv.patch` with
`-Dgpl=false -Dcplayer=false -Dlibmpv=true`) is the intended replacement for the
constants in `windows/cmake/playback_runtime.cmake` once such a build is pinned.

libmpv is dynamically loaded as `libmpv-2.dll`, so users can replace this library
with a compatible libmpv build. BangumiToday's own license is in the project root
`LICENSE`.
