// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import 'bangumi_data_item.dart';

/// Indexed projection of Bangumi IDs, retaining every broadcast run.
@DataClassName('DataSubjectRow')
@TableIndex(name: 'BangumiDataSubject_itemId', columns: {#itemId})
class BangumiDataSubject extends Table {
  @override
  String get tableName => 'BangumiDataSubject';

  TextColumn get subjectId => text().named('subjectId')();
  IntColumn get itemId => integer()
      .named('itemId')
      .references(BangumiDataItem, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {subjectId, itemId};
}
