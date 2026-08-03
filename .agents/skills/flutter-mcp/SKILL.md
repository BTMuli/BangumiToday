---
name: flutter-mcp
description: Use the official Dart and Flutter MCP server (the `dart` MCP server) to develop, analyze, test, and interactively drive the BangumiToday Flutter app. Invoke when analyzing or fixing Dart code, running tests, managing pub dependencies, formatting, inspecting the widget tree, or connecting to and driving a running app (screenshot, tap, scroll, hot reload) via flutter_driver. Also use it to write and run standalone `test_driver/*.dart` verification scripts against a live app.
---

# Flutter MCP

## Overview

This project connects to the official Dart and Flutter MCP server, registered in Codex as the `dart` MCP server. The server bundled with the Flutter SDK on this machine reports version **0.1.4** (`dart mcp-server --version`), and this document is verified against that exact binary (Dart SDK 3.12.2, `flutter run -d windows`/`-d macos`).

Prefer MCP tools over ad-hoc shell commands for anything they cover, but only use tools that are actually registered in the current session (see below). If a tool is missing, fall back to the shell command instead of retrying the MCP call.

## MCP server setup (read first)

### Required server args

Since server 0.1.3, the Dart MCP server disables several tool groups by default:

- `cli` tools (`run_tests`, `dart_fix`, `dart_format`, `create_project`) are disabled by default.
- `flutter_app_lifecycle` tools (`launch_app`, `stop_app`, `list_devices`, `get_app_logs`, `list_running_apps`) are disabled by default.
- `get_active_location` is disabled by default.

If `~/.codex/config.toml` still uses the bare invocation, calls to those tools fail with `No tool registered with the name <name>`. The recommended entry is:

```toml
[mcp_servers.dart]
command = "dart"
args = ["mcp-server", "--force-roots-fallback", "--enable", "cli", "--enable", "flutter_app_lifecycle"]
```

`--enable get_active_location` can be appended if that niche tool is wanted. Any change to these args requires restarting Codex.

### Verify the tool list

Do not trust this document blindly; the tool set depends on the server version and the `--enable` flags. Before relying on a tool, verify it is registered (check the session tool list, or `/mcp` in the CLI). A quick way to see the real list from a shell:

```powershell
@'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1.0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
'@ | dart mcp-server --force-roots-fallback --enable cli --enable flutter_app_lifecycle
```

### Register the project root

Root-scoped tools (`run_tests`, `dart_fix`, `dart_format`, `pub`, `launch_app`, `read_package_uris`, `rip_grep_packages`) only accept roots the client has granted. Because this machine runs with `--force-roots-fallback`, add the project root once per session before using any of them:

`roots` tool: `command: "add"`, `uris: ["file:///D:/Code/App/bangumi_today"]`

## Verified tool inventory (server 0.1.4 + the args above)

Available by default (11 tools):

| Tool | Purpose |
|---|---|
| `roots` | add/remove project roots (call `add` first) |
| `read_package_uris` | read `package:` / `package-root:` URIs in dependencies |
| `rip_grep_packages` | ripgrep inside package dependencies (`searchDir: ""` searches the whole package, e.g. `example/`) |
| `pub` | `add`/`get`/`remove`/`upgrade`/`outdated`/`deps` on `pubspec.yaml` |
| `pub_dev_search` | search pub.dev for packages |
| `dtd` | `listDtdUris` -> `connect` -> `listConnectedApps` (live app connection) |
| `widget_inspector` | `get_widget_tree`, `get_selected_widget`, `set_widget_selection_mode` |
| `flutter_driver_command` | drive the connected app: tap, scroll, waitFor, screenshot, ... |
| `get_runtime_errors` | recent runtime errors from the connected app (`clearRuntimeErrors` to reset) |
| `hot_reload` / `hot_restart` | apply code changes to the running app |

Enabled by `--enable cli` (4 extra): `run_tests`, `dart_fix`, `dart_format`, `create_project`.

Enabled by `--enable flutter_app_lifecycle` (5 extra): `launch_app`, `stop_app`, `list_devices`, `get_app_logs`, `list_running_apps`.

Not available on this SDK, do not rely on them:

