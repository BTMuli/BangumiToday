// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bt_engine_client.dart';
import 'package:bangumi_today/pages/app/download_page.dart';
import 'package:bangumi_today/store/bt_download_store.dart';
import 'package:bangumi_today/widgets/app/nav_item_icon.dart';
import 'package:bangumi_today/widgets/common/bt_content_frame.dart';

void main() {
  const dpis = [1.25, 1.5, 2.0];

  void setDpi(WidgetTester tester, double dpi) {
    tester.view.physicalSize = Size(1280 * dpi, 720 * dpi);
    tester.view.devicePixelRatio = dpi;
  }

  testWidgets('dynamic nav renders and stays tappable at common DPIs', (
    tester,
  ) async {
    for (var dpi in dpis) {
      setDpi(tester, dpi);
      await tester.pumpWidget(
        FluentApp(
          home: NavigationView(
            pane: NavigationPane(
              displayMode: PaneDisplayMode.compact,
              selected: 0,
              items: List.generate(30, (index) {
                var title = '动画详情 $index';
                return PaneItem(
                  icon: NavItemIcon(
                    title: title,
                    onClose: () {},
                    onCloseOthers: () {},
                    onCloseAll: () {},
                  ),
                  title: Text(title),
                  body: const SizedBox.shrink(),
                );
              }),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'nav overflow at $dpi');
      await tester.tap(find.byType(NavItemIcon).first);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull, reason: 'tap at $dpi');

      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    }
  });

  testWidgets('content frame renders without overflow at common DPIs', (
    tester,
  ) async {
    for (var dpi in dpis) {
      setDpi(tester, dpi);
      await tester.pumpWidget(
        const FluentApp(
          home: ScaffoldPage(
            content: BTContentFrame(
              child: SizedBox(width: 1600, height: 300, child: Text('超宽屏内容约束')),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'frame overflow at $dpi');
      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    }
  });

  testWidgets('download page renders without overflow at common DPIs', (
    tester,
  ) async {
    var engine = _DpiEngine()
      ..currentTasks = [_dpiTask('task-a'), _dpiTask('task-b')];
    for (var dpi in dpis) {
      setDpi(tester, dpi);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            btDownloadStoreProvider.overrideWith(
              (ref) => BtDownloadStore(client: engine),
            ),
          ],
          child: const FluentApp(home: DownloadPage()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'page overflow at $dpi');
      expect(find.text('下载管理'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    }
  });
}

BtTaskSnapshot _dpiTask(String id) {
  return BtTaskSnapshot(
    id: id,
    state: 'downloading',
    sourceKind: 'magnet',
    savePath: r'D:\Downloads',
    displayName: '任务 $id',
    infoHash: 'abc',
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

class _DpiEngine implements BtEngineGateway {
  final _events = StreamController<BtEngineEvent>.broadcast();
  final _tasks = StreamController<List<BtTaskSnapshot>>.broadcast();
  final _states = StreamController<BtEngineClientState>.broadcast();
  List<BtTaskSnapshot> currentTasks = [];

  @override
  Stream<BtEngineEvent> get events => _events.stream;

  @override
  bool get isReady => true;

  @override
  BtEngineClientState get state => BtEngineClientState.ready;

  @override
  Stream<BtEngineClientState> get states => _states.stream;

  @override
  List<BtTaskSnapshot> get tasks => currentTasks;

  @override
  Stream<List<BtTaskSnapshot>> get taskSnapshots => _tasks.stream;

  @override
  Future<BtTaskSnapshot> addMagnet({
    required String uri,
    required String savePath,
    String? displayName,
    bool start = true,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<BtTaskSnapshot> addTorrentFile({
    required String torrentPath,
    required String savePath,
    String? displayName,
    bool start = true,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> configure(Map<String, dynamic> config) async =>
      const {};

  @override
  Future<void> refreshTasks() async {
    _tasks.add(List.of(currentTasks));
  }

  @override
  Future<void> remove(String id, {bool deleteData = false}) async {}

  @override
  Future<void> start({
    String? executablePath,
    List<String> arguments = const [],
    String? statePath,
    Map<String, dynamic> config = const {},
    Duration readyTimeout = const Duration(seconds: 5),
  }) async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<Map<String, dynamic>> status() async => const {};

  @override
  Future<BtTaskSnapshot> pause(String id) async => throw UnimplementedError();

  @override
  Future<BtTaskSnapshot> resume(String id) async => throw UnimplementedError();

  @override
  Future<BtTaskSnapshot> recheck(String id) async => throw UnimplementedError();

  @override
  Future<BtTaskSnapshot> retry(String id) async => throw UnimplementedError();

  @override
  Future<List<int>> setFilePriorities(
    String id,
    Map<int, int> priorities,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<BtTaskDetails> taskDetails(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<BtTaskFilesResult> taskFiles(
    String id, {
    int offset = 0,
    int? limit,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<BtTaskPeersResult> taskPeers(
    String id, {
    int offset = 0,
    int? limit,
  }) async {
    throw UnimplementedError();
  }
}
