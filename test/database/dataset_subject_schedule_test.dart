// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/database/drift/bt_database.dart';
import 'package:bangumi_today/database/drift/dataset_storage.dart';

void main() {
  test('按 Bangumi ID 批量读取排期，保留多个档期并排除同名和其他站点', () async {
    var db = BtDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (var (index, site, id) in [
      (1, 'bangumi', '123'),
      (2, 'bangumi', '123'),
      (3, 'bangumi', '456'),
      (4, 'bangumi', '1234'),
      (5, 'tmdb', '123'),
    ]) {
      await db
          .into(db.bangumiDataItem)
          .insert(
            BangumiDataItemCompanion.insert(
              title: '同名番剧',
              itemKey: Value('schedule-$index'),
              sites: Value(
                jsonEncode([
                  {'site': site, 'id': id},
                ]),
              ),
            ),
          );
    }
    var storage = DatasetStorage(db);
    expect(await storage.readItemsForSubjects({}), isEmpty);
    expect(
      (await storage.readItemsForSubjects({
        123,
        456,
      })).map((row) => row.itemKey),
      ['schedule-1', 'schedule-2', 'schedule-3'],
    );
    expect(await storage.readItemsForSubjects({999}), isEmpty);
  });
}
