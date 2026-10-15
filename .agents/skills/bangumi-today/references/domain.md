# Domain Reference

Contents:
1. Bangumi.tv API
2. OAuth
3. BangumiData
4. RSS sources & parsing
5. BMF subscriptions
6. bt_download engine

## Bangumi.tv API

- Base URLs (`lib/core/constants/app_constants.dart`): site, API and image mirrors are selected independently. Fresh defaults are VIP site `bangumi.vip`, official API `https://api.bgmapi.com` and AniBT images `bgmimg.anibt.net`; each selector offers official (`bgm.tv` / `api.bgmapi.com` / `lain.bgm.tv`), VIP (`bangumi.vip` / `api.bangumi.vip` / `lain.bangumi.vip`) and AniBT (`bgmmi.anibt.net` / `bgmapi.anibt.net` / `bgmimg.anibt.net`). There is no separate bgmapi selection. AppConfig keeps the API in `bangumiUrl`, site in `bangumiSiteUrl` and images in `bangumiImageUrl`; `readBangumiMirrors()` transactionally initializes fresh settings with independent defaults, while missing site/image selections in legacy settings are derived from the saved API choice. Existing explicit selections are preserved. Old PRO settings migrate to VIP and old `api.bgm.tv` settings migrate to `api.bgmapi.com`. Changing one selector preserves the other two. `rewriteBangumiUrl` maps official and cached mirror links to the corresponding selection; `fast` follows images, `doujin` follows the site, and Next requests follow the API (VIP uses `next.bangumi.vip`, others use `next.bgm.tv`). Startup and the playback child window apply all three selections.
- Client `BtrBangumiApi` (docs: https://bangumi.github.io/api/): `/calendar`, `POST /v0/search/subjects` (filter `type`/`tag`/`airdate`/`rating`/`rank`/`nsfw`, sort `match|heat|rank|score`), subject detail/episodes/characters/persons, user info and collections, plus legacy v2 endpoints.
- Models live in `lib/models/bangumi/` split per domain (subject, episode, character, person, collection, user, revision, patch, index, legacy) with generated JSON; `bangumi_enum.dart` holds subject types, episode types, and collection status.
- Custom mirrors: `lib/models/app/bangumi_mirror.dart` owns the three mirror types, protected built-ins, name/origin validation, duplicate checks and immutable custom catalog. Each type supports adding, editing and deleting named HTTP/HTTPS origins with optional ports; paths, query strings, fragments and credentials are rejected. Adding selects the new mirror; editing updates its selected address; deleting the selected mirror restores that type's default. AppConfig transactionally saves `bangumiCustomMirrors` together with the selection. The catalog retains old origins for rewriting cached links after edits/deletions, including after restart, and is synchronized to the playback window. OAuth remains fixed on official endpoints.
- Requests go through `RequestManager` with `RequestKey` entries: `bangumi_calendar`, `subject_detail_<id>`, `subject_episodes_<id>`, `user_collection_<user>_<id>`, `user_collections_<user>`, `search_<kw>_<offset>[_tag_...]`, `rss_<source>`.

## OAuth

- Flow (`BangumiOAuthCoordinator.authorize`): authorization always uses official OAuth, independently of site/API/image mirror choices. Open `https://bgm.tv/oauth/authorize` with app id, `redirect_uri=BangumiToday://oauth/bangumi/callback`, and random base64url `state` (the authorize page stays on the site host: the API host's login fallback is a frontend shell whose `/p1/login` is not served there, so login cannot complete); wait for the app-link callback `bangumitoday://oauth?...` (5-minute timeout), validate `state`, then exchange the code at `https://api.bgmapi.com/oauth/access_token` (form body, same `redirect_uri`). Refresh uses that same endpoint with `grant_type=refresh_token`. Its [upstream OAuth implementation](https://github.com/bangumi/server-private/blob/master/routes/oauth/index.ts) returns `user_id` as a decimal string; the token model accepts both that and the legacy numeric ID. The legacy `/oauth/token_status` remains on `bgm.tv`. HTTP 200 OAuth error payloads such as `app_nonexistence` and non-JSON responses are treated as failures; OAuth never retries through a mirror.
- Credentials `BANGUMI_APP_ID` / `BANGUMI_APP_SECRET` are compile-time dart-defines, never shipped as assets. Tokens persist via `BgmUserHive` + secure storage; `AuthInterceptor` refreshes on 401.

## BangumiData

- `BtrBangumiDataApi` pulls https://unpkg.com/bangumi-data@0.3/dist/data.json (anime schedule metadata) and stores it into the `BangumiDataSite` / `BangumiDataItem` SQLite tables in batches; used to backfill air dates.

## RSS sources & parsing

- Self-built parser `lib/data/parsers/rss_parser.dart` (`RssFeed` / `RssItem`, re-exported by `lib/models/rss/rss.dart`) on `package:xml`. It supports standard RSS 2.0 plus the `<torrent>` extension (AniBT) and Mikan's pubDate inside `<torrent>` (fallback when `<item><pubDate>` is absent); `SafeParseDateTime` handles RFC-822 dates.
- Mikan (`BtrMikanApi`, default base https://mikanani.kas.pub; official https://mikanani.me is a selectable preset): `/RSS/Classic`, `/RSS/MyBangumi?token=...`, `/RSS/Bangumi?bangumiId=<id>&subgroupid=<gid>`, `/Home/Search?searchstr=...`, plus arbitrary custom RSS fetch. Token is stored in secure storage.
- AniBT (`AnibtAPI`): `https://anibt.net/rss/magnets.xml`.
- Comicat (`ComicatAPI`): `https://www.comicat.org/rss.xml`.
- RSS pages: `lib/pages/rss_bmf/` (`rss_bmf_mikan`, `rss_bmf_anibt`, `rss_bmf_comicat`, `rss_bmf_workspace`) plus that page's own source cards and filter dialog; shared BMF components in `lib/widgets/bmf/`.

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
- Download UI: `lib/pages/download/download_page.dart` (task list) and `download_task_details.dart` (tabs: overview, progress, files, peers).
