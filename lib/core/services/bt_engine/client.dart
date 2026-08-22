// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Project imports:
import '../../../request/core/client.dart';
import '../../../tools/log_tool.dart';
import '../../network/system_proxy.dart';
import 'gateway.dart';
import 'protocol.dart';
import 'transport.dart';

class BtEngineClient implements BtEngineGateway {
  BtEngineClient({
    BtEngineProcessStarter? processStarter,
    void Function(String message)? diagnosticSink,
    Duration requestTimeout = const Duration(seconds: 10),
  }) : _processStarter = processStarter ?? startBtEngineProcess,
       _diagnosticSink = diagnosticSink ?? BTLogTool.warn,
       _requestTimeout = requestTimeout;

  static final BtEngineClient instance = BtEngineClient();

  final BtEngineProcessStarter _processStarter;
  final void Function(String message) _diagnosticSink;
  final Duration _requestTimeout;
  final StreamController<BtEngineEvent> _eventController =
      StreamController<BtEngineEvent>.broadcast();
  final StreamController<List<BtTaskSnapshot>> _taskController =
      StreamController<List<BtTaskSnapshot>>.broadcast();
  final StreamController<BtEngineClientState> _stateController =
      StreamController<BtEngineClientState>.broadcast();
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  final Map<String, Future<Object?>> _inflight = {};
  final Map<String, BtTaskSnapshot> _tasks = {};

  BtEngineProcess? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Completer<Map<String, dynamic>>? _readyCompleter;
  Future<void>? _taskRefresh;
  var _nextRequestId = 0;
  Future<void> _sendQueue = Future.value();
  int? _sequence;
  BtEngineClientState _state = BtEngineClientState.stopped;

  @override
  BtEngineClientState get state => _state;
  @override
  bool get isReady => _state == BtEngineClientState.ready;
  @override
  List<BtTaskSnapshot> get tasks => List.unmodifiable(_tasks.values);
  @override
  Stream<BtEngineEvent> get events => _eventController.stream;
  @override
  Stream<List<BtTaskSnapshot>> get taskSnapshots => _taskController.stream;
  @override
  Stream<BtEngineClientState> get states => _stateController.stream;

  static String bundledExecutablePath({String? hostExecutablePath}) {
    var hostPath = hostExecutablePath ?? Platform.resolvedExecutable;
    return path.join(path.dirname(hostPath), 'bt_download', 'bt_download.exe');
  }

  @override
  Future<void> start({
    String? executablePath,
    List<String> arguments = const [],
    String? statePath,
    Map<String, dynamic> config = const {},
    Duration readyTimeout = const Duration(seconds: 5),
  }) async {
    if (_process != null) {
      throw const BtEngineClientException('download engine is already running');
    }

    _setState(BtEngineClientState.starting);
    var enginePath = path.absolute(executablePath ?? bundledExecutablePath());
    if (!await File(enginePath).exists()) {
      _setState(BtEngineClientState.failed);
      throw BtEngineClientException(
        'download engine executable was not found: $enginePath',
      );
    }

    var engineStatePath = statePath;
    if (engineStatePath == null) {
      var supportDirectory = await getApplicationSupportDirectory();
      engineStatePath = path.join(supportDirectory.path, 'bt_download');
    }
    engineStatePath = path.absolute(engineStatePath);

    try {
      var process = await _processStarter(enginePath, arguments);
      _process = process;
      _readyCompleter = Completer<Map<String, dynamic>>();
      _listenToProcess(process);

      var ready = await _readyCompleter!.future.timeout(readyTimeout);
      if (ready['protocolVersion'] != btEngineProtocolVersion) {
        throw BtEngineClientException(
          'unsupported download engine protocol: '
          '${ready['protocolVersion']}',
        );
      }

      await request('engine.initialize', {
        'protocolVersion': btEngineProtocolVersion,
        'statePath': engineStatePath,
        'userAgent': await getClientUA(),
        'proxy': SystemProxyController.engineProxyConfig,
        if (config.isNotEmpty) 'config': config,
      });
      await _loadTasks();
      if (config.isNotEmpty) await request('engine.configure', config);
      _setState(BtEngineClientState.ready);
    } catch (_) {
      _setState(BtEngineClientState.failed);
      await _terminateFailedStart();
      rethrow;
    }
  }

