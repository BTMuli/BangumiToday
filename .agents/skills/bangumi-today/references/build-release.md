# Build & Release Reference

Contents:
1. Required config (never commit)
2. Local dev run
3. Quality gates (local == CI)
4. Release build (local: dev_build.ps1)
5. CI release
6. MSIX config
7. Pitfalls

## Required config (never commit)

- `.dart-define.json` (gitignored) for local runs:
  ```json
  { "BANGUMI_APP_ID": "xxx", "BANGUMI_APP_SECRET": "xxx" }
  ```
- `.env` (gitignored) for local release: `BANGUMI_APP_ID`, `BANGUMI_APP_SECRET`, `MSIX_VERSION` (x.x.x.x), `SIGN_RAW`, `SIGN_SECRET`.
- `BTMuli.pfx` (gitignored) is the local MSIX signing cert (`genSign.ps1` regenerates it); CI uses the `MSIX_CERTIFICATE_BASE64` secret instead.

## Local dev run

- `flutter pub get`
- `flutter run --dart-define-from-file=.dart-define.json` (add `-d windows` / `-d macos`)
- Driver mode: append `--dart-define=ENABLE_FLUTTER_DRIVER=true` (see `$flutter-mcp`).
- Integration boot test: `flutter test integration_test/app_boot_test.dart -d windows --dart-define=BANGUMI_INTEGRATION_TEST=true`

## Local verification

There is no PR / `main` `quality.yml` or `flutter-ci.yml` job.
`release.yml` packages Windows artifacts on `v*.*.*` tags and does not run
`dart analyze` / `flutter test`.

Before committing, run locally:

1. `dart format --output=none --set-exit-if-changed lib test test_driver`
2. `dart analyze --fatal-infos --fatal-warnings lib test test_driver`
3. `flutter test`
4. `flutter build windows --debug`
5. `./scripts/verify_windows_bundle.ps1 -BundlePath build/windows/x64/runner/Debug`

- Desktop journey: `flutter test integration_test/app_boot_test.dart -d windows --dart-define=BANGUMI_INTEGRATION_TEST=true`
- `BT_DOWNLOAD_TEST_ENGINE` gates engine process integration tests; the default `flutter test` skips them.

## Release build (local: `dev_build.ps1`)

1. Reads `.env` for sign secret and version; refuses to build lower than the installed version and prompts to bump `MSIX_VERSION` when equal.
2. Writes a temporary `build_config.json` with app id/secret (removed in `finally`).
3. Builds `repos/bt_download` via CMake preset `windows-x64-release` + ctest (skip tests with `-SkipEngineTests`, or reuse an existing runtime with `-EngineRuntimePath <dir>`).
4. Sets `BT_DOWNLOAD_RUNTIME_DIR`, then `flutter build windows --release --dart-define-from-file=build_config.json`.
5. Verifies the bundle with `scripts/verify_windows_bundle.ps1` (exe present, `bt_download/` runtime files + SPDX-2.3 SBOM, and optional SHA-256 parity against the source runtime).
6. `dart run msix:create --build-windows false --version=<v> -p <sign secret> -c BTMuli.pfx` -> `BangumiToday.msix`.
7. Optionally installs via `Add-AppxPackage` and registers the firewall rule.

## CI release (`.github/workflows/release.yml`)

- Builds the engine on the runner (`VCPKG_INSTALLATION_ROOT`), `flutter build windows --release --dart-define-from-file=build_config.json`, verifies the bundle with SHA-256 parity, zips the Release folder, creates `BangumiToday.msix` plus a Store variant (`dart run msix:create --store true -i 27581BTMuli.BangumiToday -b "CN=5FE33156-..." -n BangumiToday_Store`), uploads artifacts, and drafts a GitHub release.

## MSIX config (`pubspec.yaml` `msix_config`)

- `display_name: BangumiToday`, `identity_name: BangumiToday`, `protocol_activation: BangumiToday`, `logo_path: assets/images/logo.png`, publisher `CN=目棃, C=CN, E=bt-muli@outlook.com`, languages `en-us, zh-cn`.
- `pubspec.yaml` `version: 0.8.0+22` is separate from the MSIX `MSIX_VERSION` in `.env`.

## Pitfalls

- Windows PowerShell 5.1 decodes BOM-less UTF-8 as GBK: read skill/docs files with `-Encoding UTF8` and write UTF-8 files with `[Text.UTF8Encoding]::new($false)`.
- `verify_windows_bundle.ps1` throws on any missing runtime file - the bundled engine is mandatory for Windows builds.
- lint-staged with many staged Dart files at once can freeze the machine; commit at most ~10 files per commit and `amend` for the rest.
- Never commit `.env`, `.dart-define.json`, `build_config.json`, `BTMuli.pfx`, or other secret-bearing files.
