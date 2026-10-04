// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../core/errors/playback_unavailable.dart';
import '../core/services/native_playback_upscale_backend.dart';
import '../core/services/playback_assets.dart';
import '../core/services/playback_subtitles.dart';
import '../core/services/playback_upscaler.dart';
import '../data/repositories/playback_cover_impl.dart';
import '../data/repositories/playback_history_impl.dart';
import '../data/repositories/playback_library_impl.dart';
import '../data/repositories/playback_settings_impl.dart';
import '../data/repositories/playback_subjects_impl.dart';
import '../domain/repositories/playback_cover.dart';
import '../domain/repositories/playback_history.dart';
import '../domain/repositories/playback_library.dart';
import '../domain/repositories/playback_settings.dart';
import '../domain/repositories/playback_subjects.dart';
import '../models/playback/playback_fit.dart';
import '../models/playback/playback_completion.dart';
import '../models/playback/playback_item.dart';
import '../models/playback/playback_rate.dart';
import '../models/playback/playback_upscale.dart';
import '../providers/bangumi_providers.dart';
import '../providers/bmf_providers.dart';
import '../tools/log_tool.dart';
import 'bt_download_store.dart';

final playbackStoreProvider = ChangeNotifierProvider<PlaybackStore>((ref) {
  // 资源校验需要任务列表，文件详情通过命令接口按需拉取。
  var downloads = ref.read(btDownloadStoreProvider.notifier);
  return PlaybackStore(
    playerAllowed: !Platform.isWindows,
    library: PlaybackLibraryImpl(
      tasks: () => downloads.tasks,
      taskFiles: (id, offset) => downloads.taskFiles(id, offset: offset),
    ),
    cover: BangumiPlaybackCoverResolver(ref.read(bangumiRepositoryProvider)),
    historyStore: AppPlaybackHistoryStore(),
    settingsStore: AppPlaybackSettingsStore(),
    subjectResolver: BmfPlaybackSubjectResolver(
      ref.read(bmfRepositoryProvider),
    ),
  );
});

/// One mpv session. Serial operations keep progress attributed to its file.
///
/// 会话只依赖注入的资源校验、历史、配置与条目归属接口，不自己构造存储访问器。
class PlaybackStore extends ChangeNotifier {
  PlaybackStore({
    required this.library,
    required this.cover,
    required this.historyStore,
    required this.settingsStore,
    required this.subjectResolver,
    this.playerAllowed = true,
    this.waitForNativeDestroy = false,
  });

  final PlaybackLibrary library;
  final PlaybackCoverResolver cover;
  final PlaybackHistoryStore historyStore;
  final PlaybackSettingsStore settingsStore;
  final PlaybackSubjectResolver subjectResolver;
  final bool playerAllowed;
  final bool waitForNativeDestroy;

  /// Directory and subject used to (re)discover the playlist for a refresh.
  String? _sourceDir;
  int? _sourceSubject;

  /// The mounted video surface can leave fullscreen before native teardown.
  Future<void> Function()? beforeVideoDispose;
  late final _rateMemory = PlaybackRateMemory(
    read: () => settingsStore.read('playbackRememberedRate'),
    write: (value) => settingsStore.write('playbackRememberedRate', value),
  );
  Future<void>? _preferencesFuture;
  PlaybackFit _fit = PlaybackFit.fit;
  double? _aspectRatio;
  Player? _player;
  VideoController? _video;
  PlaybackUpscaler? _upscaler;
  PlaybackUpscaleMode _upscaleMode = PlaybackUpscaleMode.off;
  Object? _viewportOwner;
  bool _viewportFullscreen = false;
  final _viewports = <Object, ({PlaybackViewport value, bool fullscreen})>{};
  VoidCallback? _textureListener;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _saveTimer;
  Future<void> _operation = Future.value();
  List<PlaybackItem> playlist = [];
  List<PlaybackItem> history = [];
  int index = -1;
  bool loading = false;
  String? error;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool completed = false;
  bool _closed = false;
  bool _disposed = false;
  Future<void>? _shutdownFuture;
  Future<void>? _settlementFuture;
  final _shutdownWork = <Future<void>>[];
  final _nativeDestructions = <Future<void>>[];
  final _shutdownFailures = <Object>[];
  final _session = PlaybackSession();
  final _completions = StreamController<PlaybackCompletion>.broadcast();

