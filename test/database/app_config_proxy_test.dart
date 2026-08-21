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
    await BtsAppConfig().delete('useSystemProxy');
  });

  test('system proxy defaults to disabled and persists', () async {
    expect(await BtsAppConfig().readUseSystemProxy(), isFalse);
    expect(await BtsAppConfig().read('useSystemProxy'), 'false');

    await BtsAppConfig().writeUseSystemProxy(true);
    expect(await BtsAppConfig().readUseSystemProxy(), isTrue);
  });

  test('invalid system proxy values fall back to disabled', () async {
    await BtsAppConfig().write('useSystemProxy', 'unexpected');

    expect(await BtsAppConfig().readUseSystemProxy(), isFalse);
    expect(await BtsAppConfig().read('useSystemProxy'), 'false');
  });
}
