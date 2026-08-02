import 'dart:async';

import 'package:bangumi_today/core/services/bt_engine_client.dart';
import 'package:bangumi_today/store/bt_download_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BtDownloadStore', () {
    late FakeBtEngineGateway gateway;
    late BtDownloadStore store;
    late List<BtTaskSnapshot> completedTasks;

    setUp(() {
      gateway = FakeBtEngineGateway();
      completedTasks = [];
      store = BtDownloadStore(
        client: gateway,
        completionNotifier: (task) async => completedTasks.add(task),
      );
    });

    tearDown(() async {
      store.dispose();
      await gateway.dispose();
    });

    test('projects engine state and task snapshots', () async {
      gateway
        ..emitState(BtEngineClientState.ready)
        ..emitTasks([_task(state: 'downloading')]);
      await Future<void>.delayed(Duration.zero);

      expect(store.engineState, BtEngineClientState.ready);
      expect(store.tasks.single.state, 'downloading');
    });

    test('starts a stopped engine and refreshes a ready engine', () async {
      await store.refresh();

      expect(gateway.startCalls, 1);
      expect(gateway.refreshCalls, 0);
      expect(store.refreshing, isFalse);

      await store.refresh();

      expect(gateway.startCalls, 1);
      expect(gateway.refreshCalls, 1);
    });

    test(
      'tracks task operations and always preserves data on remove',
      () async {
        var pauseCompleter = Completer<BtTaskSnapshot>();
        gateway.pauseResult = pauseCompleter.future;

        var pause = store.pause('task');
        expect(store.isTaskBusy('task'), isTrue);
        pauseCompleter.complete(_task(state: 'paused'));
        await pause;
        expect(store.isTaskBusy('task'), isFalse);

        await store.remove('task');
        expect(gateway.removedTaskId, 'task');
        expect(gateway.removedWithData, isFalse);
      },
    );

    test('retains an actionable error from a failed command', () async {
      gateway.pauseResult = Future.error(
        const BtEngineClientException('engine unavailable'),
      );

      await expectLater(
        store.pause('task'),
        throwsA(isA<BtEngineClientException>()),
      );

      expect(store.lastError, contains('engine unavailable'));
      expect(store.isTaskBusy('task'), isFalse);
    });

    test(
      'starts the engine before adding a torrent and refreshes tasks',
      () async {
        var result = await store.addTorrentFile(
          torrentPath: r'C:\Temp\example.torrent',
          savePath: r'D:\Downloads',
          displayName: 'Example',
        );

        expect(result.id, 'task');
        expect(gateway.startCalls, 1);
        expect(gateway.addedDisplayName, 'Example');
        expect(gateway.refreshCalls, 1);
      },
    );

    test('submits a magnet through the same global task store', () async {
      var result = await store.addMagnet(
        uri: 'magnet:?xt=urn:btih:example',
        savePath: r'D:\Downloads',
        displayName: 'Magnet Example',
      );

      expect(result.state, 'metadata');
      expect(gateway.startCalls, 1);
      expect(gateway.addedMagnetName, 'Magnet Example');
      expect(gateway.refreshCalls, 1);
    });

    test('notifies only when a known task enters completed state', () async {
      gateway.emitTasks([_task(state: 'downloading')]);
      gateway.emitTasks([_task(state: 'completed')]);
      gateway.emitTasks([_task(state: 'completed')]);
      await Future<void>.delayed(Duration.zero);

      expect(completedTasks, hasLength(1));
      expect(completedTasks.single.id, 'task');
    });

    test('notifies on file availability but not again after seeding', () async {
      gateway.emitTasks([_task(state: 'downloading')]);
      gateway.emitTasks([_task(state: 'seeding')]);
      gateway.emitTasks([_task(state: 'completed')]);
      await Future<void>.delayed(Duration.zero);

      expect(completedTasks, hasLength(1));
      expect(completedTasks.single.state, 'seeding');
    });

    test('applies settings immediately when the engine is ready', () async {
      gateway.emitState(BtEngineClientState.ready);
      await Future<void>.delayed(Duration.zero);

      await store.configure({'activeDownloads': 3});

      expect(gateway.configured, {'activeDownloads': 3});
    });

    test('reports when settings must wait for the next engine start', () async {
      await expectLater(
        store.configure({'activeDownloads': 3}),
        throwsA(isA<BtEngineClientException>()),
      );

      expect(store.lastError, contains('not ready'));
      expect(gateway.configured, isNull);
    });
  });
}