  /// 并发请求去重：相同 key 的在途请求共享同一个 Future。
  Future<T> _singleFlight<T>(String key, Future<T> Function() load) {
    var existing = _inflight[key];
    if (existing != null) return existing as Future<T>;
    late Future<T> future;
    future = load().whenComplete(() {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    });
    _inflight[key] = future;
    return future;
  }

  @override
  Future<BtTaskDetails> taskDetails(String id) {
    return _singleFlight('task.details:$id', () async {
      var result = await request('task.details', {'id': id});
      return BtTaskDetails.fromJson(result);
    });
  }

  @override
  Future<BtTaskFilesResult> taskFiles(String id, {int offset = 0, int? limit}) {
    return _singleFlight('task.files:$id:$offset:${limit ?? ''}', () async {
      var result = await request('task.files', {
        'id': id,
        if (offset > 0) 'offset': offset,
        'limit': ?limit,
      });
      return BtTaskFilesResult.fromJson(result);
    });
  }

  @override
  Future<BtTaskPeersResult> taskPeers(String id, {int offset = 0, int? limit}) {
    return _singleFlight('task.peers:$id:$offset:${limit ?? ''}', () async {
      var result = await request('task.peers', {
        'id': id,
        if (offset > 0) 'offset': offset,
        'limit': ?limit,
      });
      return BtTaskPeersResult.fromJson(result);
    });
  }

