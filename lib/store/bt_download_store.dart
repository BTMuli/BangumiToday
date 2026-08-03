// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../core/services/bt_engine_client.dart';
import '../core/services/windows_firewall_rule.dart';
import '../database/app/app_bmf.dart';
import '../database/app/app_config.dart';
import '../main.dart';
import '../models/app/bt_download_config.dart';
import '../models/database/app_bmf_model.dart';
import '../tools/file_tool.dart';
import '../tools/log_tool.dart';
import '../tools/notifier_tool.dart';
import 'bt_task_elapsed_store.dart';
import 'nav_store.dart';
import 'tracker_hive.dart';

typedef BtTaskCompletionNotifier = Future<void> Function(BtTaskSnapshot task);
typedef BtEngineStartConfigProvider = Future<Map<String, dynamic>> Function();
typedef BtEngineConfigReader = Future<BtDownloadConfig> Function();
typedef BtEngineConfigWriter = Future<void> Function(BtDownloadConfig config);
typedef BtFirewallRuleRegistrar = Future<void> Function();

final btDownloadStoreProvider = ChangeNotifierProvider<BtDownloadStore>((ref) {
  return BtDownloadStore();
});

class BtDownloadStore extends ChangeNotifier {
  BtDownloadStore({
    BtEngineGateway? client,
    BtTaskCompletionNotifier? completionNotifier,
    BtEngineStartConfigProvider? startConfigProvider,
    BtEngineConfigReader? readConfig,
    BtEngineConfigWriter? writeConfig,
    BtFirewallRuleRegistrar? registerFirewallRule,
    BtTaskElapsedStore? elapsedStore,
  }) : _client = client ?? BtEngineClient.instance,
       _completionNotifier = completionNotifier ?? _showCompletionNotification,
       _startConfigProvider =
           startConfigProvider ??
           (client == null ? _loadStartConfig : _emptyStartConfig),
       _readConfig =
           readConfig ?? (client == null ? _loadConfig : _enabledConfig),
       _writeConfig =
           writeConfig ?? (client == null ? _saveConfig : _noopConfigWrite),
       _firewallRegistrar = registerFirewallRule ?? _registerFirewallRule,
       _elapsedStore = elapsedStore ?? const BtSqliteTaskElapsedStore(),
       _engineState = (client ?? BtEngineClient.instance).state,
       _tasks = List.of((client ?? BtEngineClient.instance).tasks) {
    _taskStates.addEntries(_tasks.map((task) => MapEntry(task.id, task.state)));
    _availableTaskIds.addAll(
      _tasks.where(_isFileAvailable).map((task) => task.id),
    );
    _taskSubscription = _client.taskSnapshots.listen((tasks) {
      _updateTaskBaseStates(tasks);
      _notifyNewCompletions(tasks);
      _restoreNewElapsed(tasks);
      _trackDownloadElapsed(tasks);
      _tasks = List.of(tasks);
      notifyListeners();
    });
    _stateSubscription = _client.states.listen((state) {
      _engineState = state;
      if (state == BtEngineClientState.ready) _lastError = null;
      notifyListeners();
    });
    _updateTaskBaseStates(_tasks);
    _restoreNewElapsed(_tasks);
    _trackDownloadElapsed(_tasks);
  }

  final BtEngineGateway _client;
  final BtTaskCompletionNotifier _completionNotifier;
  final BtEngineStartConfigProvider _startConfigProvider;
  final BtEngineConfigReader _readConfig;
  final BtEngineConfigWriter _writeConfig;
  final BtFirewallRuleRegistrar _firewallRegistrar;
  final BtTaskElapsedStore _elapsedStore;
  late final StreamSubscription<List<BtTaskSnapshot>> _taskSubscription;
  late final StreamSubscription<BtEngineClientState> _stateSubscription;
  final Set<String> _busyTaskIds = {};
  final Map<String, String> _taskStates = {};
  final Map<String, String> _taskBaseStates = {};
  final Map<String, DateTime> _activeSince = {};
  final Map<String, int> _elapsedSeconds = {};
  final Map<String, DateTime> _lastElapsedPersistAt = {};
  final Set<String> _restoredElapsedTaskIds = {};
  final Set<String> _availableTaskIds = {};
  Timer? _elapsedTimer;
  List<BtTaskSnapshot> _tasks;
  BtEngineClientState _engineState;
  String? _lastError;
  var _refreshing = false;

  List<BtTaskSnapshot> get tasks => List.unmodifiable(_tasks);

  /// 进行中任务，按 正在下载 > 未下载 > 正在做种 > 已暂停 排序。
  List<BtTaskSnapshot> get activeTasks =>
      _sortTasks(_tasks.where((task) => !isStoppedTask(task)));

  /// 已停止任务（下载出错 / 已完成做种）。
  List<BtTaskSnapshot> get stoppedTasks =>
      _sortTasks(_tasks.where(isStoppedTask));

