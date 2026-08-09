import 'package:bangumi_today/database/bangumi/bangumi_data.dart';
import 'package:bangumi_today/database/bt_sqlite.dart';
import 'package:bangumi_today/models/bangumi/bangumi_data_model.dart';
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

  setUp(() async {
    await database.execute('DROP TABLE IF EXISTS BangumiDataSite');
    await database.execute('DROP TABLE IF EXISTS BangumiDataItem');
  });

  test('empty batches write nothing', () async {
    var data = BtsBangumiData();

    await data.writeSitesBatch(const []);
    await data.writeItemBatch(const []);

    expect(await data.readSiteAll(), isEmpty);
    expect(await data.readItemAll(), isEmpty);
  });

  test('single batch writes all rows', () async {
    var data = BtsBangumiData();
    var items = [for (var i = 0; i < 50; i++) _item('item-$i')];

    await data.writeItemBatch(items);

    expect(await data.readItemAll(), hasLength(50));
  });

  test('multi-batch writes report progress and stay idempotent', () async {
    var data = BtsBangumiData();
    var sites = [for (var i = 0; i < 250; i++) _site('site-$i', 'Site $i')];
    var progress = <int>[];

    await data.writeSitesBatch(
      sites,
      batchSize: 100,
      onProgress: (completed, total) => progress.add(completed),
    );

    expect(progress, [100, 200, 250]);
    expect(await data.readSiteAll(), hasLength(250));

    await data.writeSitesBatch(sites, batchSize: 100);
    expect(await data.readSiteAll(), hasLength(250));
  });

  test(
    'mid-batch failure rolls back the batch and rerun resumes idempotently',
    () async {
      var data = BtsBangumiData();
      await data.preCheck();
      await database.execute('''
      CREATE TRIGGER IF NOT EXISTS fail_on_bad
      AFTER INSERT ON BangumiDataItem
      WHEN NEW.title = 'item-149'
      BEGIN
        SELECT RAISE(ABORT, 'injected failure');
      END;
    ''');
      var items = [for (var i = 0; i < 250; i++) _item('item-$i')];

      await expectLater(
        data.writeItemBatch(items, batchSize: 100),
        throwsA(anything),
      );

      // 第 1 批已提交，第 2 批整体回滚，第 3 批未执行。
      expect(await data.readItemAll(), hasLength(100));

      await database.execute('DROP TRIGGER IF EXISTS fail_on_bad');
      await data.writeItemBatch(items, batchSize: 100);

      expect(await data.readItemAll(), hasLength(250));
    },
  );
}

BangumiDataSiteFull _site(String key, String title) {
  return BangumiDataSiteFull(
    key: key,
    title: title,
    urlTemplate: 'https://example.com/{id}',
    type: 'onair',
    regions: const ['JP'],
  );
}

BangumiDataItem _item(String title) {
  return BangumiDataItem(
    title: title,
    titleTranslate: BangumiDataItemTitleTranslate(zh: null),
    type: 'tv',
    lang: 'ja',
    officialSite: '',
    begin: '2026-01-01T00:00:00.000Z',
    broadcast: '1',
    end: '',
    comment: null,
    sites: const [],
  );
}
