// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Project imports:
import 'package:bangumi_today/database/drift/bt_database.dart';
import 'package:bangumi_today/database/drift/dataset_import.dart';
import 'package:bangumi_today/database/drift/dataset_storage.dart';
import 'package:bangumi_today/models/bangumi/bangumi_data_model.dart';

BangumiDataItem _item(
  int id, {
  String begin = '2026-10-01',
  String name = '译名',
}) => BangumiDataItem(
  title: '同名作品',
  titleTranslate: BangumiDataItemTitleTranslate(zh: ['', name]),
  type: 'tv',
  lang: 'ja',
  officialSite: '',
  begin: begin,
  broadcast: null,
  end: '',
  comment: null,
  sites: [
    BangumiDataItemSite(
      site: 'bangumi',
      id: '$id',
      begin: null,
      broadcast: null,
    ),
  ],
);

void main() {
  late BtDatabase db;
  late DatasetStorage storage;

  setUp(() {
    db = BtDatabase(NativeDatabase.memory());
    storage = DatasetStorage(db);
  });
  tearDown(() => db.close());

  test('索引查询保留同名条目、多个排期与首个非空译名', () async {
    await storage.saveItems(
      await prepareDatasetItems([
        _item(1, name: '第一译名'),
        _item(1, begin: '2026-10-08', name: '后续译名'),
        _item(2, name: '另一个作品'),
      ]),
    );
    expect((await storage.readItemsForSubjects({1})).length, 2);
    expect(await storage.readSubjectNameCn(1), '第一译名');
    expect(await storage.readSubjectNameCn(2), '另一个作品');
    expect(await storage.readSubjectNameCn(3), isNull);
    var plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT itemId FROM BangumiDataSubject '
          'WHERE subjectId = ?',
          variables: [Variable('1')],
        )
        .get();
    expect(
      plan.any((row) => row.read<String>('detail').contains('SEARCH')),
      isTrue,
    );
  });

  test('增量更新同步投影并保留其他作品，完整替换删除旧投影', () async {
    var first = (await prepareDatasetItems([_item(1)])).single;
    await storage.saveItems([
      first,
      ...(await prepareDatasetItems([_item(2)])),
    ]);
    await storage.saveItems([
      first.copyWith(
        sites: Value(
          jsonEncode([
            {'site': 'bangumi', 'id': '3'},
            {'site': 'bangumi', 'id': '3'},
          ]),
        ),
      ),
    ]);
    expect(await storage.readItemsForSubjects({1}), isEmpty);
    expect((await storage.readItemsForSubjects({3})).length, 1);
    expect((await storage.readItemsForSubjects({2})).length, 1);
    await storage.replaceAll(
      sites: [],
      items: await prepareDatasetItems([_item(4)]),
      version: 'test',
      checkedAt: '2026-10-17',
    );
    expect(await storage.readItemsForSubjects({2, 3}), isEmpty);
    expect((await storage.readItemsForSubjects({4})).length, 1);
    expect((await db.select(db.bangumiDataSubject).get()).length, 1);
  });

  test('外层事务失败同时回滚源数据、索引投影和版本', () async {
    await storage.saveItems(await prepareDatasetItems([_item(1)]));
    await expectLater(
      db.transaction(() async {
        await storage.replaceAll(
          sites: [],
          items: await prepareDatasetItems([_item(2)]),
          version: 'rejected',
          checkedAt: '2026-10-17',
        );
        throw StateError('rollback');
      }),
      throwsStateError,
    );
    expect((await storage.readItemsForSubjects({1})).length, 1);
    expect(await storage.readItemsForSubjects({2}), isEmpty);
    expect(await db.select(db.appConfig).get(), isEmpty);
  });

  test('v3 迁移回填投影，保留无法解析的历史 sites 原文', () async {
    await db.close();
    var raw = sqlite.sqlite3.openInMemory();
    var old = BtDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    await DatasetStorage(old).saveItems(await prepareDatasetItems([_item(1)]));
    await old.customStatement(
      'INSERT INTO BangumiDataItem (itemKey,title,sites) VALUES (?,?,?)',
      ['legacy:invalid', '历史作品', '{invalid'],
    );
    await old.close();
    raw.execute('DROP TABLE BangumiDataSubject');
    raw.execute('PRAGMA user_version = 3');
    db = BtDatabase(NativeDatabase.opened(raw));
    var store = DatasetStorage(db);
    expect((await store.readItemsForSubjects({1})).length, 1);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      4,
    );
    var historical = await store.readItem('历史作品');
    expect(historical!.sites, '{invalid');
  });

  test('v2 可连续迁移至 v4，并为已有作品回填索引', () async {
    await db.close();
    var raw = sqlite.sqlite3.openInMemory();
    var old = BtDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    await DatasetStorage(old).saveItems(await prepareDatasetItems([_item(42)]));
    await old.close();
    raw.execute('DROP TABLE BangumiDataSubject');
    for (var index in [
      'BangumiCollection_search',
      'BangumiDataItem_title',
      'BangumiDataItem_itemKey',
    ]) {
      raw.execute('DROP INDEX $index');
    }
    raw.execute('ALTER TABLE BangumiCollection DROP COLUMN name');
    raw.execute('ALTER TABLE BangumiCollection DROP COLUMN nameCn');
    raw.execute('ALTER TABLE BangumiDataItem DROP COLUMN itemKey');
    raw.execute('PRAGMA user_version = 2');
    db = BtDatabase(NativeDatabase.opened(raw));
    expect(await DatasetStorage(db).readSubjectNameCn(42), '译名');
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      4,
    );
  });

  test('大批转换可跨 isolate，身份键与小批转换一致', () async {
    var items = [for (var i = 0; i < 201; i++) _item(i)];
    var prepared = await prepareDatasetItems(items);
    var single = (await prepareDatasetItems([items.first])).single;
    expect(prepared.length, 201);
    expect(prepared.first.itemKey.value, single.itemKey.value);
    await storage.saveItems(prepared);
    expect((await storage.readItemsForSubjects({0, 100, 200})).length, 3);
  });
}
