// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import 'bt_database.dart';

/// Rebuilt in the same transaction as its source rows, including migrations.
Future<void> rebuildDatasetSubjects(
  BtDatabase db, {
  List<String>? itemKeys,
}) async {
  if (itemKeys != null && itemKeys.isEmpty) return;
  var placeholders = itemKeys == null
      ? ''
      : List.filled(itemKeys.length, '?').join(',');
  var filter = itemKeys == null ? '' : 'WHERE item.itemKey IN ($placeholders)';
  var variables = itemKeys?.map(Variable.new).toList() ?? <Variable>[];
  await db.customUpdate(
    'DELETE FROM BangumiDataSubject '
    'WHERE itemId IN (SELECT item.id FROM BangumiDataItem AS item $filter)',
    variables: variables,
    updates: {db.bangumiDataSubject},
  );
  await db.customUpdate(
    '''
    INSERT OR IGNORE INTO BangumiDataSubject (subjectId, itemId)
    SELECT json_extract(site.value, '\$.id'), item.id
    FROM BangumiDataItem AS item, json_each(
      CASE WHEN json_valid(item.sites) THEN
        CASE WHEN json_type(item.sites) = 'array' THEN item.sites END
      END
    ) AS site
    ${filter.isEmpty ? 'WHERE' : '$filter AND'}
      CASE WHEN site.type = 'object' THEN
        json_extract(site.value, '\$.site') = 'bangumi'
        AND json_type(site.value, '\$.id') = 'text'
        AND json_extract(site.value, '\$.id') != ''
      ELSE 0 END
    ''',
    variables: variables,
    updates: {db.bangumiDataSubject},
  );
}
