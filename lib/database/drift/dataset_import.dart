// Dart imports:
import 'dart:isolate';

// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../models/bangumi/bangumi_data_model.dart';
import 'bt_database.dart';
import 'catalog_projection.dart';

Future<List<BangumiDataItemCompanion>> prepareDatasetItems(
  List<BangumiDataItem> items,
) async => items.length <= 200
    ? _prepare(items)
    : await Isolate.run(() => _prepare(items));

List<BangumiDataItemCompanion> _prepare(List<BangumiDataItem> items) => [
  for (var item in items) _itemCompanion(item),
];

BangumiDataItemCompanion _itemCompanion(BangumiDataItem item) {
  var values = item.toSqlJson();
  return BangumiDataItemCompanion(
    itemKey: Value(dataItemKey(values)!),
    title: Value(values['title'] as String),
    titleTranslate: Value(values['titleTranslate'] as String),
    type: Value(values['type'] as String),
    lang: Value(values['lang'] as String),
    officialSite: Value(values['officialSite'] as String),
    begin: Value(values['begin'] as String),
    broadcast: Value(values['broadcast'] as String?),
    end: Value(values['end'] as String),
    comment: Value(values['comment'] as String?),
    sites: Value(values['sites'] as String),
  );
}
