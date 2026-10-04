import 'dart:async';
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/services/playback_window_protocol.dart';
import '../../data/repositories/playback_window_remote.dart';
import '../../providers/episode_mark_providers.dart';
import '../../providers/playback_window_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/playback_store.dart';
import '../../tools/log_tool.dart';
import 'playback_page.dart';

/// This entry never opens the application database, Hive, tray or downloads.
Future<void> startPlaybackWindow(WindowController window) async {
  await windowManager.ensureInitialized();
  try {
    var identity = PlaybackWindowIdentity.decode(window.arguments);
    var child = _PlaybackWindow(window, identity);
    await child.start();
  } catch (error) {
    BTLogTool.error('播放器启动失败：$error');
    // A malformed role must never fall through into the main startup sequence.
    runApp(FluentApp(home: Center(child: Text('播放器启动失败：$error'))));
    await windowManager.setTitle('BangumiToday · 播放器启动失败');
    await windowManager.setPreventClose(false);
    await windowManager.show();
  }
}

class _PlaybackWindow with WindowListener {
  _PlaybackWindow(this.window, this.identity)
    : host = WindowMethodChannel(
        identity.hostChannel,
        mode: ChannelMode.unidirectional,
      );
  final WindowController window;
  final PlaybackWindowIdentity identity;
  final WindowMethodChannel host;
  final presentation = ValueNotifier<Map<String, Object?>>({});
  final closing = ValueNotifier<String?>(null);
  late final PlaybackStore store;
  late final ProviderContainer container;
  late final RemoteEpisodeMarkController marking;
  Future<void>? _closeFuture;
  int _sequence = 0;
  int _commandSequence = 0;
  int _presentationRevision = -1;
  bool _closing = false;
  Timer? _boundsTimer;
  Rect? _normalBounds;

  Future<Object?> call(String method, Map<String, Object?> body) {
    return host.invokeMethod<Object?>(
      method,
      identity.request(++_sequence, body),
    );
  }

