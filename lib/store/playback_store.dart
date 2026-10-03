// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../core/services/playback_cover.dart';
import '../core/services/playback_library.dart';
import '../core/services/playback_subtitles.dart';
import '../database/app/app_config.dart';
import '../database/app/app_playback.dart';
import '../models/playback/playback_fit.dart';
import '../models/playback/playback_item.dart';
import '../models/playback/playback_rate.dart';
import '../providers/bangumi_providers.dart';
import '../tools/log_tool.dart';
import 'bt_download_store.dart';

final playbackStoreProvider = ChangeNotifierProvider<PlaybackStore>((ref) {
  var downloads = ref.read(btDownloadStoreProvider);
  return PlaybackStore(
    library: PlaybackLibrary(
      tasks: () => downloads.tasks,
      taskFiles: (id, offset) => downloads.taskFiles(id, offset: offset),
    ),
    cover: PlaybackCover(ref.read(bangumiRepositoryProvider)),
  );
});

/// One mpv session. Serial operations keep progress attributed to its file.
class PlaybackStore extends ChangeNotifier {
  PlaybackStore({required this.library, required this.cover});

  final PlaybackLibrary library;
  final PlaybackCover cover;

  /// Directory and subject used to (re)discover the playlist for a refresh.
  String? _sourceDir;
  int? _sourceSubject;

  /// The mounted video surface can leave fullscreen before native teardown.
  Future<void> Function()? beforeVideoDispose;
  final BtsAppPlayback _history = BtsAppPlayback();
  final BtsAppConfig _config = BtsAppConfig();
  late final _rateMemory = PlaybackRateMemory(
    read: () => _config.read('playbackRememberedRate'),
    write: (value) => _config.write('playbackRememberedRate', value),
  );
  Future<void>? _preferencesFuture;
  PlaybackFit _fit = PlaybackFit.fit;
  double? _aspectRatio;
  Player? _player;
  VideoController? _video;
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

  Player? get player => _player;
  VideoController? get video => _video;
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
    MediaKit.ensureInitialized();
    // Render subtitles with mpv/libass so ASS styling and embedded fonts are
    // preserved instead of reducing every subtitle track to Flutter text.
    var player = Player(configuration: const PlayerConfiguration(libass: true));
    try {
      await PlaybackSubtitles.configure(player);
    } catch (_) {
      await player.dispose();
      rethrow;
    }
    if (_closed) {
      await player.dispose();
      return;
    }
    _player = player;
    _video = VideoController(player);
    _subscriptions.addAll([
      player.stream.position.listen((value) {
        if (!loading) position = value;
      }),
      player.stream.duration.listen((value) {
        if (!loading && value > Duration.zero) duration = value;
      }),
      player.stream.videoParams.listen((value) {
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
        error = value;
        _notify();
      }),
      player.stream.completed.listen((value) {
        if (loading || current == null) return;
        completed = value;
        if (!value) return;
        var finishedKey = current!.key;
        unawaited(
          _serial(() async {
            if (current?.key != finishedKey) return;
            await _save();
            if (index + 1 < playlist.length) await _openIndex(index + 1);
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
    history = await _history.readAll();
    _notify();
  }

  Future<void> open(List<PlaybackItem> items, String selectedPath) =>
      _serial(() async {
        if (items.isEmpty) throw const PlaybackUnavailable('没有可播放的视频');
        var selected = PlaybackItem.pathKey(selectedPath);
        var selectedIndex = items.indexWhere((item) => item.key == selected);
        if (selectedIndex < 0) {
          throw const PlaybackUnavailable('所选视频尚未就绪');
        }
        await library.ensureReady(items[selectedIndex].filePath);
        if (_closed) return;
        await _save();
        if (_closed) return;
        _sourceDir = path.dirname(selectedPath);
        _sourceSubject = _firstSubject(items);
        await _openIndex(selectedIndex, items: List.unmodifiable(items));
      });

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
    var previous = await _history.read(item.filePath);
    await _loadPreferences();
    if (_closed) return;
    await _initializePlayer();
    if (_closed) return;
    loading = true;
    error = null;
    _notify();
    try {
      await _player!.stop();
      if (_closed) return;
      playlist = nextPlaylist;
      index = nextIndex;
      position = previous?.resumePosition ?? Duration.zero;
      duration = Duration(milliseconds: previous?.durationMs ?? 0);
      completed = false;
      // Keep the previous aspect ratio until the new stream reports its own, so
      // auto-advancing between episodes (usually the same ratio) does not make
      // the playback surface size jump.
      await _player!.open(Media(item.filePath, start: position));
    } catch (e) {
      index = -1;
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

  Future<void> _loadPreferences() => _preferencesFuture ??= (() async {
    await _rateMemory.load();
    _fit = PlaybackFit.parse(await _config.read('playbackFit'));
    _notify();
  })();

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
    await _config.write('playbackFit', mode.name);
    if (_closed) return;
    _fit = mode;
    _notify();
  });

  Future<void> stop() => _serial(() async {
    await _save();
    loading = true;
    try {
      await _player?.stop();
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
    await _history.write(
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
    var savedHistory = await _history.readAll();
    if (_closed) return;
    history = savedHistory;
    _notify();
  }

  Future<void> removeHistory(String filePath) => _serial(() async {
    // Stop first so periodic saves cannot re-create a deleted active record.
    if (current?.key == PlaybackItem.pathKey(filePath)) {
      loading = true;
      try {
        await _player?.stop();
        index = -1;
        playlist = [];
      } finally {
        loading = false;
      }
    }
    await _history.delete(filePath);
    await refreshHistory();
  });

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    // Refuse newly queued work before waiting for the current operation.
    _closed = true;
    _saveTimer?.cancel();
    var pending = _operation;
    await _shutdownStep('等待播放操作', () => pending, const Duration(seconds: 2));
    await _shutdownStep(
      '保存播放位置',
      () => _save(refreshHistory: false),
      const Duration(seconds: 2),
    );
    var detach = beforeVideoDispose;
    beforeVideoDispose = null;
    if (detach != null) {
      await _shutdownStep('退出视频全屏', detach, const Duration(seconds: 1));
    }

    // StreamController.close can wait on widget subscriptions. Unmount Video
    // and its controls while the window can still render, then dispose mpv.
    var player = _player;
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
    if (player != null) {
      await _shutdownStep(
        '释放原生播放器',
        player.dispose,
        const Duration(seconds: 2),
      );
    }
  }

  Future<void> _shutdownStep(
    String name,
    Future<void> Function() action,
    Duration timeout,
  ) async {
    try {
      await action().timeout(timeout);
    } on TimeoutException {
      BTLogTool.warn('播放器清理超时：$name');
    } catch (error) {
      BTLogTool.warn('播放器清理失败：$name，$error');
    }
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
