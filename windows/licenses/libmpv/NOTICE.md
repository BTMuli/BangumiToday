# Windows libmpv runtime

BangumiToday bundles the Windows x64 libmpv build of the pinned AnimeJaNai mpv
fork from:

https://github.com/the-database/mpv-winbuild/releases/tag/2026-11-12-042613482d-addons-43119200800

Artifact: `mpv-dev-x86_64-20261111-git-042613482d.7z`

Archive SHA-256: `6a4ee99fbcba03e99af3190ff60bd8124fc112946646f86e1b6f3d674724c2dc`

DLL SHA-256: `77fec11d11a566c612f68f7fc70863412f9975cf1caa7e2b203442fed4d743b2`

This is the native producer pinned by AnimeJaNai 3.11.1's
[package builder](https://github.com/the-database/mpv-AnimeJaNai/blob/0e85115cbce2a12f87239ebd4e6606ec9008a782/BuildMpvUpscale2xAnimeJaNai/Program.cs).
Its [native metadata](https://github.com/the-database/mpv-winbuild/releases/download/2026-11-12-042613482d-addons-43119200800/mpv-addon-native-x86_64.json)
also records the DLL hash and build configuration.

This runtime is what makes the AnimeJaNai upscaling filter available: media_kit's
own libmpv build and upstream mpv do not contain `vf_animejanai`, which exists
only in `the-database/mpv`. The build also keeps the FFmpeg audio filters used
for loudness equalization. The media_kit Dart and video plugins, and their ANGLE
runtime, are retained; Windows explicitly uses D3D11 GPU decoding (`d3d11va`)
for plain playback, Anime4K and AnimeJaNai with the embedded ANGLE renderer
instead of this runtime's automatic decoder selection. Upscaling changes leave
the decoder configuration unchanged.

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
  https://github.com/the-database/mpv/tree/042613482dd6fad51a0cf8dc728cd74d2a9ad665
- FFmpeg: https://github.com/FFmpeg/FFmpeg/tree/72f8c3376
  (the binary reports `FFmpeg version: N-128820-g72f8c3376`)
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
