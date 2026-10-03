import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/services/playback_library.dart';
import '../database/app/app_playback.dart';
import '../models/playback/playback_item.dart';
import '../tools/log_tool.dart';
import 'bt_download_store.dart';

final playbackStoreProvider = ChangeNotifierProvider<PlaybackStore>((ref) {
  var downloads = ref.read(btDownloadStoreProvider);
  return PlaybackStore(
    library: PlaybackLibrary(
      tasks: () => downloads.tasks,
      taskFiles: (id, offset) => downloads.taskFiles(id, offset: offset),
    ),
  );
});

/// One mpv session. Serial operations keep progress attributed to its file.
class PlaybackStore extends ChangeNotifier {
  PlaybackStore({required this.library});

  final PlaybackLibrary library;

  /// The mounted video surface can leave fullscreen before native teardown.
  Future<void> Function()? beforeVideoDispose;
  final BtsAppPlayback _history = BtsAppPlayback();
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
  PlaybackItem? get current =>
      index >= 0 && index < playlist.length ? playlist[index] : null;

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

  void _initializePlayer() {
    if (_player != null) return;
    MediaKit.ensureInitialized();
    var player = _player = Player();
    _video = VideoController(player);
    _subscriptions.addAll([
      player.stream.position.listen((value) {
        if (!loading) position = value;
      }),
      player.stream.duration.listen((value) {
        if (!loading && value > Duration.zero) duration = value;
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
        await _openIndex(selectedIndex, items: List.unmodifiable(items));
      });

  Future<void> _openIndex(int nextIndex, {List<PlaybackItem>? items}) async {
    if (_closed) return;
    var nextPlaylist = items ?? playlist;
    if (nextIndex < 0 || nextIndex >= nextPlaylist.length) return;
    var item = nextPlaylist[nextIndex];
    await library.ensureReady(item.filePath);
    if (_closed) return;
    var previous = await _history.read(item.filePath);
    if (_closed) return;
    _initializePlayer();
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
    await _save();
    await _openIndex(nextIndex);
  });

  Future<void> pause() => _serial(() async {
    await _player?.pause();
    await _save();
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

  Future<void> _save() async {
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
    history = await _history.readAll();
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
    await _shutdownStep('保存播放位置', _save, const Duration(seconds: 2));
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
