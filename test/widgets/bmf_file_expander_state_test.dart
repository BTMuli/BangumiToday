// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart' show Scaffold;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'package:bangumi_today/core/services/bt_engine_client.dart';
import 'package:bangumi_today/store/bt_download_store.dart';
import 'package:bangumi_today/widgets/bangumi/subject_detail/bmf_expander.dart';

void main() {
  late Directory tempDir;
  late _FakeGateway gateway;
  late BtDownloadStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bmf_state_test');
    gateway = _FakeGateway();
  });

  tearDown(() async {
    await gateway.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  BtDownloadStore createStore() {
    store = BtDownloadStore(client: gateway, completionNotifier: (_) async {});
    return store;
  }

  Widget wrap(String dir) {
    return ProviderScope(
      overrides: [btDownloadStoreProvider.overrideWith((ref) => store)],
      child: FluentApp(
        home: Scaffold(
          body: BmfFileExpander(downloadDir: dir, subject: 1, maxHeight: 300),
        ),
      ),
    );
  }

  Future<void> pumpForRealAsync(
    WidgetTester tester,
    Widget widget, {
    Duration settle = const Duration(milliseconds: 250),
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(settle);
      await tester.pump(const Duration(milliseconds: 100));
    });
  }

  Future<void> settle(
    WidgetTester tester, {
    Duration settle = const Duration(milliseconds: 250),
  }) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(settle);
      }
      await tester.pump(const Duration(milliseconds: 100));
    });
  }

  testWidgets('marks engine downloading file and hides open action', (
    tester,
  ) async {
    var fileName = '[Sub] Anime - 01.mkv';
    File(
      path.join(tempDir.path, fileName),
    ).writeAsBytesSync(List.filled(100, 0));
    gateway.currentTasks = [
      _task(savePath: tempDir.path, state: 'downloading', progress: 0.1),
    ];
    gateway.fileResults['task'] = const BtTaskFilesResult(
      files: [
        BtTaskFileDetail(
          path: '[Sub] Anime - 01.mkv',
          size: 1000,
          completedBytes: 100,
        ),
      ],
      truncated: false,
      totalFiles: 1,
      offset: 0,
    );
    createStore();

    await pumpForRealAsync(tester, wrap(tempDir.path));

    expect(find.text(fileName), findsOneWidget);
    expect(find.text('下载中'), findsOneWidget);
    expect(find.text('1 个下载中'), findsOneWidget);
    expect(find.byIcon(FluentIcons.open_file), findsNothing);
    var progressBar = tester.widget<ProgressBar>(find.byType(ProgressBar));
    expect(progressBar.value, closeTo(0.1, 0.001));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('restores open action after task completes', (tester) async {
    var fileName = '[Sub] Anime - 01.mkv';
    File(
      path.join(tempDir.path, fileName),
    ).writeAsBytesSync(List.filled(100, 0));
    gateway.currentTasks = [
      _task(savePath: tempDir.path, state: 'downloading'),
    ];
    gateway.fileResults['task'] = const BtTaskFilesResult(
      files: [
        BtTaskFileDetail(
          path: '[Sub] Anime - 01.mkv',
          size: 1000,
          completedBytes: 100,
        ),
      ],
      truncated: false,
      totalFiles: 1,
      offset: 0,
    );
    createStore();

    await pumpForRealAsync(tester, wrap(tempDir.path));
    expect(find.byIcon(FluentIcons.open_file), findsNothing);

    gateway.emitTasks([_task(savePath: tempDir.path, state: 'completed')]);
    await settle(tester);

    expect(find.text('下载中'), findsNothing);
    expect(find.byIcon(FluentIcons.open_file), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows paused and failed labels without open action', (
    tester,
  ) async {
    var fileName = '[Sub] Anime - 01.mkv';
    File(
      path.join(tempDir.path, fileName),
    ).writeAsBytesSync(List.filled(100, 0));
    gateway.currentTasks = [_task(savePath: tempDir.path, state: 'paused')];
    gateway.fileResults['task'] = const BtTaskFilesResult(
      files: [
        BtTaskFileDetail(
          path: '[Sub] Anime - 01.mkv',
          size: 1000,
          completedBytes: 400,
        ),
      ],
      truncated: false,
      totalFiles: 1,
      offset: 0,
    );
    createStore();

    await pumpForRealAsync(tester, wrap(tempDir.path));
    expect(find.text('已暂停'), findsOneWidget);
    expect(find.byIcon(FluentIcons.open_file), findsNothing);

    gateway.emitTasks([_task(savePath: tempDir.path, state: 'error')]);
    await settle(tester);

    expect(find.text('下载失败'), findsOneWidget);
    expect(find.byIcon(FluentIcons.open_file), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keeps aria2 fallback downloading state', (tester) async {
    var fileName = '[Sub] Anime - 02.mkv';
    File(
      path.join(tempDir.path, fileName),
    ).writeAsBytesSync(List.filled(100, 0));
    File(
      path.join(tempDir.path, '$fileName.aria2'),
    ).writeAsBytesSync(List.filled(10, 0));
    createStore();

    await pumpForRealAsync(tester, wrap(tempDir.path));

    expect(find.text(fileName), findsOneWidget);
    expect(find.text('下载中'), findsOneWidget);
    expect(find.text('1 个下载中'), findsOneWidget);
    expect(find.byIcon(FluentIcons.open_file), findsNothing);
    var progressBar = tester.widget<ProgressBar>(find.byType(ProgressBar));
    expect(progressBar.value, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('refreshes file progress from engine snapshots', (tester) async {
    var fileName = '[Sub] Anime - 01.mkv';
    File(
      path.join(tempDir.path, fileName),
    ).writeAsBytesSync(List.filled(100, 0));
    gateway.currentTasks = [
      _task(savePath: tempDir.path, state: 'downloading', progress: 0.1),
    ];
    gateway.fileResults['task'] = const BtTaskFilesResult(
      files: [
        BtTaskFileDetail(
          path: '[Sub] Anime - 01.mkv',
          size: 1000,
          completedBytes: 100,
        ),
      ],
      truncated: false,
      totalFiles: 1,
      offset: 0,
    );
    createStore();

    await pumpForRealAsync(tester, wrap(tempDir.path));
    expect(
      tester.widget<ProgressBar>(find.byType(ProgressBar)).value,
      closeTo(0.1, 0.001),
    );

    gateway.fileResults['task'] = const BtTaskFilesResult(
      files: [
        BtTaskFileDetail(
          path: '[Sub] Anime - 01.mkv',
          size: 1000,
          completedBytes: 500,
        ),
      ],
      truncated: false,
      totalFiles: 1,
      offset: 0,
    );
    gateway.emitTasks([
      _task(savePath: tempDir.path, state: 'downloading', progress: 0.5),
    ]);
    await settle(tester);

    expect(
      tester.widget<ProgressBar>(find.byType(ProgressBar)).value,
      closeTo(0.5, 0.001),
    );

    await tester.pumpWidget(const SizedBox());
  });
}

BtTaskSnapshot _task({
  required String savePath,
  required String state,
  double progress = 0,
}) {
  return BtTaskSnapshot(
    id: 'task',
    state: state,
    sourceKind: 'torrentFile',
    savePath: savePath,
    displayName: '[Sub] Anime - 01.mkv',
    infoHash: 'abc',
    totalBytes: 1000,
    downloadedBytes: 500,
    verifiedBytes: 0,
    uploadedBytes: 0,
    shareRatio: 0,
    seedingSeconds: 0,
    seedRatioLimit: 2,
    seedTimeLimitMinutes: 60,
    seedStopReason: null,
    progress: progress,
    downloadRate: 10,
    uploadRate: 0,
    peers: 1,
    seeds: 0,
    isPrivate: false,
    lastError: null,
  );
}

class _FakeGateway implements BtEngineGateway {
  final StreamController<BtEngineEvent> _events = StreamController.broadcast();
  final StreamController<List<BtTaskSnapshot>> _tasks =
      StreamController.broadcast();
  final StreamController<BtEngineClientState> _states =
      StreamController.broadcast();
  BtEngineClientState currentState = BtEngineClientState.stopped;
  List<BtTaskSnapshot> currentTasks = [];
  Map<String, BtTaskFilesResult> fileResults = {};

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
    emitState(BtEngineClientState.ready);
  }

  @override
  Future<void> refreshTasks() async {
    emitTasks(currentTasks);
  }

  @override
  Future<BtTaskDetails> taskDetails(String id) async {
    return BtTaskDetails(
      task: _task(savePath: '', state: 'downloading'),
      pieceLength: 16,
      pieceCount: 1,
      completedPieces: '',
      files: const [],
      filesTruncated: false,
      totalFiles: 0,
      peers: const [],
      peersTruncated: false,
      totalPeers: 0,
    );
  }

  @override
  Future<BtTaskFilesResult> taskFiles(
    String id, {
    int offset = 0,
    int? limit,
  }) async {
    return fileResults[id] ??
        const BtTaskFilesResult(
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
    return _task(savePath: savePath, state: 'queued');
  }

  @override
  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
    bool start = true,
  }) async {
    return _task(savePath: savePath, state: 'metadata');
  }

  @override
  Future<Map<String, dynamic>> configure(Map<String, dynamic> config) async {
    return {'config': config};
  }

  @override
  Future<BtTaskSnapshot> pause(String id) async {
    return _task(savePath: '', state: 'paused');
  }

  @override
  Future<BtTaskSnapshot> recheck(String id) async {
    return _task(savePath: '', state: 'checking');
  }

  @override
  Future<void> remove(String id, {bool deleteData = false}) async {}

  @override
  Future<BtTaskSnapshot> resume(String id) async {
    return _task(savePath: '', state: 'queued');
  }

  @override
  Future<BtTaskSnapshot> retry(String id) async {
    return _task(savePath: '', state: 'queued');
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
