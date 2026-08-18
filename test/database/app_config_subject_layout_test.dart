// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'package:bangumi_today/database/app/app_config.dart';
import 'package:bangumi_today/database/bt_sqlite.dart';

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
    await BtsAppConfig().delete('subjectDetailLayout');
  });

  test('subject detail layout is empty until chosen', () async {
    expect(await BtsAppConfig().readSubjectDetailLayout(), '');

    await BtsAppConfig().writeSubjectDetailLayout('a');
    expect(await BtsAppConfig().readSubjectDetailLayout(), 'a');
  });
}