- `analyze_files` and `lsp` are **not registered** even with `--enable all`: server 0.1.4 spawns `dart language-server --protocol lsp`, but that command was removed from Dart SDK 3.12. Use shell `flutter analyze` / `dart analyze` instead.
- `flutter_driver_user_journey_test` is an MCP **prompt** (via `prompts/list`), not a tool: it instructs the agent to accomplish a user journey in the running app with flutter driver commands.

## Debugging the running app

The app's `main()` gates `enableFlutterDriverExtension()` behind the compile-time flag `ENABLE_FLUTTER_DRIVER`, so the driver is only active when explicitly requested and never ships in production builds. There are two ways to debug, and both require launching with the flag.

### Discovering the running app's URIs (DTD / VM service)

If you are handed a DTD address like `ws://127.0.0.1:<dtdPort>/<token>/ws`, or need the VM service URL for a driver script, find the `development-service` process - it owns both endpoints:

```powershell
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'development-service' } | Select-Object ProcessId, CommandLine
```

- Its `--vm-service-uri=http://127.0.0.1:<vmPort>/<vmToken>=/` is the URL to pass to `FlutterDriver.connect` (Path B below).
- The DTD ws port belongs to that same PID (`Get-NetTCPConnection -State Listen`).
- Both URIs change on every app launch. Re-run the discovery after a restart, and confirm the launch actually used `--dart-define=ENABLE_FLUTTER_DRIVER=true` (check the `flutter run --machine` process command line); without the flag the driver extension is absent and `connect` hangs.
- If the `dart` MCP server tools are not loaded in the current session (no `mcp__dart__*` tools, empty MCP resource list) even though `[mcp_servers.dart]` is configured and `dart mcp-server` processes are running, do not fight it: use Path B directly. Restart Codex later so the MCP config takes effect.

### Path A - Interactive via MCP tools (fast iteration)

1. Launch the app with the driver enabled:
   - MCP: `launch_app` with `root: "file:///D:/Code/App/bangumi_today"`, `device: "<id>"` (from `list_devices` or `flutter devices --machine`), and `args: ["--dart-define", "ENABLE_FLUTTER_DRIVER=true"]`. Returns a DTD URI.
   - Shell fallback: `flutter run -d windows --dart-define=ENABLE_FLUTTER_DRIVER=true` (use `-d macos` on macOS).
2. Connect: `dtd` with `command: "listDtdUris"`, then `command: "connect"`, `uri: "<dtd-uri>"`. Confirm with `listConnectedApps`; note the `appUri` (VM service URI) if more than one app is connected.
3. Inspect before interacting: `widget_inspector` with `command: "get_widget_tree"` (use `summaryOnly: false` to see nested text widgets). The `flutter_driver_command` tool itself says: do not guess finders - use real text, tooltips, and widget types from the tree.
4. Interact: `flutter_driver_command` with `command: "waitFor"` / `"tap"` / `"scroll"` / `"screenshot"` and `appUri` when required.
5. Iterate: patch code, then `hot_reload` (`clearRuntimeErrors: true`); if global/const values changed, `hot_restart` instead. Re-check with `get_runtime_errors`.
6. Clean up: `stop_app` when done (only if launched via `launch_app`; a shell `flutter run` keeps running until interrupted).

### Path B - Standalone driver script (reproducible, shareable)

For scripted verification (the pattern already proven in `test_driver/settings_verify.dart` and `test_driver/verify_settings_fresh.dart`):

1. Launch the app with the flag (shell): `flutter run -d windows --dart-define=ENABLE_FLUTTER_DRIVER=true`. Copy the VM service URL printed by `flutter run` (or discover it from the `development-service` process as above):

   `A Dart VM Service on Windows is available at: http://127.0.0.1:<port>/<token>=/`

2. Write `test_driver/<name>.dart` using the template below (or copy an existing script and edit its steps).
3. While the app is still running, execute the script from another shell:

   `dart run test_driver/<name>.dart http://127.0.0.1:<port>/<token>=/ <outDir>`

   (Second arg defaults to the current directory; `VM_SERVICE_URL` env var is also accepted.)
