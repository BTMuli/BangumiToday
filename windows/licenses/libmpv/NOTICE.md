# Windows libmpv runtime

BangumiToday bundles the LGPL Windows x64 libmpv build from:

https://github.com/zhongfly/mpv-winbuild/releases/tag/2026-10-03-413ff0b1cd

Artifact: `mpv-dev-lgpl-x86_64-20261003-git-413ff0b1cd.7z`

Archive SHA-256: `12a9966bad239672c97276f01a9e625504e0b1d1fdcff95256066eeb8ffb1f21`

DLL SHA-256: `6209dfe89b45d726bedc3b932e9321e9d1a49b64b2e1fefdf8c2973e384e7001`

This LGPL build includes the FFmpeg audio filters required for loudness
equalization. The previous media_kit runtime disabled these filters. The
media_kit Dart and video plugins, and their ANGLE runtime, are retained.
Windows explicitly uses D3D11 copy-back decoding (`d3d11va-copy`) for the
embedded ANGLE renderer instead of this runtime's automatic decoder selection.

Build recipe and LGPL configuration:

- https://github.com/zhongfly/mpv-winbuild
- https://github.com/zhongfly/mpv-winbuild/blob/main/compile-lgpl-libmpv.patch
- https://github.com/shinchiro/mpv-winbuild-cmake

Upstream sources and license information:

- mpv: https://github.com/mpv-player/mpv/tree/413ff0b1cd
- FFmpeg: https://github.com/FFmpeg/FFmpeg/tree/c9c354503
- FFmpeg licensing: https://ffmpeg.org/legal.html
- Dependencies and their source locations are recorded in the build recipe.

libmpv is dynamically loaded as `libmpv-2.dll`. Users can replace this library
with a compatible libmpv build. The LGPL v3 license and its GPL v3 base text
are included in this directory. BangumiToday's own license is in the project
root `LICENSE`.
