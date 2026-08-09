import 'package:bangumi_today/database/bangumi/bangumi_collection.dart';
import 'package:bangumi_today/database/bangumi/bangumi_data.dart';
import 'package:bangumi_today/database/bangumi/bangumi_user.dart';
import 'package:bangumi_today/database/app/app_bmf.dart';
import 'package:bangumi_today/database/app/app_config.dart';
import 'package:bangumi_today/database/app/app_mikan_credential.dart';
import 'package:bangumi_today/database/app/app_rss.dart';
import 'package:bangumi_today/database/bt_sqlite.dart';
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/models/database/app_rss_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;

  setUpAll(() async {
    sqfliteFfiInit();
    FlutterSecureStorage.setMockInitialValues({});
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
    // Flutter's desktop test host does not register the platform secure
    // storage plugin, so migration can legitimately fall back to SQLite.
    expect(rows.length, lessThanOrEqualTo(1));
    expect(await user.readAccessToken(), 'token');
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
      await BtsMikanCredential().writeToken(mikanToken);
    } finally {
      debugPrint = originalDebugPrint;
    }

    var output = messages.join('\n');
    expect(output, isNot(contains(accessToken)));
    expect(output, isNot(contains(mikanToken)));
  });

  test('Mikan token migrates from legacy config to secure storage', () async {
    const legacyMikanToken = 'legacy-mikan-token-for-migration';
    await FlutterSecureStorage().delete(key: 'mikan.token');
    await BtsAppConfig().delete(BtsMikanCredential.legacyConfigKey);
    await BtsAppConfig().write(
      BtsMikanCredential.legacyConfigKey,
      legacyMikanToken,
    );

    var credential = BtsMikanCredential();
    expect(await credential.readToken(), legacyMikanToken);

    var rows = await database.query(
      'AppConfig',
      where: 'key = ?',
      whereArgs: [BtsMikanCredential.legacyConfigKey],
    );
    expect(rows, isEmpty);
    expect(
      await FlutterSecureStorage().read(key: 'mikan.token'),
      legacyMikanToken,
    );
  });

  test(
    'Mikan token falls back to legacy config when secure storage fails',
    () async {
      const fallbackMikanToken = 'fallback-mikan-token-for-plugin-failure';
      await BtsAppConfig().delete(BtsMikanCredential.legacyConfigKey);

      var credential = BtsMikanCredential(
        secureStorage: _FailingSecureStorage(),
      );
      await credential.writeToken(fallbackMikanToken);

      var rows = await database.query(
        'AppConfig',
        where: 'key = ?',
        whereArgs: [BtsMikanCredential.legacyConfigKey],
      );
      expect(rows, hasLength(1));
      expect(rows.first['value'], fallbackMikanToken);

      expect(await credential.readToken(), fallbackMikanToken);
    },
  );

  test(
    'deleting Mikan token cleans secure storage and legacy config',
    () async {
      const deleteMikanToken = 'mikan-token-to-delete';
      await FlutterSecureStorage().delete(key: 'mikan.token');
      await BtsAppConfig().delete(BtsMikanCredential.legacyConfigKey);

      var credential = BtsMikanCredential();
      await credential.writeToken(deleteMikanToken);
      await credential.deleteToken();

      expect(await FlutterSecureStorage().read(key: 'mikan.token'), isNull);
      var rows = await database.query(
        'AppConfig',
        where: 'key = ?',
        whereArgs: [BtsMikanCredential.legacyConfigKey],
      );
      expect(rows, isEmpty);
      expect(await credential.readToken(), isNull);
    },
  );

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

  test(
    'RSS cache version and failure columns migrate and round trip',
    () async {
      await database.execute('DROP TABLE IF EXISTS AppRss');
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
      BtsAppRss.hasCacheVersion = false;
      BtsAppRss.hasLastFailed = false;

      var rss = BtsAppRss();
      await rss.preCheck();
      var names = (await database.rawQuery(
        'PRAGMA table_info(AppRss)',
      )).map((column) => column['name']).toSet();
      expect(names, containsAll(['cacheVersion', 'lastFailed']));

      var model = AppRssModel(
        rss: 'https://example.com/feed.xml',
        data: '<rss />',
        ttl: 15,
      );
      model.lastFailed = 12345;
      await rss.write(model);

      var saved = await rss.read(model.rss);
      expect(saved?.cacheVersion, AppRssModel.currentCacheVersion);
      expect(saved?.lastFailed, 0);

      await rss.markRefreshFailure(saved!);
      var afterFailure = await rss.read(model.rss);
      expect(afterFailure?.lastFailed, isNot(0));
      expect(afterFailure?.updated, saved.updated);
    },
  );

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

/// 模拟安全存储插件不可用，用于验证回退路径。
class _FailingSecureStorage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(code: 'test_secure_storage_failure');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(code: 'test_secure_storage_failure');
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(code: 'test_secure_storage_failure');
  }
}
