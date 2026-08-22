// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart' show LogicalKeyboardKey;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bt_engine_client.dart';
import 'package:bangumi_today/pages/app/download_task_details.dart';
import 'package:bangumi_today/store/bt_download_store.dart';

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

  testWidgets('peer tab fetches immediately even when details are in flight', (
    tester,
  ) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());
    expect(engine.taskDetailsCalls, 1);
    expect(engine.taskPeersCalls, 0);

    var completer = Completer<BtTaskDetails>();
    engine.nextDetailsCompleter = completer;

    await tester.tap(find.text('进度'));
    await tester.pump();
    expect(engine.taskDetailsCalls, 2);
    expect(engine.taskPeersCalls, 0);

    await tester.tap(find.text('Peer 2'));
    await tester.pump();
    await tester.pump();

    expect(engine.taskPeersCalls, 1);
    expect(find.text('127.0.0.1:6881'), findsOneWidget);
    expect(find.text('分片完成情况'), findsNothing);

    completer.complete(_detailsWithSections());
    engine.nextDetailsCompleter = null;
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'progress tab fetches immediately even when peers are in flight',
    (tester) async {
      var engine = await _pumpDetails(tester, details: _detailsWithSections());
      var completer = Completer<BtTaskPeersResult>();
      engine.nextPeersCompleter = completer;

      await tester.tap(find.textContaining('Peer'));
      await tester.pump();
      expect(engine.taskPeersCalls, 1);
      expect(engine.taskDetailsCalls, 1);

      await tester.tap(find.text('进度'));
      await tester.pump();
      expect(engine.taskDetailsCalls, 2);
      expect(find.text('分片完成情况'), findsOneWidget);

      completer.complete(_peerPage());
      engine.nextPeersCompleter = null;
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('peer tab does not duplicate an in-flight peer request', (
    tester,
  ) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());
    var completer = Completer<BtTaskPeersResult>();
    engine.nextPeersCompleter = completer;

    await tester.tap(find.textContaining('Peer'));
    await tester.pump();
    expect(engine.taskPeersCalls, 1);

    await tester.tap(find.text('进度'));
    await tester.pump();
    await tester.tap(find.text('Peer 2'));
    await tester.pump();
    expect(engine.taskPeersCalls, 1);

    completer.complete(_peerPage());
    engine.nextPeersCompleter = null;
    await tester.pump();
    expect(find.text('127.0.0.1:6881'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('peer tab polling does not wait on task.details', (tester) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());
    await tester.tap(find.textContaining('Peer'));
    await tester.pump();
    await tester.pump();
    expect(engine.taskPeersCalls, 1);
    var detailsCalls = engine.taskDetailsCalls;

    await tester.pump(const Duration(seconds: 2));
    expect(engine.taskPeersCalls, 2);
    expect(engine.taskDetailsCalls, detailsCalls);

    await tester.pumpWidget(const SizedBox());
  });

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

  testWidgets('HTTP progress tab renders byte-range pieces', (tester) async {
    await _pumpDetails(tester, details: _httpDetails());

    await tester.tap(find.text('进度'));
    await tester.pump();

    expect(find.text('分片完成情况'), findsOneWidget);
    expect(find.textContaining('2 / 4'), findsOneWidget);
    expect(find.textContaining('HTTP 分片按字节区间展示传输进度'), findsOneWidget);
    expect(find.text('HTTP 连接'), findsOneWidget);
    expect(find.text('3 条'), findsOneWidget);
    expect(find.text('已上传'), findsNothing);
    expect(find.text('已校验'), findsNothing);
    expect(find.text('连接'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('file tab uses content count before loading file list', (
    tester,
  ) async {
    var engine = await _pumpDetails(
      tester,
      details: _detailsWithSections(includePadding: true),
    );

    expect(find.text('文件 2'), findsOneWidget);
    expect(engine.taskFilesCalls, 0);

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

  testWidgets('files tab sorts progress and keeps original file indices', (
    tester,
  ) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());

    await tester.tap(find.textContaining('文件'));
    await tester.pump();
    await tester.pump();

    var progressHeader = find.text('进度').last;
    await tester.tap(progressHeader);
    await tester.pump();
    await tester.tap(progressHeader);
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('subtitle.ass')).dy,
      lessThan(tester.getTopLeft(find.text('episode.mkv')).dy),
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.lastPriorities, {1: 0});

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('files tab shows selected count separately from metadata count', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      details: _detailsWithSections(subtitlePriority: 0),
    );

    await tester.tap(find.textContaining('文件'));
    await tester.pump();
    await tester.pump();

    expect(find.text('文件 1/2'), findsOneWidget);
    expect(find.text('已选下载 1 个'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('files tab hides padding files from the list and count', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      details: _detailsWithSections(includePadding: true),
    );

    await tester.tap(find.textContaining('文件'));
    await tester.pump();
    await tester.pump();

    expect(find.text('文件 2'), findsOneWidget);
    expect(find.text('360413'), findsNothing);
    expect(find.text('episode.mkv'), findsOneWidget);
    expect(find.text('subtitle.ass'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('已选下载 2 个'), findsOneWidget);

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

  testWidgets('overview section scrolls with keyboard', (tester) async {
    await _pumpDetails(tester, details: _detailsWithSections());

    await _tabUntilLabel(tester, 'download-detail-scroll');

    var scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    var before = scrollable.position.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    var after = scrollable.position.pixels;

    expect(after, greaterThan(before));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('peer table headers respond to keyboard', (tester) async {
    var engine = await _pumpDetails(tester, details: _detailsWithSections());

    await tester.tap(find.textContaining('Peer'));
    await tester.pump();
    await tester.pump();

    // Tab 进入表头，聚焦“地址”后按空格切换排序。
    await _tabUntilLabel(tester, 'download-table-header-');
    expect(find.byIcon(FluentIcons.chevron_up), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.byIcon(FluentIcons.chevron_up), findsOneWidget);

    // 再 Tab 到“客户端”表头，回车打开筛选菜单。
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'download-table-header-客户端',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('全部客户端'), findsOneWidget);

    expect(engine.taskPeersCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('peer table rows are focusable and arrow keys navigate', (
    tester,
  ) async {
    await _pumpDetails(tester, details: _detailsWithSections());

    await tester.tap(find.textContaining('Peer'));
    await tester.pump();
    await tester.pump();

    await _tabUntilLabel(tester, 'download-table-row-');
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'download-table-row-0',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'download-table-row-1',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'download-table-row-0',
    );

    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _tabUntilLabel(
  WidgetTester tester,
  String prefix, {
  int maxTabs = 40,
}) async {
  for (var i = 0; i < maxTabs; i++) {
    var label = FocusManager.instance.primaryFocus?.debugLabel ?? '';
    if (label.startsWith(prefix)) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  fail('焦点未到达 $prefix（当前 ${FocusManager.instance.primaryFocus?.debugLabel}）');
}

Future<FakeDetailsEngine> _pumpDetails(
  WidgetTester tester, {
  BtTaskDetails? details,
}) async {
  var initialTask = details?.task ?? _task();
  var engine = FakeDetailsEngine()
    ..currentState = BtEngineClientState.ready
    ..currentTasks = [initialTask]
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
            child: DownloadTaskDetails(
              taskId: 'task-1',
              initialTask: initialTask,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return engine;
}

BtTaskSnapshot _task({
  String state = 'downloading',
  String sourceKind = 'magnet',
}) {
  return BtTaskSnapshot(
    id: 'task-1',
    state: state,
    sourceKind: sourceKind,
    savePath: r'D:\Downloads',
    displayName: 'Example',
    infoHash: sourceKind == 'http' ? null : 'abcd',
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
    contentFileCount: 0,
    peers: const [],
    peersTruncated: false,
    totalPeers: 0,
  );
}

BtTaskDetails _httpDetails() {
  var task = _task(sourceKind: 'http');
  return BtTaskDetails(
    task: task,
    pieceLength: 256 * 1024,
    pieceCount: 4,
    completedPieces: '1100',
    files: const [],
    filesTruncated: false,
    totalFiles: 1,
    contentFileCount: 1,
    peers: const [],
    peersTruncated: false,
    totalPeers: 0,
    httpConnections: 3,
  );
}

BtTaskDetails _detailsWithSections({
  int subtitlePriority = 4,
  bool includePadding = false,
}) {
  return BtTaskDetails(
    task: _task(),
    pieceLength: 16384,
    pieceCount: 2,
    completedPieces: '10',
    files: [
      BtTaskFileDetail(path: 'episode.mkv', size: 100, completedBytes: 50),
      if (includePadding)
        BtTaskFileDetail(
          path: '360413',
          size: 360413,
          completedBytes: 360413,
          priority: 0,
          paddingFile: true,
        ),
      BtTaskFileDetail(
        path: 'subtitle.ass',
        size: 10,
        completedBytes: 10,
        priority: subtitlePriority,
      ),
    ],
    filesTruncated: false,
    totalFiles: includePadding ? 3 : 2,
    contentFileCount: 2,
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

BtTaskPeersResult _peerPage() {
  var details = _detailsWithSections();
  return BtTaskPeersResult(
    peers: details.peers,
    truncated: false,
    totalPeers: details.peers.length,
    offset: 0,
    nextOffset: null,
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
  Map<int, int> lastPriorities = const {};
  Object? filesError;
  Object? peersError;
  Completer<BtTaskDetails>? nextDetailsCompleter;
  Completer<BtTaskPeersResult>? nextPeersCompleter;

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
      contentFileCount: value.contentFileCount,
      peers: const [],
      peersTruncated: false,
      totalPeers: value.peers.length,
      httpConnections: value.httpConnections,
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
      totalContentFiles: value.contentFileCount,
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
    if (nextPeersCompleter != null) return nextPeersCompleter!.future;
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
    lastPriorities = Map.of(priorities);
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
  Future<BtTaskSnapshot> addHttp({
    required String url,
    required String savePath,
    String? displayName,
    bool start = true,
  }) async {
    return _task(state: 'downloading');
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
