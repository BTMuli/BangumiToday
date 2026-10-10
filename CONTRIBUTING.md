# Contributing to BangumiToday

> 中文版：[贡献指南](./docs/贡献指南.md)

BangumiToday is a personal Flutter desktop project under active development.
Bug reports, documentation fixes and focused pull requests are welcome. Please
follow the [Code of Conduct](./CODE_OF_CONDUCT.md); report vulnerabilities using
the private contact in the [Security Policy](./SECURITY.md).

## Before making changes

- Search existing Issues and Discussions first. Use the
  [Issue templates](https://github.com/BTMuli/BangumiToday/issues/new/choose) for
  reproducible bugs and concrete feature requests.
- Discuss large features, architecture changes or new native dependencies with
  the maintainer before investing in an implementation.
- Base your branch and pull request on **`master`**, the repository's default
  branch. Keep each change focused and explain its purpose and validation.
- Include the app version, OS and installation method in bug reports. Redact
  tokens, private RSS URLs and personal paths; share crash dumps privately when
  necessary.

## Development environment

The verified SDK baseline is **Flutter beta `3.49.0-0.2.pre`**, matching
[`pubspec.yaml`](./pubspec.yaml) and the
[release workflow](./.github/workflows/release.yml). The Dart constraint is
`>=3.9.0 <4.0.0`; use the Dart SDK bundled with Flutter. Older Flutter versions
below the declared minimum are unsupported.

Windows x64 is the current packaged release target. The repository also contains
a macOS runner, but no macOS release workflow. Linux, mobile and web are not
current project targets. Windows builds require Visual Studio's **Desktop
development with C++** workload, Windows SDK, CMake and vcpkg. The native build
uses `VCPKG_ROOT`, `VCPKG_INSTALLATION_ROOT` or Visual Studio's bundled vcpkg.

Fork the repository if you need to, then clone and install dependencies:

```shell
git clone https://github.com/BTMuli/BangumiToday.git
cd BangumiToday
git submodule init
git config submodule.repos/bt_download.url https://github.com/BTMuli/bt_download.git
git submodule update --init --recursive
flutter pub get
dart run husky install
```

The submodule URL in [`.gitmodules`](./.gitmodules) uses SSH. The local override
above allows HTTPS-only contributors to initialize it without a GitHub SSH key;
it does not modify `.gitmodules`. If SSH is already configured, cloning with
`--recurse-submodules` is sufficient. For an existing checkout, initialize the
submodule before building.

Create a topic branch from `master`. Agents creating a branch use the `codex/`
prefix as configured for this workspace.

## OAuth configuration and running

Create a Bangumi application at [Bangumi developer settings](https://bgm.tv/dev/app).
Set its callback URL to `BangumiToday://oauth/bangumi/callback`, as defined in
[`app_constants.dart`](./lib/core/constants/app_constants.dart). Create the
ignored `.dart-define.json` file in the project root:

```json
{
  "BANGUMI_APP_ID": "your-app-id",
  "BANGUMI_APP_SECRET": "your-app-secret"
}
```

These values are compile-time defines. Flutter does not load `.env` at runtime,
and compile-time injection does not keep secrets unrecoverable from desktop
binaries. Do not commit credentials or signing keys.

Before the first Windows run/build, prepare the pinned playback assets:

```powershell
./scripts/prepare_playback_inference.ps1
flutter run -d windows --dart-define-from-file=.dart-define.json
```

This downloads and verifies the base inference resources and SDK headers under
`.dart_tool/playback_inference/`. CMake checks these files and builds the native
shim; it does not prepare missing inference resources. Full NVIDIA TensorRT
runtime components are installed separately by the user through Settings.

When `BT_DOWNLOAD_RUNTIME_DIR` is unset, Windows CMake also builds and installs
the `bt_download` submodule's Release runtime and bundles it with the runner,
including Debug/Profile builds. A first build can therefore take considerable
time. Set `VCPKG_ROOT` if automatic discovery fails.

For macOS development, use a macOS host with the Flutter desktop toolchain:

```shell
flutter run -d macos --dart-define-from-file=.dart-define.json
```

The bundled download engine, Windows system-proxy integration and native
Anime4K/AnimeJaNai playback enhancements are Windows-specific. A macOS source
checkout does not imply feature parity or a verified packaged release.

## Where changes belong

| Path | Responsibility |
| --- | --- |
| `lib/pages/` | Feature pages and components used only by that page |
| `lib/widgets/` | Components shared by multiple pages |
| `lib/data/`, `lib/domain/`, `lib/request/` | Repositories, parsers and network access |
| `lib/models/` | Data models and generated serialization code |
| `lib/database/drift/` | SQLite schema, generated database and migrations |
| `lib/database/app/`, `lib/database/bangumi/` | Database accessors |
| `lib/providers/`, `lib/store/` | Riverpod wiring and application state |
| `lib/core/` | Shared services, configuration and utilities |
| `windows/playback/` | Windows renderer and inference integration |
| `repos/bt_download/` | C++ download-engine submodule |
| `test/` | Maintained functional regression tests and fixtures |

When changing JSON models or the Drift schema, regenerate and include the
relevant tracked outputs:

```shell
dart run build_runner build --delete-conflicting-outputs
```

Keep migrations for existing installations. The app and `bt_download` ship as
one version: protocol changes must update both sides together. Do not add
compatibility guesses for mismatched app/engine versions. For AniBT work, use
the [AniBT skill](./.agents/skills/anibt/SKILL.md) and current official API documents.

## Style and validation

Follow [`analysis_options.yaml`](./analysis_options.yaml) and
[`AGENTS.md`](./AGENTS.md). Keep dependencies alphabetized by package name within
`dependencies`, `dev_dependencies` and `dependency_overrides`, preserving
versions, sources and associated comments. Match existing UI controls and keep
actions visible; the detailed interaction rules are in `AGENTS.md`.

For Dart changes, run formatting and static analysis for the affected scope.
The repository-wide `lib` checks are:

```shell
dart format --output=none --set-exit-if-changed lib
dart analyze --fatal-infos --fatal-warnings lib
```

Run relevant functional tests when behavior changes. For example, the maintained
comment-parser regression test is:

```shell
flutter test test/bangumi/comment_parser_test.dart
```

Keep lasting functional regression tests and fixtures under `test/`. Put
one-off verification scripts, fixtures and outputs in a purpose-named directory
under `temp/`, then delete them after verification. Do not submit throwaway
verification files. UI interaction tests are not part of the default workflow;
the developer performs UI acceptance manually.

Documentation-only changes need link/content checks, not an app build. Full
builds, launching the app and manual UI checks are performed by the developer
as needed; agents require an explicit request to do them. There is currently
no PR/default-branch quality workflow. Tag packaging does not run Dart analysis
or functional tests, so report the checks actually performed in your PR.

## Windows packaging (manual)

The native runtime is part of the Windows bundle. To reuse a separately built
engine, point `BT_DOWNLOAD_RUNTIME_DIR` at its **complete install directory**,
not its build directory or a lone `bt_download.exe`. Include DLLs, MSVC runtime,
licenses, notices and the SPDX SBOM.

After a Windows build, verify the bundle; adjust the configuration path to the
build you are checking:

```powershell
./scripts/verify_windows_bundle.ps1 `
  -BundlePath build/windows/x64/runner/Release `
  -EngineRuntimePath $env:BT_DOWNLOAD_RUNTIME_DIR
```

Omit `-EngineRuntimePath` if that environment variable is unset. Supplying it
also checks engine files against the source runtime by SHA-256. See the
[playback integration](./windows/playback/README.md) and
[inference preparation](./windows/playback/inference/README.md) for native assets
and third-party notices; the current Windows libmpv binary is a GPL build.

For a local MSIX release, [`dev_build.ps1`](./dev_build.ps1) reads `SIGN_SECRET`
and the four-part `MSIX_VERSION` from the ignored `.env`, and uses `BTMuli.pfx`.
OAuth values come from `.dart-define.json` when it exists, otherwise from `.env`.
It prepares playback resources, builds or reuses the engine, verifies the bundle
and creates the MSIX. `-SkipInstall -SkipFirewallRule` skips its installation
prompt and firewall registration. Temporary `build_config.json` is removed in
`finally`.

The [`v*.*.*` tag workflow](./.github/workflows/release.yml) builds Windows ZIP,
MSIX and Store-MSIX artifacts and creates a **draft** GitHub release. CI uses
`BANGUMI_APP_ID`, `BANGUMI_APP_SECRET`, `MSIX_CERTIFICATE_BASE64` and `SIGN_SECRET`
secrets; the exported `BTMuli.cer` is a public certificate without a private key.
Creating the Store artifact does not itself publish it to Microsoft Store.

Engine tests are opt-in and excluded from both release paths. To run them by
hand inside `repos/bt_download`:

```shell
cmake --preset windows-x64-debug-tests
cmake --build --preset windows-x64-debug-tests
ctest --preset windows-x64-debug-tests
```

## Commits and pull requests

Commit messages may use any language and should clearly describe the change.
The [Gitmoji](https://gitmoji.dev/) style `<emoji> <description>` is recommended,
for example `📝 Update contribution guidelines`, but is not required. Choose an
emoji that matches the change intent; the
[selection reference](./.agents/skills/gitmoji-commit/references/emoji-selection.md)
can help.

Keep commits focused. The installed pre-commit hook sorts imports, formats
tracked Dart files in batches and runs `lint_staged`; it may change files beyond
the ones you edited. Review the working tree afterward. Large staged Dart
changes can make `lint_staged` resource-intensive. Split by independent purpose
where appropriate; a file-count threshold is not a reason to rewrite history.

Agents must stop at the working tree after completing an authorized change and
only commit, amend, rebase, cherry-pick, revert or push when explicitly requested
by the user, as required by `AGENTS.md`.

Open the PR against `master`, describe the problem and resulting behavior, link
related Issues and list validation results and limitations. Include updated
documentation and relevant generated files. For UI changes, add developer-made
screenshots when available and state any manual acceptance still outstanding.
