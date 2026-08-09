import 'dart:async';

import 'package:bangumi_today/core/services/bt_engine_client.dart';
import 'package:bangumi_today/pages/app/download_page.dart';
import 'package:bangumi_today/store/bt_download_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders active tasks with card details', (tester) async {
    await _pumpPage(
      tester,
      tasks: [
        _task(id: 'a', state: 'downloading', displayName: 'Task A'),
        _task(id: 'b', state: 'paused', displayName: 'Task B'),
      ],
    );

    expect(find.text('下载管理'), findsOneWidget);
    expect(find.text('进行中 2'), findsOneWidget);
    expect(find.text('已停止 0'), findsOneWidget);
    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Task B'), findsOneWidget);
    expect(find.text('下载中'), findsOneWidget);
    expect(find.text('已暂停'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tab switch filters stopped tasks', (tester) async {
    await _pumpPage(
      tester,
      tasks: [
        _task(id: 'a', state: 'downloading', displayName: 'Task A'),
        _task(id: 'b', state: 'completed', displayName: 'Task B'),
      ],
    );

    await tester.tap(find.text('已停止 1'));
    await tester.pump();

    expect(find.text('Task B'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('Task A'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('selection mode selects all and batch deletes', (tester) async {
    var engine = await _pumpPage(
      tester,
      tasks: [
        _task(id: 'a', state: 'downloading', displayName: 'Task A'),
        _task(id: 'b', state: 'paused', displayName: 'Task B'),
      ],
    );

    await tester.tap(find.byIcon(FluentIcons.check_list));
    await tester.pump();
    expect(find.byIcon(FluentIcons.select_all), findsOneWidget);

    await tester.tap(find.byIcon(FluentIcons.select_all));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(FluentIcons.delete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('批量删除所选任务？'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(engine.removeCalls, ['a', 'b']);
    expect(engine.pauseCalls, ['a']);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows empty states per tab', (tester) async {
    await _pumpPage(
      tester,
      tasks: [],
      engineState: BtEngineClientState.stopped,
    );

    expect(find.text('暂无下载任务'), findsOneWidget);
    expect(find.text('下载引擎未开启，点击右上角引擎状态开启'), findsOneWidget);

    await tester.tap(find.text('已停止 0'));
    await tester.pump();
    expect(find.text('暂无已停止任务'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pause action calls the store', (tester) async {
    var engine = await _pumpPage(
      tester,
      tasks: [_task(id: 'a', state: 'downloading', displayName: 'Task A')],
    );

    await tester.tap(find.byIcon(FluentIcons.pause));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(engine.pauseCalls, ['a']);

    await tester.pumpWidget(const SizedBox());
  });
}

Future<FakePageEngine> _pumpPage(
  WidgetTester tester, {
  required List<BtTaskSnapshot> tasks,
  BtEngineClientState engineState = BtEngineClientState.ready,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  var engine = FakePageEngine()
    ..currentState = engineState
    ..currentTasks = tasks;
  var store = BtDownloadStore(client: engine);
  addTearDown(engine.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [btDownloadStoreProvider.overrideWith((ref) => store)],
      child: const FluentApp(home: DownloadPage()),
    ),
  );
  await tester.pump();
  return engine;
}

BtTaskSnapshot _task({
  required String id,
  required String state,
  required String displayName,
}) {
  return BtTaskSnapshot(
    id: id,
    state: state,
    sourceKind: 'magnet',
    savePath: r'D:\Downloads',
    displayName: displayName,
    infoHash: 'abcd',
    totalBytes: 100,
    downloadedBytes: state == 'completed' ? 100 : 10,
    verifiedBytes: state == 'completed' ? 100 : 10,
    uploadedBytes: 0,
    shareRatio: 0,
    seedingSeconds: 0,
    seedRatioLimit: 2,
    seedTimeLimitMinutes: 60,
    seedStopReason: null,
    progress: state == 'completed' ? 1 : 0.1,
    downloadRate: state == 'downloading' ? 10 : 0,
    uploadRate: 2,
    peers: 1,
    seeds: 0,
    isPrivate: false,
    lastError: null,
  );
}

class FakePageEngine implements BtEngineGateway {
  final _events = StreamController<BtEngineEvent>.broadcast();
  final _tasks = StreamController<List<BtTaskSnapshot>>.broadcast();
  final _states = StreamController<BtEngineClientState>.broadcast();

  BtEngineClientState currentState = BtEngineClientState.stopped;
  List<BtTaskSnapshot> currentTasks = [];
  List<String> pauseCalls = [];
  List<String> removeCalls = [];

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
  Future<BtTaskDetails> taskDetails(String id) async => BtTaskDetails(
    task: currentTasks.firstWhere((task) => task.id == id),
    pieceLength: 16,
    pieceCount: 2,
    completedPieces: '10',
    files: const [],
    filesTruncated: false,
    totalFiles: 0,
    peers: const [],
    peersTruncated: false,
    totalPeers: 0,
  );

  @override
  Future<BtTaskFilesResult> taskFiles(
    String id, {
    int offset = 0,
    int? limit,
  }) async {
    return const BtTaskFilesResult(
      files: [],
      truncated: false,
      totalFiles: 0,
      offset: 0,
    );
  }

  @override
  Future<BtTaskPeersResult> taskPeers(
    String id, {
    int offset = 0,
    int? limit,
  }) async {
    return const BtTaskPeersResult(
      peers: [],
      truncated: false,
      totalPeers: 0,
      offset: 0,
    );
  }

  @override
  Future<void> start({
    String? executablePath,
    List<String> arguments = const [],
    String? statePath,
    Map<String, dynamic> config = const {},
    Duration readyTimeout = const Duration(seconds: 5),
  }) async {
    currentState = BtEngineClientState.ready;
    _states.add(currentState);
  }

  @override
  Future<void> refreshTasks() async {
    _tasks.add(List.of(currentTasks));
  }

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
    return currentTasks.first;
  }

  @override
  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
    bool start = true,
  }) async {
    return currentTasks.first;
  }

  @override
  Future<BtTaskSnapshot> pause(String id) async {
    pauseCalls.add(id);
    return _replaceState(id, 'paused');
  }

  @override
  Future<BtTaskSnapshot> resume(String id) async {
    return _replaceState(id, 'downloading');
  }

  @override
  Future<BtTaskSnapshot> retry(String id) async {
    return _replaceState(id, 'downloading');
  }

  @override
  Future<BtTaskSnapshot> recheck(String id) async {
    return _replaceState(id, 'checking');
  }

  @override
  Future<void> remove(String id, {bool deleteData = false}) async {
    removeCalls.add(id);
    currentTasks = currentTasks.where((task) => task.id != id).toList();
    _tasks.add(List.of(currentTasks));
  }

  BtTaskSnapshot _replaceState(String id, String state) {
    var updated = [
      for (var task in currentTasks)
        if (task.id == id)
          _task(id: id, state: state, displayName: task.displayName)
        else
          task,
    ];
    currentTasks = updated;
    _tasks.add(List.of(currentTasks));
    return currentTasks.firstWhere((task) => task.id == id);
  }

  @override
  Future<void> shutdown() async {}
}