  Stream<PlaybackCompletion> get completions => _completions.stream;
  bool get isClosed => _closed;

  Player? get player => _player;
  VideoController? get video => _video;
  PlaybackUpscaler? get upscaler => _upscaler;
  PlaybackUpscaleMode get upscaleMode => _upscaleMode;
  PlaybackFit get fit => _fit;
  double? get aspectRatio => _aspectRatio;
  double? get rememberedRate => _rateMemory.remembered;
  PlaybackItem? get current =>
      index >= 0 && index < playlist.length ? playlist[index] : null;

  /// Whether a playlist source directory is known and can be re-scanned.
  bool get canRefresh => _sourceDir != null;

  /// The cached cover URL for a subject, or `null` when unknown.
  String? coverFor(int? subject) =>
      subject == null ? null : cover.coverOf(subject);

  /// The cached subject name, or `null` when unknown.
  String? nameFor(int? subject) =>
      subject == null ? null : cover.nameOf(subject);

  void clearError() {
    if (error == null) return;
    error = null;
    _notify();
  }

  /// Fullscreen owns the texture while the windowed controls remain mounted.
  void reportViewport(
    Object owner,
    PlaybackViewport value, {
    required bool fullscreen,
  }) {
    if (_closed) return;
    _viewports[owner] = (value: value, fullscreen: fullscreen);
    if (_viewportFullscreen && !fullscreen) return;
    _viewportOwner = owner;
    _viewportFullscreen = fullscreen;
    _upscaler?.viewport(value);
  }

  void releaseViewport(Object owner) {
    if (_closed) return;
    _viewports.remove(owner);
    if (!identical(owner, _viewportOwner)) return;
    _viewportOwner = null;
    _viewportFullscreen = false;
    if (_viewports.isEmpty) {
      _upscaler?.viewport(null);
    } else {
      var remaining = _viewports.entries.last;
      reportViewport(
        remaining.key,
        remaining.value.value,
        fullscreen: remaining.value.fullscreen,
      );
    }
  }

  static PlaybackVideoSource? _videoSource(VideoParams value) =>
      playbackVideoSource(
        width: value.dw ?? value.w,
        height: value.dh ?? value.h,
        rotation: value.rotate,
        gamma: value.gamma,
      );

  void _updateTexture() {
    var rect = _video?.rect.value;
    _upscaler?.texture(
      rect == null
          ? null
          : (width: rect.width.round(), height: rect.height.round()),
    );
  }

  Future<void> resolveCover(int subject) async {
    if (cover.contains(subject)) return;
    var before = cover.coverOf(subject);
    var after = await cover.resolve(subject);
    if (before != after && !_disposed) _notify();
  }

