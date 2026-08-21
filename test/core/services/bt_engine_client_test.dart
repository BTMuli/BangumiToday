// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'package:bangumi_today/core/services/bt_engine_client.dart';

void main() {
  test('locates the sidecar beside the host executable', () {
    var hostPath = path.join('C:', 'Program Files', 'BangumiToday', 'app.exe');

    expect(
      BtEngineClient.bundledExecutablePath(hostExecutablePath: hostPath),
      path.join(
        'C:',
        'Program Files',
        'BangumiToday',
        'bt_download',
        'bt_download.exe',
      ),
    );
  });

  group('BtTaskSnapshot.displayInfoHash', () {
    BtTaskSnapshot snapshotWithHash(String? hash) {
      return BtTaskSnapshot.fromJson({
        ..._taskJson(id: 'task', state: 'downloading'),
        'infoHash': hash,
      });
    }

    test('strips the v2 placeholder from a v1 torrent', () {
      var hash =
          '[d6a69b11d7ab0c62d4eaacb626314e982408e8b0,'
          '0000000000000000000000000000000000000000000000000000000000000000]';
      expect(
        snapshotWithHash(hash).displayInfoHash,
        'd6a69b11d7ab0c62d4eaacb626314e982408e8b0',
      );
    });

    test('falls back to the v2 hash for a v2-only torrent', () {
      var hash =
          '[0000000000000000000000000000000000000000000000000000000000000000,'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa]';
      expect(
        snapshotWithHash(hash).displayInfoHash,
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
    });

    test('prefers the v1 hash for hybrid torrents', () {
      var hash =
          '[d6a69b11d7ab0c62d4eaacb626314e982408e8b0,'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb]';
      expect(
        snapshotWithHash(hash).displayInfoHash,
        'd6a69b11d7ab0c62d4eaacb626314e982408e8b0',
      );
    });

    test('leaves plain hashes and null unchanged', () {
      expect(snapshotWithHash(null).displayInfoHash, isNull);
      expect(snapshotWithHash('abc123').displayInfoHash, 'abc123');
    });
  });

  group('BtTaskFileDetail.isPadding', () {
    test('uses the engine padding marker', () {
      expect(
        const BtTaskFileDetail(
          path: r'media\_____padding_file_0_____',
          size: 8,
          completedBytes: 8,
          paddingFile: true,
        ).isPadding,
        isTrue,
      );
      expect(
        const BtTaskFileDetail(
          path: '360413',
          size: 360413,
          completedBytes: 360413,
          priority: 0,
          paddingFile: false,
        ).isPadding,
        isFalse,
      );
      expect(
        const BtTaskFileDetail(
          path: 'media/episode.mp4',
          size: 8,
          completedBytes: 8,
        ).isPadding,
        isFalse,
      );
    });

    test('parses the engine padding marker', () {
      expect(
        BtTaskFileDetail.fromJson({
          'path': 'episode.mp4',
          'size': 8,
          'completedBytes': 8,
          'priority': 0,
          'isPadding': true,
        }).isPadding,
        isTrue,
      );
    });
  });

  group('BtTaskPeerDetail', () {
    BtTaskPeerDetail peer(String client, {String endpoint = '1.2.3.4:51413'}) {
      return BtTaskPeerDetail(
        endpoint: endpoint,
        client: client,
        progress: 0.5,
        downloadRate: 1,
        uploadRate: 1,
      );
    }

    test('strips brackets from ipv6 endpoints', () {
      expect(
        peer(
          'qBittorrent 4.4.5',
          endpoint: '[2001:db8::1]:51413',
        ).endpointLabel,
        '2001:db8::1:51413',
      );
    });

    test('keeps plain ipv4 endpoints unchanged', () {
      expect(peer('qBittorrent 4.4.5').endpointLabel, '1.2.3.4:51413');
    });

    test('splits space-separated client into name and version', () {
      var value = peer('Transmission 2.94');
      expect(value.clientName, 'Transmission');
      expect(value.clientVersion, '2.94');
    });

    test('splits slash-separated client into name and version', () {
      var value = peer('qBittorrent/4.4.5');
      expect(value.clientName, 'qBittorrent');
      expect(value.clientVersion, '4.4.5');
    });

    test('splits multi-word name with slash-separated version', () {
      var value = peer('Baidu Netdisk/7.2.3');
      expect(value.clientName, 'Baidu Netdisk');
      expect(value.clientVersion, '7.2.3');
    });

    test('keeps the whole string as name when no version is present', () {
      var value = peer('unknown');
      expect(value.clientName, 'unknown');
      expect(value.clientVersion, isEmpty);
    });

    test('does not treat a trailing non-version word as version', () {
      var value = peer('Some Custom Client');
      expect(value.clientName, 'Some Custom Client');
      expect(value.clientVersion, isEmpty);
    });
  });

  group('BtEngineClient', () {
    late Directory temporaryDirectory;
    late String executablePath;
    late FakeBtEngineProcess process;
    late BtEngineClient client;
    late List<String> diagnostics;

    setUp(() async {
      PackageInfo.setMockInitialValues(
        appName: 'BangumiToday',
        packageName: 'BangumiToday',
        version: '0.8.0',
        buildNumber: '22',
        buildSignature: '',
      );
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'bangumi_today_bt_client_',
      );
      executablePath = path.join(temporaryDirectory.path, 'bt_download.exe');
      await File(executablePath).writeAsBytes(const []);
      process = FakeBtEngineProcess();
      diagnostics = [];
      client = BtEngineClient(
        processStarter: (executable, arguments) async => process,
        diagnosticSink: diagnostics.add,
        requestTimeout: const Duration(milliseconds: 500),
      );
    });

    tearDown(() async {
      await client.shutdown();
      await process.dispose();
      await temporaryDirectory.delete(recursive: true);
    });

    test('handshakes, initializes and restores the task snapshot', () async {
      process.taskLists.add({
        'tasks': [_taskJson(id: 'restored', state: 'paused')],
        'sequence': 4,
      });
      var statePath = path.join(temporaryDirectory.path, 'state');

      await client.start(
        executablePath: executablePath,
        statePath: statePath,
        config: {'activeDownloads': 1},
      );

      expect(client.state, BtEngineClientState.ready);
      expect(client.tasks, hasLength(1));
      expect(client.tasks.single.id, 'restored');
      expect(client.tasks.single.state, 'paused');
      var initialize = process.requests.firstWhere(
        (request) => request['method'] == 'engine.initialize',
      );
      expect(initialize['params'], {
        'protocolVersion': btEngineProtocolVersion,
        'statePath': path.absolute(statePath),
        'userAgent': 'BangumiToday/0.8.0',
        'config': {'activeDownloads': 1},
      });
      expect(
        process.requests.any(
          (request) => request['method'] == 'engine.configure',
        ),
        isTrue,
      );

      process.emitStderr('diagnostic');
      await Future<void>.delayed(Duration.zero);
      expect(diagnostics, contains('BT 下载引擎：diagnostic'));

      await client.shutdown();
      expect(client.state, BtEngineClientState.stopped);
      expect(
        process.requests.any(
          (request) => request['method'] == 'engine.shutdown',
        ),
        isTrue,
      );
    });

    test('exposes stable JSON-RPC business errors', () async {
      await client.start(
        executablePath: executablePath,
        statePath: path.join(temporaryDirectory.path, 'state'),
      );
      process.errorMethods['engine.status'] = {
        'code': -32004,
        'message': 'not found',
        'data': {
          'code': 'TASK_NOT_FOUND',
          'retryable': false,
          'taskId': 'missing',
        },
      };

      await expectLater(
        client.status(),
        throwsA(
          isA<BtEngineRpcException>()
              .having((error) => error.code, 'code', 'TASK_NOT_FOUND')
              .having((error) => error.rpcCode, 'rpcCode', -32004)
              .having((error) => error.retryable, 'retryable', isFalse)
              .having((error) => error.data['taskId'], 'taskId', 'missing'),
        ),
      );
    });

    test('parses task detail sections', () async {
      await client.start(
        executablePath: executablePath,
        statePath: path.join(temporaryDirectory.path, 'state'),
      );

      var details = await client.taskDetails('task');

      expect(details.task.id, 'task');
      expect(details.pieceCount, 2);
      expect(details.contentFileCount, 1);
      expect(details.completedPieces, '10');
      expect(details.files.single.path, 'episode.mkv');
      expect(details.files.single.progress, 0.5);
      expect(details.files.single.priority, 0);
      expect(details.files.single.isSkipped, isTrue);
      expect(details.peers.single.client, 'qBittorrent');
      expect(details.peers.single.downloadRate, 1024);
    });

    test(
      'rejects an engine whose protocol version is not exactly 1.2',
      () async {
        process.readyProtocolVersion = '1.1';

        await expectLater(
          client.start(
            executablePath: executablePath,
            statePath: path.join(temporaryDirectory.path, 'state'),
          ),
          throwsA(
            isA<BtEngineClientException>().having(
              (error) => error.message,
              'message',
              contains('unsupported download engine protocol'),
            ),
          ),
        );
        expect(client.state, BtEngineClientState.failed);
      },
    );

    test(
      'requests tabbed file and peer lists on a protocol 1.2 engine',
      () async {
        await client.start(
          executablePath: executablePath,
          statePath: path.join(temporaryDirectory.path, 'state'),
        );

        var files = await client.taskFiles('task', limit: 1);
        var peers = await client.taskPeers('task', offset: 1);

        expect(files.files.single.path, 'episode.mkv');
        expect(files.truncated, isFalse);
        expect(files.offset, 0);
        expect(files.nextOffset, isNull);
        expect(peers.peers.single.client, 'qBittorrent');
        expect(peers.offset, 1);
        var fileRequest = process.requests.firstWhere(
          (request) => request['method'] == 'task.files',
        );
        expect(fileRequest['params'], {'id': 'task', 'limit': 1});
        var peerRequest = process.requests.firstWhere(
          (request) => request['method'] == 'task.peers',
        );
        expect(peerRequest['params'], {'id': 'task', 'offset': 1});
      },
    );

    test('deduplicates concurrent tabbed detail requests', () async {
      await client.start(
        executablePath: executablePath,
        statePath: path.join(temporaryDirectory.path, 'state'),
      );

      var results = await Future.wait([
        client.taskFiles('task', limit: 1),
        client.taskFiles('task', limit: 1),
        client.taskDetails('task'),
        client.taskDetails('task'),
      ]);

      expect(
        process.requests.where((request) => request['method'] == 'task.files'),
        hasLength(1),
      );
      expect(
        process.requests.where(
          (request) => request['method'] == 'task.details',
        ),
        hasLength(1),
      );
      expect(
        (results[0] as BtTaskFilesResult).files.single.path,
        'episode.mkv',
      );
      expect((results[2] as BtTaskDetails).task.id, 'task');
    });

    test(
      'sends partial file priorities and parses the applied vector',
      () async {
        await client.start(
          executablePath: executablePath,
          statePath: path.join(temporaryDirectory.path, 'state'),
        );

        var applied = await client.setFilePriorities('task', {1: 0, 3: 7});

        expect(applied, [4, 0, 4, 7]);
        var request = process.requests.singleWhere(
          (request) => request['method'] == 'task.setFilePriorities',
        );
        expect(
          request['params'],
          equals({
            'id': 'task',
            'priorities': {'1': 0, '3': 7},
          }),
        );
      },
    );

    test(
      'reloads the full snapshot when an event sequence has a gap',
      () async {
        process.taskLists
          ..add({
            'tasks': [_taskJson(id: 'task', state: 'downloading')],
            'sequence': 1,
          })
          ..add({
            'tasks': [_taskJson(id: 'task', state: 'completed')],
            'sequence': 3,
          });
        await client.start(
          executablePath: executablePath,
          statePath: path.join(temporaryDirectory.path, 'state'),
        );

        var refreshed = client.taskSnapshots.firstWhere(
          (tasks) => tasks.single.state == 'completed',
        );
        process.emitTaskEvent(
          'event.taskUpdated',
          sequence: 3,
          task: _taskJson(id: 'task', state: 'completed'),
        );

        expect((await refreshed).single.state, 'completed');
        expect(
          process.requests.where((request) => request['method'] == 'task.list'),
          hasLength(2),
        );
      },
    );

    test('fails pending requests when the engine exits unexpectedly', () async {
      await client.start(
        executablePath: executablePath,
        statePath: path.join(temporaryDirectory.path, 'state'),
      );
      process.ignoredMethods.add('engine.status');

      var status = client.status();
      await Future<void>.delayed(Duration.zero);
      process.exit(23);

      await expectLater(status, throwsA(isA<BtEngineClientException>()));
      await Future<void>.delayed(Duration.zero);
      expect(client.state, BtEngineClientState.failed);
      expect(diagnostics, contains('BT 下载引擎意外退出，退出码：23'));
    });
  });

  var integrationEngine = Platform.environment['BT_DOWNLOAD_TEST_ENGINE'];
  test(
    'communicates with the packaged bt_download process',
    () async {
      var stateDirectory = await Directory.systemTemp.createTemp(
        'bangumi_today_bt_integration_',
      );
      var client = BtEngineClient();
      try {
        await client.start(
          executablePath: integrationEngine,
          statePath: stateDirectory.path,
          config: {
            'additionalTrackers': ['udp://127.0.0.1:6969/announce'],
            'seedingEnabled': false,
            'seedRatioLimit': 2.0,
            'seedTimeLimitMinutes': 60,
          },
        );
        var status = await client.status();

        expect(status['initialized'], isTrue);
        expect(status['protocolVersion'], btEngineProtocolVersion);
        expect((status['config'] as Map)['additionalTrackers'], [
          'udp://127.0.0.1:6969/announce',
        ]);
        expect(client.state, BtEngineClientState.ready);
      } finally {
        await client.shutdown();
        await stateDirectory.delete(recursive: true);
      }
    },
    skip: integrationEngine == null
        ? 'Set BT_DOWNLOAD_TEST_ENGINE to run the process integration test.'
        : false,
  );
}

