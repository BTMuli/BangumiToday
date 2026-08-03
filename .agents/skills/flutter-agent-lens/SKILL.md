---
name: flutter-agent-lens
description: Profile, debug, and optimize a running Flutter app through the Flutter Agent Lens MCP server (registered in Codex as the `flutter_agent_lens` MCP server). Use when diagnosing frame jank or rendering bottlenecks, CPU hotspots, memory leaks or allocation growth, widget rebuild storms, HTTP network traffic, console logs, widget tree/layout structure, navigation stack, screenshots, breakpoints, expression evaluation, or hot reload/restart of the running BangumiToday app. Do not use for running tests, static analysis, or driving taps/scrolling - use $flutter-mcp for those.
---

# Flutter Agent Lens

## Overview

`flutter_agent_lens` (v1.7.0) is an MCP server that connects to a running Flutter app's Dart VM Service over WebSocket. It exposes profiling and debugging tools: memory snapshots/leak audits, CPU profiling, jank diagnosis, widget rebuild tracking, network capture, console logs, widget tree inspection, screenshots, breakpoints, and hot reload.

Division of labor with `$flutter-mcp` (the official Dart MCP server):

- `$flutter-mcp` - drive the app (launch, tap, scroll, screenshot via flutter_driver) and run tests/analysis.
- `$flutter-agent-lens` - diagnose and profile a running app. No `ENABLE_FLUTTER_DRIVER` flag needed; it uses the VM Service exposed by any debug/profile run.

## Setup

Installed globally with `dart pub global activate flutter_agent_lens` (creates `flutter-agent-lens.bat` in the Pub cache bin). Registered in `~/.codex/config.toml`:

```toml
[mcp_servers.flutter_agent_lens]
command = "cmd"
args = ["/c", "C:\\Users\\bt-mu\\AppData\\Local\\Pub\\Cache\\bin\\flutter-agent-lens.bat"]
```

On Windows the `.bat` shim must be launched via `cmd /c`; Codex cannot spawn batch files directly. Restart Codex after editing the config, then verify registration with `/mcp` before relying on the tools.

## Workflow

1. Launch the app in debug or profile mode: `flutter run -d windows` (or `-d macos`). Release builds disable the VM Service.
2. Discover: `discover_apps` and pick the target app's VM Service URI.
3. Connect: `connection` with `action: "connect"`, the VM Service (or DTD) URI, and `workspace_root: "D:/Code/App/bangumi_today"` (absolute path - required for layout/file path mapping). Use `action: "connect_dtd"` for DTD-backed tools.
4. Profile flow (example): `rebuild_tracking` `start` or `profiling` `start`, reproduce the issue in the app, then `stop` and inspect `get_counts` / `get_cpu` / `diagnose_jank`.
5. Memory: `memory` with `action: "get_snapshot"` (or `save`/`compare`), `audit_leak`, `get_referrers`.
6. Network/logs: `network` `start` -> reproduce -> `stop`/`get_profile`; `console_logs` `fetch`/`watch`.
7. Clean up: `hot_reload` after code fixes, or `hot_restart` when global/const values changed.

## Tool inventory (v1.7.0)

Tools are registered in two phases. Before any connection only 4 tools exist: `connection`, `discover_apps`, `set_response_format`, `diagnose_project`. The rest register automatically after a successful `connection`/`discover_apps` and unregister on disconnect. Verify what is registered with `/mcp` before calling.

| Tool | Actions | Purpose |
|---|---|---|
| `connection` | `connect`, `connect_dtd`, `disconnect` | Connect to VM Service / DTD |
| `discover_apps` | - | Find running Flutter apps |
| `diagnose_project` | `bundle_size`, `deep_links` | Local build size / deep link checks |
| `set_response_format` | - | `markdown` or `json` output |
| `get_app_info` | - | VM version, isolates, service extensions |
| `get_active_location` | - | Editor path/cursor (needs DTD) |
| `memory` | `get_snapshot`, `save`, `compare`, `list`, `audit_leak`, `diff_allocations`, `get_referrers`, `force_gc`, `start_gc_stream`, `stop_gc_stream`, `get_memory_timeline`, `watch_gc_pressure`, `explain_memory_breakdown` | Heap, leaks, GC, retention paths |
| `profiling` | `start`, `stop`, `get_cpu`, `diagnose_jank` | Render/CPU hotspots, jank |
| `rebuild_tracking` | `start`, `stop`, `get_counts` | Widget rebuild counts |
| `network` | `start`, `stop`, `get_profile`, `watch`, `get_request_details` | HTTP capture and inspection |
| `console_logs` | `fetch`, `watch` | Buffered/live stdout, stderr, logs |
| `trigger_scroll_gesture` | - | Scroll the app viewport |
| `widget` | `inspect`, `toggle_selection`, `get_tree` | Widget tree and layout details |
| `get_navigation_stack` | - | Router/Navigator routes, URL, depth |
| `debug_flag` | `toggle`, `toggle_package_widgets` | Debug visuals, package widget visibility |
| `screenshot` | `take`, `capture_baseline`, `compare` | Capture / visual regression |
| `hot_reload` / `hot_restart` | - | Apply code changes |
| `breakpoint` | `add`, `remove` | Code breakpoints |
| `get_call_stack` | - | Frames when paused |
| `set_exception_pause_mode` | - | Pause on exceptions |
| `evaluate_expression` | - | Run Dart expression in isolate |

## Key parameters

- Limits: `limit`/`topN` - `network get_profile` (30), `profiling diagnose_jank`/`get_cpu` (15), `diagnose_project bundle_size` (25), memory audits (50-100), `rebuild_tracking` (30), `memory compare` (10), `get_snapshot` (20).
- `duration_seconds`: watch/stream tools (default 5, max 30).
- `slow_threshold_ms`: `network watch` slow-request flag (default 500).
- `widget get_tree`: `maxDepth` (8), `projectOnly` (true) - filters non-project widgets.
- Flags: `include_details` (network), `includeRawResponse`, `includeExtensions` (get_app_info), `includeRawNode` (widget inspect), `forceGC` (memory snapshots).

## Troubleshooting

- Connection fails: app must run in debug/profile mode; release builds have no VM Service. On physical devices/emulators map ports: `adb reverse tcp:8181 tcp:8181`.
- `discover_apps` finds nothing: verify DDS initialized; retry with `autoConnect: false` to list endpoints.
- File/layout path mapping errors: pass the absolute `workspace_root` in `connect`.
- `No tool registered`: server not loaded - restart Codex after editing `config.toml`, check `/mcp`.
- Server version drift: tool set depends on the installed version (`dart pub global list` to check); re-verify against the tool catalog above.

## Project notes

- BangumiToday is a desktop-only Flutter app (Windows/macOS), `fluent_ui` + Riverpod; launch with `flutter run -d windows`.
- No `--dart-define=ENABLE_FLUTTER_DRIVER=true` needed for this server (unlike flutter_driver).
- Commit messages follow the repo's Gitmoji convention (see AGENTS.md).
