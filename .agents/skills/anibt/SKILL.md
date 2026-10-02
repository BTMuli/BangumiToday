---
name: anibt
description: "Integrate AniBT RSS and Open API in BangumiToday. Use for AniBT feed URLs and filters, XML release metadata, anime/release display, torrent downloads, subscriptions, authentication, caching, or publishing API work. Also use when interpreting AniBT's official machine-readable documentation. Use bangumi-today for general repository architecture and flutter-mcp for Flutter tooling."
---

# AniBT

## Find the current contract

1. Start with the [official LLM guide](https://wiki.anibt.net/docs/llm.md) and [documentation index](https://wiki.anibt.net/llms.txt). Read only the relevant `/docs/<slug>.md` pages; use [OpenAPI](https://wiki.anibt.net/openapi.yaml) to confirm parameter names, enums, response schemas, and status codes.
2. Documentation lives on `wiki.anibt.net`; production API and RSS requests use `https://anibt.net`. The default Chinese documentation has no language prefix; English uses `/en`, Traditional Chinese `/zh-Hant`.
3. Prefer the raw Markdown and OpenAPI contracts when a cached HTML page disagrees. Inspect a fresh response when changing parsing or display. Treat this skill's endpoint summary as orientation, and verify the current contract before changing network behavior.
4. Use `Accept: text/markdown` to read public AniBT anime/release HTML pages. JSON, RSS, and static resources keep their native formats. Use `/llms-full.txt` or `/llms-full.en.txt` only when the index and individual pages are insufficient.

Keep official source links when summarizing the documentation. The documentation is licensed under CC BY-SA 4.0; consult the LLM guide when redistributing its content.

Read [API reference](references/api-reference.md) for endpoint selection, authentication, caching, limits, and error handling.

## Locate the integration

Paths below are relative to the repository root. Use `$bangumi-today` for architecture and `$flutter-mcp` for analysis, formatting, or app interaction.

| Responsibility | File |
| --- | --- |
| AniBT feed request and base URL | `lib/request/rss/anibt_api.dart` |
| Shared RSS models and namespace-aware parser | `lib/plugins/rss/rss_parser.dart` (exported by `lib/models/rss/rss.dart`) |
| AniBT feed page, search, refresh, lazy list, and website link | `lib/pages/rss-bmf/rb_pw_anibt.dart` |
| RSS query filters, local filtering, and sort rules | `lib/models/rss/anibt_filters.dart` |
| Filter panel and shared metadata chips | `lib/widgets/rss/anibt_filter_dialog.dart`, `lib/widgets/rss/anibt_tag_chip.dart` |
| RSS/BMF tab order and tab icon | `lib/pages/rss-bmf/rss_bmf_page.dart` |
| Release title, metadata, subject navigation, download actions | `lib/widgets/rss/rss_anibt_card_fluent.dart` |
| Background BMF subscriptions | `lib/core/services/bmf_rss_service.dart` |
| Subject RSS integration and persisted subscriptions | `lib/widgets/bangumi/subject_detail/bmf_rss_data.dart`, `lib/database/app/app_rss.dart` |
| AniBT branding | `assets/images/platforms/anibt-logo.png`, `assets/images/platforms/anibt-favicon.ico` |

The feed fetch uses `/rss/magnets.xml`; the page's website action opens `/magnets`. The current tab order is BMF, AniBT, Mikan, Comicat. The card uses the anime name as its main title and allows three lines for the release subtitle. Follow these existing conventions when extending the integration.

## Parse and display releases

- Parse direct item children by namespace URI, not by the literal prefix `anibt`. The AniBT namespace is `https://anibt.net/xmlns/rss/1.0/`; the torrent extension is `https://anibt.moe/xmlns/0.1/`.
- Keep the optional `RssItem.anibt` / `RssAnibtMetadata` model alongside generic RSS fields. Trim text, treat blank optional values as absent, and preserve repeated `language` and `customTag` values. Other feeds must continue to parse without AniBT metadata.
- Prefer structured `animeTitle`, `releaseTitle`, `episodeKey`, `groupName`, resolution, languages, subtitle type, format, file size, and custom tags over extracting these from HTML descriptions or guessing from a release filename. Retain generic title, link, enclosure, and torrent fallbacks for missing metadata.
- Use the RSS `groupSlug` for links to `/group/{slug}`; the display name is not a slug. Keep group navigation unavailable when the slug is missing.
- Treat `bgmId` as optional. Only enable Bangumi subject navigation for a valid positive ID; an unbound anime or non-anime release need not have one.
- Display `BATCH` as a collection, numeric episodes/ranges as episode labels, and preserve other `episodeKey` labels. Keep version/revision information available instead of silently merging releases with the same title.
- Read file sizes as bytes and ignore nonpositive values when selecting a display size. Prefer torrent extension timestamps when present, accept the RSS timestamp fallback, and preserve time-zone offsets before converting for display.
- A feed called “magnets” does not guarantee a magnet URI field. Inspect `torrentUrl`, enclosure, and torrent metadata before choosing the download source. A release page URL is for navigation and must not be passed as a torrent URL.
- Keep complete long titles available through the card's tooltip. Check the card's available height when increasing line counts or adding metadata rows.

## Search and list behavior

- Encode multiple resolution, language, and format values as repeated query keys. Omit default RSS query values; unsupported subtitle filters and episode sorting stay local to the returned window (at most 100 releases).
- If a filtered request specifically returns HTTP 503 with `Search backend unavailable`, fetch the default latest feed and filter its window locally. Show that limited scope in the page; other request failures keep the normal error path.
- Build release rows lazily, cache filtered results until data or filters change, and preserve active download state when its row scrolls out of view. Align metadata chips at the bottom; selected chips change only their background, with no checkmark or selected text-color change.

## Verify changes

For parser or request changes, check a fresh official feed and representative missing metadata, multiple languages/tags, numeric/range/special episode labels, batches, revision fields, and alternate XML prefixes. Include a generic RSS item to verify shared-parser compatibility. For display changes, check long release titles and the card's existing actions.

Run the applicable format and analysis checks from the repository skills. Follow the root `AGENTS.md` rules for temporary verification files and commits. Keep private RSS credentials and API keys out of logs, fixtures, screenshots, and skill examples.
