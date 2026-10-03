// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../core/container.dart';
import '../core/network/system_proxy.dart';
import '../core/services/bt_engine_client.dart';
import '../core/services/file_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/windows_firewall_rule.dart';
import '../database/app/app_config.dart';
import '../models/app/bt_download_config.dart';
import '../models/database/app_bmf_model.dart';
import '../providers/bmf_providers.dart';
import '../tools/log_tool.dart';
import 'nav_store.dart';
import 'tracker_hive.dart';

typedef BtTaskCompletionNotifier = Future<void> Function(BtTaskSnapshot task);
typedef BtEngineStartConfigProvider = Future<Map<String, dynamic>> Function();
typedef BtEngineConfigReader = Future<BtDownloadConfig> Function();
typedef BtEngineConfigWriter = Future<void> Function(BtDownloadConfig config);
typedef BtFirewallRuleRegistrar = Future<void> Function();
typedef BtDownloadProxySettingReader = Future<bool> Function();
typedef BtDownloadProxySettingWriter = Future<void> Function(bool value);
typedef BtDownloadProxyConfigBuilder =
    Future<Map<String, dynamic>> Function({required bool enabled});

final btDownloadStoreProvider =
    NotifierProvider<BtDownloadStore, BtDownloadState>(BtDownloadStore.new);

enum BtBatchAction { pause, resume, stop }

/// 下载页可见的任务快照。
///
/// 只保存可比较的数据：任务列表、引擎状态、错误与忙碌标记。引擎客户端、
/// 订阅、定时刷新等留在 [BtDownloadStore] 私有字段，不进入状态。
class BtDownloadState {
  /// 构造函数
  const BtDownloadState({
    this.tasks = const [],
    this.activeTasks = const [],
    this.stoppedTasks = const [],
    this.taskBaseStates = const {},
    this.busyTaskIds = const {},
    this.engineState = BtEngineClientState.stopped,
    this.lastError,
    this.refreshing = false,
    this.useSystemProxy = false,
  });

  /// 全部任务
  final List<BtTaskSnapshot> tasks;

  /// 进行中任务，按 正在下载 > 未下载 > 正在做种 > 已暂停 排序。
  final List<BtTaskSnapshot> activeTasks;

  /// 已停止任务（下载出错 / 已完成做种）。
  final List<BtTaskSnapshot> stoppedTasks;

  /// 每个任务进入“校验中”之前的稳定状态。
  final Map<String, String> taskBaseStates;

  /// 正在执行命令的任务 id。
  final Set<String> busyTaskIds;

  /// 下载引擎状态
  final BtEngineClientState engineState;

  /// 最近一次错误
  final String? lastError;

  /// 是否正在刷新任务列表
  final bool refreshing;

  /// 下载引擎是否使用 Windows 系统代理。
  final bool useSystemProxy;

  /// 任务是否已停止：下载出错或已完成做种，不再参与下载与上传。
  ///
  /// 校验中（`checking`）沿用进入校验前的分类，避免“重新校验”让任务在
  /// 进行中/已停止两个标签页之间跳转。
  bool isStoppedTask(BtTaskSnapshot task) {
    var base = taskBaseStates[task.id] ?? task.state;
    return base == 'completed' || base == 'error' || base == 'stopped';
  }

  /// 任务是否正在执行命令。
  bool isTaskBusy(String id) => busyTaskIds.contains(id);

  /// 是否可批量操作
  bool canBatchAct(BtTaskSnapshot task, BtBatchAction action) {
    if (busyTaskIds.contains(task.id)) return false;
    return switch (action) {
      BtBatchAction.pause => BtDownloadStore.shouldPauseBeforeRemove(
        task.state,
      ),
      BtBatchAction.resume => {'paused', 'stopped'}.contains(task.state),
      BtBatchAction.stop =>
        BtDownloadStore.shouldPauseBeforeRemove(task.state) ||
            task.state == 'paused',
    };
  }

  /// 总下载速率
  int get totalDownloadRate =>
      tasks.fold(0, (total, task) => total + task.downloadRate);

