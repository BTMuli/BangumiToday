import 'package:bangumi_today/database/bangumi/bangumi_collection.dart';
import 'package:bangumi_today/database/bangumi/bangumi_data.dart';
import 'package:bangumi_today/database/bangumi/bangumi_user.dart';
import 'package:bangumi_today/database/bt_sqlite.dart';
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
}
