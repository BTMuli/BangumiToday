# AniBT API reference

These are integration notes, not a frozen API specification. Before modifying an endpoint, read its current official Markdown or the [OpenAPI contract](https://wiki.anibt.net/openapi.yaml). Base URL: `https://anibt.net`.

## Choose the feed or query

| Endpoint | Use and current parameters | Official contract |
| --- | --- | --- |
| `GET /rss/magnets.xml` | Public anime release feed. `q` (`search` alias), repeated `resolution` / `language` / `format`, `sortField` (`publishedAt` / `fileSize`), `sortOrder` (`desc` / `asc`), `limit` 1–100, default 100. | [magnets](https://wiki.anibt.net/docs/open-api/rss-magnets.md) |
| `GET /rss/anime.xml` | Filter anime releases by `bgmId` and/or `groupSlug`; at least one is required. Also supports tag filters, subtitle type, `episode`, `episodeKey`, and `limit`. Confirm combinations and types in the schema. | [anime RSS](https://wiki.anibt.net/docs/open-api/rss-anime.md) |
| `GET /rss/group/{slug}.xml` | Public anime releases from a subtitle group. Parameters are the group slug and `limit`; do not assume this endpoint accepts the magnets feed's filters. | [group RSS](https://wiki.anibt.net/docs/open-api/rss-group.md) |
| `GET /rss/other/{category}.xml` | Separate non-anime release feed. `q` / `search`, organization `groupId`, sorting, and `limit`. Read the schema for category codes; a category is not a Bangumi ID. | [other RSS](https://wiki.anibt.net/docs/open-api/rss-other.md) |
| `GET /rss/subscriptions.xml` | Account-generated private subscription feed; use its complete URL. `key` is the personal RSS credential, `token` its alias. `limit` defaults to 50, maximum 200. | [subscription RSS](https://wiki.anibt.net/docs/open-api/rss-subscriptions.md) |
| `GET /api/bgm/search` | Anonymous anime search. `q` is required, maximum 100 characters; `limit` defaults to 5, range 1–25. | [Bangumi search](https://wiki.anibt.net/docs/open-api/bgm-search.md) |
| `GET /api/subtitle-groups` | Subtitle-group directory; optional `status=ACTIVE`. This is a full catalog, not a paginated endpoint. | [subtitle groups](https://wiki.anibt.net/docs/open-api/subtitle-groups.md) |

Public RSS currently has no `cursor` or `page` pagination. Omit explicit default parameters when constructing a canonical feed URL; handle a canonicalizing `308` via `Location`. For filters, read the endpoint's schema instead of reusing parameters from another feed.

## Response and XML details

For public RSS, expect XML on `200`, an empty response on `304`, and often plain-text error bodies on `400`, `404`, `429`, or `503`. Inspect HTTP status and Content-Type before XML/JSON parsing. A Torznab XML error can use HTTP `200`; edge failures may return HTML. A valid empty channel is a successful feed.

The RSS enclosure describes a `.torrent` download with `application/x-bittorrent` and a byte length. AniBT namespaced fields include release/torrent URLs, optional Bangumi ID, anime and release titles, episode/key/version, group, technical specifications, byte size, and repeated language/custom tags. Do not require fields omitted from an individual release. See the [magnets RSS schema](https://wiki.anibt.net/docs/open-api/rss-magnets.md) for the full XML contract.

JSON success envelopes vary: directory/query, `me`, and synchronization use `data`; publish, `whoami`, and deletion use `result`; title matching is unwrapped; preview exposes `previewUrl`. JSON errors carry `ok: false` and `error` details. Decode the endpoint's actual envelope. [API reference](https://wiki.anibt.net/docs/open-api/reference.md)

## Authentication and mutations

- Public directory/query/RSS/torrent endpoints are anonymous.
- Publishing, deletion, synchronization, and API identity use a fansub API key via `Authorization: Bearer …` or `X-API-Key`; Bearer takes precedence when both are supplied.
- Personal RSS `key`/`token` credentials are different from a fansub API key.
- Title matching without `groupId` is anonymous. With `groupId`, it requires a logged-in group-member session; an API key does not replace that session.
- Required scopes include `releases:publish`, `releases:delete`, and `releases:sync:read`. Read the relevant endpoint before user-requested mutations; confirm identity with the documented read-only identity route. A publication receipt includes release identity/revision, not every display field.
- Resource IDs (`rel_…` / `orel_…`), subtitle-group slugs, organization IDs, and Bangumi IDs identify different resources. Use the identifier required by that endpoint.

Source: [authentication, scopes, IDs, and envelopes](https://wiki.anibt.net/docs/open-api/reference.md).

## Caching and retry behavior

Persist the complete representation and ETag for the same request URL before using `If-None-Match`. On `304`, reuse that URL's cached body; the response has no new body. Never apply one URL's ETag/body to another filter or account URL.

Public directory queries, public RSS, and torrent downloads support the documented conditional requests. Private subscriptions and Torznab use `no-store`; do not introduce public ETag caching for them. Mutation, identity, sync, and title-match responses also use `no-store`. Public feeds may redirect to a canonical URL. Publication success does not guarantee immediate appearance in downstream search/RSS.

Source: [caching contract](https://wiki.anibt.net/docs/open-api/caching.md).

Honor `Retry-After` on `429` when present; its value is seconds. Bound read-only retries and avoid concurrent polling of the same feed. Conditional requests can still consume quota. The current guidance recommends ordinary RSS polling intervals of at least five minutes; deployment-specific quotas are not universal constants.

The public RSS query budget is 160 UTF-8 bytes after normalization, which differs from the character limit of Bangumi search. Public RSS `limit` must be a single integer in range; empty, repeated, or malformed values may return `400`. Authentication and validation errors are not generic retry signals, and write requests need endpoint-specific replay handling.

Source: [limits and polling guidance](https://wiki.anibt.net/docs/open-api/limits.md).
