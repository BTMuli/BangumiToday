# Architecture Reference

Contents:
1. Startup sequence
2. State management
3. Navigation model
4. Persistence (SQLite + Hive)
5. Request layer
6. Key singletons
7. Playback responsibilities

## Startup sequence (`lib/main.dart`)

1. Ensure windowManager, acrylic `Window.initialize()`, and `SystemTheme.accentColor.load()` in parallel.
2. Init log + SQLite, read theme mode, apply window material, show the splash screen.
3. `_initBackgroundServices()`: init log, SQLite, set `BtrBangumiApi` base URL from AppConfig, init Hive, read download config and tracker store; then in parallel start optional services: `BTDownloadTool`, `BTNotifierTool`, and (Windows + `engineEnabled`) the `bt_download` engine with tracker store `effectiveTrackers`. Then init `BTCacheManager` + `LRUCacheManager`, apply window effects, and after a 3s delay start `BmfRssService`.
4. Each optional service failure is logged, not fatal; unrecoverable errors render the splash with the error message.
5. `UncontrolledProviderScope(container: globalContainer)` wraps the app. `globalContainer` is exported from `main.dart` so services (e.g. BMF notifications) can navigate.

## State management

- Riverpod 3; app, navigation, account, tracker and download stores use `NotifierProvider` with immutable state, while `bmfListProvider` uses `AsyncNotifierProvider`. Playback retains `ChangeNotifierProvider` from `package:flutter_riverpod/legacy.dart`. `lib/providers/providers.dart` re-exports the stores.
- Bangumi reads/writes go through `bangumiRepositoryProvider` (`lib/providers/bangumi_providers.dart`): remote API plus SQLite collections. Remote collection failures other than 404 fall back to local rows; 404 deletes the local row.
- BMF subscriptions: `bmfRepositoryProvider` (`lib/providers/bmf_providers.dart`; interface `lib/domain/repositories/bmf_repository.dart`, impl `lib/data/repositories/bmf_repository_impl.dart`). Only the impl triggers the post-write RSS refresh, and it publishes `BmfChange` events that `bmfListProvider` consumes.
- Stores persist through their storage/repository interfaces and then publish state. Riverpod notifiers replace state snapshots; `PlaybackStore` publishes its coordinated media state with `notifyListeners()`.
- `lib/core/services/` singletons expose `instance` (`BmfRssService`, `BangumiOAuthCoordinator`, `BtEngineClient`) and are used without Riverpod; `BTFileTool` / `BTDownloadTool` / `BTNotifierTool` live here, `BTLogTool` in `lib/tools/`, `BTHiveTool` in `lib/database/bt_hive.dart`.

## Navigation model

- `NavWidget` (`lib/widgets/shell/nav.dart`) builds a `NavigationPane` in compact display mode.
- Constant items (`topNavCount` = 4 on Windows, else 3): Bangumi-今日放送 (0), RSS & BMF (1), user page (2), 下载管理 (3, Windows only). Footer: 更多设置 flyout, theme toggle, 应用设置.
- Dynamic subject tabs: `BTNavStore.addNavItemB(subject: id)` creates a `SubjectDetailPage` tab, persists it to Hive box `nav`, and caps at `maxDynamicItems = 50`, evicting the least recently used. `curIndex = topNavCount + navIndex`.
- App links (`AppLinkService`): `bangumitoday://subject/<id>` opens a subject tab; `bangumitoday://oauth?...` is the OAuth callback consumed by `BangumiOAuthCoordinator`.

## Persistence

### SQLite (`BTSqlite` / `BtDatabase`)

- DB file: `<appData>/app/BangumiToday.db`, owned by `BtDatabase` (`lib/database/drift/bt_database.dart`) and opened with `NativeDatabase.createInBackground` at `schemaVersion` **3**. `BtDatabase.open()` acquires the database process lock before opening the executor. `BTSqlite.init()` runs `SELECT 1` so migration and validation finish before business reads.
- The current schema registers **10 tables**:
  - `AppConfig`: key-value settings.
  - `AppBmf`: parent identity and download configuration (`id, subject, title, download, airDate`); `subject` is unique.
  - `AppSubscription`: RSS source URL/configuration, refresh policy, baseline, known and pending item keys; references `AppBmf.id` with cascading deletion, unique on `(bmfId, feedKey)`.
  - `AppRssCache`: raw XML and success/failure metadata shared by `feedKey`. Pending items belong to subscriptions, not this cache.
  - `AppMigrationRecovery`: legacy migration payloads, candidate BMF IDs and resolution state.
  - `AppPlayback`: local playback history.
  - `BangumiCollection`: account collection cache, including v3 `name` / `nameCn` search projections.
  - `BangumiUser`: cached account profile.
  - `BangumiDataSite`: bangumi-data site definitions.
  - `BangumiDataItem`: schedule data with v3 `itemKey` identity and title index.
