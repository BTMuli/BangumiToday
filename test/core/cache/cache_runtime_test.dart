import 'dart:convert';
import 'dart:io';

import 'package:bangumi_today/core/cache/cache_manager.dart';
import 'package:bangumi_today/core/cache/lru_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late BTCacheManager cacheManager;
  late LRUCacheManager lruCacheManager;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp('bt_cache_test_');
    Hive.init(tempDirectory.path);
    cacheManager = BTCacheManager();
    lruCacheManager = LRUCacheManager();
    await cacheManager.init();
    await lruCacheManager.init();
  });

  setUp(() async {
    await cacheManager.clear();
    await lruCacheManager.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('BTCacheManager removes expired disk entries when reading', () async {
    var box = Hive.box<dynamic>('app_cache');
    await box.put(
      'expired',
      jsonEncode({
        'data': 'stale',
        'timestamp': DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
        'etag': null,
      }),
    );

    expect(
      await cacheManager.get<String>(
        'expired',
        maxAge: const Duration(hours: 1),
      ),
      isNull,
    );
    expect(box.containsKey('expired'), isFalse);
  });

  test('updating a full memory cache does not evict another entry', () async {
    for (var index = 0; index < 100; index++) {
      await cacheManager.set('key_$index', index, saveToDisk: false);
    }

    await cacheManager.set('key_0', 999, saveToDisk: false);

    expect(cacheManager.memoryCacheSize, 100);
    expect(await cacheManager.get<int>('key_1', checkDisk: false), 1);
    expect(await cacheManager.get<int>('key_0', checkDisk: false), 999);
  });

  test('LRUCacheManager removes expired and type-invalid entries', () async {
    var box = Hive.box<dynamic>('lru_cache');
    await box.put(
      'expired',
      jsonEncode({
        'data': 'stale',
        'timestamp': DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
        'accessCount': 1,
        'lastAccessed': DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      }),
    );

    expect(
      await lruCacheManager.get<String>(
        'expired',
        maxAge: const Duration(hours: 1),
      ),
      isNull,
    );
    expect(box.containsKey('expired'), isFalse);

    await lruCacheManager.set('wrong_type', 123);
    expect(await lruCacheManager.get<String>('wrong_type'), isNull);
    expect(lruCacheManager.exists('wrong_type'), isFalse);
  });

  test('LRUCacheManager enforces the disk cache size limit', () async {
    for (var index = 0; index < 505; index++) {
      await lruCacheManager.set('disk_$index', index, saveToMemory: false);
    }

    expect(lruCacheManager.diskCacheSize, 500);
    expect(lruCacheManager.exists('disk_504'), isTrue);
  });
}