  /// 任务是否已停止：下载出错或已完成做种，不再参与下载与上传。
  ///
  /// 校验中（`checking`）沿用进入校验前的分类，避免“重新校验”让任务在
  /// 进行中/已停止两个标签页之间跳转。
  bool isStoppedTask(BtTaskSnapshot task) {
    var base = _taskBaseStates[task.id] ?? task.state;
    return base == 'completed' || base == 'error';
  }

  BtEngineClientState get engineState => _engineState;
  String? get lastError => _lastError;
  bool get refreshing => _refreshing;
  int get totalDownloadRate =>
      _tasks.fold(0, (total, task) => total + task.downloadRate);
  int get totalUploadRate =>
      _tasks.fold(0, (total, task) => total + task.uploadRate);
  bool isTaskBusy(String id) => _busyTaskIds.contains(id);

  /// 任务处于下载状态（含拉取元数据、数据校验）的累计秒数，跨 App 重启保留。
  int downloadElapsedSeconds(String id) => _elapsedSeconds[id] ?? 0;

  static bool _isElapsedActive(String state) {
    return state == 'downloading' ||
        state == 'metadata' ||
        state == 'checking';
  }

  void _trackDownloadElapsed(List<BtTaskSnapshot> tasks) {
    var now = DateTime.now();
    var activeIds = <String>{};
    for (var task in tasks) {
      if (_isElapsedActive(task.state)) {
        activeIds.add(task.id);
        _advanceElapsed(task.id, now);
        _maybePersistElapsed(task.id, now);
      }
    }
    _activeSince.removeWhere((id, since) {
      if (activeIds.contains(id)) return false;
      _advanceElapsed(id, now);
      _lastElapsedPersistAt.remove(id);
      if (_restoredElapsedTaskIds.contains(id)) {
        unawaited(_persistElapsed(id));
      }
      return true;
    });
    _syncElapsedTimer(tasks);
  }

  void _advanceElapsed(String id, DateTime now) {
    var since = _activeSince[id] ?? now;
    _elapsedSeconds[id] =
        (_elapsedSeconds[id] ?? 0) + now.difference(since).inSeconds;
    _activeSince[id] = now;
  }

  void _maybePersistElapsed(String id, DateTime now) {
    if (!_restoredElapsedTaskIds.contains(id)) return;
    var persistedAt = _lastElapsedPersistAt[id];
    if (persistedAt != null &&
        now.difference(persistedAt).inSeconds < 10) {
      return;
    }
    _lastElapsedPersistAt[id] = now;
    unawaited(_persistElapsed(id));
  }

