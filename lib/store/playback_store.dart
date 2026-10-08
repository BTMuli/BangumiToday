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
import '../core/services/playback_assets.dart';
import '../core/services/playback_audio.dart';
import '../core/services/playback_audio_metadata.dart';
import '../core/services/playback_cache.dart';
import '../core/services/playback_chapters.dart';
import '../core/services/playback_diagnostics.dart';
import '../core/services/playback_janai_benchmarks.dart';
import '../core/services/playback_janai_video_source.dart';
import '../core/services/playback_loudness.dart';
import '../core/services/playback_screenshot.dart';
import '../core/services/playback_subtitles.dart';
import '../core/services/playback_tensorrt_gpu.dart';
import '../core/services/playback_tensorrt_resources.dart';
import '../core/services/playback_upscaler.dart';
import '../core/utils/playback_audio_recovery.dart';
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
      episodes: (subject) async => (await loadPlaybackEpisodes(
        ref.read(bangumiRepositoryProvider),
        subject,
      )).map(episodeMarkChapter).toList(),
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
  bool _loudnessEnabled = Platform.isWindows;
  bool _hiResEnabled = false;
  bool _hiResConfigured = false;
  bool _audioExclusiveEnabled = false;
  bool _audioExclusiveConfigured = false;
  PlaybackAudioSource? _audioSource;
  PlaybackAudioOutput? _audioOutput;
  String? _hiResFailure;
  String? _hiResBlockedSource;
  String? _lastAudioSourceKey;
  final _audioClock = Stopwatch()..start();
  final _audioRecovery = PlaybackAudioRecovery();
  Timer? _audioRefreshTimer;
  Timer? _audioWatchdog;
  final _audioMetadata = PlaybackAudioMetadata();
  PlaybackWasapiFormat? _wasapiFormat;
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
  PlaybackUpscaleMode _upscaleMode = PlaybackUpscaleMode.off;
  bool _tensorRtEnabled = false;
  Object? _viewportOwner;
  bool _viewportFullscreen = false;
  final _viewports = <Object, ({PlaybackViewport value, bool fullscreen})>{};
  VoidCallback? _textureListener;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _saveTimer;
  Future<void> _operation = Future.value();
  String? _operationFile;
  List<PlaybackItem> playlist = [];
  List<PlaybackItem> history = [];
  List<PlaybackHistoryGroup> historyGroups = [];
  int index = -1;
  bool loading = false;
  String? error;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool completed = false;
  bool _closed = false;
  bool _disposed = false;
  Future<void>? _shutdownFuture;
  Future<void>? _shutdownWorkFuture;
  Future<void>? _settlementFuture;
  final _shutdownWork = <Future<void>>[];
  final _nativeDestructions = <Future<void>>[];
  final _shutdownFailures = <Object>[];
  final _session = PlaybackSession();
  final _completions = StreamController<PlaybackCompletion>.broadcast();

  Stream<PlaybackCompletion> get completions => _completions.stream;
  bool get isClosed => _closed;

  Player? get player => _player;

  Future<String> readVideoProperty(String name) =>
      _diagnostics?.readProperty(name) ?? Future.value('');
  List<PlaybackChapter> get chapters => _chapters?.chapters ?? const [];
  bool get automaticSubtitles => !_manualSubtitles;
  VideoController? get video => _video;
  PlaybackUpscaler? get upscaler => _upscaler;
  PlaybackUpscaleMode get upscaleMode => _upscaleMode;
  bool get tensorRtEnabled => _tensorRtEnabled && tensorRtResources.canEnable;
  PlaybackTensorRtResources? _tensorRtResources;
  PlaybackTensorRtResources get tensorRtResources =>
      _tensorRtResources ??= PlaybackTensorRtResources(onChanged: _notify);

  PlaybackJanaiBenchmarks? _janaiBenchmarks;
  PlaybackJanaiBenchmarks get janaiBenchmarks =>
      _janaiBenchmarks ??= PlaybackJanaiBenchmarks(
        directory: tensorRtResources.dataDirectory,
        onChanged: _notify,
        loadBundled: () =>
            rootBundle.loadString('assets/benchmarks/animejanai.json'),
      );

  /// Use the actual renderer's adapter, not the first detected CUDA device.
  PlaybackJanaiRecommendation get janaiRecommendation {
    var catalog = janaiBenchmarks.catalog;
    if (catalog == null) {
      return PlaybackJanaiRecommendation(
        janaiBenchmarks.error ?? '正在读取 benchmark',
      );
    }
    var native = _upscaler?.janaiStatus;
    var gpu = native?.gpuName ?? '';
    if (gpu.isEmpty) {
      gpu = PlaybackJanaiBenchmarkCatalog.rendererGpu(
        _upscaler?.renderer ?? '',
      );
    }
    var detected = tensorRtResources.gpu;
    var supported = native != null && native.gpuName.isNotEmpty
        ? native.gpuVendor == 0x10de &&
              PlaybackTensorRtGpu(
                name: native.gpuName,
                sm: native.gpuSm,
                driver: native.gpuDriver,
              ).supported
        : gpu.isEmpty ||
              (detected?.supported == true &&
                  PlaybackJanaiBenchmarkCatalog.gpuKey(gpu) ==
                      PlaybackJanaiBenchmarkCatalog.gpuKey(detected!.name));
    var state = !loading && current != null ? _player?.state : null;
    var source = state == null ? null : _janaiVideoSource?.parameters;
    var trackId = source?.trackId ?? state?.track.video.id;
    var track = state?.tracks.video
        .where(
          (track) =>
              track.id == trackId && track.id != 'auto' && track.id != 'no',
        )
        .firstOrNull;
    if (track == null &&
        state?.track.video.id == trackId &&
        trackId != 'auto' &&
        trackId != 'no') {
      track = state?.track.video;
    }
    return catalog.recommend(
      gpu: gpu,
      supported: supported,
      width: source?.width ?? track?.w ?? 0,
      height: source?.height ?? track?.h ?? 0,
      fps: source?.fps ?? track?.fps ?? 0,
      rate: state?.rate ?? 1,
    );
  }

  Future<void> downloadTensorRt() async {
    if (_closed || !Platform.isWindows) return;
    await tensorRtResources.initialize();
    if (_closed) return;
    var installed = await tensorRtResources.install();
    // Use the current preference and media generation after installation.
    if (installed && !_closed && _tensorRtEnabled) {
      _upscaler?.inferencePreferenceChanged();
      _notify();
    }
  }

  Future<void> cancelTensorRt() async {
    if (tensorRtResources.busy) {
      tensorRtResources.cancel();
    } else {
      await setUpscaleMode(PlaybackUpscaleMode.off);
    }
  }

  Future<void> retryTensorRt() async {
    if (tensorRtEnabled) {
      _upscaler?.inferencePreferenceChanged();
    }
  }

  bool get loudnessEnabled => _loudnessEnabled;
  bool get hiResEnabled => _hiResEnabled;
  bool get audioExclusiveEnabled => _audioExclusiveEnabled;
  bool get canEnableAudioExclusive => PlaybackAudio.supported && _hiResEnabled;
  PlaybackHiResState get hiRes => PlaybackHiResState(
    source: _audioSource,
    output: _audioOutput,
    requested: _hiResEnabled,
    configured: _hiResConfigured,
    exclusiveRequested: _hiResEnabled && _audioExclusiveEnabled,
    supported: PlaybackAudio.supported,
    rate: _player?.state.rate ?? 1,
    failure: _hiResFailure,
  );
  bool get loudnessActive => _loudnessEnabled && !_hiResConfigured;
  bool get loudnessPausedForHiRes => _hiResConfigured;
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

  Future<void> _serial(Future<void> Function() action, {String? file}) {
    var next = _operation.then((_) async {
      if (_closed) return;
      _operationFile = file ?? current?.filePath;
      await action();
    });
    _operation = next.catchError((Object e, StackTrace s) {
      error = e.toString();
      BTLogTool.error([
        '播放操作失败：file=$_operationFile',
        e.toString(),
        s.toString(),
      ]);
      _notify();
    });
    return next;
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
          'upscale': _upscaleMode.name,
          'loudness': loudnessActive,
          'hires_requested': _hiResEnabled,
          'audio_exclusive_requested': _audioExclusiveEnabled,
          'audio_exclusive_configured': _audioExclusiveConfigured,
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
      if (value.prefix == 'ao/wasapi') {
        var format = PlaybackWasapiFormat.parse(value.text);
        if (format != null) {
          _wasapiFormat = format;
          _scheduleAudioRefresh();
        }
      }
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
        for (var property in ['current-tracks/video', 'video-dec-params']) {
          await native.observeProperty(property, (_) async {
            unawaited(janaiSource.refresh());
          });
        }
      }
      for (var property in ['audio-out-params', 'current-tracks/audio']) {
        await native.observeProperty(property, (_) async {
          _scheduleAudioRefresh();
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
      _upscaler =
          PlaybackUpscaler(
              backend: NativePlaybackUpscaleBackend(
                player,
                video,
                tensorRtEnabled: () => tensorRtEnabled,
                tensorRtResources: tensorRtResources,
              ),
              loadShaders: assets.load,
              onChanged: _notify,
              onError: (error) => BTLogTool.warn('视频超分：$error'),
              onDiagnostics: diagnostics.upscaleEvent,
            )
            ..preferences(_upscaleMode)
            ..playbackRate(player.state.rate);
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
      }),
      player.stream.buffering.listen((value) {
        diagnostics.event('缓冲状态改变：buffering=$value');
      }),
      player.stream.rate.listen((value) {
        diagnostics.event('播放速率改变：rate=$value');
        _upscaler?.playbackRate(value);
        _scheduleAudioRefresh();
        _notify();
      }),
      player.stream.audioParams.listen((_) => _scheduleAudioRefresh()),
      player.stream.audioDevice.listen((_) {
        _hiResBlockedSource = null;
        _hiResFailure = null;
        _scheduleAudioRefresh();
      }),
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
        if (_closed || loading || current == null) return;
        completed = value;
        if (!value) return;
        diagnostics.event('视频播放完成');
        var snapshot = _session.finish(position: position, duration: duration);
        if (snapshot == null) return;
        var items = playlist;
        var finishedIndex = index;
        unawaited(
          _serial(() async {
                if (_session.id != snapshot.sessionId) return;
                await historyStore.write(snapshot.historyItem);
                if (_closed) return;
                // Broadcast asynchronously; UI/network work must never join the
                // playback queue or delay the next episode.
                _completions.add(snapshot);
                await refreshHistory();
                _notify();
              })
              .then((_) async {
                if (_closed || _session.id != snapshot.sessionId) return;
                // Resolve chapters outside the operation queue: a manual file
                // change remains responsive while matching data is loading.
                var nextIndex = await library.nextEpisodeIndex(
                  items,
                  finishedIndex,
                );
                if (nextIndex == null) return;
                await _serial(() async {
                  if (_closed || _session.id != snapshot.sessionId) return;
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
      if (_closed || loading || !player.state.playing || completed) return;
      // Persist progress without fetching/grouping the entire library or
      // rebuilding the video surface every five seconds during playback.
      unawaited(
        _serial(() => _save(refreshHistory: false)).catchError((Object _) {}),
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

  /// Opens a single local file, resolving its Bangumi subject when the caller
  /// does not know it, and rebuilds the playlist from its download root.
  Future<void> openLocalFile(String filePath, {int? subject}) => _serial(
    () async {
      var resolved = subject ?? await subjectResolver.subjectForFile(filePath);
      await library.ensureReady(filePath);
      if (_closed) return;
      var directory = await subjectResolver.directoryForFile(
        filePath,
        subject: resolved,
      );
      if (_closed) return;
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
    _notify();
  });

  Future<void> _openIndex(int nextIndex, {List<PlaybackItem>? items}) async {
    if (_closed) return;
    var nextPlaylist = items ?? playlist;
    if (nextIndex < 0 || nextIndex >= nextPlaylist.length) return;
    var item = nextPlaylist[nextIndex];
    _operationFile = item.filePath;
    BTLogTool.info('准备播放：${item.filePath}');
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
      _manualSubtitles = true;
      _chapters?.reset();
      _janaiVideoSource?.reset();
      await _upscaler?.resetMedia();
      if (_closed) return;
      await _player!.stop();
      await _resetAudio();
      if (_closed) return;
      playlist = nextPlaylist;
      index = nextIndex;
      _session.begin(item);
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
      _scheduleAudioRefresh();
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

  Future<void> _loadPreferences() {
    var pending = _preferencesFuture;
    if (pending != null) return pending;
    var operation = () async {
      await _rateMemory.load();
      _hiResEnabled =
          await settingsStore.read(PlaybackAudio.settingKey) == 'true';
      _audioExclusiveEnabled =
          await settingsStore.read(PlaybackAudio.exclusiveSettingKey) == 'true';
      _episodeLayout = PlaybackEpisodeLayout.parse(
        await settingsStore.read('playbackEpisodeLayout'),
      );
      if (Platform.isWindows) {
        unawaited(janaiBenchmarks.initialize());
        await tensorRtResources.initialize();
        _loudnessEnabled = PlaybackLoudness.parse(
          await settingsStore.read(PlaybackLoudness.settingKey),
        );
        _upscaleMode = PlaybackUpscaleMode.parse(
          await settingsStore.read('playbackUpscaleMode'),
        );
        _tensorRtEnabled =
            await settingsStore.read('playbackTensorRTEnabled') == 'true' &&
            tensorRtResources.canEnable;
        if (_upscaleMode.isJanai && !_tensorRtEnabled) {
          _upscaleMode = PlaybackUpscaleMode.off;
        }
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
    if (_closed || _loudnessEnabled == enabled || !Platform.isWindows) return;
    var player = _player;
    if (player != null && !_hiResConfigured) {
      await PlaybackLoudness.apply(player, enabled);
    }
    if (_closed) return;
    try {
      await settingsStore.write(PlaybackLoudness.settingKey, '$enabled');
    } catch (_) {
      if (!_closed && player != null && !_hiResConfigured) {
        await PlaybackLoudness.apply(player, loudnessActive);
      }
      rethrow;
    }
    if (_closed) return;
    _loudnessEnabled = enabled;
    _diagnostics?.event('音量标准化改变：enabled=$enabled');
    _notify();
  });

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

  Future<void> setHiResEnabled(bool enabled) => _serial(() async {
    await _loadPreferences();
    if (_closed || _hiResEnabled == enabled) return;
    await settingsStore.write(PlaybackAudio.settingKey, '$enabled');
    if (_closed) return;
    _hiResEnabled = enabled;
    _hiResBlockedSource = null;
    _hiResFailure = null;
    await _refreshAudio();
    _diagnostics?.event('HiRes 偏好改变：enabled=$enabled，${hiRes.status}');
    _notify();
  });

  Future<void> setAudioTrack(AudioTrack track) => _serial(() async {
    await _resetAudio();
    await _player?.setAudioTrack(track);
    _scheduleAudioRefresh();
  });

  Future<void> setAudioExclusiveEnabled(bool enabled) => _serial(() async {
    await _loadPreferences();
    if (_closed ||
        _audioExclusiveEnabled == enabled ||
        (enabled && !canEnableAudioExclusive)) {
      return;
    }
    await settingsStore.write(PlaybackAudio.exclusiveSettingKey, '$enabled');
    if (_closed) return;
    _audioExclusiveEnabled = enabled;
    _hiResBlockedSource = null;
    _hiResFailure = null;
    await _refreshAudio();
    _diagnostics?.event('独占输出偏好改变：enabled=$enabled，${hiRes.status}');
    _notify();
  });

  void _scheduleAudioRefresh({
    Duration delay = const Duration(milliseconds: 150),
  }) {
    if (_closed || current == null || _audioRefreshTimer?.isActive == true) {
      return;
    }
    var sessionId = _session.id;
    _audioRefreshTimer = Timer(delay, () {
      unawaited(
        _serial(() async {
          if (_session.id != sessionId || current == null) return;
          await _refreshAudio();
        }).catchError((Object _) {}),
      );
    });
  }

  Future<void> _configureHiRes(bool enabled) async {
    var player = _player;
    var exclusive = enabled && _audioExclusiveEnabled;
    if (player == null ||
        (_hiResConfigured == enabled &&
            _audioExclusiveConfigured == exclusive)) {
      return;
    }
    var previous = _hiResConfigured;
    var previousExclusive = _audioExclusiveConfigured;
    // Shared HiRes can keep the current device open when only its filters
    // change. Retain its accepted format unless the access mode changes.
    if (previousExclusive != exclusive) _wasapiFormat = null;
    _diagnostics?.event('HiRes 输出配置开始：enabled=$enabled，exclusive=$exclusive');
    try {
      if (Platform.isWindows) {
        await PlaybackLoudness.apply(player, _loudnessEnabled && !enabled);
      }
      await PlaybackAudio.apply(player, exclusive);
    } catch (_) {
      if (!_closed) {
        await PlaybackAudio.apply(player, previousExclusive);
        if (Platform.isWindows) {
          await PlaybackLoudness.apply(player, _loudnessEnabled && !previous);
        }
      }
      rethrow;
    }
    if (_closed) return;
    _hiResConfigured = enabled;
    _audioExclusiveConfigured = exclusive;
    if (enabled) {
      _audioRecovery.configured(_audioClock.elapsed);
      _audioWatchdog ??= Timer.periodic(const Duration(seconds: 5), (_) {
        if (_player?.state.playing == true && !completed) {
          _scheduleAudioRefresh();
        }
      });
    } else {
      _audioRecovery.reset();
      _audioWatchdog?.cancel();
      _audioWatchdog = null;
    }
    _diagnostics?.event('HiRes 输出配置完成：enabled=$enabled，exclusive=$exclusive');
  }

  String? _audioSourceKey(PlaybackAudioSource? source) => source == null
      ? null
      : '${source.id}/${source.codec}/${source.sampleRate}/${source.format}/${source.channels}';

  Future<void> _refreshAudio() async {
    var player = _player;
    if (_closed || player == null || current == null) return;
    var sessionId = _session.id;
    var before = hiRes.tooltip;
    var params = await PlaybackAudio.read(
      player,
      filePath: current!.filePath,
      metadata: _audioMetadata,
      deviceFormat: _wasapiFormat,
    );
    if (_closed || sessionId != _session.id) return;
    _audioSource = params.source;
    _audioOutput = params.output;
    var key = _audioSourceKey(params.source) ?? _lastAudioSourceKey;
    _lastAudioSourceKey = key;
    if (_hiResBlockedSource != key) _hiResFailure = null;
    var desired =
        _hiResEnabled &&
        PlaybackAudio.supported &&
        (params.source?.hiRes ?? _hiResConfigured) &&
        (_hiResBlockedSource == null || _hiResBlockedSource != key);
    try {
      await _configureHiRes(desired);
      if (_closed) return;
      if (_hiResConfigured) {
        var recovery = _audioRecovery.check(_audioClock.elapsed, hiRes);
        if (recovery.retry) {
          _scheduleAudioRefresh(delay: const Duration(milliseconds: 500));
        } else if (recovery.failure != null) {
          _hiResFailure = recovery.failure;
          _hiResBlockedSource = key;
          await _configureHiRes(false);
          if (_closed) return;
          await PlaybackAudio.reopenOutput(player);
          _diagnostics?.event('HiRes 回退共享输出：$_hiResFailure');
          _scheduleAudioRefresh(delay: const Duration(milliseconds: 500));
        }
      }
    } catch (failure) {
      _hiResFailure = failure.toString();
      _hiResBlockedSource = key;
      _diagnostics?.event('HiRes 配置失败：$failure');
    }
    if (before != hiRes.tooltip) _notify();
  }

  Future<void> _resetAudio() async {
    _audioRefreshTimer?.cancel();
    _audioWatchdog?.cancel();
    _audioWatchdog = null;
    _audioRecovery.reset();
    _lastAudioSourceKey = null;
    _audioMetadata.clear();
    _audioSource = null;
    _audioOutput = null;
    _hiResFailure = null;
    _hiResBlockedSource = null;
    await _configureHiRes(false);
    _notify();
  }

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
    if (_closed || _upscaleMode == mode || !Platform.isWindows) return;
    if (mode.isJanai && !tensorRtEnabled) return;
    await settingsStore.write('playbackUpscaleMode', mode.name);
    if (_closed) return;
    _upscaleMode = mode;
    _upscaler?.preferences(_upscaleMode);
    _notify();
  });

  Future<void> setTensorRtEnabled(bool enabled) => _serial(() async {
    await _loadPreferences();
    if (_closed || !Platform.isWindows || _tensorRtEnabled == enabled) return;
    if (enabled && !tensorRtResources.canEnable) return;
    await settingsStore.write('playbackTensorRTEnabled', enabled.toString());
    if (_closed) return;
    _tensorRtEnabled = enabled;
    if (!enabled && _upscaleMode.isJanai) {
      _upscaleMode = PlaybackUpscaleMode.off;
      _upscaler?.preferences(_upscaleMode);
    }
    _upscaler?.inferencePreferenceChanged();
    _notify();
  });

  Future<void> stop() => _serial(_stop);

  /// Unload media while retaining the Player and its native render context.
  Future<void> clearCurrentPlayback() => _serial(() async {
    await beforeVideoDispose?.call();
    await _stop(refreshHistory: false);
    _sourceDir = null;
    _sourceSubject = null;
    _aspectRatio = null;
    _videoSize = null;
    error = null;
    _diagnostics?.stopped();
    _notify();
  });

  Future<void> _stop({bool refreshHistory = true}) async {
    await _save(refreshHistory: refreshHistory);
    loading = true;
    _janaiVideoSource?.reset();
    try {
      _manualSubtitles = true;
      _chapters?.reset();
      await _upscaler?.resetMedia();
      if (_closed) return;
      await _player?.stop();
      await _resetAudio();
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
        await _upscaler?.resetMedia();
        if (_closed) return;
        await _player?.stop();
        await _resetAudio();
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

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  /// The window can be hidden after UI detachment and accepted work settle.
  /// Keep its engine alive separately for mpv's delayed native destruction.
  Future<void> waitForShutdownWork() =>
      _shutdownWorkFuture ??= _waitForShutdownWork();

  Future<void> _waitForShutdownWork() async {
    await shutdown();
    await Future.wait(_shutdownWork);
    _checkShutdownFailures();
  }

  /// Closing a child engine must not cancel timed-out writes or mpv's delayed
  /// destruction. Keep the engine alive until every accepted operation settles.
  Future<void> waitForShutdownSettlement() =>
      _settlementFuture ??= _waitForShutdownSettlement();

  Future<void> _waitForShutdownSettlement() async {
    await waitForShutdownWork();
    await Future.wait(_nativeDestructions);
    _checkShutdownFailures();
  }

  void _checkShutdownFailures() {
    if (_shutdownFailures.isNotEmpty) {
      throw StateError('播放器未能完成保存或清理：${_shutdownFailures.first}');
    }
  }

  Future<void> _disposePlayer(Player player) {
    var upscale = _upscaler;
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
    var destruction = disposal
        .then((_) async {
          if (waitForNativeDestroy) {
            await Future<void>.delayed(const Duration(milliseconds: 5200));
          }
        })
        .catchError(_shutdownFailures.add);
    _nativeDestructions.add(destruction);
    return disposal;
  }

  Future<void> _shutdown() async {
    // Refuse newly queued work before waiting for the current operation.
    _closed = true;
    _janaiBenchmarks?.dispose();
    _tensorRtResources?.dispose();
    _diagnostics?.close();
    _janaiVideoSource?.close();
    _chapters?.close();
    _session.close();
    _saveTimer?.cancel();
    _audioRefreshTimer?.cancel();
    var pending = _operation;
    _audioWatchdog?.cancel();
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
    _shutdownWork.add(work.catchError(_shutdownFailures.add));
    try {
      await work.timeout(timeout);
      return true;
    } on TimeoutException {
      BTLogTool.warn('播放器清理超时：$name');
    } catch (error, stackTrace) {
      BTLogTool.error(['播放器清理失败：$name，$error', stackTrace.toString()]);
    }
    return false;
  }

  @override
  void dispose() {
    _janaiBenchmarks?.dispose();
    _tensorRtResources?.dispose();
    _disposed = true;
    unawaited(
      shutdown().catchError((Object e) {
        BTLogTool.warn('释放播放器失败：$e');
      }),
    );
    super.dispose();
  }
}
