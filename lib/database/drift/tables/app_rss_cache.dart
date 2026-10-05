// Package imports:
import 'package:drift/drift.dart';

@DataClassName('RssCacheRow')
class AppRssCache extends Table {
  @override
  String get tableName => 'AppRssCache';

  TextColumn get feedKey => text().named('feedKey')();
  TextColumn get requestUrl => text().named('requestUrl')();
  TextColumn get data => text().nullable()();
  IntColumn get ttlMinutes => integer()
      .named('ttlMinutes')
      .withDefault(const Constant(0))
      .check(const CustomExpression('ttlMinutes >= 0'))();
  IntColumn get lastSuccessAt => integer()
      .named('lastSuccessAt')
      .withDefault(const Constant(0))
      .check(const CustomExpression('lastSuccessAt >= 0'))();
  IntColumn get lastAttemptAt => integer()
      .named('lastAttemptAt')
      .withDefault(const Constant(0))
      .check(const CustomExpression('lastAttemptAt >= 0'))();
  IntColumn get lastFailedAt => integer()
      .named('lastFailedAt')
      .withDefault(const Constant(0))
      .check(const CustomExpression('lastFailedAt >= 0'))();
  IntColumn get cacheVersion => integer()
      .named('cacheVersion')
      .withDefault(const Constant(1))
      .check(const CustomExpression('cacheVersion > 0'))();

  @override
  Set<Column> get primaryKey => {feedKey};
}