  Future<void> start() async {
    store = PlaybackStore(
      library: RemotePlaybackLibrary(call),
      historyStore: RemotePlaybackHistory(call),
      settingsStore: RemotePlaybackSettings(call),
      subjectResolver: RemotePlaybackSubjects(call),
      cover: RemotePlaybackCover(call),
      waitForNativeDestroy: true,
    );
    marking = RemoteEpisodeMarkController(call);
    container = ProviderContainer(
      overrides: [
        playbackStoreProvider.overrideWith((ref) => store),
        episodeMarkProvider.overrideWith(() => marking),
        isPlaybackWindowProvider.overrideWithValue(true),
        playbackSubjectNavigationProvider.overrideWithValue((subject) async {
          await call('subject.open', {'subject': subject});
        }),
      ],
    );
    container.read(episodeMarkProvider);
    await window.setWindowMethodHandler(_handle);
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'BangumiToday · 播放器',
        size: Size(1120, 720),
        minimumSize: Size(720, 480),
        center: true,
      ),
    );
    try {
      _receive(await call('bootstrap', {'windowId': window.windowId}));
      await _restoreBounds();
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: _PlaybackWindowApp(
            presentation: presentation,
            closing: closing,
          ),
        ),
      );
      // A hidden/minimized native window may stop producing frames. Make it
      // visible before waiting for the mounted page's first-frame handshake.
      await windowManager.show();
      await WidgetsBinding.instance.endOfFrame;
      _receive(await call('ready', {'windowId': window.windowId}));
      await windowManager.focus();
    } catch (error) {
      // Before opening media, this engine owns no native Player. Report that
      // cleanup explicitly so the main owner can safely retire the generation.
      await call('failed', {'message': error.toString()});
      await store.waitForShutdownSettlement();
      await call('closed', {});
      await _nativeClose();
      return;
    }
  }

  void _receive(Object? value) {
    var data = playbackMap(value);
    var episodes = playbackMap(data['episodes']);
    var revision = playbackInt(episodes, 'revision');
    if (_closing || revision <= _presentationRevision) return;
    _presentationRevision = revision;
    BtrBangumiApi.setBaseUrl(data['bangumiUrl'] as String);
    marking.receive(episodes);
    presentation.value = data;
  }

  Future<Object?> _handle(MethodCall call) async {
    var request = identity.read(call.arguments);
    // Main-to-child operations are ordered by the owner. Never execute a
    // delayed open or an old presentation after a more recent command.
    if (request.sequence <= _commandSequence) throw StateError('播放器命令已经失效');
    _commandSequence = request.sequence;
    if (call.method == 'prepareClose') {
      await _beginClose();
      return null;
    }
    if (_closing) throw StateError('播放器正在关闭');
    switch (call.method) {
      case 'presentation':
        _receive(request.body);
      case 'activate':
        if (await windowManager.isMinimized()) await windowManager.restore();
        await windowManager.show();
        await windowManager.focus();
      case 'open':
        await store.openLocalFile(
          playbackString(request.body, 'filePath'),
          subject: playbackSubject(request.body),
        );
      default:
        throw FormatException('不支持的播放器命令：${call.method}');
    }
    return null;
  }

  @override
  void onWindowClose() {
    unawaited(
      _beginClose().catchError((Object error) {
        BTLogTool.error('关闭播放器失败：$error');
      }),
    );
  }

  Future<void> _beginClose() => _closeFuture ??= _close();
  Future<void> _close() async {
    _closing = true;
    _boundsTimer?.cancel();
    closing.value = '正在保存并关闭播放器…';
    marking.invalidate();
    try {
      await call('closing', {});
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      // The mounted PlaybackPage exits fullscreen and removes Video while this
      // window can still draw; the strict wait includes final durable writes.
      await store.shutdown();
      if (_normalBounds != null) {
        var bounds = _normalBounds!;
        await store.settingsStore.write(
          'playbackWindowBounds',
          jsonEncode({
            'x': bounds.left,
            'y': bounds.top,
            'width': bounds.width,
            'height': bounds.height,
          }),
        );
      }
      await store.waitForShutdownSettlement();
      await call('closed', {});
      // Return the prepareClose reply before taking down its channel/HWND.
      Timer(const Duration(milliseconds: 100), () {
        unawaited(
          _nativeClose().catchError((Object error) {
            closing.value = '关闭窗口失败：$error';
            BTLogTool.error(closing.value);
          }),
        );
      });
    } catch (error) {
      closing.value = '保存或清理失败：$error。请保留此窗口并从主窗口退出应用。';
      rethrow;
    }
  }

  Future<void> _nativeClose() async {
    windowManager.removeListener(this);
    await windowManager.setPreventClose(false);
    // destroy() posts a process-wide quit on Windows; only the root may use it.
    await windowManager.close();
  }

  @override
  void onWindowMoved() => _scheduleBounds();
  @override
  void onWindowResized() => _scheduleBounds();
  @override
  void onWindowLeaveFullScreen() => _scheduleBounds();
  void _scheduleBounds() {
    if (_closing) return;
    _boundsTimer?.cancel();
    _boundsTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(
        _rememberBounds().catchError((Object error) {
          BTLogTool.warn('读取播放器位置失败：$error');
        }),
      );
    });
  }

  Future<void> _rememberBounds() async {
    if (_closing ||
        await windowManager.isFullScreen() ||
        await windowManager.isMaximized() ||
        await windowManager.isMinimized())
      return;
    _normalBounds = await windowManager.getBounds();
  }

  Future<void> _restoreBounds() async {
    try {
      var saved = await store.settingsStore.read('playbackWindowBounds');
      if (saved != null) {
        var data = playbackMap(jsonDecode(saved));
        var numbers = [
          for (var key in ['x', 'y', 'width', 'height'])
            (data[key] as num).toDouble(),
        ];
        if (numbers.every((value) => value.isFinite) &&
            numbers[2] >= 720 &&
            numbers[3] >= 480) {
          var bounds = Rect.fromLTWH(
            numbers[0],
            numbers[1],
            numbers[2],
            numbers[3],
          );
          var displays = await screenRetriever.getAllDisplays();
          for (var display in displays) {
            var area =
                (display.visiblePosition ?? Offset.zero) &
                (display.visibleSize ?? display.size);
            if (area.width < 720 || area.height < 480 || !area.overlaps(bounds))
              continue;
            var width = bounds.width.clamp(720.0, area.width);
            var height = bounds.height.clamp(480.0, area.height);
            await windowManager.setBounds(
              Rect.fromLTWH(
                bounds.left.clamp(area.left, area.right - width),
                bounds.top.clamp(area.top, area.bottom - height),
                width,
                height,
              ),
            );
            break;
          }
        }
      }
    } catch (error) {
      BTLogTool.warn('恢复播放器位置失败，使用默认位置：$error');
    }
    await _rememberBounds();
  }
}

class _PlaybackWindowApp extends StatelessWidget {
  const _PlaybackWindowApp({required this.presentation, required this.closing});
  final ValueNotifier<Map<String, Object?>> presentation;
  final ValueNotifier<String?> closing;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, Object?>>(
      valueListenable: presentation,
      builder: (context, value, _) {
        var mode = ThemeMode.values.byName(
          value['theme'] as String? ?? 'system',
        );
        var accent = Color(
          value['accent'] as int? ?? 0xff0078d4,
        ).toAccentColor();
        return FluentApp(
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: FluentThemeData(
            brightness: Brightness.light,
            accentColor: accent,
            fontFamily: 'SMonoSC',
          ),
          darkTheme: FluentThemeData(
            brightness: Brightness.dark,
            accentColor: accent,
            fontFamily: 'SMonoSC',
          ),
          home: ValueListenableBuilder<String?>(
            valueListenable: closing,
            builder: (context, message, _) => Stack(
              children: [
                IgnorePointer(
                  ignoring: message != null,
                  child: const PlaybackPage(independent: true),
                ),
                if (message != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: FluentTheme.of(
                        context,
                      ).micaBackgroundColor.withValues(alpha: 0.96),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(message),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
