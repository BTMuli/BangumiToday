// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Project imports:
import '../../tools/log_tool.dart';

const btEngineProtocolVersion = '1.0';
const _maxProtocolFrameBytes = 1024 * 1024;

enum BtEngineClientState { stopped, starting, ready, stopping, failed }

class BtTaskError {
  const BtTaskError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  factory BtTaskError.fromJson(Map<String, dynamic> json) {
    return BtTaskError(
      code: json['code'] as String,
      message: json['message'] as String,
      retryable: json['retryable'] as bool? ?? false,
    );
  }

  final String code;
  final String message;
  final bool retryable;
}

class BtTaskSnapshot {
  const BtTaskSnapshot({
    required this.id,
    required this.state,
    required this.sourceKind,
    required this.savePath,
    required this.displayName,
    required this.infoHash,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.verifiedBytes,
    required this.progress,
    required this.downloadRate,
    required this.uploadRate,
    required this.peers,
    required this.seeds,
    required this.isPrivate,
    required this.lastError,
  });

  factory BtTaskSnapshot.fromJson(Map<String, dynamic> json) {
    return BtTaskSnapshot(
      id: json['id'] as String,
      state: json['state'] as String,
      sourceKind: json['sourceKind'] as String,
      savePath: json['savePath'] as String,
      displayName: json['displayName'] as String? ?? '',
      infoHash: json['infoHash'] as String?,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      verifiedBytes: (json['verifiedBytes'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      downloadRate: (json['downloadRate'] as num?)?.toInt() ?? 0,
      uploadRate: (json['uploadRate'] as num?)?.toInt() ?? 0,
      peers: (json['peers'] as num?)?.toInt() ?? 0,
      seeds: (json['seeds'] as num?)?.toInt() ?? 0,
      isPrivate: json['private'] as bool? ?? false,
      lastError: json['lastError'] is Map
          ? BtTaskError.fromJson(
              Map<String, dynamic>.from(json['lastError'] as Map),
            )
          : null,
    );
  }

  final String id;
  final String state;
  final String sourceKind;
  final String savePath;
  final String displayName;
  final String? infoHash;
  final int totalBytes;
  final int downloadedBytes;
  final int verifiedBytes;
  final double progress;
  final int downloadRate;
  final int uploadRate;
  final int peers;
  final int seeds;
  final bool isPrivate;
  final BtTaskError? lastError;
}

class BtEngineEvent {
  const BtEngineEvent({required this.method, required this.params});

  final String method;
  final Map<String, dynamic> params;
}

class BtEngineClientException implements Exception {
  const BtEngineClientException(this.message);

  final String message;

  @override
  String toString() => 'BtEngineClientException: $message';
}

class BtEngineRpcException extends BtEngineClientException {
  const BtEngineRpcException({
    required String message,
    required this.rpcCode,
    required this.code,
    required this.retryable,
    required this.data,
  }) : super(message);

  final int rpcCode;
  final String code;
  final bool retryable;
  final Map<String, dynamic> data;

  @override
  String toString() => 'BtEngineRpcException($code): $message';
}

abstract interface class BtEngineProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  IOSink get stdin;
  Future<int> get exitCode;
  bool kill();
}

class IoBtEngineProcess implements BtEngineProcess {
  IoBtEngineProcess(this._process);

  final Process _process;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  IOSink get stdin => _process.stdin;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill() => _process.kill();
}

typedef BtEngineProcessStarter =
    Future<BtEngineProcess> Function(String executable, List<String> arguments);

abstract interface class BtEngineGateway {
  BtEngineClientState get state;
  bool get isReady;
  List<BtTaskSnapshot> get tasks;
  Stream<BtEngineEvent> get events;
  Stream<List<BtTaskSnapshot>> get taskSnapshots;
  Stream<BtEngineClientState> get states;

  Future<void> start({
    String? executablePath,
    List<String> arguments = const [],
    String? statePath,
    Map<String, dynamic> config = const {},
    Duration readyTimeout = const Duration(seconds: 5),
  });

  Future<void> refreshTasks();
  Future<Map<String, dynamic>> status();
  Future<Map<String, dynamic>> configure(Map<String, dynamic> config);
  Future<BtTaskSnapshot> addTorrentFile({
    required String torrentPath,
    required String savePath,
    String? displayName,
    bool start = true,
  });
  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
    bool start = true,
  });
  Future<BtTaskSnapshot> pause(String id);
  Future<BtTaskSnapshot> resume(String id);
  Future<BtTaskSnapshot> retry(String id);
  Future<BtTaskSnapshot> recheck(String id);
  Future<void> remove(String id, {bool deleteData = false});
  Future<void> shutdown();
}

class BtEngineClient implements BtEngineGateway {
  BtEngineClient({
    BtEngineProcessStarter? processStarter,
    void Function(String message)? diagnosticSink,
    Duration requestTimeout = const Duration(seconds: 10),
  }) : _processStarter = processStarter ?? _startProcess,
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
  final Map<String, BtTaskSnapshot> _tasks = {};

  BtEngineProcess? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Completer<Map<String, dynamic>>? _readyCompleter;
  Future<void>? _taskRefresh;
  var _nextRequestId = 0;
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
    if (utf8.encode(frame).length > _maxProtocolFrameBytes) {
      _pendingRequests.remove(id);
      throw const BtEngineClientException('protocol request is too large');
    }

    try {
      process.stdin.writeln(frame);
      await process.stdin.flush();
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

  @override
  Future<Map<String, dynamic>> status() => request('engine.status');

  @override
  Future<void> refreshTasks() => _loadTasks();

  @override
  Future<Map<String, dynamic>> configure(Map<String, dynamic> config) {
    return request('engine.configure', config);
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
      if (utf8.encode(line).length > _maxProtocolFrameBytes) {
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
    _failPendingRequests(
      const BtEngineClientException('download engine stopped'),
    );
  }

  void _setState(BtEngineClientState value) {
    if (_state == value) return;
    _state = value;
    _stateController.add(value);
  }

  static Future<BtEngineProcess> _startProcess(
    String executable,
    List<String> arguments,
  ) async {
    var process = await Process.start(
      executable,
      arguments,
      workingDirectory: path.dirname(executable),
      mode: ProcessStartMode.normal,
    );
    return IoBtEngineProcess(process);
  }
}
