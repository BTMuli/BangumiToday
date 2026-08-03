import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi_today/core/services/bt_engine_client.dart';
import 'package:bangumi_today/models/app/bt_download_config.dart';
import 'package:bangumi_today/store/bt_download_store.dart';

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
      expect(store.totalDownloadRate, 10);
      expect(store.totalUploadRate, 2);
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
        expect(gateway.removedTaskIds, ['task']);
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

    test('enableEngine starts the engine, persists the flag and registers the '
        'firewall rule', () async {
      var written = <BtDownloadConfig?>[];
      var firewallCalls = 0;
      var switchStore = BtDownloadStore(
        client: gateway,
        completionNotifier: (task) async {},
        readConfig: () async => const BtDownloadConfig(engineEnabled: false),
        writeConfig: (config) async => written.add(config),
        registerFirewallRule: () async => firewallCalls++,
      );
      addTearDown(switchStore.dispose);

      var warning = await switchStore.enableEngine();

      expect(warning, isNull);
      expect(gateway.startCalls, 1);
      expect(written.single?.engineEnabled, isTrue);
      expect(firewallCalls, 1);
    });

    test('enableEngine does not restart an already running engine', () async {
      var firewallCalls = 0;
      gateway.emitState(BtEngineClientState.ready);
      await Future<void>.delayed(Duration.zero);
      var switchStore = BtDownloadStore(
        client: gateway,
        completionNotifier: (task) async {},
        writeConfig: (config) async {},
        registerFirewallRule: () async => firewallCalls++,
      );
      addTearDown(switchStore.dispose);

      var warning = await switchStore.enableEngine();

      expect(warning, isNull);
      expect(gateway.startCalls, 0);
      expect(firewallCalls, 1);
    });

    test('enableEngine reports firewall registration failure as a warning',
        () async {
      var switchStore = BtDownloadStore(
        client: gateway,
        completionNotifier: (task) async {},
        writeConfig: (config) async {},
        registerFirewallRule: () async => throw Exception('elevation canceled'),
      );
      addTearDown(switchStore.dispose);

      var warning = await switchStore.enableEngine();

      expect(warning, contains('防火墙规则注册失败'));
      expect(gateway.startCalls, 1);
    });

    test('disableEngine persists the disabled flag and shuts the engine down',
        () async {
      var written = <BtDownloadConfig?>[];
      gateway.emitState(BtEngineClientState.ready);
      await Future<void>.delayed(Duration.zero);
      var switchStore = BtDownloadStore(
        client: gateway,
        completionNotifier: (task) async {},
        writeConfig: (config) async => written.add(config),
      );
      addTearDown(switchStore.dispose);

      await switchStore.disableEngine();

      expect(written.single?.engineEnabled, isFalse);
      expect(gateway.shutdownCalls, 1);
    });

    test('refresh refuses to auto-start a disabled engine', () async {
      var switchStore = BtDownloadStore(
        client: gateway,
        completionNotifier: (task) async {},
        readConfig: () async => const BtDownloadConfig(engineEnabled: false),
        writeConfig: (config) async {},
        registerFirewallRule: () async {},
      );
      addTearDown(switchStore.dispose);

      await expectLater(
        switchStore.refresh(),
        throwsA(isA<BtEngineClientException>()),
      );
      expect(gateway.startCalls, 0);
      expect(switchStore.lastError, contains('未开启'));
    });

    test('adding a task refuses to auto-start a disabled engine', () async {
      var switchStore = BtDownloadStore(
        client: gateway,
        completionNotifier: (task) async {},
        readConfig: () async => const BtDownloadConfig(engineEnabled: false),
        writeConfig: (config) async {},
        registerFirewallRule: () async {},
      );
      addTearDown(switchStore.dispose);

      await expectLater(
        switchStore.addMagnet(
          uri: 'magnet:?xt=urn:btih:example',
          savePath: r'D:\Downloads',
        ),
        throwsA(isA<BtEngineClientException>()),
      );
      expect(gateway.startCalls, 0);
    });

    test(
      'sorts active tasks by downloading > queued > seeding > error',
      () async {
        gateway.emitTasks([
          _task(id: 'h', state: 'completed'),
          _task(id: 'f', state: 'error'),
          _task(id: 'e', state: 'metadata'),
          _task(id: 'b', state: 'seeding'),
          _task(id: 'g', state: 'paused'),
          _task(id: 'c', state: 'queued'),
          _task(id: 'd', state: 'checking'),
          _task(id: 'a', state: 'downloading'),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(store.activeTasks.map((task) => task.id).toList(), [
          'e',
          'd',
          'a',
          'c',
          'b',
          'f',
        ]);
        expect(store.stoppedTasks.map((task) => task.id).toList(), ['h', 'g']);
      },
    );

    test('keeps engine order inside the same group', () async {
      gateway.emitTasks([
        _task(id: 'd1', state: 'downloading'),
        _task(id: 'd2', state: 'downloading'),
        _task(id: 'q1', state: 'queued'),
        _task(id: 'q2', state: 'queued'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(store.activeTasks.map((task) => task.id).toList(), [
        'd1',
        'd2',
        'q1',
        'q2',
      ]);
    });

    test('batch remove pauses active tasks and preserves data', () async {
      gateway.emitTasks([
        _task(id: 'down', state: 'downloading'),
        _task(id: 'seed', state: 'seeding'),
        _task(id: 'done', state: 'completed'),
      ]);
      await Future<void>.delayed(Duration.zero);

      await store.removeAll(['down', 'seed', 'done']);

      expect(gateway.pausedIds, containsAll(['down', 'seed']));
      expect(gateway.pausedIds, isNot(contains('done')));
      expect(gateway.removedTaskIds, ['down', 'seed', 'done']);
      expect(gateway.removedWithData, isFalse);
      expect(store.isTaskBusy('down'), isFalse);
    });

    test('batch remove reports busy state while running', () async {
      var removeCompleter = Completer<void>();
      gateway.removeResult = removeCompleter;
      gateway.emitTasks([_task(id: 'task', state: 'downloading')]);
      await Future<void>.delayed(Duration.zero);

      var removal = store.removeAll(['task']);
      expect(store.isTaskBusy('task'), isTrue);
      removeCompleter.complete();
      await removal;
      expect(store.isTaskBusy('task'), isFalse);
    });
  });
}

BtTaskSnapshot _task({String? id, required String state}) {
  return BtTaskSnapshot(
    id: id ?? 'task',
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
  final List<String> removedTaskIds = [];
  final List<String> pausedIds = [];
  Completer<void>? removeResult;
  bool? removedWithData;
  String? addedDisplayName;
  String? addedMagnetName;
  Map<String, dynamic>? configured;
  var shutdownCalls = 0;

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
  Future<BtTaskDetails> taskDetails(String id) async {
    return BtTaskDetails(
      task: _task(state: 'downloading'),
      pieceLength: 16,
      pieceCount: 2,
      completedPieces: '10',
      files: const [],
      filesTruncated: false,
      peers: const [],
      peersTruncated: false,
    );
  }

  @override
  Future<List<int>> setFilePriorities(
    String id,
    Map<int, int> priorities,
  ) async {
    return const [];
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
    pausedIds.add(id);
    return pauseResult ?? Future.value(_task(state: 'paused'));
  }

  @override
  Future<BtTaskSnapshot> recheck(String id) async {
    return _task(state: 'checking');
  }

  @override
  Future<void> remove(String id, {bool deleteData = false}) async {
    removedTaskIds.add(id);
    removedWithData = deleteData;
    if (removeResult != null) await removeResult!.future;
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
    shutdownCalls++;
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