  Future<Map<String, dynamic>> request(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    var process = _process;
    if (process == null) {
      throw const BtEngineClientException('download engine is not running');
    }

    var id = (++_nextRequestId).toString();
    var completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;
    var frame = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params.isNotEmpty) 'params': params,
    });
    if (utf8.encode(frame).length > btEngineMaxProtocolFrameBytes) {
      _pendingRequests.remove(id);
      throw const BtEngineClientException('protocol request is too large');
    }

    try {
      await _enqueueSend(frame);
    } catch (error) {
      _pendingRequests.remove(id);
      throw BtEngineClientException(
        'failed to send download engine request: $error',
      );
    }
    try {
      return await completer.future.timeout(_requestTimeout);
    } on TimeoutException {
      _pendingRequests.remove(id);
      throw BtEngineClientException(
        'download engine request timed out: $method',
      );
    }
  }

  /// 串行化 stdin 写入：`IOSink.flush()` 在途时再次写入会抛错，
  /// 并发 RPC（如详情页按 Tab 请求）必须排队发送。
  Future<void> _enqueueSend(String frame) {
    var next = _sendQueue.then((_) => _writeFrame(frame));
    _sendQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _writeFrame(String frame) {
    var process = _process;
    if (process == null) {
      throw const BtEngineClientException('download engine is not running');
    }
    process.stdin.writeln(frame);
    return process.stdin.flush();
  }

  @override
  Future<Map<String, dynamic>> status() => request('engine.status');

  @override
  Future<void> refreshTasks() => _loadTasks();

  @override
  Future<List<int>> setFilePriorities(
    String id,
    Map<int, int> priorities,
  ) async {
    var result = await request('task.setFilePriorities', {
      'id': id,
      'priorities': priorities.map(
        (index, priority) => MapEntry('$index', priority),
      ),
    });
    var values = result['priorities'];
    if (values is! List) return const [];
    return values
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> configure(Map<String, dynamic> config) {
    return request('engine.configure', config);
  }

  Future<Map<String, dynamic>> configureProxy(Map<String, dynamic> proxy) {
    return request('engine.configureProxy', proxy);
  }

  @override
  Future<BtTaskSnapshot> addTorrentFile({
    required String torrentPath,
    required String savePath,
    String? displayName,
    bool start = true,
  }) {
    return _addTask(
      source: {'kind': 'torrentFile', 'path': path.absolute(torrentPath)},
      savePath: savePath,
      displayName: displayName,
      start: start,
    );
  }

  @override
  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
    bool start = true,
  }) {
    return _addTask(
      source: {'kind': 'magnet', 'uri': uri},
      savePath: savePath,
      displayName: displayName,
      start: start,
    );
  }

  @override
  Future<BtTaskSnapshot> addHttp({
    required String url,
    required String savePath,
    String? displayName,
    bool start = true,
  }) {
    return _addTask(
      source: {'kind': 'http', 'url': url},
      savePath: savePath,
      displayName: displayName,
      start: start,
    );
  }

  @override
  Future<BtTaskSnapshot> pause(String id) => _taskCommand('task.pause', id);
  @override
  Future<BtTaskSnapshot> resume(String id) => _taskCommand('task.resume', id);
  @override
  Future<BtTaskSnapshot> retry(String id) => _taskCommand('task.retry', id);
  @override
  Future<BtTaskSnapshot> recheck(String id) => _taskCommand('task.recheck', id);

  @override
  Future<void> remove(String id, {bool deleteData = false}) async {
    await request('task.remove', {'id': id, 'deleteData': deleteData});
  }

  @override
  Future<void> shutdown() async {
    var process = _process;
    if (process == null) return;
    _setState(BtEngineClientState.stopping);

    try {
      await request('engine.shutdown');
    } catch (error) {
      _diagnosticSink('BT 下载引擎无法优雅退出：$error');
    }

    await process.stdin.close();
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 2));
    } finally {
      await _resetProcess();
      _setState(BtEngineClientState.stopped);
    }
  }

  Future<BtTaskSnapshot> _addTask({
    required Map<String, dynamic> source,
    required String savePath,
    required String? displayName,
    required bool start,
  }) async {
    var result = await request('task.add', {
      'source': source,
      'savePath': path.absolute(savePath),
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      'start': start,
    });
    return _taskFromResult(result);
  }

  Future<BtTaskSnapshot> _taskCommand(String method, String id) async {
    var result = await request(method, {'id': id});
    return _taskFromResult(result);
  }

  BtTaskSnapshot _taskFromResult(Map<String, dynamic> result) {
    return BtTaskSnapshot.fromJson(
      Map<String, dynamic>.from(result['task'] as Map),
    );
  }

  void _listenToProcess(BtEngineProcess process) {
    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleProtocolLine, onError: _handleProtocolError);
    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _diagnosticSink('BT 下载引擎：$line'),
          onError: (Object error) {
            _diagnosticSink('读取 BT 下载引擎日志失败：$error');
          },
        );
    unawaited(
      process.exitCode.then(
        _handleProcessExit,
        onError: (Object error, StackTrace stackTrace) {
          _handleProtocolError(error, stackTrace);
        },
      ),
    );
  }

  void _handleProtocolLine(String line) {
    try {
      if (utf8.encode(line).length > btEngineMaxProtocolFrameBytes) {
        throw const FormatException('protocol frame is too large');
      }
      var decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw const FormatException('protocol frame is not an object');
      }
      var message = Map<String, dynamic>.from(decoded);
      var id = message['id']?.toString();
      if (id != null) {
        _handleResponse(id, message);
        return;
      }

      var method = message['method'];
      if (method is! String || message['params'] is! Map) {
        throw const FormatException('invalid protocol event');
      }
      var params = Map<String, dynamic>.from(message['params'] as Map);
      if (method == 'event.ready') {
        var completer = _readyCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(params);
        }
        return;
      }

      _eventController.add(BtEngineEvent(method: method, params: params));
      if (method.startsWith('event.task')) {
        _handleTaskEvent(method, params);
      }
    } catch (error, stackTrace) {
      _handleProtocolError(error, stackTrace);
    }
  }

  void _handleResponse(String id, Map<String, dynamic> message) {
    var completer = _pendingRequests.remove(id);
    if (completer == null) return;
    if (message['error'] is Map) {
      var error = Map<String, dynamic>.from(message['error'] as Map);
      var data = error['data'] is Map
          ? Map<String, dynamic>.from(error['data'] as Map)
          : <String, dynamic>{};
      completer.completeError(
        BtEngineRpcException(
          rpcCode: (error['code'] as num?)?.toInt() ?? -32000,
          code: data['code'] as String? ?? 'UNKNOWN_ERROR',
          message: error['message'] as String? ?? 'download engine error',
          retryable: data['retryable'] as bool? ?? false,
          data: data,
        ),
      );
      return;
    }
    if (message['result'] is! Map) {
      completer.completeError(
        const BtEngineClientException('invalid protocol response'),
      );
      return;
    }
    completer.complete(Map<String, dynamic>.from(message['result'] as Map));
  }

  void _handleTaskEvent(String method, Map<String, dynamic> params) {
    var eventSequence = (params['sequence'] as num?)?.toInt();
    if (eventSequence == null) {
      _scheduleTaskRefresh();
      return;
    }
    if (_taskRefresh != null) return;
    if (_sequence != null && eventSequence != _sequence! + 1) {
      _scheduleTaskRefresh();
      return;
    }

    var taskJson = params['task'];
    if (taskJson is! Map) {
      _scheduleTaskRefresh();
      return;
    }
    var task = BtTaskSnapshot.fromJson(Map<String, dynamic>.from(taskJson));
    if (method == 'event.taskRemoved') {
      _tasks.remove(task.id);
    } else {
      _tasks[task.id] = task;
    }
    _sequence = eventSequence;
    _emitTasks();
  }

  void _scheduleTaskRefresh() {
    if (_taskRefresh != null || _process == null) return;
    late Future<void> refresh;
    refresh = _loadTasks().whenComplete(() {
      if (identical(_taskRefresh, refresh)) _taskRefresh = null;
    });
    _taskRefresh = refresh;
    unawaited(
      refresh.catchError((Object error, StackTrace stackTrace) {
        _diagnosticSink('重新同步 BT 下载任务失败：$error');
      }),
    );
  }

  Future<void> _loadTasks() async {
    var result = await request('task.list');
    var taskList = result['tasks'];
    if (taskList is! List) {
      throw const BtEngineClientException('invalid task list response');
    }
    var snapshots = taskList.map((item) {
      if (item is! Map) {
        throw const BtEngineClientException('invalid task snapshot');
      }
      return BtTaskSnapshot.fromJson(Map<String, dynamic>.from(item));
    });
    _tasks
      ..clear()
      ..addEntries(snapshots.map((task) => MapEntry(task.id, task)));
    _sequence = (result['sequence'] as num?)?.toInt();
    _emitTasks();
  }

  void _emitTasks() {
    _taskController.add(List.unmodifiable(_tasks.values));
  }

  void _handleProtocolError(Object error, [StackTrace? stackTrace]) {
    _diagnosticSink('BT 下载引擎协议错误：$error');
    _setState(BtEngineClientState.failed);
    var exception = BtEngineClientException(
      'download engine protocol failed: $error',
    );
    var ready = _readyCompleter;
    if (ready != null && !ready.isCompleted) ready.completeError(exception);
    _failPendingRequests(exception);
    _process?.kill();
  }

  void _handleProcessExit(int exitCode) {
    var expected = _state == BtEngineClientState.stopping;
    if (!expected) {
      _diagnosticSink('BT 下载引擎意外退出，退出码：$exitCode');
      _setState(BtEngineClientState.failed);
    }
    var exception = BtEngineClientException(
      'download engine exited with code $exitCode',
    );
    var ready = _readyCompleter;
    if (ready != null && !ready.isCompleted) ready.completeError(exception);
    _failPendingRequests(exception);
    if (!expected) unawaited(_resetProcess());
  }

  void _failPendingRequests(Object error) {
    var pending = _pendingRequests.values.toList();
    _pendingRequests.clear();
    for (var request in pending) {
      if (!request.isCompleted) request.completeError(error);
    }
  }

  Future<void> _terminateFailedStart() async {
    var process = _process;
    if (process != null) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        _diagnosticSink('终止 BT 下载引擎超时');
      }
    }
    await _resetProcess();
  }

  Future<void> _resetProcess() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _process = null;
    _readyCompleter = null;
    _taskRefresh = null;
    _sequence = null;
    _inflight.clear();
    _sendQueue = Future.value();
    _failPendingRequests(
      const BtEngineClientException('download engine stopped'),
    );
  }

  void _setState(BtEngineClientState value) {
    if (_state == value) return;
    _state = value;
    _stateController.add(value);
  }
}
