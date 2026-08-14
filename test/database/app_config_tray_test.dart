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
    await BtsAppConfig().delete('minimizeToTray');
  });

  test('minimize-to-tray defaults to enabled and persists', () async {
    expect(await BtsAppConfig().readMinimizeToTray(), isTrue);
    expect(await BtsAppConfig().read('minimizeToTray'), 'true');

    await BtsAppConfig().writeMinimizeToTray(false);
    expect(await BtsAppConfig().readMinimizeToTray(), isFalse);
  });

  test('invalid minimize-to-tray values fall back to enabled', () async {
    await BtsAppConfig().write('minimizeToTray', 'unexpected');

    expect(await BtsAppConfig().readMinimizeToTray(), isTrue);
    expect(await BtsAppConfig().read('minimizeToTray'), 'true');
  });
}