  /// 引擎事件驱动快照可能长时间不来（例如任务卡在 0 速度、无 Peer），
  /// 用 1 秒定时器保证下载中的耗时显示持续走动，避免“卡住”。
  void _syncElapsedTimer(List<BtTaskSnapshot> tasks) {
    var hasActive = tasks.any((task) => _isElapsedActive(task.state));
    if (hasActive && _elapsedTimer == null) {
      _elapsedTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tickElapsed(),
      );
    } else if (!hasActive && _elapsedTimer != null) {
      _elapsedTimer!.cancel();
      _elapsedTimer = null;
    }
  }

  void _tickElapsed() {
    var now = DateTime.now();
    var changed = false;
    for (var id in _activeSince.keys.toList()) {
      var since = _activeSince[id];
      if (since == null) continue;
      var delta = now.difference(since).inSeconds;
      if (delta <= 0) continue;
      _elapsedSeconds[id] = (_elapsedSeconds[id] ?? 0) + delta;
      _activeSince[id] = now;
      changed = true;
    }
    if (!changed) return;
    notifyListeners();
    for (var id in _activeSince.keys) {
      _maybePersistElapsed(id, now);
    }
  }

  /// 记录每个任务进入“校验中”之前的稳定状态，用于分类与排序。
  void _updateTaskBaseStates(List<BtTaskSnapshot> tasks) {
    var ids = <String>{};
    for (var task in tasks) {
      ids.add(task.id);
      if (task.state == 'checking') {
        _taskBaseStates.putIfAbsent(task.id, () => task.state);
      } else {
        _taskBaseStates[task.id] = task.state;
      }
    }
    _taskBaseStates.removeWhere((id, _) => !ids.contains(id));
  }

  void _restoreNewElapsed(List<BtTaskSnapshot> tasks) {
    for (var task in tasks) {
      if (!_restoredElapsedTaskIds.contains(task.id)) {
        unawaited(_restoreElapsedFor(task.id));
      }
    }
  }

  Future<void> _restoreElapsedFor(String id) async {
    try {
      var base = await _elapsedStore.readSeconds(id);
      if (base != null && base > 0) {
        _elapsedSeconds[id] = base + (_elapsedSeconds[id] ?? 0);
        notifyListeners();
      }
    } catch (error) {
      BTLogTool.error('Failed to restore download elapsed time: $error');
    } finally {
      _restoredElapsedTaskIds.add(id);
    }
  }

  Future<void> _persistElapsed(String id) async {
    try {
      await _elapsedStore.writeSeconds(id, _elapsedSeconds[id] ?? 0);
    } catch (error) {
      BTLogTool.error('Failed to persist download elapsed time: $error');
    }
  }

  Future<void> _deleteElapsed(String id) async {
    try {
      await _elapsedStore.delete(id);
    } catch (error) {
      BTLogTool.error('Failed to delete download elapsed time: $error');
    }
  }

  Future<BtTaskDetails> taskDetails(String id) => _client.taskDetails(id);
  Future<List<int>> setFilePriorities(String id, Map<int, int> priorities) =>
      _client.setFilePriorities(id, priorities);

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
  Future<void> remove(String id) async {
    await _runTask(id, () => _client.remove(id, deleteData: false));
    _activeSince.remove(id);
    _elapsedSeconds.remove(id);
    _lastElapsedPersistAt.remove(id);
    _restoredElapsedTaskIds.remove(id);
    unawaited(_deleteElapsed(id));
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
      for (var id in targets) {
        _activeSince.remove(id);
        _elapsedSeconds.remove(id);
        _lastElapsedPersistAt.remove(id);
        _restoredElapsedTaskIds.remove(id);
        unawaited(_deleteElapsed(id));
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

  /// 手动开启下载引擎：启动引擎、持久化开启状态，并自动注册防火墙规则。
  ///
  /// 引擎已开启时重复调用不会重复启动。返回非空字符串表示引擎已运行但
  /// 防火墙规则注册失败（例如用户取消了管理员授权），调用方可作为警告展示。
  Future<String?> enableEngine() async {
    _lastError = null;
    notifyListeners();
    var config = await _readConfig();
    try {
      if (!_client.isReady) {
        await _client.start(config: await _startConfigProvider());
      }
      if (!config.engineEnabled) {
        await _writeConfig(config.copyWith(engineEnabled: true));
      }
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }

    String? warning;
    try {
      await _firewallRegistrar();
    } catch (error) {
      warning = '下载引擎已开启，但防火墙规则注册失败：$error';
    }
    notifyListeners();
    return warning;
  }

  /// 手动关闭下载引擎：停止引擎进程并持久化关闭状态。
  Future<void> disableEngine() async {
    _lastError = null;
    notifyListeners();
    var config = await _readConfig();
    try {
      if (config.engineEnabled) {
        await _writeConfig(config.copyWith(engineEnabled: false));
      }
      if (_client.isReady) {
        await _client.shutdown();
      }
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  BtTaskSnapshot? _taskById(String id) {
    for (var task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// 分组排序：进行中为 正在下载 > 未下载 > 正在做种 > 已暂停，
  /// 已停止为 错误 > 已完成做种，
  /// 同组内保持引擎返回顺序（稳定排序）。
  List<BtTaskSnapshot> _sortTasks(Iterable<BtTaskSnapshot> tasks) {
    var snapshots = tasks.toList();
    var order = List.generate(snapshots.length, (index) => index);
    order.sort((a, b) {
      var rank = _stateRankFor(
        snapshots[a],
      ).compareTo(_stateRankFor(snapshots[b]));
      if (rank != 0) return rank;
      return a.compareTo(b);
    });
    return List.unmodifiable(order.map((index) => snapshots[index]));
  }

  int _stateRankFor(BtTaskSnapshot task) {
    var state = _taskBaseStates[task.id] ?? task.state;
    return _stateRank(state);
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
      globalContainer
          .read(navStoreProvider)
          .addNavItemB(subject: bmf.subject, paneTitle: bmf.title, type: '动画');
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
    var config = await _readConfig();
    if (!config.engineEnabled) {
      throw const BtEngineClientException(
        '下载引擎未开启，请先手动开启下载引擎',
      );
    }
    await _client.start(config: await _startConfigProvider());
  }

  static Future<Map<String, dynamic>> _loadStartConfig() async {
    var config = await BtsAppConfig().readBtDownloadConfig();
    return config.toEngineJson(
      additionalTrackers: TrackerHive().effectiveTrackers,
    );
  }

  static Future<Map<String, dynamic>> _emptyStartConfig() async => const {};

  static Future<BtDownloadConfig> _loadConfig() =>
      BtsAppConfig().readBtDownloadConfig();

  static Future<void> _saveConfig(BtDownloadConfig config) =>
      BtsAppConfig().writeBtDownloadConfig(config);

  /// 测试注入引擎时默认视为已开启，保持既有自动启动行为可测。
  static Future<BtDownloadConfig> _enabledConfig() async =>
      const BtDownloadConfig(engineEnabled: true);

  static Future<void> _noopConfigWrite(BtDownloadConfig config) async {}

  static Future<void> _registerFirewallRule() async {
    if (!Platform.isWindows) return;
    var service = WindowsFirewallRuleService.instance;
    var enginePath = BtEngineClient.bundledExecutablePath();
    var status = await service.status(enginePath);
    if (status == EngineFirewallRuleStatus.registered) return;
    await service.register(enginePath);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    unawaited(_taskSubscription.cancel());
    unawaited(_stateSubscription.cancel());
    super.dispose();
  }
}