  /// 总上传速率
  int get totalUploadRate =>
      tasks.fold(0, (total, task) => total + task.uploadRate);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BtDownloadState) return false;
    return engineState == other.engineState &&
        lastError == other.lastError &&
        refreshing == other.refreshing &&
        useSystemProxy == other.useSystemProxy &&
        BtDownloadStore.sameTaskSnapshots(activeTasks, other.activeTasks) &&
        BtDownloadStore.sameTaskSnapshots(stoppedTasks, other.stoppedTasks) &&
        BtDownloadStore.sameTaskSnapshots(tasks, other.tasks) &&
        mapEquals(taskBaseStates, other.taskBaseStates) &&
        setEquals(busyTaskIds, other.busyTaskIds);
  }

  @override
  int get hashCode => Object.hash(
    engineState,
    lastError,
    refreshing,
    useSystemProxy,
    activeTasks.length,
    stoppedTasks.length,
    tasks.length,
  );
}

class BtDownloadStore extends Notifier<BtDownloadState> {
  BtDownloadStore({
    BtEngineGateway? client,
    BtTaskCompletionNotifier? completionNotifier,
    BtEngineStartConfigProvider? startConfigProvider,
    BtEngineConfigReader? readConfig,
    BtEngineConfigWriter? writeConfig,
    BtFirewallRuleRegistrar? registerFirewallRule,
    bool useSystemProxy = false,
    BtDownloadProxySettingReader? readProxySetting,
    BtDownloadProxySettingWriter? writeProxySetting,
    BtDownloadProxyConfigBuilder? buildProxyConfig,
  }) : _client = client ?? BtEngineClient.instance,
       _injected = client != null,
       _useProxy = useSystemProxy,
       _completionNotifier = completionNotifier ?? _showCompletionNotification,
       _startConfigProvider =
           startConfigProvider ??
           (client == null ? _loadStartConfig : _emptyStartConfig),
       _readConfig =
           readConfig ?? (client == null ? _loadConfig : _enabledConfig),
       _writeConfig =
           writeConfig ?? (client == null ? _saveConfig : _noopConfigWrite),
       _firewallRegistrar = registerFirewallRule ?? _registerFirewallRule,
       _readProxySetting =
           readProxySetting ??
           (client == null
               ? BtsAppConfig().readUseDownloadSystemProxy
               : () async => useSystemProxy),
       _writeProxySetting =
           writeProxySetting ??
           (client == null
               ? BtsAppConfig().writeUseDownloadSystemProxy
               : (_) async {}),
       _buildProxyConfig =
           buildProxyConfig ??
           (client == null ? WindowsSystemProxy.engineConfig : _directProxy);

  final BtEngineGateway _client;
  final bool _injected;
  final BtTaskCompletionNotifier _completionNotifier;
  final BtEngineStartConfigProvider _startConfigProvider;
  final BtEngineConfigReader _readConfig;
  final BtEngineConfigWriter _writeConfig;
  final BtFirewallRuleRegistrar _firewallRegistrar;
  final BtDownloadProxySettingReader _readProxySetting;
  final BtDownloadProxySettingWriter _writeProxySetting;
  final BtDownloadProxyConfigBuilder _buildProxyConfig;
  late final StreamSubscription<List<BtTaskSnapshot>> _taskSubscription;
  late final StreamSubscription<BtEngineClientState> _stateSubscription;
  final Set<String> _busyTaskIds = {};
  final Map<String, String> _taskStates = {};
  final Map<String, String> _taskBaseStates = {};
  final Set<String> _availableTaskIds = {};
  late bool _useProxy;
  late BtEngineClientState _engineState;
  String? _lastStoreError;
  bool _refreshing = false;
  Future<void>? _proxyInit;

  @override
  BtDownloadState build() {
    var initialTasks = List<BtTaskSnapshot>.of(_client.tasks);
    _engineState = _client.state;
    // 关闭引擎或 provider 销毁时取消订阅，避免流继续向已释放的对象推送。
    ref.onDispose(() {
      unawaited(_taskSubscription.cancel());
      unawaited(_stateSubscription.cancel());
    });
    _taskStates.addEntries(
      initialTasks.map((task) => MapEntry(task.id, task.state)),
    );
    _availableTaskIds.addAll(
      initialTasks.where(_isFileAvailable).map((task) => task.id),
    );
    _updateTaskBaseStates(initialTasks);
    _taskSubscription = _client.taskSnapshots.listen(_onTaskSnapshots);
    _stateSubscription = _client.states.listen(_onEngineState);
    if (!_injected) _proxyInit = _initProxySetting();
    return _buildState(initialTasks);
  }

