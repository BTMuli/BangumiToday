# Domain Reference

Contents:
1. Bangumi.tv API
2. OAuth
3. BangumiData
4. RSS sources & parsing
5. BMF subscriptions
6. bt_download engine

## Bangumi.tv API

- Base URLs (`lib/core/constants/app_constants.dart`): default mirror API `https://bgmapi.anibt.net` (site `https://bgmmi.anibt.net`, images `https://bgmimg.anibt.net`); official `api.bgm.tv` / `bgm.tv` / `lain.bgm.tv`; and `api.bangumi.lol` (with `fast`/`next`/`doujin` mirrors). The user-selected endpoint is stored in AppConfig; `rewriteBangumiUrl` maps official hosts to the active mirror.
- Client `BtrBangumiApi` (docs: https://bangumi.github.io/api/): `/calendar`, `POST /v0/search/subjects` (filter `type`/`tag`/`airdate`/`rating`/`rank`/`nsfw`, sort `match|heat|rank|score`), subject detail/episodes/characters/persons, user info and collections, plus legacy v2 endpoints.
- Models live in `lib/models/bangumi/` split per domain (subject, episode, character, person, collection, user, revision, patch, index, legacy) with generated JSON; `bangumi_enum.dart` holds subject types, episode types, and collection status.
- Requests go through `RequestManager` with `RequestKey` entries: `bangumi_calendar`, `subject_detail_<id>`, `subject_episodes_<id>`, `user_collection_<user>_<id>`, `user_collections_<user>`, `search_<kw>_<offset>[_tag_...]`, `rss_<source>`.

## OAuth

- Flow (`BangumiOAuthCoordinator.authorize`): open `<site>/oauth/authorize` with app id + random base64url `state`, wait for the app-link callback `bangumitoday://oauth?code=...&state=...` (5-minute timeout), validate `state`, exchange the code at `/oauth/access_token` (form-encoded), then fetch user info.
- Credentials `BANGUMI_APP_ID` / `BANGUMI_APP_SECRET` are compile-time dart-defines, never shipped as assets. Tokens persist via `BgmUserHive` + secure storage; `AuthInterceptor` refreshes on 401.

## BangumiData

- `BtrBangumiDataApi` pulls https://unpkg.com/bangumi-data@0.3/dist/data.json (anime schedule metadata) and stores it into the `BangumiDataSite` / `BangumiDataItem` SQLite tables in batches; used to backfill air dates.

## RSS sources & parsing

- Self-built parser `lib/plugins/rss/rss_parser.dart` (`RssFeed` / `RssItem`) on `package:xml`. It supports standard RSS 2.0 plus the `<torrent>` extension (AniBT) and Mikan's pubDate inside `<torrent>` (fallback when `<item><pubDate>` is absent); `SafeParseDateTime` handles RFC-822 dates.
- Mikan (`BtrMikanApi`, default base https://mikanani.kas.pub; official https://mikanani.me is a selectable preset): `/RSS/Classic`, `/RSS/MyBangumi?token=...`, `/RSS/Bangumi?bangumiId=<id>&subgroupid=<gid>`, `/Home/Search?searchstr=...`, plus arbitrary custom RSS fetch. Token is stored in secure storage.
- AniBT (`AnibtAPI`): `https://anibt.net/rss/magnets.xml`.
- Comicat (`ComicatAPI`): `https://www.comicat.org/rss.xml`.
- RSS pages: `lib/pages/rss-bmf/` (`rb_pw_mikan`, `rb_pw_anibt`, `rb_pw_comicat`); cards in `lib/widgets/rss/`.

## BMF subscriptions

- Model `AppBmfModel` (table `AppBmf`): `subject` (Bangumi id), `title`, `airDate`, `rss` URL, `download` dir, `autoUpdate`, and `mkBgmId` / `mkGroupId` parsed from the Mikan RSS URL query.
- `BmfRssService` (singleton, started ~3s after boot, refresh every 15 min):
  - Freshness cache 30 min; concurrency 4; per-source max 4 attempts with exponential backoff + jitter (max 2 min); failure backoff recovery window 5 min; bulk refresh is single-flight; per-key refreshes are serial.
  - Tracks `knownItems` (keys `title|pubDate`) per subscription; only genuinely new items produce `BmfRssUpdateEvent` and a mini notification. `pendingItemKeys` is persisted in `AppRss`.
  - Notifications navigate to the RSS & BMF page through `globalContainer`.
  - `lastRefreshMetrics` exposes cache hits / requests / successes / failures / backoff skips / peak concurrency / elapsed ms (asserted by tests).
- `BTDownloadTool` downloads `.torrent` files into the app-data download dir before handing them to the engine.

## bt_download engine

- C++ submodule `repos/bt_download` (CMake preset `windows-x64-release`, vcpkg toolchain, libtorrent). Bundled runtime lives at `<app>/bt_download/` with `bt_download.exe`, `torrent-rasterbar.dll`, OpenSSL / VC runtime DLLs, `sbom.spdx.json` (SPDX-2.3), `THIRD_PARTY_NOTICES.txt`, and `licenses/`.
- Wire protocol in `lib/core/services/bt_engine/`: JSON messages over the child process stdio; protocol version `1.2` (`btEngineProtocolVersion`), max frame 1 MiB; client state machine `stopped -> starting -> ready -> stopping -> failed`.
- Config `BtDownloadConfig` -> `toEngineJson()` drops app-only flags, ANDs `seedingEnabled` with the disclosure acceptance, and adds `additionalTrackers`; `validate()` enforces ranges.
- Snapshots: `BtTaskSnapshot` (state, `sourceKind`, `savePath`, progress, rates, peers/seeds, `isPrivate`, seed limits, `lastError`), `BtTaskFileDetail` (priority 0 = skip), `BtTaskPeerDetail`, and paged `BtTaskFilesResult` / `BtTaskPeersResult` (offset/limit windows with `truncated` + `nextOffset`).
- `BtEngineClient` spawns `<host>/bt_download/bt_download.exe`, sends requests with a 10s timeout, and exposes event / task snapshot / state streams.
- Windows firewall rule `BangumiToday bt_download engine` (inbound allow) is registered at build/install time.
- Download UI: `lib/pages/app/download_page.dart` (task list) and `download_task_details.dart` (tabs: overview, progress, files, peers).