- Schema evolution lives only in `BtDatabase.migration`. v1 subscriptions are converted to the v2 parent/subscription/cache/recovery structure by `migrations/subscription_migration.dart`; `migrations/catalog_migration.dart` adds the v3 catalog projections and indexes. Existing data is backed up before migration; conversion validates its input and uses transactions. `beforeOpen` validates v3, enables/verifies foreign keys and resolves recoverable no-RSS records. The old `AppRss` table is migration input, not part of the current schema.
- Accessors go through `BTSqlite().db` and Drift's typed queries (`select`/`into`/`update`/`delete`), then map rows into models. Do not add `preCheck()` / `ALTER TABLE` to accessors or silently backfill an unexpected schema in `beforeOpen`.
- Secrets: Mikan token in `flutter_secure_storage` (`BtsMikanCredential`); Bangumi user tokens in secure storage + Hive `bgmUser`.

### Hive

- Boxes opened in `BTHiveTool.init()`: `nav` (`BtmAppNavHive`), `bgmUser` (`BgmUserHiveModel`), `tracker` (`TrackerHiveModel`).
- The tracker box stores BitTorrent tracker URLs; `effectiveTrackers` is merged into the engine config.

### Caches

- `BTCacheManager`: Hive-backed cache keyed by `CacheKeys` with `CacheDuration` max ages (e.g. calendar).
- `LRUCacheManager`: bounded LRU cache for hot data.
- `RssFreshness`: 30-minute freshness window for RSS caching inside `BmfRssService`.

## Request layer

- `BtrClient` variants: plain `BtrClient()`, `withHeader()` (adds UA), `withAuth()` (adds `AuthInterceptor` for token attach + 401 refresh retry).
- All API responses funnel into `BTResponse` (code 0 = success; 666 = generic error).
- `RequestManager` gives keyed dedup/cancel (`RequestKey.*`) and `withRetry` (Dio cancel rethrown, exponential backoff).
- `BtrBangumiApi` rewrites official bgm.tv URLs to the configured mirror (`rewriteUrl` / `rewriteResponseData`).
- `BtrBangumiDataApi` fetches https://unpkg.com/bangumi-data@0.3/dist/data.json and the GitHub latest-release metadata for version checks.

## Key singletons & entry points

| Class | File | Purpose |
|---|---|---|
| `globalContainer` | `lib/main.dart` | Root ProviderContainer used by services for navigation |
| `BTBangumiRepository` | `lib/data/repositories/bangumi_repository_impl.dart` | Bangumi API + local collection cache |
| `BtrBangumiApi` | `lib/request/bangumi/bangumi_api.dart` | Bangumi API client (static base URL) |
| `BtrMikanApi` | `lib/request/mikan/mikan_api.dart` | Mikan RSS/search client |
| `BmfRssService` | `lib/core/services/bmf_rss_service.dart` | Background RSS refresh + notifications |
| `BtEngineClient` | `lib/core/services/bt_engine/client.dart` | bt_download process client |
| `BTSqlite` | `lib/database/bt_sqlite.dart` | SQLite singleton holding the single `BtDatabase` connection |
| `BtDatabase` | `lib/database/drift/bt_database.dart` | Drift schema owner (v3, 10 tables, validated migrations) |
| `BTHiveTool` | `lib/database/bt_hive.dart` | Opens Hive boxes |
| `BTLogTool` | `lib/tools/log_tool.dart` | Structured logging with `sanitize` |
| `BTCacheManager` / `LRUCacheManager` | `lib/core/cache/` | App cache and LRU cache |

## Playback responsibilities

- `lib/store/playback_store.dart` remains the public `ChangeNotifier` facade. It coordinates playlist discovery, media changes, progress/history, subtitles and per-Player subscriptions. Existing callers continue to use the same Store methods and getters.
- `PlaybackAudioController` (`lib/core/services/playback_audio_controller.dart`) owns HiRes/exclusive/loudness preferences, audio metadata, WASAPI observations, refresh timers and output recovery. Preference changes run on the Store's serial queue; delayed refreshes retain the session ID so a previous file cannot change the current file's output.
- `PlaybackUpscaleController` (`lib/core/services/playback_upscale_controller.dart`) owns upscale/TensorRT preferences, lazy TensorRT and benchmark resources, GPU/source recommendations and upscaler construction. The Store retains the per-Player upscaler, texture and viewport lifecycle. Browsing history still avoids initializing inference resources.
- `PlaybackSessionLifecycle` (`lib/core/services/playback_session_lifecycle.dart`) owns the serial operation queue and shutdown bookkeeping. Closing rejects new work; a timeout does not cancel accepted work. UI detachment/work settlement and delayed native destruction retain their separate waits. `PlaybackSession` in `models/playback/playback_completion.dart` still owns media identity and EOF deduplication.
- `lib/pages/playback/playback_controls.dart` owns control State, focus, visibility and gesture/shortcut wiring. Its `playback_page.dart` library parts group commands (`playback_control_commands.dart`), bar/chrome layout (`playback_control_bar.dart`), flyout placement and chapter menus (`playback_control_menus.dart`), reusable buttons (`playback_control_buttons.dart`) and settings/track/upscale menus (`playback_control_settings.dart`). These parts share private State without exposing new page APIs; keep interaction changes separate from responsibility extraction.