BtTaskSnapshot _task({required String state}) {
  return BtTaskSnapshot(
    id: 'task',
    state: state,
    sourceKind: 'torrentFile',
    savePath: r'D:\Downloads',
    displayName: 'Example',
    infoHash: 'abc',
    totalBytes: 100,
    downloadedBytes: 50,
    verifiedBytes: 40,
    uploadedBytes: state == 'seeding' ? 25 : 0,
    shareRatio: state == 'seeding' ? 0.25 : 0,
    seedingSeconds: state == 'seeding' ? 30 : 0,
    seedRatioLimit: 2,
    seedTimeLimitMinutes: 60,
    seedStopReason: state == 'completed' ? 'ratio' : null,
    progress: 0.5,
    downloadRate: 10,
    uploadRate: 2,
    peers: 3,
    seeds: 1,
    isPrivate: false,
    lastError: null,
  );
}

class FakeBtEngineGateway implements BtEngineGateway {
  final StreamController<BtEngineEvent> _events = StreamController.broadcast();
  final StreamController<List<BtTaskSnapshot>> _tasks =
      StreamController.broadcast();
  final StreamController<BtEngineClientState> _states =
      StreamController.broadcast();
  BtEngineClientState currentState = BtEngineClientState.stopped;
  List<BtTaskSnapshot> currentTasks = [];
  Future<BtTaskSnapshot>? pauseResult;
  var startCalls = 0;
  var refreshCalls = 0;
  String? removedTaskId;
  bool? removedWithData;
  String? addedDisplayName;
  String? addedMagnetName;
  Map<String, dynamic>? configured;

  @override
  Stream<BtEngineEvent> get events => _events.stream;

  @override
  bool get isReady => currentState == BtEngineClientState.ready;

  @override
  BtEngineClientState get state => currentState;

  @override
  Stream<BtEngineClientState> get states => _states.stream;

  @override
  List<BtTaskSnapshot> get tasks => currentTasks;

  @override
  Stream<List<BtTaskSnapshot>> get taskSnapshots => _tasks.stream;

  void emitState(BtEngineClientState value) {
    currentState = value;
    _states.add(value);
  }

  void emitTasks(List<BtTaskSnapshot> value) {
    currentTasks = value;
    _tasks.add(value);
  }

  @override
  Future<void> start({
    String? executablePath,
    List<String> arguments = const [],
    String? statePath,
    Map<String, dynamic> config = const {},
    Duration readyTimeout = const Duration(seconds: 5),
  }) async {
    startCalls++;
    emitState(BtEngineClientState.ready);
  }

  @override
  Future<void> refreshTasks() async {
    refreshCalls++;
    emitTasks(currentTasks);
  }

  @override
  Future<BtTaskSnapshot> addTorrentFile({
    required String torrentPath,
    required String savePath,
    String? displayName,
    bool start = true,
  }) async {
    addedDisplayName = displayName;
    return _task(state: 'queued');
  }

  @override
  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
    bool start = true,
  }) async {
    addedMagnetName = displayName;
    return _task(state: 'metadata');
  }

  @override
  Future<Map<String, dynamic>> configure(Map<String, dynamic> config) async {
    configured = config;
    return {'config': config};
  }

  @override
  Future<BtTaskSnapshot> pause(String id) {
    return pauseResult ?? Future.value(_task(state: 'paused'));
  }

  @override
  Future<BtTaskSnapshot> recheck(String id) async {
    return _task(state: 'checking');
  }

  @override
  Future<void> remove(String id, {bool deleteData = false}) async {
    removedTaskId = id;
    removedWithData = deleteData;
  }

  @override
  Future<BtTaskSnapshot> resume(String id) async {
    return _task(state: 'queued');
  }

  @override
  Future<BtTaskSnapshot> retry(String id) async {
    return _task(state: 'queued');
  }

  @override
  Future<void> shutdown() async {
    emitState(BtEngineClientState.stopped);
  }

  @override
  Future<Map<String, dynamic>> status() async {
    return {'initialized': isReady};
  }

  Future<void> dispose() async {
    await _events.close();
    await _tasks.close();
    await _states.close();
  }
}
