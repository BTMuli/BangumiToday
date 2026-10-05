// Package imports:
import 'package:drift/drift.dart';

@DataClassName('MigrationRecoveryRow')
class AppMigrationRecovery extends Table {
  @override
  String get tableName => 'AppMigrationRecovery';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get migrationVersion => integer().named('migrationVersion')();
  TextColumn get kind => text()();
  TextColumn get legacyKey => text().named('legacyKey')();
  TextColumn get payload => text().check(
    const CustomExpression(
      "json_valid(payload) "
      "AND json_type(payload) = 'object'",
    ),
  )();
  TextColumn get candidateBmfIds => text()
      .named('candidateBmfIds')
      .withDefault(const Constant('[]'))
      .check(
        const CustomExpression(
          "json_valid(candidateBmfIds) "
          "AND json_type(candidateBmfIds) = 'array'",
        ),
      )();
  IntColumn get createdAt => integer().named('createdAt')();
  IntColumn get resolvedAt => integer().named('resolvedAt').nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {migrationVersion, kind, legacyKey},
  ];
}
