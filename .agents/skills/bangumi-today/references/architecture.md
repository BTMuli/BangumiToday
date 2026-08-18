# Architecture Reference

Contents:
1. Startup sequence
2. State management
3. Navigation model
4. Persistence (SQLite + Hive)
5. Request layer
6. Key singletons

## Startup sequence (`lib/main.dart`)

1. Optional `enableFlutterDriverExtension()` when `--dart-define=ENABLE_FLUTTER_DRIVER=true`.
2. Ensure windowManager, acrylic `Window.initialize()`, and `SystemTheme.accentColor.load()` in parallel.
3. Init log + SQLite, read theme mode, apply window material, show the splash screen.
4. `_initBackgroundServices()`: init log, SQLite, set `BtrBangumiApi` base URL from AppConfig, init Hive, read download config and tracker store; then in parallel start optional services: `BTDownloadTool`, `BTNotifierTool`, and (Windows + `engineEnabled`) the `bt_download` engine with tracker store `effectiveTrackers`. Then init `BTCacheManager` + `LRUCacheManager`, apply window effects, and after a 3s delay start `BmfRssService`.
5. Each optional service failure is logged, not fatal; unrecoverable errors render the splash with the error message.
6. `UncontrolledProviderScope(container: globalContainer)` wraps the app. `globalContainer` is exported from `main.dart` so services (e.g. BMF notifications) can navigate.

## State management

- Riverpod 3; store providers import `package:flutter_riverpod/legacy.dart` and use `ChangeNotifierProvider` / `AsyncNotifierProvider` (`appStoreProvider`, `navStoreProvider`, `bmfListProvider`, `bmfNavigationProvider`, `btDownloadStoreProvider`). `lib/providers/providers.dart` re-exports the stores.
- Bangumi reads/writes go through `bangumiRepositoryProvider` (`lib/providers/bangumi_providers.dart`): remote API plus SQLite collections. Remote collection failures other than 404 fall back to local rows; 404 deletes the local row.
- Store classes in `lib/store/` are `ChangeNotifier`s: write to SQLite/Hive, then `notifyListeners()`.
- `lib/tools/` classes are stateless singletons (`BTLogTool`, `BTHiveTool`, `BTFileTool`, `BTDownloadTool`, `BTNotifierTool`); call them without Riverpod.
- `lib/core/services/` singletons expose `instance` plus `forTesting` constructors with injected dependencies (see `BmfRssService`, `BangumiOAuthCoordinator`, `BtEngineClient`).

## Navigation model

- `AppNavWidget` builds a `NavigationPane` in compact display mode.
- Constant items (`topNavCount` = 4 on Windows, else 3): Bangumi-今日放送 (0), RSS & BMF (1), user page (2), 下载管理 (3, Windows only). Footer: 更多设置 flyout, theme toggle, 应用设置.
- Dynamic subject tabs: `BTNavStore.addNavItemB(subject: id)` creates a `SubjectDetailPage` tab, persists it to Hive box `nav`, and caps at `maxDynamicItems = 50`, evicting the least recently used. `curIndex = topNavCount + navIndex`.
- App links (`AppLinkService`): `bangumitoday://subject/<id>` opens a subject tab; `bangumitoday://oauth?...` is the OAuth callback consumed by `BangumiOAuthCoordinator`.

## Persistence

### SQLite (`BTSqlite`)

- DB file: `<appData>/app/BangumiToday.db`, opened with `sqflite_common_ffi` at version 1.
- Tables: `AppConfig` (key-value settings), `AppBmf` (subject -> Mikan RSS + download dir; columns `subject, title, airDate, rss, download, autoUpdate, mkBgmId, mkGroupId`), `AppRss` (cached raw RSS XML per URL/mkId, with `ttl`, `updated`, `pendingItemKeys`), `BangumiCollection`, `BangumiUser`, `BangumiDataSite` / `BangumiDataItem` (bangumi-data schedule).
- Every table class has `preCheck()` with `PRAGMA table_info` guarded `ALTER TABLE` migrations for old installs; always run `preCheck()` before queries.
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
| `BtrMikanApi` | `lib/plugins/mikan/mikan_api.dart` | Mikan RSS/search client |
| `BmfRssService` | `lib/core/services/bmf_rss_service.dart` | Background RSS refresh + notifications |
| `BtEngineClient` | `lib/core/services/bt_engine/client.dart` | bt_download process client |
| `BTSqlite` | `lib/database/bt_sqlite.dart` | SQLite singleton |
| `BTHiveTool` | `lib/tools/hive_tool.dart` | Opens Hive boxes |
| `BTLogTool` | `lib/tools/log_tool.dart` | Structured logging with `sanitize` |
| `BTCacheManager` / `LRUCacheManager` | `lib/core/cache/` | App cache and LRU cache |
