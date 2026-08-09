import 'dart:async';

import 'package:bangumi_today/core/services/bt_engine_client.dart';
import 'package:bangumi_today/pages/app/download_task_details.dart';
import 'package:bangumi_today/store/bt_download_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
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

  testWidgets('overview tab renders task and torrent sections', (tester) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());

    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('存储路径'), findsOneWidget);
    expect(find.text(r'D:\Downloads'), findsWidgets);
    expect(find.text('Info Hash'), findsOneWidget);
    expect(find.text('abcd'), findsOneWidget);
    expect(find.text('来源类型'), findsOneWidget);
    expect(find.text('Magnet 磁力链接'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pump();

    expect(find.text('种子信息'), findsOneWidget);
    expect(find.text('分片大小'), findsOneWidget);
    expect(find.text('分片数量'), findsOneWidget);
    expect(find.text('Peer 2'), findsOneWidget);
    expect(find.text('文件 2'), findsOneWidget);
    expect(engine.taskPeersCalls, 0);
    expect(engine.taskFilesCalls, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('progress tab renders piece and transfer sections', (
    tester,
  ) async {
    await _pumpDetails(tester, details: _detailsWithSections());

    await tester.tap(find.text('进度'));
    await tester.pump();

    expect(find.text('分片完成情况'), findsOneWidget);
    expect(find.text('传输统计'), findsOneWidget);
    expect(find.text('已下载'), findsOneWidget);
    expect(find.text('已上传'), findsOneWidget);
    expect(find.text('已校验'), findsOneWidget);
    expect(find.text('连接'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('peers tab renders rows and client filter narrows the list', (
    tester,
  ) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());

    await tester.tap(find.textContaining('Peer'));
    await tester.pump();
    await tester.pump();

    expect(find.text('127.0.0.1:6881'), findsOneWidget);
    expect(find.text('qBittorrent'), findsOneWidget);
    expect(find.text('Transmission'), findsOneWidget);
    expect(engine.taskPeersCalls, 1);
    expect(engine.taskFilesCalls, 0);

    await tester.tap(find.text('客户端'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('全部客户端'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(FlyoutListTile),
        matching: find.text('Transmission'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('127.0.0.1:6881'), findsNothing);
    expect(find.text('qBittorrent'), findsNothing);
    expect(find.text('Transmission'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('files tab renders rows and bulk actions apply priorities', (
    tester,
  ) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());

    await tester.tap(find.textContaining('文件'));
    await tester.pump();
    await tester.pump();

    expect(find.text('episode.mkv'), findsOneWidget);
    expect(find.text('subtitle.ass'), findsOneWidget);
    expect(find.text('全部下载'), findsOneWidget);
    expect(find.text('全部跳过'), findsOneWidget);
    expect(engine.taskFilesCalls, 1);
    expect(engine.taskPeersCalls, 0);

    await tester.tap(find.text('全部跳过'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.setFilePrioritiesCalls, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('peer tab fetches peers on demand without requesting files', (
    tester,
  ) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());
    expect(engine.taskDetailsCalls, 1);
    expect(engine.taskPeersCalls, 0);
    expect(engine.taskFilesCalls, 0);
    expect(find.text('Peer 2'), findsOneWidget);
    expect(find.text('文件 2'), findsOneWidget);

    await tester.tap(find.textContaining('Peer'));
    await tester.pump();
    await tester.pump();

    expect(engine.taskPeersCalls, 1);
    expect(engine.taskFilesCalls, 0);
    expect(find.text('127.0.0.1:6881'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tab fetch failure shows retry without breaking the page', (
    tester,
  ) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());
    engine.filesError = const BtEngineClientException('engine unavailable');

    await tester.tap(find.textContaining('文件'));
    await tester.pump();
    await tester.pump();

    expect(find.text('无法加载列表'), findsOneWidget);
    expect(find.text('基本信息'), findsNothing);
    expect(find.text('Peer 2'), findsOneWidget);

    engine.filesError = null;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();

    expect(find.text('episode.mkv'), findsOneWidget);

    // 消化按钮 hover 定时器后再销毁页面。
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tab bar switches with arrow keys and enter', (tester) async {
    await _pumpDetails(tester, details: _detailsWithSections());
    expect(find.text('基本信息'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    expect(find.text('分片完成情况'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    expect(find.text('127.0.0.1:6881'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('分片完成情况'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('分片完成情况'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('escape returns to the overview tab', (tester) async {
    await _pumpDetails(tester, details: _detailsWithSections());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();
    expect(find.text('127.0.0.1:6881'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('基本信息'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

Future<FakeDetailsEngine> _pumpDetails(
  WidgetTester tester, {
  BtTaskDetails? details,
}) async {
  var engine = FakeDetailsEngine()
    ..currentState = BtEngineClientState.ready
    ..currentTasks = [_task()]
    ..details = details;
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
    totalFiles: 0,
    peers: const [],
    peersTruncated: false,
    totalPeers: 0,
  );
}

BtTaskDetails _detailsWithSections() {
  return BtTaskDetails(
    task: _task(),
    pieceLength: 16384,
    pieceCount: 2,
    completedPieces: '10',
    files: [
      BtTaskFileDetail(path: 'episode.mkv', size: 100, completedBytes: 50),
      BtTaskFileDetail(path: 'subtitle.ass', size: 10, completedBytes: 10),
    ],
    filesTruncated: false,
    totalFiles: 2,
    peers: [
      BtTaskPeerDetail(
        endpoint: '127.0.0.1:6881',
        client: 'qBittorrent 4.4.5',
        progress: 0.75,
        downloadRate: 1024,
        uploadRate: 0,
      ),
      BtTaskPeerDetail(
        endpoint: '192.168.1.10:51413',
        client: 'Transmission 2.94',
        progress: 0.25,
        downloadRate: 128,
        uploadRate: 32,
      ),
    ],
    peersTruncated: false,
    totalPeers: 2,
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
  BtTaskDetails? details;
  int taskDetailsCalls = 0;
  int taskFilesCalls = 0;
  int taskPeersCalls = 0;
  int setFilePrioritiesCalls = 0;
  Object? filesError;
  Object? peersError;
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
    var value = details ?? _details();
    return BtTaskDetails(
      task: value.task,
      pieceLength: value.pieceLength,
      pieceCount: value.pieceCount,
      completedPieces: value.completedPieces,
      files: const [],
      filesTruncated: false,
      totalFiles: value.files.length,
      peers: const [],
      peersTruncated: false,
      totalPeers: value.peers.length,
    );
  }

  @override
  Future<BtTaskFilesResult> taskFiles(
    String id, {
    int offset = 0,
    int? limit,
  }) async {
    taskFilesCalls++;
    if (filesError != null) throw filesError!;
    var value = details ?? _details();
    var files = value.files;
    var end = (offset + (limit ?? files.length)).clamp(0, files.length);
    return BtTaskFilesResult(
      files: offset < end ? files.sublist(offset, end) : const [],
      truncated: false,
      totalFiles: files.length,
      offset: offset,
      nextOffset: null,
    );
  }

  @override
  Future<BtTaskPeersResult> taskPeers(
    String id, {
    int offset = 0,
    int? limit,
  }) async {
    taskPeersCalls++;
    if (peersError != null) throw peersError!;
    var value = details ?? _details();
    var peers = value.peers;
    var end = (offset + (limit ?? peers.length)).clamp(0, peers.length);
    return BtTaskPeersResult(
      peers: offset < end ? peers.sublist(offset, end) : const [],
      truncated: false,
      totalPeers: peers.length,
      offset: offset,
      nextOffset: null,
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
    emitState(BtEngineClientState.ready);
  }

  @override
  Future<void> refreshTasks() async {}

  @override
  Future<List<int>> setFilePriorities(
    String id,
    Map<int, int> priorities,
  ) async {
    setFilePrioritiesCalls++;
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