4. Read `<name>.log` for PASS/FAIL lines and view the PNG screenshots it wrote. Fix the app, `r` (hot reload) or `R` (hot restart) in the `flutter run` console, then rerun the script.

### Driver script template

```dart
// Verification script template.
// Usage: dart run test_driver/verify_<name>.dart <vmServiceUrl> <outDir>
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  var vmUrl =
      args.isNotEmpty ? args[0] : Platform.environment['VM_SERVICE_URL'];
  var outDir = args.length > 1 ? args[1] : Directory.current.path;
  var logFile = File('$outDir/verify.log');
  if (logFile.existsSync()) logFile.deleteSync();

  void say(String s) {
    var line = '[${DateTime.now().toIso8601String().substring(11, 19)}] $s';
    logFile.writeAsStringSync('$line\n', mode: FileMode.append);
    try {
      stdout.writeln(line);
      stdout.flush();
    } catch (_) {}
  }

  if (vmUrl == null) {
    say('No VM service URL provided.');
    exit(2);
  }

  var driver = await FlutterDriver.connect(
    dartVmServiceUrl: vmUrl,
    timeout: const Duration(seconds: 60),
  );
  say('CONNECTED');
  // Required before any find.bySemanticsLabel finder.
  await driver.setSemantics(true);

  Future<bool> exists(
    SerializableFinder finder, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      await driver.waitFor(finder, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> waitVisible(
    String text, {
    Duration timeout = const Duration(seconds: 20),
  }) =>
      exists(find.text(text), timeout: timeout);

  Future<void> shot(String name) async {
    var png = await driver.screenshot().timeout(const Duration(seconds: 30));
    File('$outDir/$name').writeAsBytesSync(png);
    say('SHOT $name (${png.length} bytes)');
  }

  // Desktop Flutter ignores synthetic touch drags on fluent_ui ListViews, so
  // driver.scroll / scrollUntilVisible do nothing here. Use native mouse-wheel
  // injection instead. The path below is the repo-root copy of the bundled
  // helper (scripts/scroll_app.ps1); point -File at the skill copy otherwise.
  Future<void> wheel(String dir, int ticks) async {
    await Process.run('powershell', <String>[
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', 'scripts/scroll_app.ps1',
      dir,
      '$ticks',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<bool> scrollTo(SerializableFinder finder) async {
    for (final dir in <String>['down', 'up']) {
      for (var i = 0; i < 12; i++) {
        if (await exists(finder, timeout: const Duration(seconds: 2))) {
          return true;
        }
        await wheel(dir, 8);
      }
    }
    return false;
  }

  Future<bool> guarded(String label, Future<bool> Function() action) async {
    try {
      var ok = await action().timeout(const Duration(seconds: 60));
      say(ok ? 'PASS $label' : 'FAIL $label');
      return ok;
    } catch (e) {
      say('FAIL $label => $e');
      return false;
    }
  }

  // ---- custom steps start here ----
  await shot('01_current.png');

  // Navigate: prefer exact text; for icon-only compact NavigationPane entries
  // use an anchored regex on the semantic label (exact labels can fail, and
  // find.byTooltip does NOT match fluent_ui Tooltips - they set richMessage,
  // not message). Restore a known state first if a previous run left the page
  // scrolled/collapsed (state persists via PageStorage across runs).
  if (!await exists(find.text('目标页面标题'))) {
    final entry = find.bySemanticsLabel(RegExp(r'^入口语义标签'));
    if (await exists(entry)) {
      await driver.tap(entry);
    } else {
      say('NO entry found');
    }
  }

  await guarded('页面标题可见', () async {
    var ok = await waitVisible('目标页面标题');
    await shot('02_after_nav.png');
    return ok;
  });

  // Scroll targets into view before verifying or tapping them. waitFor only
  // proves the widget is in the tree (lazy lists build items inside the
  // cacheExtent), so wheel-scroll until the item is on screen, then screenshot.
  await guarded('分区内容', () async {
    await scrollTo(find.text('分区标题'));
    return waitVisible('分区标题');
  });

  say('DONE');
  await driver.close();
}
```

## flutter_driver_command reference

Parameters are strings unless noted. Required args depend on `command`; timeouts default to `"5000"` ms.

