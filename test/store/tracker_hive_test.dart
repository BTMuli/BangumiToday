// Dart imports:
import 'dart:io';
import 'dart:typed_data';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'package:bangumi_today/database/bt_sqlite.dart';
import 'package:bangumi_today/models/app/bt_tracker_config.dart';
import 'package:bangumi_today/models/hive/tracker_model.dart';
import 'package:bangumi_today/store/tracker_hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late _TrackerHttpAdapter adapter;

  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'bangumi_today_tracker_',
    );
    Hive.init(temporaryDirectory.path);
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TrackerHiveAdapter());
    }
    await Hive.openBox<TrackerHiveModel>('tracker');
    sqfliteFfiInit();
    BTSqlite().db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await TrackerHive().init();
    adapter = _TrackerHttpAdapter();
    TrackerHive().client.httpClientAdapter = adapter;
  });

  tearDownAll(() async {
    await Hive.close();
    await BTSqlite().db.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('keeps snapshots and uses validators across refreshes', () async {
    const source = 'https://lists.example/trackers.txt';
    await TrackerHive().updateConfig(
      BtTrackerConfig(
        sources: [source],
        manualTrackers: const ['udp://manual.example:6969/announce'],
      ),
    );

    await TrackerHive().refresh(force: true);
    var firstSnapshot = TrackerHive().effectiveTrackers;

    expect(firstSnapshot, [
      'udp://manual.example:6969/announce',
      'udp://tracker.example:6969/announce',
      'https://tracker.example/announce',
    ]);
    expect(TrackerHive().config.sourceEtags[source], '"v1"');
    expect(TrackerHive().config.lastUpdateSuccessAt, isNotNull);

    await TrackerHive().refresh(force: true);

    expect(TrackerHive().effectiveTrackers, firstSnapshot);
    expect(adapter.requests, 2);
    expect(adapter.conditionalRequests, 1);

    await TrackerHive().checkUpdate();
    expect(adapter.requests, 2);

    await TrackerHive().updateConfig(
      TrackerHive().config.copyWith(
        sources: [source, 'https://fail.example/trackers.txt'],
      ),
    );
    await TrackerHive().refresh(force: true);

    expect(TrackerHive().effectiveTrackers, firstSnapshot);
    expect(TrackerHive().config.lastUpdateError, contains('1 个'));
  });
}

class _TrackerHttpAdapter implements HttpClientAdapter {
  var requests = 0;
  var conditionalRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    if (options.uri.host == 'fail.example') {
      return ResponseBody.fromString('failed', HttpStatus.internalServerError);
    }
    if (options.headers['If-None-Match'] == '"v1"') {
      conditionalRequests++;
      return ResponseBody.fromString('', HttpStatus.notModified);
    }
    return ResponseBody.fromString(
      '''
udp://tracker.example:6969/announce
invalid
https://tracker.example/announce
''',
      HttpStatus.ok,
      headers: {
        HttpHeaders.etagHeader: ['"v1"'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