  static int? _firstSubject(List<PlaybackItem> items) {
    for (var item in items) {
      if (item.subject != null) return item.subject;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _serial(Future<void> Function() action) {
    var next = _operation.then((_) async {
      if (_closed) return;
      await action();
    });
    _operation = next.catchError((Object e, StackTrace s) {
      error = e.toString();
      BTLogTool.warn(['播放操作失败', e.toString()]);
      _notify();
    });
    return next;
  }

  Future<void> _initializePlayer() async {
    if (_player != null) return;
    if (!playerAllowed) throw StateError('主窗口不能创建原生播放器');
    MediaKit.ensureInitialized();
    // Render subtitles with mpv/libass so ASS styling and embedded fonts are
    // preserved instead of reducing every subtitle track to Flutter text.
    var player = Player(
      configuration: PlayerConfiguration(
        libass: true,
        logLevel: Platform.isWindows ? MPVLogLevel.v : MPVLogLevel.error,
      ),
    );
    // Subscribe before the rendering context is created. Keep only capability
    // evidence until the per-Player coordinator exists, never the full log.
    var earlyLogs = <PlayerLog>[];
    var logs = player.stream.log.listen((value) {
      var upscale = _upscaler;
      if (upscale != null) {
        upscale.log(value.prefix, value.level, value.text);
      } else if (earlyLogs.length < 16 &&
          (value.text.contains('GL_RENDERER=') ||
              value.text.contains('High bit depth FBOs unsupported'))) {
        earlyLogs.add(value);
      }
    });
    try {
      await PlaybackSubtitles.configure(player);
    } catch (_) {
      await logs.cancel();
      await _disposePlayer(player);
      rethrow;
    }
    if (_closed) {
      await logs.cancel();
      await _disposePlayer(player);
      return;
    }
    _player = player;
    _video = VideoController(player);
    if (Platform.isWindows) {
      var video = _video!;
      var assets = PlaybackAnime4kAssets(
        path.join(
          PlaybackAssets.directory(
            executable: Platform.resolvedExecutable,
            operatingSystem: Platform.operatingSystem,
          ),
          'shaders',
          'anime4k',
          'v4.0.1',
        ),
      );
      _upscaler = PlaybackUpscaler(
        backend: NativePlaybackUpscaleBackend(player, video),
        loadShaders: assets.load,
        onChanged: _notify,
        onError: (error) => BTLogTool.warn('视频超分：$error'),
      )..preferences(_upscaleMode, _fit);
      for (var value in earlyLogs) {
        _upscaler!.log(value.prefix, value.level, value.text);
      }
      _textureListener = _updateTexture;
      video.rect.addListener(_updateTexture);
      _updateTexture();
    }
    _subscriptions.addAll([
      logs,
      player.stream.position.listen((value) {
        if (!_closed && !loading) position = value;
      }),
      player.stream.duration.listen((value) {
        if (!_closed && !loading && value > Duration.zero) duration = value;
      }),
      player.stream.videoParams.listen((value) {
        if (_closed) return;
        _upscaler?.source(_videoSource(value));
        var ratio = playbackAspectRatio(
          aspect: value.aspect,
          width: value.dw ?? value.w,
          height: value.dh ?? value.h,
          rotation: value.rotate,
        );
        if (ratio == _aspectRatio) return;
        _aspectRatio = ratio;
        _notify();
      }),
      player.stream.error.listen((value) {
        if (_closed) return;
        if (_upscaler?.consumesError(value) ?? false) return;
        error = value;
        _notify();
      }),
      player.stream.completed.listen((value) {
        if (_closed || loading || current == null) return;
        completed = value;
        if (!value) return;
        var snapshot = _session.finish(position: position, duration: duration);
        if (snapshot == null) return;
        unawaited(
          _serial(() async {
            if (_session.id != snapshot.sessionId) return;
            await historyStore.write(snapshot.historyItem);
            if (_closed) return;
            // Broadcast asynchronously; UI/network work must never join the
            // playback queue or delay the next episode.
            _completions.add(snapshot);
            if (index + 1 < playlist.length) await _openIndex(index + 1);
            await refreshHistory();
            _notify();
          }).catchError((Object _) {}),
        );
      }),
    ]);
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_serial(_save).catchError((Object _) {}));
    });
  }

  Future<void> refreshHistory() async {
    await _loadPreferences();
    if (_closed) return;
    var result = await historyStore.readAll();
    if (_closed) return;
    history = result;
    _notify();
  }

  /// Opens a single local file, resolving its Bangumi subject when the caller
  /// does not know it, and rebuilds the playlist from the file's directory.
  Future<void> openLocalFile(String filePath, {int? subject}) => _serial(
    () async {
      var resolved = subject ?? await subjectResolver.subjectForFile(filePath);
      await library.ensureReady(filePath);
      if (_closed) return;
      var discovered = await library.discover(
        path.dirname(filePath),
        subject: resolved,
      );
      if (_closed) return;
      await _openSelection(discovered, filePath);
    },
  );

  Future<void> open(List<PlaybackItem> items, String selectedPath) =>
      _serial(() => _openSelection(items, selectedPath));

  Future<void> _openSelection(
    List<PlaybackItem> items,
    String selectedPath,
  ) async {
    if (items.isEmpty) throw const PlaybackUnavailable('没有可播放的视频');
    var selected = PlaybackItem.pathKey(selectedPath);
    var selectedIndex = items.indexWhere((item) => item.key == selected);
    if (selectedIndex < 0) {
      throw const PlaybackUnavailable('所选视频尚未就绪');
    }
    if (current?.key == selected && !completed) return;
    await library.ensureReady(items[selectedIndex].filePath);
    if (_closed) return;
    await _save();
    if (_closed) return;
    _sourceDir = path.dirname(selectedPath);
    _sourceSubject = _firstSubject(items);
    await _openIndex(selectedIndex, items: List.unmodifiable(items));
  }

  /// Re-scans the source directory to pick up newly completed files, keeping
  /// the currently playing item when it is still present.
  Future<void> refresh() => _serial(() async {
    var dir = _sourceDir;
    if (dir == null) return;
    var discovered = await library.discover(dir, subject: _sourceSubject);
    if (_closed) return;
    if (discovered.isEmpty) {
      error = '没有可播放的视频';
      _notify();
      return;
    }
    var currentKey = current?.key;
    if (currentKey == null) {
      playlist = List.unmodifiable(discovered);
      index = -1;
      _notify();
      return;
    }
    var nextIndex = discovered.indexWhere((item) => item.key == currentKey);
    if (nextIndex < 0) {
      await _openIndex(0, items: List.unmodifiable(discovered));
      return;
    }
    playlist = List.unmodifiable(discovered);
    index = nextIndex;
    _notify();
  });

  Future<void> _openIndex(int nextIndex, {List<PlaybackItem>? items}) async {
    if (_closed) return;
    var nextPlaylist = items ?? playlist;
    if (nextIndex < 0 || nextIndex >= nextPlaylist.length) return;
    var item = nextPlaylist[nextIndex];
    await library.ensureReady(item.filePath);
    if (_closed) return;
    var previous = await historyStore.read(item.filePath);
    await _loadPreferences();
    if (_closed) return;
    await _initializePlayer();
    if (_closed) return;
    loading = true;
    error = null;
    _notify();
    try {
      await _upscaler?.resetMedia();
      if (_closed) return;
      await _player!.stop();
      if (_closed) return;
      playlist = nextPlaylist;
      index = nextIndex;
      _session.begin(item);
      position = previous?.resumePosition ?? Duration.zero;
      duration = Duration(milliseconds: previous?.durationMs ?? 0);
      completed = false;
      // Keep the previous aspect ratio until the new stream reports its own, so
      // auto-advancing between episodes (usually the same ratio) does not make
      // the playback surface size jump.
      await _player!.open(Media(item.filePath, start: position));
      if (_closed) return;
      _upscaler?.mediaReady(_videoSource(_player!.state.videoParams));
      _updateTexture();
    } catch (e) {
      index = -1;
      _session.clear();
      rethrow;
    } finally {
      loading = false;
      _notify();
    }
    await _save();
  }

  Future<void> jump(int nextIndex) => _serial(() async {
    if (nextIndex == index) return;
    await _save();
    await _openIndex(nextIndex);
  });

  Future<void> pause() => _serial(() async {
    await _player?.pause();
    await _save();
  });

  Future<void> _loadPreferences() {
    var pending = _preferencesFuture;
    if (pending != null) return pending;
    var operation = () async {
      await _rateMemory.load();
      _fit = PlaybackFit.parse(await settingsStore.read('playbackFit'));
      if (Platform.isWindows) {
        _upscaleMode = PlaybackUpscaleMode.parse(
          await settingsStore.read('playbackUpscaleMode'),
        );
      }
      _notify();
    }();
    _preferencesFuture = operation;
    unawaited(
      operation.catchError((Object _) {
        // A transport/storage failure must allow the next explicit open/refresh
        // to retry, instead of caching a failed preference Future for this session.
        if (identical(_preferencesFuture, operation)) _preferencesFuture = null;
      }),
    );
    return operation;
  }

  Future<void> setRate(double rate) => _serial(() async {
    await _player?.setRate(PlaybackRateMemory.normalize(rate));
  });

  Future<void> stepRate(double delta) => _serial(() async {
    var player = _player;
    if (player == null) return;
    await player.setRate(PlaybackRateMemory.step(player.state.rate, delta));
  });

  Future<void> toggleRate() => _serial(() async {
    var player = _player;
    if (player == null) return;
    var rate = await _rateMemory.toggle(player.state.rate);
    if (_closed) return;
    await player.setRate(rate);
  });

  Future<void> setFit(PlaybackFit mode) => _serial(() async {
    await _loadPreferences();
    if (_closed || _fit == mode) return;
    await settingsStore.write('playbackFit', mode.name);
    if (_closed) return;
    _fit = mode;
    _upscaler?.preferences(_upscaleMode, _fit);
    _notify();
  });

  Future<void> setUpscaleMode(PlaybackUpscaleMode mode) => _serial(() async {
    await _loadPreferences();
    if (_closed || _upscaleMode == mode || !Platform.isWindows) return;
    await settingsStore.write('playbackUpscaleMode', mode.name);
    if (_closed) return;
    _upscaleMode = mode;
    _upscaler?.preferences(_upscaleMode, _fit);
    _notify();
  });

  Future<void> stop() => _serial(() async {
    await _save();
    loading = true;
    try {
      await _upscaler?.resetMedia();
      if (_closed) return;
      await _player?.stop();
      _session.clear();
      index = -1;
      playlist = [];
      position = Duration.zero;
      duration = Duration.zero;
      completed = false;
    } finally {
      loading = false;
      _notify();
    }
  });

  Future<void> _save({bool refreshHistory = true}) async {
    var item = current;
    if (item == null || loading) return;
    await historyStore.write(
      PlaybackItem(
        filePath: item.filePath,
        title: item.title,
        subject: item.subject,
        positionMs: completed
            ? duration.inMilliseconds
            : position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        completed: completed,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    // Closing only needs the durable write. Don't query the entire history or
    // rebuild the page while native resources are being released.
    if (!refreshHistory || _closed) return;
    var savedHistory = await historyStore.readAll();
    if (_closed) return;
    history = savedHistory;
    _notify();
  }

  Future<void> removeHistory(String filePath) => _serial(() async {
    // Stop first so periodic saves cannot re-create a deleted active record.
    if (current?.key == PlaybackItem.pathKey(filePath)) {
      loading = true;
      try {
        await _upscaler?.resetMedia();
        if (_closed) return;
        await _player?.stop();
        _session.clear();
        index = -1;
        playlist = [];
      } finally {
        loading = false;
      }
    }
    await historyStore.delete(filePath);
    await refreshHistory();
  });

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  /// Closing a child engine must not cancel timed-out writes or mpv's delayed
  /// destruction. Keep the engine alive until every accepted operation settles.
  Future<void> waitForShutdownSettlement() =>
      _settlementFuture ??= _waitForShutdownSettlement();

  Future<void> _waitForShutdownSettlement() async {
    await shutdown();
    await Future.wait(_shutdownWork);
    await Future.wait(_nativeDestructions);
    if (_shutdownFailures.isNotEmpty) {
      throw StateError('播放器未能完成保存或清理：${_shutdownFailures.first}');
    }
  }

  Future<void> _disposePlayer(Player player) {
    var upscale = _upscaler;
    var disposal = () async {
      // This wait is not cancelled by the shutdown budget: native commands may
      // still own the media_kit disposal lock after a timeout.
      await upscale?.close();
      await player.dispose();
    }();
    // media_kit 1.2.6 schedules mpv_terminate_destroy 5 seconds after dispose.
    // Do not destroy the child isolate before that timer runs, or call the
    // native destructor ourselves (which would double-free the same handle).
    var destruction = disposal
        .then((_) async {
          if (waitForNativeDestroy) {
            await Future<void>.delayed(const Duration(milliseconds: 5200));
          }
        })
        .catchError((Object error) {
          _shutdownFailures.add(error);
        });
    _nativeDestructions.add(destruction);
    return disposal;
  }

  Future<void> _shutdown() async {
    // Refuse newly queued work before waiting for the current operation.
    _closed = true;
    _session.close();
    _saveTimer?.cancel();
    var pending = _operation;
    var drained = await _shutdownStep(
      '等待播放操作',
      () => pending,
      const Duration(seconds: 2),
    );
    // Future.timeout does not cancel the pending operation. If it is still
    // using mpv, detach the UI now but release native resources only after it
    // settles. Global process exit remains bounded by the existing budgets.
    var finalItem = current;
    var finalRecord = finalItem == null
        ? null
        : PlaybackItem(
            filePath: finalItem.filePath,
            title: finalItem.title,
            subject: finalItem.subject,
            positionMs: completed
                ? duration.inMilliseconds
                : position.inMilliseconds,
            durationMs: duration.inMilliseconds,
            completed: completed,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
    if (drained && finalRecord != null) {
      await _shutdownStep(
        '保存播放位置',
        () => historyStore.write(finalRecord),
        const Duration(seconds: 2),
      );
    }
    var detach = beforeVideoDispose;
    beforeVideoDispose = null;
    if (detach != null) {
      await _shutdownStep('退出视频全屏', detach, const Duration(seconds: 1));
    }

    // StreamController.close can wait on widget subscriptions. Unmount Video
    // and its controls while the window can still render, then dispose mpv.
    var player = _player;
    var textureListener = _textureListener;
    if (textureListener != null) _video?.rect.removeListener(textureListener);
    _textureListener = null;
    var upscale = _upscaler;
    if (upscale != null) {
      await _shutdownStep(
        '停止视频超分操作',
        upscale.close,
        const Duration(seconds: 1),
      );
    }
    _player = null;
    _video = null;
    index = -1;
    playlist = [];
    loading = false;
    _notify();
    if (!_disposed && player != null) {
      await _shutdownStep(
        '移除视频界面',
        () => WidgetsBinding.instance.endOfFrame,
        const Duration(seconds: 1),
      );
    }

    var subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    await _shutdownStep('取消播放监听', () async {
      await Future.wait(subscriptions.map((s) => s.cancel()));
    }, const Duration(seconds: 1));
    unawaited(_completions.close());
    if (player != null && drained) {
      await _shutdownStep(
        '释放原生播放器',
        () => _disposePlayer(player),
        const Duration(seconds: 2),
      );
    } else if (player != null) {
      var cleanup = () async {
        try {
          await pending;
        } catch (_) {
          // The queue already records operation errors.
        }
        if (finalRecord != null) {
          try {
            await historyStore.write(finalRecord);
          } catch (error) {
            _shutdownFailures.add(error);
            BTLogTool.warn('迟到播放位置保存失败：$error');
          }
        }
        await _disposePlayer(player);
      }();
      _shutdownWork.add(
        cleanup.catchError((Object error) {
          _shutdownFailures.add(error);
          BTLogTool.warn('迟到原生播放器释放失败：$error');
        }),
      );
    }
  }

  Future<bool> _shutdownStep(
    String name,
    Future<void> Function() action,
    Duration timeout,
  ) async {
    var work = Future<void>.sync(action);
    _shutdownWork.add(
      work.catchError((Object error) {
        _shutdownFailures.add(error);
      }),
    );
    try {
      await work.timeout(timeout);
      return true;
    } on TimeoutException {
      BTLogTool.warn('播放器清理超时：$name');
    } catch (error) {
      BTLogTool.warn('播放器清理失败：$name，$error');
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(
      shutdown().catchError((Object e) {
        BTLogTool.warn('释放播放器失败：$e');
      }),
    );
    super.dispose();
  }
}