Finders (`finderType` + extra args):

| finderType | Extra args |
|---|---|
| `ByText` | `text` (exact match, including Chinese text) |
| `ByTooltipMessage` | `text` |
| `ByType` | `type` (runtimeType as a string, e.g. `"ListView"`) |
| `ByValueKey` | `keyValueString` + `keyValueType` (`"int"` or `"String"`) |
| `BySemanticsLabel` | `label` (+ `isRegExp: "true"/"false"`) |
| `PageBack` | none |
| `Descendant` / `Ancestor` | `of` + `matching` (nested finders), `matchRoot`, `firstMatchOnly` |

Commands:

| command | Notes |
|---|---|
| `get_health` | connection check |
| `waitFor` / `waitForAbsent` / `waitForTappable` | finder + `timeout` |
| `tap` | finder |
| `get_text` | finder |
| `enter_text` | `text` |
| `send_text_input_action` | `action` (done/search/next/...) |
| `scroll` | finder + `dx`, `dy` (stringified doubles), `duration` (microseconds as string), `frequency` (Hz as string) |
| `scrollIntoView` | finder + `alignment` |
| `screenshot` | returns PNG bytes |
| `get_offset` | finder + `offsetType` (topLeft/.../center) |
| `get_diagnostics_tree` | finder + `diagnosticsType` (`"renderObject"`/`"widget"`), `subtreeDepth`, `includeProperties` |
| `set_semantics` | `enabled: "true"/"false"` |
| `set_text_entry_emulation` | `enabled` |
| `set_frame_sync` | `enabled` - set `"false"` when continuous animations make tap/waitFor time out |

Gotchas:

- Always read `widget_inspector get_widget_tree` first; use the real text/tooltips/types it shows, never guessed finders.
- All numbers are strings: `timeout: "10000"`, `dy: "-300.0"`, `duration: "500000"`.
- Continuous repaints (this app uses acrylic window effects) can make `waitFor`/`tap` time out; disable frame sync with `set_frame_sync` `enabled: "false"`.
- `BySemanticsLabel` finders require `set_semantics` `enabled: "true"` first (also `driver.setSemantics(true)` in standalone scripts). Compact `NavigationPane` items are icon-only: their title `Text` is not built, so `ByText` fails and fluent_ui's `Tooltip` sets `richMessage` (not `message`), so `ByTooltipMessage` also fails - use `BySemanticsLabel` with an anchored `RegExp` like `^应用设置`.
- `scroll`/`scrollUntilVisible` synthesize touch drags, which desktop Flutter's fluent_ui scrollables ignore - the list will not move. Prefer native mouse-wheel injection (bundled `scripts/scroll_app.ps1`) or `scrollIntoView` after the target is already built.
- `screenshot` captures the current window content (window is 1280x720), so scroll the target into view first.

## Verified Windows pitfalls (driver scripts, fluent_ui)

Lessons from real verification runs against this app; all verified on Windows with the SDK-bundled server 0.1.4:

