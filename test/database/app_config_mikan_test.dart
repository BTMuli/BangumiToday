// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';
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
    await BtsAppConfig().delete('mikanUrl');
  });

  test('mikan url defaults to kas.pub and persists', () async {
    expect(
      await BtsAppConfig().readMikanUrl(),
      BTAppConstants.defaultMikanMirror,
    );
    expect(
      await BtsAppConfig().read('mikanUrl'),
      BTAppConstants.defaultMikanMirror,
    );
  });

  test('mikan url keeps a saved official site', () async {
    await BtsAppConfig().writeMikanUrl(BTAppConstants.officialMikanMirror);

    expect(
      await BtsAppConfig().readMikanUrl(),
      BTAppConstants.officialMikanMirror,
    );
  });

  test('mikan url strips trailing slashes', () async {
    await BtsAppConfig().writeMikanUrl('https://mikanani.kas.pub/');

    expect(
      await BtsAppConfig().readMikanUrl(),
      BTAppConstants.defaultMikanMirror,
    );
  });
}
