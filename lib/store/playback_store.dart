// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../core/errors/playback_unavailable.dart';
import '../core/services/native_playback_upscale_backend.dart';
import '../core/services/playback_audio.dart';
import '../core/services/playback_audio_controller.dart';
import '../core/services/playback_cache.dart';
import '../core/services/playback_chapters.dart';
import '../core/services/playback_close_progress.dart';
import '../core/services/playback_diagnostics.dart';
import '../core/services/playback_janai_benchmarks.dart';
import '../core/services/playback_janai_video_source.dart';
import '../core/services/playback_loudness.dart';
import '../core/services/playback_screenshot.dart';
import '../core/services/playback_session_lifecycle.dart';
import '../core/services/playback_subtitles.dart';
import '../core/services/playback_tensorrt_resources.dart';
import '../core/services/playback_upscale_controller.dart';
import '../core/services/playback_upscaler.dart';
import '../data/repositories/episode_mark_gateway_impl.dart';
import '../data/repositories/playback_cover_impl.dart';
import '../data/repositories/playback_episodes.dart';
import '../data/repositories/playback_history_impl.dart';
import '../data/repositories/playback_library_impl.dart';
import '../data/repositories/playback_settings_impl.dart';
import '../data/repositories/playback_subjects_impl.dart';
import '../domain/repositories/playback_cover.dart';
import '../domain/repositories/playback_history.dart';
import '../domain/repositories/playback_library.dart';
import '../domain/repositories/playback_settings.dart';
import '../domain/repositories/playback_subjects.dart';
import '../models/playback/playback_chapter.dart';
import '../models/playback/playback_completion.dart';
import '../models/playback/playback_episode_layout.dart';
import '../models/playback/playback_geometry.dart';
import '../models/playback/playback_hires.dart';
import '../models/playback/playback_history_group.dart';
import '../models/playback/playback_item.dart';
import '../models/playback/playback_janai_benchmark.dart';
import '../models/playback/playback_rate.dart';
import '../models/playback/playback_subtitle.dart';
import '../models/playback/playback_upscale.dart';
import '../providers/bangumi_providers.dart';
import '../providers/bmf_providers.dart';
import '../providers/episode_mark_providers.dart';
import '../providers/playback_episode_link_providers.dart';
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
      links: ref.read(playbackEpisodeLinksProvider),
      knownEpisodes: (subject) =>
          ref.read(episodeMarkProvider.notifier).service.knownChapters(subject),
      episodes: (subject) async {
        var known = await ref
            .read(episodeMarkProvider.notifier)
            .service
            .chaptersForPlayback(subject);
        return known ??
            (await loadPlaybackEpisodes(
              ref.read(bangumiRepositoryProvider),
              subject,
            )).map(episodeMarkChapter).toList();
      },
    ),
    cover: BangumiPlaybackCoverResolver(ref.read(bangumiRepositoryProvider)),
    historyStore: AppPlaybackHistoryStore(),
    settingsStore: AppPlaybackSettingsStore(),
    subjectResolver: BmfPlaybackSubjectResolver(
      ref.read(bmfRepositoryProvider),
      ref.read(playbackEpisodeLinksProvider),
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
  late final _audio = PlaybackAudioController(
    settingsStore: settingsStore,
    readPlayer: () => _player,
    readSession: () => (id: _session.id, item: current, completed: completed),
    isClosed: () => _closed,
    serial: _serial,
    onDiagnostic: (message) => _diagnostics?.event(message),
    onChanged: _notify,
  );
  late final _upscale = PlaybackUpscaleController(
    settingsStore: settingsStore,
    readUpscaler: () => _upscaler,
    isClosed: () => _closed,
    onChanged: _notify,
  );
  PlaybackEpisodeLayout _episodeLayout = PlaybackEpisodeLayout.grid;
  double? _aspectRatio;
  Size? _videoSize;
  Player? _player;
  PlaybackDiagnostics? _diagnostics;
  PlaybackJanaiVideoSource? _janaiVideoSource;
  PlaybackChapters? _chapters;
  bool _manualSubtitles = true;
  VideoController? _video;
  PlaybackUpscaler? _upscaler;
  Object? _viewportOwner;
  bool _viewportFullscreen = false;
  final _viewports = <Object, ({PlaybackViewport value, bool fullscreen})>{};
  VoidCallback? _textureListener;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _saveTimer;
  Timer? _idlePlayerTimer;
  late final _lifecycle = PlaybackSessionLifecycle(
    onOperationError: (errorValue, stackTrace) {
      error = errorValue.toString();
      BTLogTool.error([
        '播放操作失败：file=$_operationFile',
        errorValue.toString(),
        stackTrace.toString(),
      ]);
      _notify();
    },
  );
  Future<void>? _clearPlaybackFuture;
  bool _clearingPlayback = false;
  String? _operationFile;
  List<PlaybackItem> playlist = [];
  List<PlaybackItem> history = [];
  List<PlaybackHistoryGroup> historyGroups = [];
  int index = -1;
  bool loading = false;
  String? _openingStatus;
  String? error;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool completed = false;
  bool get _closed => _lifecycle.isClosed;
  bool _disposed = false;
  final _session = PlaybackSession();
  final _completions = StreamController<PlaybackCompletion>.broadcast();

  Stream<PlaybackCompletion> get completions => _completions.stream;
  bool get isClosed => _closed;
  bool get isOpening => _openingStatus != null;
  String? get openingStatus => _openingStatus;
  String? get openingFile => isOpening ? _operationFile : null;

  Player? get player => _player;

  Future<String> readVideoProperty(String name) =>
      _diagnostics?.readProperty(name) ?? Future.value('');
  List<PlaybackChapter> get chapters => _chapters?.chapters ?? const [];
  bool get automaticSubtitles => !_manualSubtitles;
  VideoController? get video => _video;
  PlaybackUpscaler? get upscaler => _upscaler;
  PlaybackUpscaleMode get upscaleMode => _upscale.selectedMode;
  bool get tensorRtEnabled => _upscale.tensorRtEnabled;
  PlaybackTensorRtResources get tensorRtResources => _upscale.tensorRtResources;
  PlaybackJanaiBenchmarks get janaiBenchmarks => _upscale.janaiBenchmarks;

  PlaybackJanaiRecommendation get janaiRecommendation {
    var state = !loading && current != null ? _player?.state : null;
    return _upscale.recommendation(
      state: state,
      source: state == null ? null : _janaiVideoSource?.parameters,
    );
  }

  Future<void> downloadTensorRt() => _upscale.downloadTensorRt();
  Future<void> cancelTensorRt() => _upscale.cancelTensorRt(setUpscaleMode);
  Future<void> retryTensorRt() => _upscale.retryTensorRt();

  bool get loudnessEnabled => _audio.loudnessEnabled;
  bool get hiResEnabled => _audio.hiResEnabled;
  bool get audioExclusiveEnabled => _audio.audioExclusiveEnabled;
  bool get canEnableAudioExclusive => _audio.canEnableAudioExclusive;
  PlaybackHiResState get hiRes => _audio.hiRes;
  bool get loudnessActive => _audio.loudnessActive;
  bool get loudnessPausedForHiRes => _audio.loudnessPausedForHiRes;
  PlaybackEpisodeLayout get episodeLayout => _episodeLayout;
  double? get aspectRatio => _aspectRatio;

  /// 当前视频的显示像素尺寸；独立窗口按它计算原始尺寸与倍率。
  Size? get videoSize => _videoSize;
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

  void beginViewportTransition() => _upscaler?.beginViewportTransition();

  void endViewportTransition() => _upscaler?.endViewportTransition();

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
    var before = (cover.coverOf(subject), cover.nameOf(subject));
    await cover.resolve(subject);
    if (_disposed) return;
    if (before != (cover.coverOf(subject), cover.nameOf(subject))) _notify();
  }

  /// Fills names for list titles from local caches only.
  ///
  /// 打开播放记录或选集不应该顺带请求 bgm：命中磁盘缓存就直接用条目名，没命中
  /// 就让列表继续显示文件名，等真正播放时再由 [resolveCover] 解析。
  Future<void> hydrateCovers(Iterable<int> subjects) async {
    var changed = false;
    for (var subject in subjects) {
      if (_disposed) return;
      if (cover.contains(subject)) continue;
      if (await cover.hydrate(subject)) changed = true;
    }
    if (changed && !_disposed) _notify();
  }

  /// 独立播放窗口解析条目后，主窗口的记录与选集标题需要跟着刷新。
  void notifyCoverResolved() => _notify();

  static int? _firstSubject(List<PlaybackItem> items) {
    for (var item in items) {
      if (item.subject != null) return item.subject;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Preparation starts before media loading and must still allow saving the
  /// previous item's position. Keep this separate from [loading].
  void _setOpeningStatus(String? value) {
    if (_openingStatus == value || (_closed && value != null)) return;
    if (_openingStatus == null && value != null) error = null;
    if (value != null) {
      _idlePlayerTimer?.cancel();
      _idlePlayerTimer = null;
    }
    _openingStatus = value;
    _notify();
  }

  Future<void> _serial(Future<void> Function() action, {String? file}) =>
      _lifecycle.run(() async {
        _operationFile = file ?? current?.filePath;
        try {
          await action();
        } finally {
          _setOpeningStatus(null);
          _syncIdlePlayerTimer();
        }
      });

  // A paused or completed file still owns its Player. Only unloaded media can
  // release the native render context without interrupting a viewing session.
  bool get _canReleaseIdlePlayer =>
      !_closed &&
      _player != null &&
      current == null &&
      _player!.state.playlist.medias.isEmpty &&
      !loading &&
      !isOpening &&
      !_clearingPlayback;

  void _syncIdlePlayerTimer() {
    if (!_canReleaseIdlePlayer) {
      _idlePlayerTimer?.cancel();
      _idlePlayerTimer = null;
      return;
    }
    // Settings and history operations must not extend the idle deadline.
    if (_idlePlayerTimer != null) return;
    late Timer timer;
    timer = _idlePlayerTimer = Timer(const Duration(hours: 2), () {
      unawaited(
        _serial(() async {
          // An open may have cancelled this timeout while it was queued.
          if (!identical(_idlePlayerTimer, timer) || !_canReleaseIdlePlayer) {
            return;
          }
          _idlePlayerTimer = null;
          await _releaseIdlePlayer();
        }).catchError((Object _) {}),
      );
    });
  }

  Future<void> _releaseIdlePlayer() async {
    var player = _player!;
    var upscale = _upscaler;
    var textureListener = _textureListener;
    if (textureListener != null) _video?.rect.removeListener(textureListener);
    _textureListener = null;
    // Detach synchronously so shutdown cannot take ownership of this Player
    // while listener cancellation or native disposal is still pending.
    _player = null;
    _video = null;
    _upscaler = null;
    _diagnostics?.close();
    _diagnostics = null;
    _janaiVideoSource?.close();
    _janaiVideoSource = null;
    _chapters?.close();
    _chapters = null;
    _saveTimer?.cancel();
    _saveTimer = null;
    _audio.releasePlayer();
    _viewports.clear();
    _viewportOwner = null;
    _viewportFullscreen = false;
    _aspectRatio = null;
    _videoSize = null;
    var subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    BTLogTool.info('未加载文件已满 2 小时，释放原生播放器');
    _notify();
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
    await _disposePlayer(player, upscale: upscale);
  }

  Future<void> _initializePlayer() async {
    if (_player != null) return;
    if (!playerAllowed) throw StateError('主窗口不能创建原生播放器');
    BTLogTool.info('开始初始化原生播放器');
    MediaKit.ensureInitialized();
    // Render subtitles with mpv/libass so ASS styling and embedded fonts are
    // preserved instead of reducing every subtitle track to Flutter text.
    var player = Player(
      configuration: PlayerConfiguration(
        libass: true,
        logLevel: Platform.isWindows ? MPVLogLevel.v : MPVLogLevel.info,
      ),
    );
    var diagnostics = _diagnostics = PlaybackDiagnostics(
      player,
      context: () {
        var rect = _video?.rect.value;
        return {
          'file': current?.filePath,
          'loading': loading,
          'upscale': _upscale.preferredMode.name,
          'loudness': loudnessActive,
          'hires_requested': _audio.hiResEnabled,
          'audio_exclusive_requested': _audio.audioExclusiveEnabled,
          'audio_exclusive_configured': _audio.exclusiveConfigured,
          'hires_status': hiRes.status,
          'texture': rect == null ? null : '${rect.width}x${rect.height}',
          'upscale_configured': _upscaler?.configuredMode?.name,
        };
      },
    );
    // Subscribe before the rendering context is created. Keep only capability
    // evidence until the per-Player coordinator exists, never the full log.
    var earlyLogs = <PlayerLog>[];
    var logs = player.stream.log.listen((value) {
      diagnostics.log(value);
      _audio.log(value);
      var upscale = _upscaler;
      if (upscale != null) {
        upscale.log(value.prefix, value.level, value.text);
      } else if (earlyLogs.length < 16 &&
          (value.text.contains('GL_RENDERER=') ||
              value.text.contains('High bit depth FBOs unsupported'))) {
        earlyLogs.add(value);
      }
    });
    var chapters = PlaybackChapters(
      player.platform as NativePlayer,
      onChanged: _notify,
    );
    var janaiSource = PlaybackJanaiVideoSource(
      read: diagnostics.readProperty,
      onChanged: _notify,
    );
    try {
      await PlaybackCache.configure(player);
      await PlaybackSubtitles.configure(player);
      await PlaybackAudio.apply(player, false);
      await chapters.initialize();
      var native = player.platform as NativePlayer;
      if (Platform.isWindows) {
        // Use the shader-capable pipeline from the first frame. mpv's simple
        // path samples the padded D3D11 decoder texture differently (e.g.
        // 1088 vs 1080 lines), shifting the picture when shaders are toggled.
        // Set this before VideoController creates the rendering context so
        // ordinary playback and upscale recovery share the same cropping.
        await native.setProperty('gpu-dumb-mode', 'no');
        for (var property in ['current-tracks/video', 'video-dec-params']) {
          await native.observeProperty(property, (_) async {
            unawaited(janaiSource.refresh());
          });
        }
      }
      for (var property in ['audio-out-params', 'current-tracks/audio']) {
        await native.observeProperty(property, (_) async {
          _audio.scheduleRefresh();
        });
      }
      if (Platform.isWindows) {
        await PlaybackLoudness.apply(player, loudnessActive);
      }
    } catch (error, stackTrace) {
      BTLogTool.error(['初始化播放器失败：$error', stackTrace.toString()]);
      diagnostics.close();
      chapters.close();
      janaiSource.close();
      await logs.cancel();
      await _disposePlayer(player);
      rethrow;
    }
    if (_closed) {
      diagnostics.close();
      chapters.close();
      janaiSource.close();
      await logs.cancel();
      await _disposePlayer(player);
      return;
    }
    _player = player;
    _chapters = chapters;
    _janaiVideoSource = janaiSource;
    // Keep the same GPU decoder for plain playback, Anime4K and AnimeJaNai.
    // The coordinator only changes filters after checking the media's range.
    _video = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        hwdec: Platform.isWindows
            ? NativePlaybackUpscaleBackend.hardwareDecoder
            : null,
      ),
    );
    if (Platform.isWindows) {
      var video = _video!;
      _upscaler = _upscale.createUpscaler(player, video, diagnostics);
      for (var value in earlyLogs) {
        _upscaler!.log(value.prefix, value.level, value.text);
      }
      _textureListener = _updateTexture;
      video.rect.addListener(_updateTexture);
      _updateTexture();
    }
    _subscriptions.addAll([
      logs,
      player.stream.playing.listen((value) {
        diagnostics.event('播放状态改变：playing=$value');
        _upscaler?.playbackState(
          playing: value,
          buffering: player.state.buffering,
        );
      }),
      player.stream.buffering.listen((value) {
        diagnostics.event('缓冲状态改变：buffering=$value');
        _upscaler?.playbackState(
          playing: player.state.playing,
          buffering: value,
        );
      }),
      player.stream.rate.listen((value) {
        diagnostics.event('播放速率改变：rate=$value');
        _upscaler?.playbackRate(value);
        _audio.scheduleRefresh();
        _notify();
      }),
      player.stream.audioParams.listen((_) => _audio.scheduleRefresh()),
      player.stream.audioDevice.listen((_) => _audio.deviceChanged()),
      player.stream.tracks.listen((_) {
        if (Platform.isWindows) unawaited(janaiSource.refresh());
        if (_closed || completed || _manualSubtitles || current == null) return;
        var sessionId = _session.id;
        unawaited(
          _serial(() async {
            if (_session.id != sessionId || current == null) return;
            await _autoSelectSubtitle();
          }).catchError((Object _) {}),
        );
      }),
      player.stream.position.listen((value) {
        if (!_closed && !loading && current != null) position = value;
      }),
      player.stream.duration.listen((value) {
        if (!_closed && !loading && current != null && value > Duration.zero) {
          duration = value;
        }
      }),
      player.stream.videoParams.listen((value) {
        if (_closed || current == null) return;
        if (Platform.isWindows) unawaited(janaiSource.refresh());
        var source = _videoSource(value);
        _upscaler?.source(source);
        var ratio = playbackAspectRatio(
          aspect: value.aspect,
          width: value.dw ?? value.w,
          height: value.dh ?? value.h,
          rotation: value.rotate,
        );
        // 像素尺寸参与窗口缩放，等比例的分辨率切换也必须通知界面。
        var size = source == null
            ? null
            : Size(source.width.toDouble(), source.height.toDouble());
        if (ratio == _aspectRatio && size == _videoSize) return;
        _aspectRatio = ratio;
        _videoSize = size;
        _notify();
      }),
      player.stream.error.listen((value) {
        diagnostics.failure(value);
        if (_closed || current == null) return;
        if (_upscaler?.consumesError(value) ?? false) return;
        error = value;
        _notify();
      }),
      player.stream.completed.listen((value) {
        if (_closed || _clearingPlayback || loading || current == null) return;
        completed = value;
        if (!value) return;
        diagnostics.event('视频播放完成');
        var snapshot = _session.finish(position: position, duration: duration);
        if (snapshot == null) return;
        var items = playlist;
        var finishedIndex = index;
        unawaited(
          // Matching runs alongside the durable write, outside the operation
          // queue. Refreshing the full history waits until after the switch.
          Future.wait<int?>([
                _serial(() async {
                  if (_session.id != snapshot.sessionId) return;
                  await historyStore.write(snapshot.historyItem);
                  if (_closed) return;
                  _completions.add(snapshot);
                  _notify();
                }).then((_) => null),
                library.nextEpisodeIndex(items, finishedIndex),
              ])
              .then((results) async {
                if (_closed ||
                    _clearingPlayback ||
                    _session.id != snapshot.sessionId) {
                  return;
                }
                var nextIndex = results[1];
                if (nextIndex == null) {
                  await refreshHistory();
                  return;
                }
                await _serial(() async {
                  if (_closed ||
                      _clearingPlayback ||
                      _session.id != snapshot.sessionId) {
                    return;
                  }
                  var nextKey = items[nextIndex].key;
                  var liveIndex = playlist.indexWhere(
                    (item) => item.key == nextKey,
                  );
                  if (liveIndex >= 0) await _openIndex(liveIndex);
                });
              })
              .catchError((Object failure) {
                if (_closed || _session.id != snapshot.sessionId) return;
                error = '自动切换下一集失败：$failure';
                _notify();
              }),
        );
      }),
    ]);
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_closed ||
          _clearingPlayback ||
          loading ||
          !player.state.playing ||
          completed) {
        return;
      }
      // Persist progress without fetching/grouping the entire library or
      // rebuilding the video surface every five seconds during playback.
      unawaited(
        _serial(() async {
          if (!_clearingPlayback) await _save(refreshHistory: false);
        }).catchError((Object _) {}),
      );
    });
  }

  /// Browsing history must not probe CUDA or verify TensorRT runtime files.
  /// Playback preferences are loaded when opening media or changing settings.
  Future<void> refreshHistory() async {
    if (_closed) return;
    var result = await historyStore.readAll();
    if (_closed) return;
    history = result;
    historyGroups = groupPlaybackHistory(result);
    _notify();
  }

  void _prepareNextEpisode() {
    if (_closed || current == null) return;
    unawaited(
      library.prepareNextEpisode(playlist, index).catchError((Object failure) {
        // Preloading is optional; EOF matching retries a failed chapter load.
        BTLogTool.warn('预加载自动切集章节失败：$failure');
      }),
    );
  }

  /// Opens a single local file, resolving its Bangumi subject when the caller
  /// does not know it, and rebuilds the playlist from its download root.
  Future<void> openLocalFile(String filePath, {int? subject}) => _serial(
    () async {
      _setOpeningStatus('正在准备视频…');
      var resolved = subject ?? await subjectResolver.subjectForFile(filePath);
      await library.ensureReady(filePath);
      if (_closed) return;
      var directory = await subjectResolver.directoryForFile(
        filePath,
        subject: resolved,
      );
      if (_closed) return;
      _setOpeningStatus('正在扫描播放列表…');
      var discovered = await library.discover(directory, subject: resolved);
      if (_closed) return;
      await _openSelection(
        discovered,
        filePath,
        sourceDirectory: directory,
        sourceSubject: resolved,
      );
    },
    file: filePath,
  );

  Future<void> open(List<PlaybackItem> items, String selectedPath) =>
      _serial(() => _openSelection(items, selectedPath), file: selectedPath);

  Future<void> _openSelection(
    List<PlaybackItem> items,
    String selectedPath, {
    String? sourceDirectory,
    int? sourceSubject,
  }) async {
    _setOpeningStatus('正在准备视频…');
    if (items.isEmpty) throw const PlaybackUnavailable('没有可播放的视频');
    var selected = PlaybackItem.pathKey(selectedPath);
    var selectedIndex = items.indexWhere((item) => item.key == selected);
    if (selectedIndex < 0) {
      throw const PlaybackUnavailable('所选视频尚未就绪');
    }
    var keepCurrent = current?.key == selected && !completed;
    await library.ensureReady(items[selectedIndex].filePath);
    if (_closed) return;
    if (!keepCurrent) await _save();
    if (_closed) return;
    _sourceDir = sourceDirectory ?? path.dirname(selectedPath);
    _sourceSubject = sourceSubject ?? _firstSubject(items);
    if (keepCurrent) {
      playlist = List.unmodifiable(items);
      index = selectedIndex;
      _prepareNextEpisode();
      _notify();
      return;
    }
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
    _prepareNextEpisode();
    _notify();
  });

  Future<void> _openIndex(int nextIndex, {List<PlaybackItem>? items}) async {
    if (_closed) return;
    var nextPlaylist = items ?? playlist;
    if (nextIndex < 0 || nextIndex >= nextPlaylist.length) return;
    var item = nextPlaylist[nextIndex];
    _operationFile = item.filePath;
    BTLogTool.info('准备播放：${item.filePath}');
    _setOpeningStatus('正在读取播放记录…');
    await library.ensureReady(item.filePath);
    if (_closed) return;
    var previous = await historyStore.read(item.filePath);
    _setOpeningStatus('正在加载播放设置…');
    await _loadPreferences();
    if (_closed) return;
    _setOpeningStatus('正在初始化播放器…');
    await _initializePlayer();
    if (_closed) return;
    _setOpeningStatus('正在打开视频…');
    loading = true;
    error = null;
    _notify();
    try {
      _manualSubtitles = true;
      _chapters?.reset();
      _janaiVideoSource?.reset();
      await _upscaler?.resetMedia(keepOutput: true);
      if (_closed) return;
      await _player!.stop();
      await _audio.reset();
      if (_closed) return;
      playlist = nextPlaylist;
      index = nextIndex;
      _session.begin(item);
      _prepareNextEpisode();
      _janaiVideoSource?.reset(active: true);
      _manualSubtitles = false;
      position = previous?.resumePosition ?? Duration.zero;
      duration = Duration(milliseconds: previous?.durationMs ?? 0);
      completed = false;
      _diagnostics?.opening(item.filePath, position);
      // Keep the previous aspect ratio until the new stream reports its own, so
      // auto-advancing between episodes (usually the same ratio) does not make
      // the playback surface size jump.
      await _player!.setSubtitleTrack(SubtitleTrack.no());
      _chapters?.reset(active: true);
      await _player!.open(Media(item.filePath, start: position));
      if (_closed) return;
      _setOpeningStatus('正在恢复播放状态…');
      _audio.scheduleRefresh();
      await _autoSelectSubtitle();
      await _chapters?.refresh();
      _upscaler?.mediaReady(_videoSource(_player!.state.videoParams));
      if (Platform.isWindows) unawaited(_janaiVideoSource?.refresh());
      _updateTexture();
    } catch (e) {
      index = -1;
      _janaiVideoSource?.reset();
      _manualSubtitles = true;
      _chapters?.reset();
      _session.clear();
      // A failed open must release any output retained for an episode switch.
      await _upscaler?.resetMedia();
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

  /// Capture before queued media changes reset the renderer. Once copied, the
  /// image belongs to this request even if another episode starts afterwards.
  Future<({Uint8List image, Duration position})?> captureScreenshot() async {
    var player = _player;
    if (_closed || loading || player == null || current == null) return null;
    var sessionId = _session.id;
    var capturedPosition = player.state.position;
    ({Uint8List image, Duration position})? screenshot;
    await _serial(() async {
      if (_session.id != sessionId || _player != player || current == null) {
        return;
      }
      var image = await PlaybackScreenshot.capture(
        player,
        rendered: _upscaler?.configuredMode != null,
      );
      if (image == null || image.isEmpty) {
        throw const PlaybackUnavailable('当前没有可截取的视频画面');
      }
      screenshot = (image: image, position: capturedPosition);
    });
    return screenshot;
  }

  Future<void> _autoSelectSubtitle() async {
    var player = _player;
    if (_closed || player == null || _manualSubtitles || current == null) {
      return;
    }
    var id = preferredPlaybackSubtitle(
      player.state.tracks.subtitle.map(
        (track) => (
          id: track.id,
          title: track.title,
          language: track.language,
          isDefault: track.isDefault,
        ),
      ),
    );
    if (player.state.track.subtitle.id == id) return;
    var track = player.state.tracks.subtitle.firstWhere(
      (track) => track.id == id,
      orElse: SubtitleTrack.no,
    );
    await player.setSubtitleTrack(track);
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) {
    var sessionId = _session.id;
    var automatic = track.id == 'auto';
    // Mark the manual choice before queued automatic selections can run.
    _manualSubtitles = !automatic;
    return _serial(() async {
      if (_session.id != sessionId || current == null) return;
      if (!automatic) {
        await _player?.setSubtitleTrack(track);
      } else {
        await _autoSelectSubtitle();
      }
      _notify();
    });
  }

  /// Settings can load saved preferences without creating a player.
  Future<void> loadPreferences() => _serial(_loadPreferences);

  /// The main window owns this switch; a retained child must re-read it.
  Future<void> refreshTensorRtEnabled() async {
    var pending = _preferencesFuture;
    // A child that has only shown history will load the switch with its media.
    if (pending == null || _closed || !Platform.isWindows) return;
    await pending;
    var enabled = await settingsStore.read('playbackTensorRTEnabled') == 'true';
    await setTensorRtEnabled(enabled);
  }

  Future<void> _loadPreferences() {
    var pending = _preferencesFuture;
    if (pending != null) return pending;
    var operation = () async {
      await _rateMemory.load();
      await _audio.loadPreferences();
      _episodeLayout = PlaybackEpisodeLayout.parse(
        await settingsStore.read('playbackEpisodeLayout'),
      );
      if (Platform.isWindows) {
        // Resolves the component root before the benchmark cache reads it.
        await _upscale.initializeResources();
        await _audio.loadLoudnessPreference();
        await _upscale.loadPreferences();
      }
      _notify();
    }();
    _preferencesFuture = operation;
    unawaited(
      operation.catchError((Object _) {
        // A transport/storage failure must allow the next explicit open/refresh
        // to retry instead of caching a failed preference Future.
        if (identical(_preferencesFuture, operation)) _preferencesFuture = null;
      }),
    );
    return operation;
  }

  Future<void> setLoudnessEnabled(bool enabled) => _serial(() async {
    await _loadPreferences();
    await _audio.setLoudnessEnabled(enabled);
  });

  Future<void> setRate(double rate) => _serial(() => _setRate(rate));

  Future<void> _setRate(double rate) async {
    var player = _player;
    if (player == null) return;
    rate = PlaybackRateMemory.normalize(rate);
    await player.setRate(rate);
    await _rateMemory.remember(rate);
    _notify();
  }

  Future<void> stepRate(double delta) => _serial(() async {
    var player = _player;
    if (player == null) return;
    await _setRate(PlaybackRateMemory.step(player.state.rate, delta));
  });

  Future<void> toggleRate() => _serial(() async {
    var player = _player;
    if (player == null) return;
    var rate = await _rateMemory.toggle(player.state.rate);
    if (_closed) return;
    await player.setRate(rate);
  });

  Future<void> setHiResEnabled(bool enabled) => _serial(() async {
    await _loadPreferences();
    await _audio.setHiResEnabled(enabled);
  });

  Future<void> setAudioTrack(AudioTrack track) =>
      _serial(() => _audio.setAudioTrack(track));

  Future<void> setAudioExclusiveEnabled(bool enabled) => _serial(() async {
    await _loadPreferences();
    await _audio.setAudioExclusiveEnabled(enabled);
  });

  Future<void> setEpisodeLayout(PlaybackEpisodeLayout layout) =>
      _serial(() async {
        await _loadPreferences();
        if (_closed || _episodeLayout == layout) return;
        await settingsStore.write('playbackEpisodeLayout', layout.name);
        if (_closed) return;
        _episodeLayout = layout;
        _notify();
      });

  Future<void> setUpscaleMode(PlaybackUpscaleMode mode) => _serial(() async {
    await _loadPreferences();
    await _upscale.setUpscaleMode(mode);
  });

  Future<void> restoreUpscaleMode() => _serial(() async {
    // Recheck after queued media/settings changes to avoid restoring a stale
    // notice's mode in another episode or after the user selects a new mode.
    var mode = _upscaler?.restorableMode;
    if (mode != null) await _upscale.setUpscaleMode(mode);
  });

  Future<void> setTensorRtEnabled(bool enabled) => _serial(() async {
    await _loadPreferences();
    await _upscale.setTensorRtEnabled(enabled);
  });

  Future<void> stop() => _serial(_stop);

  /// Unload media, retaining its native context for up to two idle hours.
  Future<void> clearCurrentPlayback({PlaybackCloseProgress? progress}) =>
      _clearPlaybackFuture ??= _clearCurrentPlayback(
        progress ?? const PlaybackCloseProgress(),
      ).whenComplete(() => _clearPlaybackFuture = null);

  Future<void> _clearCurrentPlayback(PlaybackCloseProgress progress) {
    _clearingPlayback = true;
    var pending = _lifecycle.pending;
    var ready = progress.run('等待当前播放操作完成', () => pending);
    return _serial(() async {
      await ready;
      await progress.run('暂停超分更新', () async => _upscaler?.suspendMedia());
      await progress.run('退出全屏', () async => beforeVideoDispose?.call());
      await _stop(refreshHistory: false, progress: progress);
      _sourceDir = null;
      _sourceSubject = null;
      _aspectRatio = null;
      _videoSize = null;
      error = null;
      _diagnostics?.stopped();
      _notify();
    }).whenComplete(() {
      _clearingPlayback = false;
      _syncIdlePlayerTimer();
    });
  }

  Future<void> _stop({
    bool refreshHistory = true,
    PlaybackCloseProgress? progress,
  }) async {
    var stages = progress ?? const PlaybackCloseProgress();
    await stages.run('保存播放进度', () => _save(refreshHistory: refreshHistory));
    loading = true;
    _janaiVideoSource?.reset();
    try {
      _manualSubtitles = true;
      _chapters?.reset();
      await stages.run('等待超分操作完成', () async => _upscaler?.suspendMedia());
      if (_closed) return;
      // Resetting vf/shaders while a video is loaded can rebuild its decoder
      // and inference chain. Stop first, then clear options on the idle player.
      await stages.run('停止媒体播放', () async => _player?.stop());
      await stages.run('清理超分配置', () async => _upscaler?.resetMedia());
      await stages.run('恢复音频配置', _audio.reset);
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
  }

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
    historyGroups = groupPlaybackHistory(savedHistory);
    _notify();
  }

  Future<void> removeHistory(String filePath) => _serial(() async {
    // Stop first so periodic saves cannot re-create a deleted active record.
    await _stopBeforeHistoryDelete({PlaybackItem.pathKey(filePath)});
    await historyStore.delete(filePath);
    await refreshHistory();
  });

  Future<void> removeHistoryGroup(String key) => _serial(() async {
    var records = (await historyStore.readAll())
        .where((item) => PlaybackHistoryGroup.keyFor(item) == key)
        .toList();
    await _stopBeforeHistoryDelete({
      for (var item in records) item.key,
      if (current != null && PlaybackHistoryGroup.keyFor(current!) == key)
        current!.key,
    });
    for (var item in records) {
      await historyStore.delete(item.filePath);
    }
    await refreshHistory();
  });

  Future<void> _stopBeforeHistoryDelete(Set<String> keys) async {
    if (keys.contains(current?.key)) {
      loading = true;
      try {
        _manualSubtitles = true;
        _chapters?.reset();
        await beforeVideoDispose?.call();
        await _upscaler?.suspendMedia();
        if (_closed) return;
        await _player?.stop();
        await _upscaler?.resetMedia();
        await _audio.reset();
        _session.clear();
        index = -1;
        playlist = [];
        position = Duration.zero;
        duration = Duration.zero;
        completed = false;
      } finally {
        loading = false;
      }
    }
  }

  Future<void> shutdown() => _lifecycle.shutdown(_shutdown);

  /// Wait for UI detachment and accepted work before hiding the window.
  Future<void> waitForShutdownWork() => _lifecycle.waitForWork(shutdown);

  /// Keep the engine alive until delayed native destruction also settles.
  Future<void> waitForShutdownSettlement() =>
      _lifecycle.waitForSettlement(shutdown);

  Future<void> _disposePlayer(Player player, {PlaybackUpscaler? upscale}) {
    var disposal = () async {
      BTLogTool.info('开始释放原生播放器');
      // This wait is not cancelled by the shutdown budget: native commands may
      // still own the media_kit disposal lock after a timeout.
      await upscale?.close();
      await player.dispose();
      BTLogTool.info('Player.dispose 已完成，等待原生销毁=$waitForNativeDestroy');
    }();
    // media_kit 1.2.6 schedules mpv_terminate_destroy 5 seconds after dispose.
    // Do not destroy the child isolate before that timer runs, or call the
    // native destructor ourselves (which would double-free the same handle).
    _lifecycle.trackNativeDisposal(
      disposal,
      waitForNativeDestroy: waitForNativeDestroy,
    );
    return disposal;
  }

  Future<void> _shutdown() async {
    // Refuse newly queued work before waiting for the current operation.
    _idlePlayerTimer?.cancel();
    _idlePlayerTimer = null;
    _upscale.dispose();
    _diagnostics?.close();
    _janaiVideoSource?.close();
    _chapters?.close();
    _session.close();
    _saveTimer?.cancel();
    _audio.releasePlayer();
    var pending = _lifecycle.pending;
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
    _openingStatus = null;
    _notify();
    // Hidden retained windows have already unmounted Video when media cleared.
    if (!_disposed && player != null && finalItem != null) {
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
        () => _disposePlayer(player, upscale: upscale),
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
            _lifecycle.recordFailure(error);
            BTLogTool.warn('迟到播放位置保存失败：$error');
          }
        }
        await _disposePlayer(player, upscale: upscale);
      }();
      _lifecycle.trackCleanup(
        cleanup.catchError((Object error) {
          _lifecycle.recordFailure(error);
          BTLogTool.warn('迟到原生播放器释放失败：$error');
        }),
      );
    }
  }

  Future<bool> _shutdownStep(
    String name,
    Future<void> Function() action,
    Duration timeout,
  ) => _lifecycle.step(name, action, timeout);

  @override
  void dispose() {
    _upscale.dispose();
    _disposed = true;
    unawaited(
      shutdown().catchError((Object e) {
        BTLogTool.warn('释放播放器失败：$e');
      }),
    );
    super.dispose();
  }
}
