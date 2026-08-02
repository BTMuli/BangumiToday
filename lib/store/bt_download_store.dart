// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_riverpod/legacy.dart';

// Project imports:
import '../core/services/bt_engine_client.dart';
import '../database/app/app_config.dart';
import '../tools/file_tool.dart';
import '../tools/log_tool.dart';
import '../tools/notifier_tool.dart';
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
        ? task.infoHash ?? task.id
        : task.displayName;
    return BTNotifierTool.showMini(
      title: '下载完成',
      body: title,
      onClick: () => unawaited(BTFileTool().openDir(task.savePath)),
    );
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
