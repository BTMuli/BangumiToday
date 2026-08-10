// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

// Project imports:
import 'package:bangumi_today/models/hive/nav_model.dart';
import 'package:bangumi_today/store/nav_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('nav_store_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(BtmAppNavItemAdapter());
    await Hive.openBox<BtmAppNavHive>('nav');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box<BtmAppNavHive>('nav').clear();
  });

  int dynamicCount(BTNavStore store) {
    return store.totalNavCount - store.topNavCount;
  }

  int navIndex(BTNavStore store, int subject) {
    return store.getNavIndex(
      BtmAppNavItemType.subject,
      '条目 $subject',
      'subjectDetail_$subject',
    );
  }

  test('caps dynamic items and evicts the least recently used', () {
    var store = BTNavStore();

    // 填满上限再追加，超出的最早条目应被淘汰。
    for (var i = 0; i < BTNavStore.maxDynamicItems + 5; i++) {
      store.addNavItemB(subject: i, paneTitle: '条目 $i', jump: false);
    }

    expect(dynamicCount(store), BTNavStore.maxDynamicItems);
    expect(navIndex(store, 0), -1);
    expect(navIndex(store, 4), -1);
    expect(navIndex(store, 5), isNot(-1));
    expect(navIndex(store, 49), isNot(-1));

    // 被淘汰的条目同时清理 Hive 记录。
    expect(Hive.box<BtmAppNavHive>('nav').containsKey('0'), isFalse);
    expect(Hive.box<BtmAppNavHive>('nav').containsKey('5'), isTrue);
  });

  test('recently opened items are not evicted first', () {
    var store = BTNavStore();
    for (var i = 1; i <= 3; i++) {
      store.addNavItemB(subject: i, paneTitle: '条目 $i', jump: false);
    }

    // 打开条目 1，使其成为最近使用。
    store.setCurIndex(store.topNavCount);

    // 追加到超过上限：应淘汰未打开的条目 2。
    for (var i = 4; i <= BTNavStore.maxDynamicItems + 1; i++) {
      store.addNavItemB(subject: i, paneTitle: '条目 $i', jump: false);
    }

    expect(dynamicCount(store), BTNavStore.maxDynamicItems);
    expect(navIndex(store, 2), -1);
    expect(navIndex(store, 1), isNot(-1));
  });

  test('closes all dynamic items except the selected one', () {
    var store = BTNavStore();
    for (var i = 1; i <= 3; i++) {
      store.addNavItemB(subject: i, paneTitle: '条目 $i', jump: false);
    }

    store.removeNavItemOthers('subjectDetail_2');

    expect(dynamicCount(store), 1);
    expect(navIndex(store, 2), isNot(-1));
    expect(navIndex(store, 1), -1);
    expect(navIndex(store, 3), -1);
  });

  test('closes all dynamic items and keeps const items', () {
    var store = BTNavStore();
    for (var i = 1; i <= 3; i++) {
      store.addNavItemB(subject: i, paneTitle: '条目 $i', jump: false);
    }

    store.removeAllNavItems();

    expect(dynamicCount(store), 0);
    expect(store.totalNavCount, store.topNavCount);
    expect(Hive.box<BtmAppNavHive>('nav').length, 0);
  });

  test('reopening an existing item does not duplicate it', () {
    var store = BTNavStore();
    store.addNavItemB(subject: 1, paneTitle: '条目 1', jump: false);
    store.addNavItemB(subject: 1, paneTitle: '条目 1', jump: false);

    expect(dynamicCount(store), 1);
    expect(Hive.box<BtmAppNavHive>('nav').length, 1);
  });
}
