// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import 'app_bmf.dart';

@DataClassName('SubscriptionRow')
@TableIndex(name: 'AppSubscription_feedKey', columns: {#feedKey})
class AppSubscription extends Table {
  @override
  String get tableName => 'AppSubscription';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bmfId => integer()
      .named('bmfId')
      .references(AppBmf, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => text().withDefault(const Constant('generic'))();
  TextColumn get url => text()();
  TextColumn get feedKey => text().named('feedKey')();
  TextColumn get sourceConfig => text()
      .named('sourceConfig')
      .withDefault(const Constant('{"version":1}'))
      .check(
        const CustomExpression(
          "json_valid(sourceConfig) "
          "AND json_type(sourceConfig) = 'object'",
        ),
      )();
  IntColumn get autoUpdate => integer()
      .named('autoUpdate')
      .withDefault(const Constant(1))
      .check(const CustomExpression('autoUpdate IN (0, 1)'))();
  TextColumn get status => text()
      .withDefault(const Constant('active'))
      .check(const CustomExpression("status IN ('active', 'needsReview')"))();
  TextColumn get pendingItems => text()
      .named('pendingItems')
      .withDefault(const Constant('[]'))
      .check(
        const CustomExpression(
          "json_valid(pendingItems) "
          "AND json_type(pendingItems) = 'array'",
        ),
      )();
  TextColumn get knownItems => text()
      .named('knownItems')
      .withDefault(const Constant('[]'))
      .check(
        const CustomExpression(
          "json_valid(knownItems) "
          "AND json_type(knownItems) = 'array'",
        ),
      )();
  IntColumn get hasBaseline => integer()
      .named('hasBaseline')
      .withDefault(const Constant(0))
      .check(const CustomExpression('hasBaseline IN (0, 1)'))();
  IntColumn get itemKeyVersion => integer()
      .named('itemKeyVersion')
      .withDefault(const Constant(1))
      .check(const CustomExpression('itemKeyVersion > 0'))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {bmfId, feedKey},
  ];
}
