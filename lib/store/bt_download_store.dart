// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../core/services/bt_engine_client.dart';
import '../database/app/app_bmf.dart';
import '../database/app/app_config.dart';
import '../main.dart';
import '../models/database/app_bmf_model.dart';
import '../tools/file_tool.dart';
import '../tools/log_tool.dart';
import '../tools/notifier_tool.dart';
import 'bmf_store.dart';
import 'nav_store.dart';
import 'tracker_hive.dart';

typedef BtTaskCompletionNotifier = Future<void> Function(BtTaskSnapshot task);
typedef BtEngineStartConfigProvider = Future<Map<String, dynamic>> Function();

final btDownloadStoreProvider = ChangeNotifierProvider<BtDownloadStore>((ref) {
  return BtDownloadStore();
});

class BtDownloadStore extends ChangeNotifier {
  BtDownloadStore({
    BtEngineGateway? client,
    BtTaskCompletionNotifier? completionNotifier,
    BtEngineStartConfigProvider? startConfigProvider,
  }) : _client = client ?? BtEngineClient.instance,
       _completionNotifier = completionNotifier ?? _showCompletionNotification,
       _startConfigProvider =
           startConfigProvider ??
           (client == null ? _loadStartConfig : _emptyStartConfig),
       _engineState = (client ?? BtEngineClient.instance).state,
       _tasks = List.of((client ?? BtEngineClient.instance).tasks) {
    _taskStates.addEntries(_tasks.map((task) => MapEntry(task.id, task.state)));
    _availableTaskIds.addAll(
      _tasks.where(_isFileAvailable).map((task) => task.id),
    );
    _taskSubscription = _client.taskSnapshots.listen((tasks) {
      _notifyNewCompletions(tasks);
      _tasks = List.of(tasks);
      notifyListeners();
    });
    _stateSubscription = _client.states.listen((state) {
      _engineState = state;
      if (state == BtEngineClientState.ready) _lastError = null;
      notifyListeners();
    });
  }

  final BtEngineGateway _client;
  final BtTaskCompletionNotifier _completionNotifier;
  final BtEngineStartConfigProvider _startConfigProvider;
  late final StreamSubscription<List<BtTaskSnapshot>> _taskSubscription;
  late final StreamSubscription<BtEngineClientState> _stateSubscription;
  final Set<String> _busyTaskIds = {};
  final Map<String, String> _taskStates = {};
  final Set<String> _availableTaskIds = {};
  List<BtTaskSnapshot> _tasks;
  BtEngineClientState _engineState;
  String? _lastError;
  var _refreshing = false;

  List<BtTaskSnapshot> get tasks => List.unmodifiable(_tasks);

  /// 进行中任务，按 正在下载 > 未下载 > 正在做种 > 错误 排序。
  List<BtTaskSnapshot> get activeTasks =>
      _sortTasks(_tasks.where((task) => !isStoppedTask(task)));

  /// 已停止任务（已暂停 / 已完成做种）。
  List<BtTaskSnapshot> get stoppedTasks =>
      _sortTasks(_tasks.where(isStoppedTask));

  /// 任务是否已停止：不参与下载与做种。
  static bool isStoppedTask(BtTaskSnapshot task) {
    return task.state == 'paused' || task.state == 'completed';
  }

  BtEngineClientState get engineState => _engineState;
  String? get lastError => _lastError;
  bool get refreshing => _refreshing;
  int get totalDownloadRate =>
      _tasks.fold(0, (total, task) => total + task.downloadRate);
  int get totalUploadRate =>
      _tasks.fold(0, (total, task) => total + task.uploadRate);
  bool isTaskBusy(String id) => _busyTaskIds.contains(id);