- **Do not import `fluent_ui` (or FFI-heavy packages) into standalone driver scripts.** The plain `dart` compiler crashes with `type 'InvalidType' is not a subtype of type 'FunctionType' in type cast` in the FFI transformer. If you need an icon, construct the `IconData` manually (e.g. `FluentIcons.settings` is `IconData(0xE713, fontFamily: 'FluentIcons', fontPackage: 'fluent_ui')`) or use semantics finders.
- **Exact semantic labels can fail where a prefix matches.** The settings pane entry matched `RegExp(r'^应用设置')` but not the exact string `'应用设置'`; probe anchored regexes before giving up on a finder.
- **`waitFor` proves in-tree presence, not visibility.** A lazy `ListView` builds off-screen items within the cacheExtent, so a "found" item can be absent from the screenshot. Wheel-scroll the target into view before screenshots or taps.
- **App state persists across runs.** `PageStorage` restores the ListView scroll offset and `BTSettingSection` keeps its collapse state, so a script re-run can start mid-page or with sections collapsed. Restore a known state (e.g. ensure a section is expanded before testing collapse/expand) instead of assuming a fresh page.
- **Hot restarts leave stale isolates.** `getVM` can list old isolates; non-UI isolates answer `Method not found` to `ext.flutter.inspector.*`. If driver commands behave oddly, re-check the current UI isolate id.
- **Widget tree without MCP tools**: `GET http://127.0.0.1:<port>/<token>=/ext.flutter.inspector.getRootWidgetSummaryTree?isolateId=isolates/<id>&objectGroup=g&groupName=g&isSummaryTree=false` returns a JSON tree (parse it with Python - PowerShell `ConvertFrom-Json` hits recursion limits). Nodes carry `widgetRuntimeType` and `creationLocation.file`, which is the fastest way to locate entries such as the settings pane item under `NavigationView`.
- **Screenshot byte size is a change detector**: identical sizes across steps mean the view did not move.
- **Console/encoding hygiene**: Windows PowerShell 5.1 decodes BOM-less UTF-8 as GBK, so always read skill/driver files with `-Encoding UTF8`. Driver logs written by Dart are UTF-8. `dart` stdout is block-buffered when piped - write results to a log file and `flush()`; wrap stdout writes in try/catch because `driver.close()` can make the sink throw `StreamSink is bound to a stream`.
- **Review screenshots with the `vision` skill** (`node <vision>/scripts/vision.js <png> "<question>"`) when the model cannot view images; it reliably catches truncation/overlap and describes the rendered layout.

## Static project work

- Analysis: MCP `analyze_files` is unavailable on this SDK - run `flutter analyze` in the shell (the repo's lint-staged config uses `dart analyze --fatal-infos --fatal-warnings`).
- Fixes: `dart_fix` (MCP, with `--enable cli`) or shell `dart fix --apply`.
- Format: `dart_format` (MCP, with `--enable cli`) or shell `dart format`; import sorting is `dart run import_sorter:main`.
- Tests: `run_tests` (MCP, with `--enable cli`) - pass `roots: [{"root": "file:///D:/Code/App/bangumi_today"}]` and optionally `arguments: {"name": ["<substring>"]}`. The project runs `flutter test`. Shell fallback: `flutter test <path>`.
- Dependencies: `pub_dev_search` to find a package, then `pub` with `command: "add"`, `packageNames`, and `roots`. The project uses `flutter pub add` semantics.

## Common pitfalls

- `No tool registered with the name X` -> the server args lack the needed `--enable` flag (or the tool is `analyze_files`/`lsp`, which cannot be enabled on Dart SDK 3.12). Restart Codex after changing args.
- Forgetting `roots add` -> root-scoped tools reject the root URI. Add `file:///D:/Code/App/bangumi_today` once per session.
- `launch_app` args must not include managed flags (`--print-dtd`, `--machine`, `--device-id`, `--target`, `-d`, `-t`); pass device via `device` and extra flags via `args`.
- Driver scripts need the app launched with `--dart-define=ENABLE_FLUTTER_DRIVER=true`; without it, `FlutterDriver.connect` hangs or the MCP driver commands error.
- After changing global/const values, `hot_reload` will not apply them - use `hot_restart`.
- If the MCP tool set looks different from this document, the server version drifted (pub.dev `dart_mcp_server` is at 1.x while the SDK bundles 0.1.4); re-verify with a tools/list probe.

## Project notes

- Desktop-only Flutter app (Windows/macOS folders; no Android/iOS targets).
- UI stack: `fluent_ui`, `flutter_acrylic`, `window_manager`, Riverpod (hooks_riverpod).
- `flutter_driver` is a dependency; the driver import in `lib/main.dart` is inert unless `--dart-define=ENABLE_FLUTTER_DRIVER=true` is passed.
- Working driver examples live in `test_driver/` (`settings_verify.dart`, `verify_settings_fresh.dart` - the latter includes wheel-scrolling and deterministic state handling) - copy them for new verification scripts.
- The native mouse-wheel helper is bundled at `scripts/scroll_app.ps1` (a copy also lives at the repo root `scripts/scroll_app.ps1`); run it via `powershell -NoProfile -ExecutionPolicy Bypass -File <path> <up|down> <ticks>`.
- Commit messages follow the repo's Gitmoji convention (see AGENTS.md).
