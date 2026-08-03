import 'package:bangumi_today/database/app/app_config.dart';
import 'package:bangumi_today/database/bt_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    BTSqlite().db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDownAll(() => BTSqlite().db.close());

  test('prefills fresh installs with product download defaults', () async {
    var config = await BtsAppConfig().readBtDownloadConfig();

    expect(config.seedingEnabled, isTrue);
    expect(config.seedingDisclosureAccepted, isTrue);
    expect(config.engineEnabled, isFalse);
    expect(config.toEngineJson()['seedingEnabled'], isTrue);
    expect(config.activeDownloads, 4);
    expect(config.uploadRateLimit, 0);
    expect(config.connectionsLimit, 256);
    expect(config.connectionsPerTask, 64);
  });

  test('migrates an existing 1.0 config to completion-immediately', () async {
    await BtsAppConfig().write('btDownloadConfig', '''{
        "activeDownloads": 2,
        "downloadRateLimit": 0,
        "uploadRateLimit": 1048576,
        "connectionsLimit": 200,
        "connectionsPerTask": 80,
        "metadataTimeoutSeconds": 300
      }''');

    var migrated = await BtsAppConfig().readBtDownloadConfig();

    expect(migrated.seedingEnabled, isFalse);
    expect(migrated.engineEnabled, isFalse);
    expect(migrated.seedRatioLimit, 2);
    expect(migrated.seedTimeLimitMinutes, 60);
  });
}