Map<String, dynamic> _taskJson({required String id, required String state}) {
  return {
    'id': id,
    'state': state,
    'sourceKind': 'torrentFile',
    'savePath': r'C:\Downloads',
    'displayName': 'Example',
    'infoHash': 'abc',
    'totalBytes': 100,
    'downloadedBytes': state == 'completed' ? 100 : 50,
    'verifiedBytes': state == 'completed' ? 100 : 40,
    'uploadedBytes': state == 'seeding' ? 20 : 0,
    'shareRatio': state == 'seeding' ? 0.2 : 0,
    'seedingSeconds': state == 'seeding' ? 15 : 0,
    'seedRatioLimit': 2.0,
    'seedTimeLimitMinutes': 60,
    'seedStopReason': state == 'completed' ? 'ratio' : null,
    'progress': state == 'completed' ? 1.0 : 0.5,
    'downloadRate': 10,
    'uploadRate': 2,
    'peers': 3,
    'seeds': 1,
    'private': false,
    'lastError': null,
  };
}

class FakeBtEngineProcess implements BtEngineProcess {
  FakeBtEngineProcess() {
    _stdin = IOSink(_stdinController.sink);
    _stdinSubscription = _stdinController.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleRequest);
    scheduleMicrotask(() {
      _emit({
        'jsonrpc': '2.0',
        'method': 'event.ready',
        'params': {
          'protocolVersion': readyProtocolVersion,
          'engineVersion': 'test',
        },
      });
    });
  }

  String readyProtocolVersion = btEngineProtocolVersion;
  final StreamController<List<int>> _stdoutController = StreamController();
  final StreamController<List<int>> _stderrController = StreamController();
  final StreamController<List<int>> _stdinController = StreamController();
  final Completer<int> _exitCode = Completer();
  final List<Map<String, dynamic>> requests = [];
  final List<Map<String, dynamic>> taskLists = [];
  final Map<String, Map<String, dynamic>> errorMethods = {};
  final Set<String> ignoredMethods = {};
  late final IOSink _stdin;
  late final StreamSubscription<String> _stdinSubscription;
  var _taskListIndex = 0;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  IOSink get stdin => _stdin;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  bool kill() {
    exit(-1);
    return true;
  }

  void emitStderr(String line) {
    if (!_stderrController.isClosed) {
      _stderrController.add(utf8.encode('$line\n'));
    }
  }

  void emitTaskEvent(
    String method, {
    required int sequence,
    required Map<String, dynamic> task,
  }) {
    _emit({
      'jsonrpc': '2.0',
      'method': method,
      'params': {'sequence': sequence, 'task': task},
    });
  }

  void exit(int code) {
    if (_exitCode.isCompleted) return;
    _exitCode.complete(code);
  }

  Future<void> dispose() async {
    exit(0);
    await _stdin.close();
    await _stdinSubscription.cancel();
    await _stdoutController.close();
    await _stderrController.close();
    if (!_stdinController.isClosed) await _stdinController.close();
  }

  void _handleRequest(String line) {
    var request = Map<String, dynamic>.from(jsonDecode(line) as Map);
    requests.add(request);
    var method = request['method'] as String;
    if (ignoredMethods.contains(method)) return;
    var error = errorMethods[method];
    if (error != null) {
      _respond(request, error: error);
      return;
    }

    switch (method) {
      case 'engine.initialize':
        _respond(
          request,
          result: {
            'protocolVersion': btEngineProtocolVersion,
            'engineVersion': 'test',
            'restoredTasks': 0,
          },
        );
      case 'task.list':
        var result = _taskListIndex < taskLists.length
            ? taskLists[_taskListIndex++]
            : {'tasks': <Map<String, dynamic>>[], 'sequence': 0};
        _respond(request, result: result);
      case 'task.details':
        _respond(
          request,
          result: {
            'task': _taskJson(id: 'task', state: 'downloading'),
            'pieceLength': 16384,
            'pieceCount': 2,
            'completedPieces': '10',
            'contentFiles': 1,
            'files': [
              {
                'path': 'episode.mkv',
                'size': 100,
                'completedBytes': 50,
                'priority': 0,
                'isPadding': false,
              },
            ],
            'filesTruncated': false,
            'peers': [
              {
                'endpoint': '127.0.0.1:6881',
                'client': 'qBittorrent',
                'progress': 0.75,
                'downloadRate': 1024,
                'uploadRate': 0,
              },
            ],
            'peersTruncated': false,
          },
        );
      case 'task.files':
        var filesOffset =
            ((request['params'] as Map?)?['offset'] as num?)?.toInt() ?? 0;
        _respond(
          request,
          result: {
            'files': [
              {
                'path': 'episode.mkv',
                'size': 100,
                'completedBytes': 50,
                'priority': 0,
                'isPadding': false,
              },
            ],
            'filesTruncated': false,
            'totalFiles': 1,
            'contentFiles': 1,
            'offset': filesOffset,
            'nextOffset': null,
          },
        );
      case 'task.peers':
        var peersOffset =
            ((request['params'] as Map?)?['offset'] as num?)?.toInt() ?? 0;
        _respond(
          request,
          result: {
            'peers': [
              {
                'endpoint': '127.0.0.1:6881',
                'client': 'qBittorrent',
                'progress': 0.75,
                'downloadRate': 1024,
                'uploadRate': 0,
              },
            ],
            'peersTruncated': false,
            'totalPeers': 1,
            'offset': peersOffset,
            'nextOffset': null,
          },
        );
      case 'task.setFilePriorities':
        _respond(
          request,
          result: {
            'priorities': [4, 0, 4, 7],
          },
        );
      case 'engine.status':
        _respond(
          request,
          result: {
            'initialized': true,
            'protocolVersion': btEngineProtocolVersion,
          },
        );
      case 'engine.shutdown':
        _respond(request, result: {'shutdown': true});
        scheduleMicrotask(() => exit(0));
      default:
        _respond(request, result: <String, dynamic>{});
    }
  }

  void _respond(
    Map<String, dynamic> request, {
    Map<String, dynamic>? result,
    Map<String, dynamic>? error,
  }) {
    _emit({
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': ?result,
      'error': ?error,
    });
  }

  void _emit(Map<String, dynamic> message) {
    if (!_stdoutController.isClosed) {
      _stdoutController.add(utf8.encode('${jsonEncode(message)}\n'));
    }
  }
}