  /// 组装对外可见的状态快照。
  ///
  /// 列表在内容一致时复用上一个实例，让 Riverpod 的 `select` 可以按引用
  /// 相等跳过无关重建（引擎快照按字节高频刷新）。
  BtDownloadState _buildState([List<BtTaskSnapshot>? tasks]) {
    var previous = state;
    var all = List<BtTaskSnapshot>.of(tasks ?? previous.tasks);
    var next = BtDownloadState(
      tasks: _reuseSnapshots(previous.tasks, all),
      activeTasks: _reuseSnapshots(
        previous.activeTasks,
        _sortTasks(all.where((task) => !isStoppedTask(task))),
      ),
      stoppedTasks: _reuseSnapshots(
        previous.stoppedTasks,
        _sortTasks(all.where(isStoppedTask)),
      ),
      taskBaseStates: Map.unmodifiable(_taskBaseStates),
      busyTaskIds: Set.unmodifiable(_busyTaskIds),
      engineState: _engineState,
      lastError: _lastStoreError,
      refreshing: _refreshing,
      useSystemProxy: _useProxy,
    );
    // 内容完全一致时保留原实例，避免向监听者推送无意义的新状态。
    return next == previous ? previous : next;
  }

  static List<BtTaskSnapshot> _reuseSnapshots(
    List<BtTaskSnapshot> previous,
    List<BtTaskSnapshot> next,
  ) {
    if (_sameTaskSnapshots(previous, next)) return previous;
    return List.unmodifiable(next);
  }

  void _publish([List<BtTaskSnapshot>? tasks]) {
    state = _buildState(tasks);
  }

  void _onTaskSnapshots(List<BtTaskSnapshot> tasks) {
    var unchanged = _sameTaskSnapshots(state.tasks, tasks);
    _updateTaskBaseStates(tasks);
    _notifyNewCompletions(tasks);
    if (unchanged) return;
    _publish(List.of(tasks));
  }

  void _onEngineState(BtEngineClientState next) {
    var ready = next == BtEngineClientState.ready;
    var errorCleared = ready && _lastStoreError != null;
    if (_engineState == next && !errorCleared) return;
    _engineState = next;
    if (ready) _lastStoreError = null;
    _publish();
  }

  /// 任务是否已停止：下载出错或已完成做种，不再参与下载与上传。
  ///
  /// 校验中（`checking`）沿用进入校验前的分类，避免“重新校验”让任务在
  /// 进行中/已停止两个标签页之间跳转。
  bool isStoppedTask(BtTaskSnapshot task) {
    var base = _taskBaseStates[task.id] ?? task.state;
    return base == 'completed' || base == 'error' || base == 'stopped';
  }

  /// 当前任务快照
  List<BtTaskSnapshot> get tasks => state.tasks;

  /// 进行中任务
  List<BtTaskSnapshot> get activeTasks => state.activeTasks;

  /// 已停止任务
  List<BtTaskSnapshot> get stoppedTasks => state.stoppedTasks;

  /// 下载引擎状态
  BtEngineClientState get engineState => state.engineState;

  /// 最近一次错误
  String? get lastError => state.lastError;

  /// 是否正在刷新任务列表
  bool get refreshing => state.refreshing;

  /// 下载引擎是否使用 Windows 系统代理。
  bool get useSystemProxy => state.useSystemProxy;

  /// 任务是否正在执行命令
  bool isTaskBusy(String id) => state.isTaskBusy(id);

  /// 是否可对该任务执行批量操作
  bool canBatchAct(BtTaskSnapshot task, BtBatchAction action) =>
      state.canBatchAct(task, action);

  static bool sameTaskSnapshots(
    List<BtTaskSnapshot> current,
    List<BtTaskSnapshot> next,
  ) {
    return _sameTaskSnapshots(current, next);
  }

