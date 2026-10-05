// Dart imports:
import 'dart:async';
import 'dart:convert';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import '../../core/services/playback_window_protocol.dart';
import '../../data/repositories/playback_window_remote.dart';
import '../../models/playback/playback_on_top.dart';
import '../../providers/episode_mark_providers.dart';
import '../../providers/playback_window_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/playback_store.dart';
import '../../tools/log_tool.dart';
import 'playback_page.dart';
import 'playback_window_mode.dart';

/// This entry never opens the application database, Hive, tray or downloads.
Future<void> startPlaybackWindow(WindowController window) async {
  try {
    await BTLogTool.init(scope: 'playback-${window.windowId}');
    await windowManager.ensureInitialized();
    var identity = PlaybackWindowIdentity.decode(window.arguments);
    var child = _PlaybackWindow(window, identity);
    await child.start();
  } catch (error, stackTrace) {
    BTLogTool.error(['播放器启动失败：$error', stackTrace.toString()]);
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
  late final PlaybackWindowMode mode;
  Future<void>? _closeFuture;
  Future<void>? _shutdownFuture;
  int _sequence = 0;
  int _commandSequence = 0;
  int _presentationRevision = -1;
  bool _closing = false;
  bool _hidden = false;
  bool _exiting = false;
  Timer? _boundsTimer;
  Rect? _normalBounds;
  StreamSubscription<bool>? _playing;
  Player? _observedPlayer;

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
    mode = PlaybackWindowMode(
      persistOnTop: (value) =>
          store.settingsStore.write('playbackOnTop', value.name),
    );
    store.addListener(_onVideoChanged);
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
    // 播放器窗口只有视频画面：显示前去掉标题栏与边框，避免先闪出一帧普通窗口。
    await mode.applyFramelessWindow();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'BangumiToday · 播放器',
        size: Size(1120, 720),
        minimumSize: PlaybackWindowMode.minimumSize,
        center: true,
      ),
    );
    try {
      _receive(await call('bootstrap', {'windowId': window.windowId}));
      await _restoreSize();
      await mode.centerWindow(area: await _displayUnderCursor());
      await _rememberBounds();
      await _restoreOnTop();
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: _PlaybackWindowApp(
            presentation: presentation,
            closing: closing,
            mode: mode,
          ),
        ),
      );
      // A hidden/minimized native window may stop producing frames. Make it
      // visible before waiting for the mounted page's first-frame handshake.
      await windowManager.show();
      await WidgetsBinding.instance.endOfFrame;
      _receive(await call('ready', {'windowId': window.windowId}));
      await windowManager.focus();
    } catch (error, stackTrace) {
      BTLogTool.error(['播放器窗口初始化失败：$error', stackTrace.toString()]);
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

  void _onVideoChanged() {
    if (_closing) return;
    _observePlaying();
    mode.updateVideo(store.aspectRatio, store.videoSize);
  }

  /// “播放时置顶”跟随 Player 的播放流；Player 被替换时旧订阅必须释放。
  void _observePlaying() {
    var player = store.player;
    if (identical(player, _observedPlayer)) return;
    _observedPlayer = player;
    unawaited(_playing?.cancel());
    _playing = null;
    if (player == null) {
      mode.updatePlaying(false);
      return;
    }
    _playing = player.stream.playing.listen(mode.updatePlaying);
    mode.updatePlaying(player.state.playing);
  }

  Future<Object?> _handle(MethodCall call) async {
    var request = identity.read(call.arguments);
    // Main-to-child operations are ordered by the owner. Never execute a
    // delayed open or an old presentation after a more recent command.
    if (request.sequence <= _commandSequence) throw StateError('播放器命令已经失效');
    _commandSequence = request.sequence;
    if (call.method == 'prepareClose') {
      await _beginShutdown();
      return null;
    }
    if (call.method == 'activate') {
      await _closeFuture;
      if (_exiting) throw StateError('应用正在退出');
      _closing = false;
      closing.value = null;
      marking.resume();
      var value = await this.call('activated', {});
      if (_exiting || _closing) throw StateError('播放器正在关闭');
      _receive(value);
      await store.refreshHistory();
      if (await windowManager.isMinimized()) await windowManager.restore();
      await mode.centerWindow();
      if (_exiting || _closing) throw StateError('播放器正在关闭');
      _hidden = false;
      await windowManager.show();
      if (_exiting || _closing) throw StateError('播放器正在关闭');
      await windowManager.focus();
      return null;
    }
    if (_closing) throw StateError('播放器正在关闭');
    switch (call.method) {
      case 'presentation':
        _receive(request.body);
      case 'open':
        await store.openLocalFile(
          playbackString(request.body, 'filePath'),
          subject: playbackSubject(request.body),
        );
        // 视频参数可能刚改变窗口尺寸；以适配后的最终尺寸重新居中。
        if (!_closing) await mode.centerWindow();
      default:
        throw FormatException('不支持的播放器命令：${call.method}');
    }
    return null;
  }

  @override
  void onWindowClose() {
    unawaited(
      _beginClose().catchError((Object error, StackTrace stackTrace) {
        BTLogTool.error(['关闭播放器失败：$error', stackTrace.toString()]);
      }),
    );
  }

  Future<void> _beginClose() {
    if (_exiting) return _shutdownFuture ?? Future.value();
    return _closeFuture ??= _close().whenComplete(() => _closeFuture = null);
  }

  Future<void> _close() async {
    if (_hidden) return;
    BTLogTool.info('播放器窗口保存并隐藏：${identity.generation}');
    _closing = true;
    _boundsTimer?.cancel();
    closing.value = '正在保存并关闭播放器…';
    marking.suspend();
    try {
      await call('closing', {});
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      var savedBounds = await _savedBounds();
      await store.clearCurrentPlayback();
      await _saveBounds(savedBounds);
      // Remove the stopped video's widget while frames are still available.
      await WidgetsBinding.instance.endOfFrame;
      await windowManager.hide();
      _hidden = true;
      await call('hidden', {});
      BTLogTool.info('播放器窗口已隐藏，保留 mpv 等待下次播放');
    } catch (error) {
      if (!_exiting) {
        _closing = false;
        marking.resume();
      }
      var message = '保存或停止播放失败：$error';
      await _showCloseFailure(message);
      try {
        _receive(await call('closeFailed', {'message': message}));
      } catch (failure) {
        BTLogTool.error('报告播放器关闭失败：$failure');
      }
      rethrow;
    }
  }

  Future<void> _saveBounds(Rect? bounds) async {
    if (bounds == null) return;
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

  Future<void> _beginShutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    _exiting = true;
    _closing = true;
    // A user close may already be saving and unloading media. Let it finish
    // before the app exit takes ownership of native destruction.
    try {
      await _closeFuture;
    } catch (_) {
      // The close error was reported; exit must still release the Player.
    }
    _closing = true;
    _boundsTimer?.cancel();
    closing.value = '正在退出并释放播放器…';
    marking.invalidate();
    BTLogTool.info('应用退出，开始销毁播放器：${identity.generation}');
    try {
      await call('closing', {});
      if (!_hidden) {
        if (await windowManager.isMinimized()) await windowManager.restore();
        await windowManager.show();
        await _saveBounds(await _savedBounds());
      }
      await store.shutdown();
      await store.waitForShutdownWork();
      await windowManager.hide();
      _hidden = true;
      await store.waitForShutdownSettlement();
      await call('closed', {});
      // Return the prepareClose reply before taking down its channel/HWND.
      Timer(const Duration(milliseconds: 100), () {
        unawaited(
          _nativeClose().catchError((Object error) async {
            await _showCloseFailure('关闭窗口失败：$error');
          }),
        );
      });
    } catch (error) {
      await _showCloseFailure('保存或清理失败：$error。请保留此窗口并从主窗口退出应用。');
      rethrow;
    }
  }

  Future<void> _showCloseFailure(String message) async {
    closing.value = message;
    BTLogTool.error(message);
    try {
      await windowManager.show();
      _hidden = false;
      await windowManager.focus();
    } catch (error) {
      BTLogTool.error('重新显示播放器清理错误失败：$error');
    }
  }

  Future<void> _nativeClose() async {
    BTLogTool.info('播放器窗口原生清理已完成，关闭窗口');
    store.removeListener(_onVideoChanged);
    await _playing?.cancel();
    _playing = null;
    mode.dispose();
    windowManager.removeListener(this);
    await windowManager.setPreventClose(false);
    // destroy() posts a process-wide quit on Windows; only the root may use it.
    await windowManager.close();
  }

  @override
  void onWindowMoved() => _scheduleBounds(movedByUser: true);
  @override
  void onWindowResized() => _scheduleBounds(movedByUser: true);
  @override
  void onWindowLeaveFullScreen() => _scheduleBounds();

  /// 拖动、缩放或吸附后的尺寸由用户决定，不再按视频分辨率自动开窗。
  void _scheduleBounds({bool movedByUser = false}) {
    if (_closing || mode.transitioning) return;
    if (movedByUser) {
      mode.markUserSized();
      unawaited(mode.settleAfterUserBoundsChange().catchError((Object _) {}));
    }
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
        mode.transitioning ||
        mode.screenFullscreen ||
        await windowManager.isFullScreen() ||
        await windowManager.isMaximized() ||
        await windowManager.isMinimized()) {
      return;
    }
    _normalBounds = await windowManager.getBounds();
  }

  /// 无边框窗口的尺寸由视频与倍率决定；关闭时保存当前边界，下次只沿用其中的
  /// 尺寸——窗口每次创建都重新居中，不再回到上次拖动留下的位置。
  Future<Rect?> _savedBounds() async {
    if (mode.screenFullscreen ||
        await windowManager.isFullScreen() ||
        await windowManager.isMaximized() ||
        await windowManager.isMinimized()) {
      return _normalBounds;
    }
    try {
      return await windowManager.getBounds();
    } catch (error) {
      BTLogTool.warn('读取播放器窗口位置失败：$error');
      return _normalBounds;
    }
  }

  /// 播放器窗口每次创建都居中显示，只沿用上次的窗口尺寸；位置不再还原，
  /// 避免新窗口出现在上次拖动留下的角落。
  Future<void> _restoreSize() async {
    try {
      var saved = await store.settingsStore.read('playbackWindowBounds');
      if (saved != null) {
        var data = playbackMap(jsonDecode(saved));
        var width = (data['width'] as num?)?.toDouble();
        var height = (data['height'] as num?)?.toDouble();
        if (width == null ||
            height == null ||
            !width.isFinite ||
            !height.isFinite ||
            width < PlaybackWindowMode.minimumSize.width ||
            height < PlaybackWindowMode.minimumSize.height) {
          return;
        }
        var area = await _displayUnderCursor();
        if (area.width < PlaybackWindowMode.minimumSize.width ||
            area.height < PlaybackWindowMode.minimumSize.height) {
          return;
        }
        // 恢复尺寸后由 start 统一居中，包括没有保存尺寸的首次启动。
        await windowManager.setSize(
          Size(
            width.clamp(PlaybackWindowMode.minimumSize.width, area.width),
            height.clamp(PlaybackWindowMode.minimumSize.height, area.height),
          ),
        );
        // 上次的窗口尺寸优先于按视频像素自动适配。
        mode.markUserSized();
      }
    } catch (error) {
      BTLogTool.warn('恢复播放器尺寸失败：$error');
    }
  }

  /// 光标所在屏幕的可用区域；恢复尺寸与窗口居中都以它为准。
  Future<Rect> _displayUnderCursor() async {
    var displays = await screenRetriever.getAllDisplays();
    var cursor = await screenRetriever.getCursorScreenPoint();
    for (var display in displays) {
      var area =
          (display.visiblePosition ?? Offset.zero) &
          (display.visibleSize ?? display.size);
      if (area.contains(cursor)) return area;
    }
    var primary = await screenRetriever.getPrimaryDisplay();
    return (primary.visiblePosition ?? Offset.zero) &
        (primary.visibleSize ?? primary.size);
  }

  /// 置顶偏好只影响播放器窗口；读取失败保持默认的“不置顶”。
  Future<void> _restoreOnTop() async {
    try {
      var saved = await store.settingsStore.read('playbackOnTop');
      mode.restoreOnTop(PlaybackOnTop.parse(saved));
    } catch (error) {
      BTLogTool.warn('恢复播放器置顶偏好失败：$error');
    }
  }
}

class _PlaybackWindowApp extends StatelessWidget {
  const _PlaybackWindowApp({
    required this.presentation,
    required this.closing,
    required this.mode,
  });
  final ValueNotifier<Map<String, Object?>> presentation;
  final ValueNotifier<String?> closing;
  final PlaybackWindowMode mode;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, Object?>>(
      valueListenable: presentation,
      builder: (context, value, _) {
        var themeMode = ThemeMode.values.byName(
          value['theme'] as String? ?? 'system',
        );
        var accent = Color(
          value['accent'] as int? ?? 0xff0078d4,
        ).toAccentColor();
        return FluentApp(
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
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
                  child: PlaybackPage(independent: true, windowMode: mode),
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
