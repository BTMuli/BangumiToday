import 'dart:async';

import 'package:bangumi_today/core/services/bt_engine_client.dart';
import 'package:bangumi_today/pages/app/download_task_details.dart';
import 'package:bangumi_today/store/bt_download_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dispose stops detail polling', (tester) async {
    var engine = await _pumpDetails(tester);
    expect(engine.taskDetailsCalls, 1);

    await tester.pump(const Duration(seconds: 2));
    expect(engine.taskDetailsCalls, 2);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(engine.taskDetailsCalls, 2);
  });

  testWidgets('engine stop pauses detail polling', (tester) async {
    var engine = await _pumpDetails(tester);
    expect(engine.taskDetailsCalls, 1);

    engine.emitState(BtEngineClientState.stopped);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(engine.taskDetailsCalls, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background pauses polling and resume refreshes once', (
    tester,
  ) async {
    var engine = await _pumpDetails(tester);
    expect(engine.taskDetailsCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(engine.taskDetailsCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(engine.taskDetailsCalls, 2);

    await tester.pump(const Duration(seconds: 2));
    expect(engine.taskDetailsCalls, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'tab switch refreshes once and does not duplicate an in-flight request',
    (tester) async {
      var engine = await _pumpDetails(tester);
      expect(engine.taskDetailsCalls, 1);

      var completer = Completer<BtTaskDetails>();
      engine.nextDetailsCompleter = completer;

      await tester.tap(find.textContaining('Peer'));
      await tester.pump();
      expect(engine.taskDetailsCalls, 2);

      // 在途请求未完成时再切 Tab：single-flight 去重，不发起新请求。
      await tester.tap(find.textContaining('文件'));
      await tester.pump();
      expect(engine.taskDetailsCalls, 2);

      completer.complete(_details());
      engine.nextDetailsCompleter = null;
      await tester.pump();

      // 请求完成后再次切换 Peer Tab，允许一次新的刷新。
      await tester.tap(find.textContaining('Peer'));
      await tester.pump();
      expect(engine.taskDetailsCalls, 3);

      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<FakeDetailsEngine> _pumpDetails(WidgetTester tester) async {
  var engine = FakeDetailsEngine()
    ..currentState = BtEngineClientState.ready
    ..currentTasks = [_task()];
  var store = BtDownloadStore(client: engine);
  addTearDown(() {
    engine.dispose();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [btDownloadStoreProvider.overrideWith((ref) => store)],
      child: FluentApp(
        home: Scaffold(
          body: SizedBox(
            width: 760,
            height: 640,
            child: DownloadTaskDetails(taskId: 'task-1', initialTask: _task()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return engine;
}

BtTaskSnapshot _task({String state = 'downloading'}) {
  return BtTaskSnapshot(
    id: 'task-1',
    state: state,
    sourceKind: 'magnet',
    savePath: r'D:\Downloads',
    displayName: 'Example',
    infoHash: 'abcd',
    totalBytes: 100,
    downloadedBytes: 10,
    verifiedBytes: 10,
    uploadedBytes: 0,
    shareRatio: 0,
    seedingSeconds: 0,
    seedRatioLimit: 2,
    seedTimeLimitMinutes: 60,
    seedStopReason: null,
    progress: 0.1,
    downloadRate: 10,
    uploadRate: 2,
    peers: 1,
    seeds: 0,
    isPrivate: false,
    lastError: null,
  );
}

BtTaskDetails _details() {
  return BtTaskDetails(
    task: _task(),
    pieceLength: 16,
    pieceCount: 2,
    completedPieces: '10',
    files: const [],
    filesTruncated: false,
    peers: const [],
    peersTruncated: false,
  );
}

class FakeDetailsEngine implements BtEngineGateway {
  final StreamController<BtEngineEvent> _events =
      StreamController<BtEngineEvent>.broadcast();
  final StreamController<List<BtTaskSnapshot>> _tasks =
      StreamController<List<BtTaskSnapshot>>.broadcast();
  final StreamController<BtEngineClientState> _states =
      StreamController<BtEngineClientState>.broadcast();

  BtEngineClientState currentState = BtEngineClientState.stopped;
  List<BtTaskSnapshot> currentTasks = [];
  int taskDetailsCalls = 0;
  Completer<BtTaskDetails>? nextDetailsCompleter;

  void emitState(BtEngineClientState value) {
    currentState = value;
    _states.add(value);
  }

  void dispose() {
    _events.close();
    _tasks.close();
    _states.close();
  }

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

  @override
  Future<BtTaskDetails> taskDetails(String id) async {
    taskDetailsCalls++;
    if (nextDetailsCompleter != null) return nextDetailsCompleter!.future;
    return _details();
  }

  @override
  Future<void> start({
    String? executablePath,
    List<String> arguments = const [],
    String? statePath,
    Map<String, dynamic> config = const {},
    Duration readyTimeout = const Duration(seconds: 5),
  }) async {
    emitState(BtEngineClientState.ready);
  }

  @override
  Future<void> refreshTasks() async {}

  @override
  Future<List<int>> setFilePriorities(
    String id,
    Map<int, int> priorities,
  ) async {
    return const [];
  }

  @override
  Future<Map<String, dynamic>> status() async => const {};

  @override
  Future<Map<String, dynamic>> configure(Map<String, dynamic> config) async =>
      const {};

  @override
  Future<BtTaskSnapshot> addTorrentFile({
    required String torrentPath,
    required String savePath,
    String? displayName,
    bool start = true,
  }) async {
    return _task();
  }

  @override
  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
    bool start = true,
  }) async {
    return _task(state: 'metadata');
  }

  @override
  Future<BtTaskSnapshot> pause(String id) async => _task();

  @override
  Future<BtTaskSnapshot> resume(String id) async => _task();

  @override
  Future<BtTaskSnapshot> retry(String id) async => _task();

  @override
  Future<BtTaskSnapshot> recheck(String id) async => _task();

  @override
  Future<void> remove(String id, {bool deleteData = false}) async {}

  @override
  Future<void> shutdown() async {}
}