  Future<BtTaskDetails> taskDetails(String id) => _client.taskDetails(id);

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    _lastError = null;
    notifyListeners();
    try {
      if (_client.isReady) {
        await _client.refreshTasks();
      } else {
        await _startEngine();
      }
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<BtTaskSnapshot> addTorrentFile({
    required String torrentPath,
    required String savePath,
    String? displayName,
  }) async {
    _lastError = null;
    notifyListeners();
    try {
      if (!_client.isReady) await _startEngine();
      var task = await _client.addTorrentFile(
        torrentPath: torrentPath,
        savePath: savePath,
        displayName: displayName,
      );
      await _client.refreshTasks();
      return task;
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
  }) async {
    _lastError = null;
    notifyListeners();
    try {
      if (!_client.isReady) await _startEngine();
      var task = await _client.addMagnet(
        uri: uri,
        savePath: savePath,
        displayName: displayName,
      );
      await _client.refreshTasks();
      return task;
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pause(String id) => _runTask(id, () => _client.pause(id));
  Future<void> resume(String id) => _runTask(id, () => _client.resume(id));
  Future<void> retry(String id) => _runTask(id, () => _client.retry(id));
  Future<void> recheck(String id) => _runTask(id, () => _client.recheck(id));
  Future<void> remove(String id) {
    return _runTask(id, () => _client.remove(id, deleteData: false));
  }

  /// 批量移除任务（保留数据）；活跃任务会先暂停再移除。
  Future<void> removeAll(Iterable<String> ids) async {
    var targets = ids.toList();
    if (targets.isEmpty) return;
    _lastError = null;
    _busyTaskIds.addAll(targets);
    notifyListeners();
    try {
      for (var id in targets) {
        var task = _taskById(id);
        if (task != null && _shouldPauseBeforeRemove(task.state)) {
          try {
            await _client.pause(id);
          } catch (_) {
            // 暂停失败不阻塞删除
          }
        }
        await _client.remove(id, deleteData: false);
      }
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _busyTaskIds.removeAll(targets);
      notifyListeners();
    }
  }

  Future<void> configure(Map<String, dynamic> config) async {
    _lastError = null;
    notifyListeners();
    try {
      if (!_client.isReady) {
        throw const BtEngineClientException('download engine is not ready');
      }
      await _client.configure(config);
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  BtTaskSnapshot? _taskById(String id) {
    for (var task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// 分组排序：正在下载 > 未下载 > 正在做种 > 错误 > 已停止，
  /// 同组内保持引擎返回顺序（稳定排序）。
  static List<BtTaskSnapshot> _sortTasks(Iterable<BtTaskSnapshot> tasks) {
    var snapshots = tasks.toList();
    var order = List.generate(snapshots.length, (index) => index);
    order.sort((a, b) {
      var rank = _stateRank(
        snapshots[a].state,
      ).compareTo(_stateRank(snapshots[b].state));
      if (rank != 0) return rank;
      return a.compareTo(b);
    });
    return List.unmodifiable(order.map((index) => snapshots[index]));
  }

  static int _stateRank(String state) {
    return switch (state) {
      'downloading' || 'metadata' || 'checking' => 0,
      'queued' => 1,
      'seeding' => 2,
      'error' => 3,
      'paused' || 'completed' => 4,
      _ => 5,
    };
  }

  static bool _shouldPauseBeforeRemove(String state) {
    return state == 'seeding' ||
        {'metadata', 'checking', 'queued', 'downloading'}.contains(state);
  }

  Future<void> _runTask(String id, Future<Object?> Function() action) async {
    if (_busyTaskIds.contains(id)) return;
    _busyTaskIds.add(id);
    _lastError = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _busyTaskIds.remove(id);
      notifyListeners();
    }
  }

  void _notifyNewCompletions(List<BtTaskSnapshot> tasks) {
    var nextStates = <String, String>{};
    for (var task in tasks) {
      var previousState = _taskStates[task.id];
      var newlyAvailable =
          _isFileAvailable(task) && _availableTaskIds.add(task.id);
      if (previousState != null && newlyAvailable) {
        unawaited(
          _completionNotifier(task).catchError((Object error) {
            BTLogTool.error('显示 BT 下载完成通知失败：$error');
          }),
        );
      }
      nextStates[task.id] = task.state;
    }
    _taskStates
      ..clear()
      ..addAll(nextStates);
  }

  static bool _isFileAvailable(BtTaskSnapshot task) {
    return task.state == 'seeding' ||
        task.state == 'completed' ||
        (task.totalBytes > 0 && task.verifiedBytes >= task.totalBytes);
  }

  static Future<void> _showCompletionNotification(BtTaskSnapshot task) {
    var title = task.displayName.isEmpty
        ? task.displayInfoHash ?? task.id
        : task.displayName;
    return BTNotifierTool.showMini(
      title: '下载完成',
      body: title,
      onClick: () => unawaited(_handleCompletionClick(task)),
    );
  }

  static Future<void> _handleCompletionClick(BtTaskSnapshot task) async {
    var bmf = await _findMatchingBmf(task.savePath);
    if (bmf != null) {
      globalContainer.read(bmfNavigationProvider).selectSubject(bmf.subject);
      globalContainer.read(navStoreProvider).setCurIndex(1);
      return;
    }
    await BTFileTool().openDir(task.savePath);
  }

  static Future<AppBmfModel?> _findMatchingBmf(String savePath) async {
    if (savePath.isEmpty) return null;
    try {
      var bmfList = await BtsAppBmf().readAll();
      var target = path.normalize(savePath).toLowerCase();
      for (var bmf in bmfList) {
        var downloadDir = bmf.download;
        if (downloadDir == null || downloadDir.isEmpty) continue;
        if (path.normalize(downloadDir).toLowerCase() == target) return bmf;
      }
    } catch (error) {
      BTLogTool.warn('匹配 BMF 下载目录失败：$error');
    }
    return null;
  }

  Future<void> _startEngine() async {
    await _client.start(config: await _startConfigProvider());
  }

  static Future<Map<String, dynamic>> _loadStartConfig() async {
    var config = await BtsAppConfig().readBtDownloadConfig();
    return config.toEngineJson(
      additionalTrackers: TrackerHive().effectiveTrackers,
    );
  }

  static Future<Map<String, dynamic>> _emptyStartConfig() async => const {};

  @override
  void dispose() {
    unawaited(_taskSubscription.cancel());
    unawaited(_stateSubscription.cancel());
    super.dispose();
  }
}
