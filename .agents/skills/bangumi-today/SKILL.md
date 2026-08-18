---
name: bangumi-today
description: "Navigate, analyze, and modify the BangumiToday Flutter codebase: its layered architecture, Bangumi.tv API and OAuth, Mikan/AniBT/Comicat RSS aggregation, BMF subscriptions, the bundled bt_download engine protocol, SQLite/Hive persistence, Riverpod state, and the Windows build/release pipeline. Use when working on this repo's Dart code, deciding where a change belongs, adding pages, models, database tables, or features, or running project-specific build, test, and commit workflows. Do not use for driving or profiling the running app - use $flutter-mcp and $flutter-agent-lens for those."
---

# BangumiToday Codebase

## Overview

BangumiToday is a desktop-only Flutter app (Windows/macOS) that aggregates Bangumi.tv data with Mikan / AniBT / Comicat RSS feeds. Features: today calendar, subject search & detail, user collection, "RSS & BMF" subscriptions (with torrent download), and a BitTorrent download manager backed by the bundled `bt_download` engine.

Stack: `fluent_ui` + `flutter_acrylic` (UI), Riverpod 3 via `hooks_riverpod` (state), SQLite via `sqflite_common_ffi` + Hive (storage), `dio` (network), `json_serializable` (codegen).

## Skill boundaries

- This skill: static codebase knowledge, architecture, domain model, conventions.
- `$flutter-mcp`: launching/driving the app, tests, analyze/format, pub dependencies, widget tree inspection.
- `$flutter-agent-lens`: profiling/debugging a running app (jank, memory, CPU, network).

## Codebase map

| Path | Responsibility |
|---|---|
| `lib/main.dart` | Startup sequence, background service bootstrap, global ProviderContainer |
| `lib/app.dart` | FluentApp shell, theme / window material sync |
| `lib/controller/` | Page-scoped controllers (nav index, progress) |
| `lib/core/` | Cross-cutting: constants, cache, layout, theme, services, errors, window effects |
| `lib/data/` + `lib/domain/` | Bangumi repository：远程 API + 收藏 SQLite 本地源 |
| `lib/database/` | SQLite access: `app/` (AppConfig, AppBmf, AppRss, Mikan credential) and `bangumi/` (user, collection, data) |
| `lib/models/` | JSON / Hive / database models with generated `.g.dart` |
| `lib/pages/` | Feature pages (`app`, `app-setting`, `bangumi-calendar`, `rss-bmf`, `subject-detail`, `subject-search`, `user-collection`) |
| `lib/plugins/` | Mikan API + self-built RSS parser |
| `lib/providers/` | Riverpod provider exports；`bangumi_providers.dart` 组装 Bangumi 仓储 |
| `lib/request/` | dio clients: `bangumi/`, `rss/`, `core/` (BtrClient, RequestManager) |
| `lib/store/` | ChangeNotifier stores (app, nav, bmf, download) + Hive boxes |
| `lib/tools/` | Stateless utility singletons (log, hive, download, file, notifier) |
| `lib/ui/` | Shared dialogs, infobars, icons, engine switch |
| `lib/utils/` | Small helpers (Bangumi URL / rating utils) |
| `lib/widgets/` | Reusable widgets grouped by domain |
| `test/`, `integration_test/`, `test_driver/` | Unit/widget tests, boot integration test, flutter_driver scripts |
| `repos/bt_download` | C++ download engine submodule (CMake/vcpkg, libtorrent) |

## Core workflows

### Decide where a change belongs

- UI page: add under `lib/pages/<feature>/`; register as a constant `PaneItem` in `lib/widgets/app/app_nav.dart` or add dynamically via `BTNavStore.addNavItemB(subject: id)` (subject detail tabs).
- Data model: add under `lib/models/` with `@JsonSerializable()` and regenerate `.g.dart`.
- Database table / column: add or alter in `lib/database/<domain>/`, following the `preCheck()` + `PRAGMA table_info` migration pattern - never assume a column exists on old installs.
- Network call: extend `BtrBangumiApi`, `BtrMikanApi`, or the RSS clients; wrap with `RequestManager` (dedup/cancel) and cache via `BTCacheManager`.
- Background work: add a singleton service in `lib/core/services/` with an `instance` and an injectable `forTesting` constructor; wire it into `_initBackgroundServices()` in `lib/main.dart`.

### Add a JSON model

1. Create `lib/models/<domain>/<name>.dart` with `part '<name>.g.dart';` and `@JsonSerializable()`.
2. Run `dart run build_runner build --delete-conflicting-outputs`.
3. Commit the generated `.g.dart` files (they are checked in; formatting excludes them).

### Add a SQLite table

Follow the pattern in `lib/database/app/app_bmf.dart`: singleton accessor, `preCheck()` creating the table, `PRAGMA table_info` guarded `ALTER TABLE` migrations for backward compatibility, and `read/write/delete` helpers that call the relevant service hooks (e.g. `BmfRssService.onBmfWritten` / `onBmfDeleted`).

### Code quality (local, before commit)

- `dart format --output=none --set-exit-if-changed lib test test_driver`
- `dart analyze --fatal-infos --fatal-warnings lib test test_driver`
- `flutter test` (engine integration tests are gated by `BT_DOWNLOAD_TEST_ENGINE` and skipped by default)
- Windows bundle check: `./scripts/verify_windows_bundle.ps1 -BundlePath build/windows/x64/runner/Debug` after `flutter build windows --debug`
- Import sorting: `dart run import_sorter:main`
- Lint traps in `analysis_options.yaml`: 80-char line limit, `unawaited_futures`, `always_declare_return_types`, `prefer_relative_imports`.

## Runtime requirements

- Flutter **beta >= 3.46.0-0.1.pre** (stable 3.44.x misses the OverlayPortal layout fix and asserts in navigation layout); Dart SDK >= 3.9.0 < 4.0.0.
- Local run needs a gitignored `.dart-define.json` with `BANGUMI_APP_ID` / `BANGUMI_APP_SECRET` (create an app at https://bgm.tv/dev/app):
  `flutter run --dart-define-from-file=.dart-define.json`
- `repos/bt_download` must exist: `git submodule update --init --recursive`.
- Install hooks once: `dart run husky install` (enables lint-staged).

## Git & commits

- Commit messages use Gitmoji (`<emoji> <description>`), e.g. `🐛` fix, `✨` feature, `♻️` refactor, `💄` UI. No Conventional Commit prefixes. See AGENTS.md.
- `lint-staged` runs on commit; committing many files at once spawns heavy processes that can freeze the machine - keep each commit to at most ~10 files and use `amend` for the remainder.

## Plan documents (docs/)

- When the user asks to create a plan (design, proposal, or refactoring plan), write the plan document under `docs/`; feature plans follow the existing `docs/feat/` convention with a short descriptive filename.
- Do not commit plan documents to git by default; keep them out of `git add` / commit unless the user explicitly asks to commit them.
- While executing tasks against a plan, update the plan document as work progresses: mark completed items, record any deviations from the plan, and refresh status and remaining todos so the document always reflects the latest state.

## References

Read only what the task needs:

- `references/architecture.md` - startup sequence, data flow, state/persistence, request layer, key singletons. Read when tracing a feature end-to-end or deciding where code belongs.
- `references/domain.md` - Bangumi API/OAuth/mirrors, BangumiData, RSS sources, BMF model and refresh semantics, bt_download engine protocol. Read when touching network or domain logic.
- `references/build-release.md` - env vars, local dev run, `dev_build.ps1`, bundle verification, CI/release workflows, MSIX. Read before building or packaging.