  static bool _sameTaskSnapshots(
    List<BtTaskSnapshot> current,
    List<BtTaskSnapshot> next,
  ) {
    if (identical(current, next)) return true;
    if (current.length != next.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != next[i]) return false;
    }
    return true;
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

  Future<BtTaskDetails> taskDetails(String id) => _client.taskDetails(id);
  Future<BtTaskFilesResult> taskFiles(
    String id, {
    int offset = 0,
    int? limit,
  }) => _client.taskFiles(id, offset: offset, limit: limit);
  Future<BtTaskPeersResult> taskPeers(
    String id, {
    int offset = 0,
    int? limit,
  }) => _client.taskPeers(id, offset: offset, limit: limit);
  Future<List<int>> setFilePriorities(String id, Map<int, int> priorities) =>
      _client.setFilePriorities(id, priorities);

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    _lastStoreError = null;
    _publish();
    try {
      if (_client.isReady) {
        await _client.refreshTasks();
      } else {
        await _startEngine();
      }
    } catch (error) {
      _lastStoreError = error.toString();
      rethrow;
    } finally {
      _refreshing = false;
      _publish();
    }
  }

  Future<BtTaskSnapshot> addTorrentFile({
    required String torrentPath,
    required String savePath,
    String? displayName,
    bool manual = false,
  }) async {
    _lastStoreError = null;
    _publish();
    try {
      if (!_client.isReady) await _startEngine();
      var task = await _client.addTorrentFile(
        torrentPath: torrentPath,
        savePath: savePath,
        displayName: displayName,
        manual: manual,
      );
      await _client.refreshTasks();
      return task;
    } catch (error) {
      _lastStoreError = error.toString();
      _publish();
      rethrow;
    }
  }

  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
    bool manual = false,
  }) async {
    _lastStoreError = null;
    _publish();
    try {
      if (!_client.isReady) await _startEngine();
      var task = await _client.addMagnet(
        uri: uri,
        savePath: savePath,
        displayName: displayName,
        manual: manual,
      );
      await _client.refreshTasks();
      return task;
    } catch (error) {
      _lastStoreError = error.toString();
      _publish();
      rethrow;
    }
  }

  Future<BtTaskSnapshot> addHttp({
    required String url,
    required String savePath,
    String? displayName,
    bool manual = false,
  }) async {
    _lastStoreError = null;
    _publish();
    try {
      if (!_client.isReady) await _startEngine();
      var task = await _client.addHttp(
        url: url,
        savePath: savePath,
        displayName: displayName,
        manual: manual,
      );
      await _client.refreshTasks();
      return task;
    } catch (error) {
      _lastStoreError = error.toString();
      _publish();
      rethrow;
    }
  }

  Future<void> pause(String id) => _runTask(id, () => _client.pause(id));
  Future<void> stop(String id) => _runTask(id, () => _client.stop(id));
  Future<void> resume(String id) => _runTask(id, () => _client.resume(id));
  Future<void> retry(String id) => _runTask(id, () => _client.retry(id));
  Future<void> recheck(String id) => _runTask(id, () => _client.recheck(id));
  Future<void> remove(String id) async {
    await _runTask(id, () => _client.remove(id, deleteData: false));
  }

  /// 应用启动后自动继续下载或做种未完成的暂停任务，返回恢复的数量。
  ///
  /// 引擎退出时会把进行中的任务改写成 `paused`，重启后引擎不会自动继续，
  /// 因此由客户端在启动时统一恢复，避免用户逐条手动恢复。文件可用但尚未
  /// 达到做种停止条件的 BT 任务也会继续；已完成做种、已停止和出错的任务
  /// 不在处理范围内，单个任务恢复失败也不影响其余任务。
  Future<int> resumeUnfinishedTasks() async {
    if (!_client.isReady) return 0;
    var config = await _readConfig();
    var targets = state.tasks
        .where((task) => _shouldResumeOnStartup(task, config))
        .map((task) => task.id)
        .toList(growable: false);
    if (targets.isEmpty) return 0;

    var resumed = 0;
    for (var id in targets) {
      try {
        await _client.resume(id);
        resumed++;
      } catch (error) {
        BTLogTool.warn('自动继续暂停中的下载任务失败（$id）：$error');
      }
    }
    if (resumed > 0) {
      // 恢复结果以引擎快照为准，避免 UI 停留在旧的暂停状态。
      try {
        await _client.refreshTasks();
      } catch (error) {
        BTLogTool.warn('自动继续下载任务后刷新任务列表失败：$error');
      }
    }
    return resumed;
  }

  static bool _shouldResumeOnStartup(
    BtTaskSnapshot task,
    BtDownloadConfig config,
  ) {
    if (task.state != 'paused') return false;
    if (!_isFileAvailable(task)) return true;
    if (task.sourceKind == 'http' ||
        !config.seedingEnabled ||
        !config.seedingDisclosureAccepted ||
        task.seedStopReason != null) {
      return false;
    }
    if (config.seedRatioLimit > 0 &&
        task.totalBytes > 0 &&
        task.uploadedBytes >= task.totalBytes * config.seedRatioLimit) {
      return false;
    }
    if (config.seedTimeLimitMinutes > 0 &&
        task.seedingSeconds >= config.seedTimeLimitMinutes * 60) {
      return false;
    }
    // 计费或节能状态等运行时限制仍由引擎在恢复时判定。
    return true;
  }

  /// Recheck eligibility for each task; one failure does not abort the batch.
  Future<int> batchAct(Iterable<String> ids, BtBatchAction action) async {
    var succeeded = 0;
    var failures = <String>[];
    for (var id in ids.toSet()) {
      var task = _taskById(id);
      if (task == null || !state.canBatchAct(task, action)) continue;
      try {
        switch (action) {
          case BtBatchAction.pause:
            await pause(id);
          case BtBatchAction.resume:
            await resume(id);
          case BtBatchAction.stop:
            await stop(id);
        }
        succeeded++;
      } catch (error) {
        failures.add('${task.displayName}: $error');
      }
    }
    if (failures.isNotEmpty) {
      throw BtEngineClientException(
        '成功 $succeeded 个，失败 ${failures.length} 个：${failures.join('；')}',
      );
    }
    return succeeded;
  }

  /// 批量移除任务（保留数据）；活跃任务会先暂停再移除。
  Future<void> removeAll(Iterable<String> ids) async {
    var targets = ids.toList();
    if (targets.isEmpty) return;
    _lastStoreError = null;
    _busyTaskIds.addAll(targets);
    _publish();
    try {
      for (var id in targets) {
        var task = _taskById(id);
        if (task != null && shouldPauseBeforeRemove(task.state)) {
          try {
            await _client.pause(id);
          } catch (_) {
            // 暂停失败不阻塞删除
          }
        }
        await _client.remove(id, deleteData: false);
      }
    } catch (error) {
      _lastStoreError = error.toString();
      rethrow;
    } finally {
      _busyTaskIds.removeAll(targets);
      _publish();
    }
  }

  Future<void> configure(Map<String, dynamic> config) async {
    _lastStoreError = null;
    _publish();
    try {
      if (!_client.isReady) {
        throw const BtEngineClientException('download engine is not ready');
      }
      await _client.configure(config);
    } catch (error) {
      _lastStoreError = error.toString();
      _publish();
      rethrow;
    }
  }

  void clearError() {
    if (_lastStoreError == null) return;
    _lastStoreError = null;
    _publish();
  }

  /// 手动开启下载引擎：启动引擎、持久化开启状态，并自动注册防火墙规则。
  ///
  /// 引擎已开启时重复调用不会重复启动。返回非空字符串表示引擎已运行但
  /// 防火墙规则注册失败（例如用户取消了管理员授权），调用方可作为警告展示。
  Future<String?> enableEngine() async {
    _lastStoreError = null;
    _publish();
    var config = await _readConfig();
    try {
      if (!_client.isReady) {
        await _startClient();
      }
      if (!config.engineEnabled) {
        await _writeConfig(config.copyWith(engineEnabled: true));
      }
    } catch (error) {
      _lastStoreError = error.toString();
      _publish();
      rethrow;
    }

    String? warning;
    try {
      await _firewallRegistrar();
    } catch (error) {
      warning = '下载引擎已开启，但防火墙规则注册失败：$error';
    }
    _publish();
    return warning;
  }

  /// 手动关闭下载引擎：停止引擎进程并持久化关闭状态。
  Future<void> disableEngine() async {
    _lastStoreError = null;
    _publish();
    var config = await _readConfig();
    try {
      if (config.engineEnabled) {
        await _writeConfig(config.copyWith(engineEnabled: false));
      }
      if (_client.isReady) {
        await _client.shutdown();
      }
    } catch (error) {
      _lastStoreError = error.toString();
      _publish();
      rethrow;
    }
    _publish();
  }

  BtTaskSnapshot? _taskById(String id) {
    for (var task in state.tasks) {
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
      'paused' || 'stopped' || 'completed' => 4,
      _ => 5,
    };
  }

  static bool shouldPauseBeforeRemove(String state) {
    return state == 'seeding' ||
        {'metadata', 'checking', 'queued', 'downloading'}.contains(state);
  }

  Future<void> _runTask(String id, Future<Object?> Function() action) async {
    if (_busyTaskIds.contains(id)) return;
    _busyTaskIds.add(id);
    _lastStoreError = null;
    _publish();
    try {
      await action();
    } catch (error) {
      _lastStoreError = error.toString();
      rethrow;
    } finally {
      _busyTaskIds.remove(id);
      _publish();
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
          .read(navStoreProvider.notifier)
          .addNavItemB(subject: bmf.subject, paneTitle: bmf.title, type: '动画');
      return;
    }
    await BTFileTool().openDir(task.savePath);
  }

  static Future<AppBmfModel?> _findMatchingBmf(String savePath) async {
    if (savePath.isEmpty) return null;
    try {
      var bmfList = await globalContainer.read(bmfRepositoryProvider).readAll();
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
      throw const BtEngineClientException('下载引擎未开启，请先手动开启下载引擎');
    }
    await _startClient();
  }

  Future<void> _startClient() async {
    await _ensureProxyReady();
    var config = await _startConfigProvider();
    var proxy = await _buildProxyConfig(enabled: _useProxy);
    var client = _client;
    if (client is BtEngineClient) {
      await client.start(config: config, proxy: proxy);
    } else {
      await client.start(config: config);
    }
  }

  Future<void> _initProxySetting() async {
    var value = await _readProxySetting();
    if (_useProxy == value) return;
    _useProxy = value;
    _publish();
  }

  Future<void> _ensureProxyReady() async {
    var init = _proxyInit;
    if (init != null) await init;
  }

  Future<void> _applyEngineProxy(Map<String, dynamic> proxy) async {
    var client = _client;
    if (client is BtEngineClient && client.isReady) {
      await client.configureProxy(proxy);
    }
  }

  /// 设置下载引擎是否使用系统代理，并在引擎已运行时热更新。
  Future<void> setUseSystemProxy(bool value) async {
    await _ensureProxyReady();
    var previous = _useProxy;
    try {
      var proxy = await _buildProxyConfig(enabled: value);
      await _applyEngineProxy(proxy);
      await _writeProxySetting(value);
    } catch (error, stackTrace) {
      try {
        await _applyEngineProxy(await _buildProxyConfig(enabled: previous));
      } catch (rollbackError) {
        BTLogTool.warn('回滚下载代理设置失败：$rollbackError');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    _useProxy = value;
    _publish();
  }

  static Future<Map<String, dynamic>> _loadStartConfig() async {
    var config = await BtsAppConfig().readBtDownloadConfig();
    return config.toEngineJson(
      additionalTrackers: globalContainer
          .read(trackerStoreProvider.notifier)
          .effectiveTrackers,
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

  static Future<Map<String, dynamic>> _directProxy({
    required bool enabled,
  }) async {
    return <String, dynamic>{'enabled': enabled};
  }

  static Future<void> _registerFirewallRule() async {
    if (!Platform.isWindows) return;
    var service = WindowsFirewallRuleService.instance;
    var enginePath = BtEngineClient.bundledExecutablePath();
    var status = await service.status(enginePath);
    if (status == EngineFirewallRuleStatus.registered) return;
    await service.register(enginePath);
  }
}
