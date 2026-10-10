# Security Policy

> 中文版：[安全策略](./docs/安全策略.md)

## Supported versions

BangumiToday is under active development. Security fixes target the latest
public release and are developed on `master`. Older releases do not have
separate security maintenance branches; please update before checking whether
an issue still occurs.

| Version | Security maintenance |
| --- | --- |
| Latest public release | Fixes are provided through updates |
| Earlier releases | No separate backports |
| Unreleased `master` builds | Development builds; stability is not guaranteed |

This is a personal open-source project without a dedicated security response
team or a guaranteed response or fix deadline.

## Report a vulnerability privately

Email [BTMuli](mailto:bt-muli@outlook.com) at **bt-muli@outlook.com** with a
subject such as `BangumiToday security report`.

GitHub private vulnerability reporting is currently disabled for this repository.
Use email; do not publish exploit details, credentials or private data in an
Issue, Discussion or pull request. Ordinary bugs and feature requests belong in
the [Issue templates](https://github.com/BTMuli/BangumiToday/issues/new/choose).

Include, where possible:

- Application version, operating system and installation method (Store, MSIX,
  ZIP or source build).
- Affected component, impact and the conditions needed to trigger the issue.
- Minimal reproduction steps or a proof of concept using synthetic data.
- Relevant, redacted log excerpts and a way to contact you.

The maintainer will assess the report, request details when needed and coordinate
a fix and disclosure with the reporter. Please allow that coordination before
publishing a working exploit. Do not test against other users' accounts or
third-party services without their authorization.

## Scope and data handling

Reports may concern the Flutter application, OAuth and application links, local
storage, RSS/torrent parsing, the bundled `bt_download` engine, Windows playback
components or packaging scripts. For upstream dependencies, identify the affected
version; the maintainer can help determine whether the fix belongs here or upstream.
Availability or policy decisions of Bangumi, RSS providers and mirrors are handled
by those services.

- `BANGUMI_APP_ID` and `BANGUMI_APP_SECRET` are compile-time Dart defines.
  Keeping their source files out of Git does **not** make values embedded in a
  desktop binary unrecoverable.
- Bangumi OAuth tokens and the Mikan subscription token use platform secure
  storage first. Legacy migration and secure-storage failures can retain or write
  a SQLite fallback. Do not assume that every credential is encrypted at rest.
- App configuration, subscriptions, local paths, collections and playback
  progress are stored locally in SQLite/Hive. Private subscription URLs can
  themselves contain credentials.
- Requests go to the selected API, RSS provider, mirror or proxy. Mirrors and
  proxies are separate trust boundaries; authenticated requests may contain
  tokens. BitTorrent also communicates with trackers and peers.
- Logs redact some common credential fields, but URLs, file paths and other
  personal information can remain. Windows crash dumps may contain process
  memory. Review attachments and share dumps privately when needed; do not
  upload the entire application data directory to a public Issue.

Never submit `.env`, `.dart-define.json`, `build_config.json`, private signing
certificates (`*.pfx`, `*.p12`), signing passwords or real account credentials.
The release's public `.cer` certificate contains no private key. If a credential
has already been exposed, revoke or rotate it through its issuing service.
