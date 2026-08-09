import 'package:bangumi_today/database/bangumi/bangumi_collection.dart';
import 'package:bangumi_today/database/bangumi/bangumi_data.dart';
import 'package:bangumi_today/database/bangumi/bangumi_user.dart';
import 'package:bangumi_today/database/app/app_bmf.dart';
import 'package:bangumi_today/database/app/app_config.dart';
import 'package:bangumi_today/database/app/app_rss.dart';
import 'package:bangumi_today/database/bt_sqlite.dart';
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/models/database/app_rss_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;

  setUpAll(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    BTSqlite().db = database;
  });

  tearDownAll(() async {
    await database.close();
  });

  test('collection initialization is idempotent and preserves rows', () async {
    var collection = BtsBangumiCollection();
    await collection.init();
    await database.insert('BangumiCollection', {
      'subjectId': 42,
      'subjectType': 2,
      'rate': 0,
      'collectionType': 1,
      'comment': null,
      'tags': '[]',
      'epStat': 0,
      'volStat': 0,
      'updatedAt': DateTime.now().toIso8601String(),
      'private': 0,
      'subject': null,
    });

    await collection.init();

    expect(await collection.getAllSubjectIds(), {42});
  });

  test('user initialization is idempotent and preserves credentials', () async {
    var user = BtsBangumiUser();
    await user.initUser();
    await database.insert('BangumiUser', {
      'key': 'accessToken',
      'value': 'token',
    });

    await user.initUser();

    var rows = await database.query(
      'BangumiUser',
      where: 'key = ?',
      whereArgs: ['accessToken'],
    );
    expect(rows.single['value'], 'token');
  });

  test('credential and config logs do not contain stored values', () async {
    const accessToken = 'access-token-that-must-not-be-logged';
    const mikanToken = 'mikan-token-that-must-not-be-logged';
    var messages = <String>[];
    var originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };

    try {
      var user = BtsBangumiUser();
      await user.deleteAccessToken();
      await user.writeAccessToken(accessToken);
      await BtsAppConfig().writeMikanToken(mikanToken);
    } finally {
      debugPrint = originalDebugPrint;
    }

    var output = messages.join('\n');
    expect(output, isNot(contains(accessToken)));
    expect(output, isNot(contains(mikanToken)));
  });

  test('Bangumi data initialization is idempotent', () async {
    var bangumiData = BtsBangumiData();
    await bangumiData.initSite();
    await bangumiData.initItem();
    await database.insert('BangumiDataSite', {
      'key': 'official',
      'title': 'Official',
      'urlTemplate': 'https://example.com/{{id}}',
    });
    await database.insert('BangumiDataItem', {'title': 'Example'});

    await bangumiData.initSite();
    await bangumiData.initItem();

    expect(await database.query('BangumiDataSite'), hasLength(1));
    expect(await database.query('BangumiDataItem'), hasLength(1));
  });

  test('RSS pending diff migration and updates are persistent', () async {
    await database.execute('''
      CREATE TABLE AppRss (
        rss TEXT PRIMARY KEY NOT NULL,
        data TEXT,
        mkBgmId TEXT,
        mkGroupId TEXT,
        ttl INTEGER NOT NULL,
        updated INTEGER NOT NULL
      );
    ''');
    BtsAppRss.hasMkBgmId = false;
    BtsAppRss.hasPendingItems = false;

    var rss = BtsAppRss();
    await rss.preCheck();
    var columns = await database.rawQuery('PRAGMA table_info(AppRss)');
    expect(columns.map((column) => column['name']), contains('pendingItems'));

    var model = AppRssModel(
      rss: 'https://example.com/feed.xml',
      data: '<rss />',
      ttl: 15,
    );
    model.setPendingItemKeys({'episode-1', 'episode-2'});
    await rss.write(model);

    var saved = await rss.read(model.rss);
    expect(saved?.pendingItemKeys, {'episode-1', 'episode-2'});
    var fetchedAt = saved!.updated;

    saved.setPendingItemKeys({'episode-2'});
    await rss.updatePendingItems(saved);
    var updated = await rss.read(model.rss);
    expect(updated?.pendingItemKeys, {'episode-2'});
    expect(updated?.updated, fetchedAt);
  });

  test('BMF auto update defaults to enabled and persists', () async {
    await database.execute('''
      CREATE TABLE AppBmf (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject INTEGER NOT NULL,
        title TEXT DEFAULT '',
        airDate TEXT DEFAULT '',
        rss TEXT,
        download TEXT,
        UNIQUE(subject)
      );
    ''');
    BtsAppBmf.hasTitle = false;
    BtsAppBmf.hasMk = false;
    BtsAppBmf.hasAirDate = false;
    BtsAppBmf.hasAutoUpdate = false;

    var bmf = BtsAppBmf();
    await bmf.preCheck();
    var columns = await database.rawQuery('PRAGMA table_info(AppBmf)');
    expect(columns.map((column) => column['name']), contains('autoUpdate'));

    var model = AppBmfModel(subject: 42, title: 'Example');
    await bmf.write(model);
    expect((await bmf.read(42))?.autoUpdate, isTrue);

    await bmf.write(model.copyWith(autoUpdate: false));
    expect((await bmf.read(42))?.autoUpdate, isFalse);
  });
}
