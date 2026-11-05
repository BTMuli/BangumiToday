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
import '../core/logging/log_tool.dart';
import '../core/services/playback_audio_controller.dart';
import '../core/services/playback_close_progress.dart';
import '../core/services/playback_janai_benchmarks.dart';
import '../core/services/playback_mpv_coordinator.dart';
import '../core/services/playback_screenshot.dart';
import '../core/services/playback_session_lifecycle.dart';
import '../core/services/playback_subtitle_files.dart';
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
  late final PlaybackAudioController _audio = PlaybackAudioController(
    settingsStore: settingsStore,
    readPlayer: () => _mpv.player,
    readSession: () => (id: _session.id, item: current, completed: completed),
    isClosed: () => _closed,
    serial: _runSerial,
    onDiagnostic: (message) => _mpv.diagnostics?.event(message),
    onChanged: _notify,
  );
  late final PlaybackUpscaleController _upscale = PlaybackUpscaleController(
    settingsStore: settingsStore,
    readUpscaler: () => _mpv.upscaler,
    isClosed: () => _closed,
    onChanged: _notify,
  );
  late final PlaybackMpvCoordinator _mpv = PlaybackMpvCoordinator(
    playerAllowed: playerAllowed,
    waitForNativeDestroy: waitForNativeDestroy,
    readSession: () => (
      id: _session.id,
      current: current,
      completed: completed,
      loading: loading,
      clearingPlayback: _clearingPlayback,
      manualSubtitles: _manualSubtitles,
      position: position,
      duration: duration,
      playlist: playlist,
      index: index,
    ),
    isClosed: () => _closed,
    isOpening: () => isOpening,
    serial: _runSerial,
    trackNativeDisposal: _trackNativeDisposal,
    onChanged: _notify,
    audio: _audio,
    upscale: _upscale,
    saveProgress: _save,
    refreshHistory: refreshHistory,
    openIndex: _openIndexByNumber,
    autoSelectSubtitle: _autoSelectSubtitle,
    finishSession: _session.finish,
    writeHistory: historyStore.write,
    emitCompletion: _emitCompletion,
    nextEpisodeIndex: library.nextEpisodeIndex,
    writePosition: (value) => position = value,
    writeDuration: (value) => duration = value,
    writeCompleted: (value) => completed = value,
    writeError: (value) => error = value,
    readLoudnessActive: () => loudnessActive,
    readHiRes: () => hiRes,
    readAspectRatio: () => _aspectRatio,
    readVideoSize: () => _videoSize,
    writeGeometry: (ratio, size) {
      _aspectRatio = ratio;
      _videoSize = size;
    },
    onPlayerReleased: () {
      _viewports.clear();
      _viewportOwner = null;
      _viewportFullscreen = false;
      _aspectRatio = null;
      _videoSize = null;
    },
  );
  PlaybackEpisodeLayout _episodeLayout = PlaybackEpisodeLayout.grid;
  bool _autoMarkWatched = false;
  double? _aspectRatio;
  Size? _videoSize;
  bool _manualSubtitles = true;
  late final _subtitleFiles = PlaybackSubtitleFiles(settingsStore);
  final _loadedSubtitleFiles = <String>{};
  final _importedSubtitlePaths = <String, String>{};
  Object? _viewportOwner;
  bool _viewportFullscreen = false;
  final _viewports = <Object, ({PlaybackViewport value, bool fullscreen})>{};
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
  bool get autoMarkWatched => _autoMarkWatched;
  bool get isClosed => _closed;
  bool get isOpening => _openingStatus != null;
  String? get openingStatus => _openingStatus;
  String? get openingFile => isOpening ? _operationFile : null;

  Player? get player => _mpv.player;

  Future<String> readVideoProperty(String name) =>
      _mpv.diagnostics?.readProperty(name) ?? Future.value('');
  List<PlaybackChapter> get chapters => _mpv.chapters?.chapters ?? const [];
  bool get automaticSubtitles => !_manualSubtitles;
  VideoController? get video => _mpv.video;
  PlaybackUpscaler? get upscaler => _mpv.upscaler;
  PlaybackUpscaleMode get upscaleMode => _upscale.selectedMode;
  bool get tensorRtEnabled => _upscale.tensorRtEnabled;
  PlaybackTensorRtResources get tensorRtResources => _upscale.tensorRtResources;
  PlaybackJanaiBenchmarks get janaiBenchmarks => _upscale.janaiBenchmarks;

  PlaybackJanaiRecommendation get janaiRecommendation {
    var state = !loading && current != null ? _mpv.player?.state : null;
    return _upscale.recommendation(
      state: state,
      source: state == null ? null : _mpv.janaiVideoSource?.parameters,
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

  void beginViewportTransition() => _mpv.upscaler?.beginViewportTransition();

  void endViewportTransition() => _mpv.upscaler?.endViewportTransition();

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
    _mpv.upscaler?.viewport(value);
  }

  void releaseViewport(Object owner) {
    if (_closed) return;
    _viewports.remove(owner);
    if (!identical(owner, _viewportOwner)) return;
    _viewportOwner = null;
    _viewportFullscreen = false;
    if (_viewports.isEmpty) {
      _mpv.upscaler?.viewport(null);
    } else {
      var remaining = _viewports.entries.last;
      reportViewport(
        remaining.key,
        remaining.value.value,
        fullscreen: remaining.value.fullscreen,
      );
    }
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
  /// 命中本地详情或收藏就使用条目名；缺少信息时由调用方按需 [resolveCover]。
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
    if (value != null) _mpv.cancelIdleTimer();
    _openingStatus = value;
    _notify();
  }

  Future<void> _runSerial(Future<void> Function() action) => _serial(action);

  Future<void> _openIndexByNumber(int nextIndex) => _openIndex(nextIndex);

  void _emitCompletion(PlaybackCompletion completion) =>
      _completions.add(completion);

  void _trackNativeDisposal(
    Future<void> disposal, {
    required bool waitForNativeDestroy,
  }) => _lifecycle.trackNativeDisposal(
    disposal,
    waitForNativeDestroy: waitForNativeDestroy,
  );

  Future<void> _serial(Future<void> Function() action, {String? file}) =>
      _lifecycle.run(() async {
        _operationFile = file ?? current?.filePath;
        try {
          await action();
        } finally {
          _setOpeningStatus(null);
          _mpv.syncIdleTimer();
        }
      });

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
    var timing = _PlaybackOpenTiming();
    BTLogTool.info('准备播放：${item.filePath}');
    _setOpeningStatus('正在读取播放记录…');
    await timing.measure('读取任务状态', () => library.ensureReady(item.filePath));
    if (_closed) return;
    var previous = await timing.measure(
      '读取播放记录',
      () => historyStore.read(item.filePath),
    );
    _setOpeningStatus('正在加载播放设置…');
    await timing.measure('加载播放设置', _loadPreferences);
    if (_closed) return;
    _setOpeningStatus('正在初始化播放器…');
    await timing.measure('初始化原生播放器', _mpv.initialize);
    if (_closed) return;
    _setOpeningStatus('正在打开视频…');
    loading = true;
    error = null;
    _notify();
    try {
      _manualSubtitles = true;
      _loadedSubtitleFiles.clear();
      _importedSubtitlePaths.clear();
      _mpv.chapters?.reset();
      _mpv.janaiVideoSource?.reset();
      await timing.measure(
        '重置超分',
        () =>
            _mpv.upscaler?.resetMedia(keepOutput: true) ?? Future<void>.value(),
      );
      if (_closed) return;
      await timing.measure('停止旧媒体', () => _mpv.player!.stop());
      await timing.measure('重置音频', _audio.reset);
      if (_closed) return;
      playlist = nextPlaylist;
      index = nextIndex;
      _session.begin(item);
      _prepareNextEpisode();
      _mpv.janaiVideoSource?.reset(active: true);
      _manualSubtitles = false;
      position = previous?.resumePosition ?? Duration.zero;
      duration = Duration(milliseconds: previous?.durationMs ?? 0);
      completed = false;
      _mpv.diagnostics?.opening(item.filePath, position);
      // Keep the previous aspect ratio until the new stream reports its own, so
      // auto-advancing between episodes (usually the same ratio) does not make
      // the playback surface size jump.
      await timing.measure(
        '设置字幕轨道',
        () => _mpv.player!.setSubtitleTrack(SubtitleTrack.no()),
      );
      _mpv.chapters?.reset(active: true);
      await timing.measure(
        '打开媒体',
        () => _mpv.player!.open(Media(item.filePath, start: position)),
      );
      if (_closed) return;
      _setOpeningStatus('正在恢复播放状态…');
      _audio.scheduleRefresh();
      await timing.measure('加载外部字幕', _loadImportedSubtitles);
      await timing.measure('选择字幕', _autoSelectSubtitle);
      await timing.measure(
        '读取章节',
        () => _mpv.chapters?.refresh() ?? Future<void>.value(),
      );
      _mpv.upscaler?.mediaReady(
        PlaybackMpvCoordinator.videoSource(_mpv.player!.state.videoParams),
      );
      if (Platform.isWindows) unawaited(_mpv.janaiVideoSource?.refresh());
      _mpv.updateTexture();
    } catch (e) {
      index = -1;
      _mpv.janaiVideoSource?.reset();
      _manualSubtitles = true;
      _mpv.chapters?.reset();
      _session.clear();
      // A failed open must release any output retained for an episode switch.
      await _mpv.upscaler?.resetMedia();
      rethrow;
    } finally {
      loading = false;
      _notify();
      BTLogTool.info('播放打开结束：${timing.summary}');
    }
    await _save();
  }

  Future<void> jump(int nextIndex) => _serial(() async {
    if (nextIndex == index) return;
    await _save();
    await _openIndex(nextIndex);
  });

  Future<void> pause() => _serial(() async {
    await _mpv.player?.pause();
    await _save();
  });

  /// Capture before queued media changes reset the renderer. Once copied, the
  /// image belongs to this request even if another episode starts afterwards.
  Future<({Uint8List image, Duration position})?> captureScreenshot() async {
    var player = _mpv.player;
    if (_closed || loading || player == null || current == null) return null;
    var sessionId = _session.id;
    var capturedPosition = player.state.position;
    ({Uint8List image, Duration position})? screenshot;
    await _serial(() async {
      if (_session.id != sessionId ||
          _mpv.player != player ||
          current == null) {
        return;
      }
      var image = await PlaybackScreenshot.capture(
        player,
        rendered: _mpv.upscaler?.configuredMode != null,
      );
      if (image == null || image.isEmpty) {
        throw const PlaybackUnavailable('当前没有可截取的视频画面');
      }
      screenshot = (image: image, position: capturedPosition);
    });
    return screenshot;
  }

  Future<void> _autoSelectSubtitle() async {
    var player = _mpv.player;
    if (_closed || player == null || _manualSubtitles || current == null) {
      return;
    }
    var id = preferredPlaybackSubtitle(
      player.state.tracks.subtitle.map(
        (track) => (
          id: track.id,
          title: _importedSubtitlePaths.containsKey(track.id)
              ? path.basename(_importedSubtitlePaths[track.id]!)
              : track.title,
          language: track.language,
          isDefault: track.isDefault,
        ),
      ),
      imported: _importedSubtitlePaths.keys.toSet(),
    );
    if (player.state.track.subtitle.id == id) return;
    var track = player.state.tracks.subtitle.firstWhere(
      (track) => track.id == id,
      orElse: SubtitleTrack.no,
    );
    await player.setSubtitleTrack(track);
  }

  Future<PlaybackSubtitleImport?> importSubtitleDirectory(
    String directory, {
    bool matchByEpisode = false,
  }) async {
    PlaybackSubtitleImport? result;
    await _serial(() async {
      result = await _subtitleFiles.importDirectory(
        directory,
        playlist,
        matchByEpisode: matchByEpisode,
      );
      if (_closed || current == null) return;
      if (!result!.matches.containsKey(current!.key)) return;
      _manualSubtitles = false;
      await _loadImportedSubtitles();
      await _autoSelectSubtitle();
      _notify();
    });
    return result;
  }

  Future<void> _loadImportedSubtitles() async {
    var item = current;
    var player = _mpv.player;
    if (_closed || item == null || player == null) return;
    try {
      for (var file in await _subtitleFiles.read(item)) {
        if (_closed) return;
        var key = PlaybackItem.pathKey(file);
        if (_loadedSubtitleFiles.contains(key) || !await File(file).exists()) {
          continue;
        }
        try {
          var title = path.basename(file);
          var native = player.platform as NativePlayer;
          await native.command(['sub-add', file, 'cached', title]);
          var id = await native.getProperty('sid');
          _loadedSubtitleFiles.add(key);
          _importedSubtitlePaths[id] = file;
        } catch (e) {
          error = '加载外部字幕失败：${path.basename(file)}';
          BTLogTool.warn('$error：$e');
        }
      }
    } catch (e) {
      error = '读取外部字幕关联失败';
      BTLogTool.warn('$error：$e');
    }
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) {
    var sessionId = _session.id;
    var automatic = track.id == 'auto';
    // Mark the manual choice before queued automatic selections can run.
    _manualSubtitles = !automatic;
    return _serial(() async {
      if (_session.id != sessionId || current == null) return;
      if (!automatic) {
        await _mpv.player?.setSubtitleTrack(track);
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
    var timing = _PlaybackOpenTiming();
    var operation = () async {
      try {
        await timing.measure('读取倍速记忆', _rateMemory.load);
        await timing.measure('读取音频设置', _audio.loadPreferences);
        _episodeLayout = PlaybackEpisodeLayout.parse(
          await timing.measure(
            '读取剧集布局',
            () => settingsStore.read('playbackEpisodeLayout'),
          ),
        );
        _autoMarkWatched =
            await settingsStore.read('playbackAutoMarkWatched') == 'true';
        if (Platform.isWindows) {
          // Resolves the component root before the benchmark cache reads it.
          await timing.measure('初始化 TensorRT 资源', _upscale.initializeResources);
          await timing.measure('读取响度设置', _audio.loadLoudnessPreference);
          await timing.measure('读取超分设置', _upscale.loadPreferences);
        }
        _notify();
      } finally {
        BTLogTool.info('播放设置加载耗时：${timing.summary}');
      }
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
    var player = _mpv.player;
    if (player == null) return;
    rate = PlaybackRateMemory.normalize(rate);
    await player.setRate(rate);
    await _rateMemory.remember(rate);
    _notify();
  }

  Future<void> stepRate(double delta) => _serial(() async {
    var player = _mpv.player;
    if (player == null) return;
    await _setRate(PlaybackRateMemory.step(player.state.rate, delta));
  });

  Future<void> toggleRate() => _serial(() async {
    var player = _mpv.player;
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

  Future<void> setAutoMarkWatched(bool enabled) => _serial(() async {
    if (_closed || _autoMarkWatched == enabled) return;
    await settingsStore.write('playbackAutoMarkWatched', enabled.toString());
    if (_closed) return;
    _autoMarkWatched = enabled;
    _notify();
  });

  Future<void> setUpscaleMode(PlaybackUpscaleMode mode) => _serial(() async {
    await _loadPreferences();
    await _upscale.setUpscaleMode(mode);
  });

  Future<void> restoreUpscaleMode() => _serial(() async {
    // Recheck after queued media/settings changes to avoid restoring a stale
    // notice's mode in another episode or after the user selects a new mode.
    var mode = _mpv.upscaler?.restorableMode;
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
      await progress.run('暂停超分更新', () async => _mpv.upscaler?.suspendMedia());
      await progress.run('退出全屏', () async => beforeVideoDispose?.call());
      await _stop(refreshHistory: false, progress: progress);
      _sourceDir = null;
      _sourceSubject = null;
      _aspectRatio = null;
      _videoSize = null;
      error = null;
      _mpv.diagnostics?.stopped();
      _notify();
    }).whenComplete(() {
      _clearingPlayback = false;
      _mpv.syncIdleTimer();
    });
  }

  Future<void> _stop({
    bool refreshHistory = true,
    PlaybackCloseProgress? progress,
  }) async {
    var stages = progress ?? const PlaybackCloseProgress();
    await stages.run('保存播放进度', () => _save(refreshHistory: refreshHistory));
    loading = true;
    _mpv.janaiVideoSource?.reset();
    try {
      _manualSubtitles = true;
      _mpv.chapters?.reset();
      await stages.run('等待超分操作完成', () async => _mpv.upscaler?.suspendMedia());
      if (_closed) return;
      // Resetting vf/shaders while a video is loaded can rebuild its decoder
      // and inference chain. Stop first, then clear options on the idle player.
      await stages.run('停止媒体播放', () async => _mpv.player?.stop());
      await stages.run('清理超分配置', () async => _mpv.upscaler?.resetMedia());
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
        _mpv.chapters?.reset();
        await beforeVideoDispose?.call();
        await _mpv.upscaler?.suspendMedia();
        if (_closed) return;
        await _mpv.player?.stop();
        await _mpv.upscaler?.resetMedia();
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

  Future<void> _shutdown() async {
    // Refuse newly queued work before waiting for the current operation.
    _mpv.prepareShutdown();
    _upscale.dispose();
    _mpv.diagnostics?.close();
    _mpv.janaiVideoSource?.close();
    _mpv.chapters?.close();
    _session.close();
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
    var upscale = _mpv.upscaler;
    if (upscale != null) {
      await _shutdownStep(
        '停止视频超分操作',
        upscale.close,
        const Duration(seconds: 1),
      );
    }
    var detached = _mpv.detachForShutdown();
    var player = detached.player;
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

    var subscriptions = _mpv.takeSubscriptions();
    await _shutdownStep('取消播放监听', () async {
      await Future.wait(subscriptions.map((s) => s.cancel()));
    }, const Duration(seconds: 1));
    unawaited(_completions.close());
    if (player != null && drained) {
      await _shutdownStep(
        '释放原生播放器',
        () => _mpv.disposePlayer(player, upscale: upscale),
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
        await _mpv.disposePlayer(player, upscale: upscale);
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

/// Attributes one player-open operation to its sequential waits. Slow stages
/// log immediately, so a failed or cancelled open still explains where the
/// time went; the caller logs the complete breakdown when the operation ends.
class _PlaybackOpenTiming {
  final _watch = Stopwatch()..start();
  final _stages = <String>[];

  Future<T> measure<T>(String name, Future<T> Function() action) async {
    var started = _watch.elapsedMicroseconds;
    try {
      return await action();
    } finally {
      var elapsed = _watch.elapsedMicroseconds - started;
      _stages.add('$name=${_format(elapsed)}ms');
      if (elapsed >= 50 * 1000) {
        BTLogTool.info('播放打开阶段：$name=${_format(elapsed)}ms');
      }
    }
  }

  String get summary =>
      '${_stages.join(' ')} total=${_format(_watch.elapsedMicroseconds)}ms';

  static String _format(int microseconds) => microseconds < 100 * 1000
      ? (microseconds / 1000).toStringAsFixed(1)
      : (microseconds / 1000).round().toString();
}
