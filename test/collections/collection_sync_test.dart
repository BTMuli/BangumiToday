// Dart imports:
import 'dart:async';

// Package imports:
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import 'package:bangumi_today/data/datasources/bangumi_local_data_source_impl.dart';
import 'package:bangumi_today/data/datasources/bangumi_remote_data_source.dart';
import 'package:bangumi_today/data/repositories/bangumi_repository_impl.dart';
import 'package:bangumi_today/database/bangumi/bangumi_collection.dart';
import 'package:bangumi_today/database/drift/bt_database.dart';
import 'package:bangumi_today/domain/repositories/bangumi_repository.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/providers/bangumi_providers.dart';
import 'package:bangumi_today/store/bgm_user_hive.dart';
import 'collection_fixture.dart';

typedef _Page = BTResponse<BangumiPageT<BangumiUserSubjectCollection>>;
typedef _Subject = BTResponse<BangumiUserSubjectCollection>;

_Page _page(
  List<BangumiUserSubjectCollection> items, {
  int? total,
  int offset = 0,
}) => BTResponse.success(
  data: BangumiPageT(
    total: total ?? items.length,
    limit: 50,
    offset: offset,
    data: items,
  ),
);

class _UserStore extends BgmUserStore {
  _UserStore(this.account);

  final BangumiUser account;

  @override
  BgmUserState build() => BgmUserState(user: account);
}

class _Remote extends Fake implements BTBangumiRemoteDataSource {
  Future<_Page> Function(int offset)? page;
  Future<_Subject> Function(int id)? subject;
  Future<BTResponse<void>> Function()? write;
  bool Function()? lastScope;
  final offsets = <int>[];
  final usernames = <String?>[];
  final subjectUsernames = <String>[];
  int reads = 0;
  bool freshRead = false;
  bool failWrite = false;

  @override
  Future<_Page> getCollectionSubjects({
    String? username,
    BangumiSubjectType? subjectType,
    BangumiCollectionType? collectionType,
    int? limit,
    int? offset,
    bool Function()? authScope,
  }) async {
    lastScope = authScope;
    expect(authScope?.call(), isTrue);
    offsets.add(offset ?? 0);
    usernames.add(username);
    return await (page?.call(offset ?? 0) ?? Future.value(_page([])));
  }

  @override
  Future<_Subject> getCollectionSubject(
    String username,
    int subjectId, {
    bool fresh = false,
    bool Function()? authScope,
  }) async {
    lastScope = authScope;
    expect(authScope?.call(), isTrue);
    reads++;
    subjectUsernames.add(username);
    freshRead = fresh;
    return await (subject?.call(subjectId) ??
        Future.value(
          BTResponse(code: 404, message: 'not collected', data: null),
        ));
  }

  @override
  Future<BTResponse<void>> addCollectionSubject(
    int subjectId, {
    bool Function()? authScope,
  }) async {
    lastScope = authScope;
    expect(authScope?.call(), isTrue);
    return await (write?.call() ??
        Future.value(
          BTResponse<void>(
            code: failWrite ? 502 : 0,
            message: 'write',
            data: null,
          ),
        ));
  }

  @override
  Future<BTResponse<void>> updateCollectionSubject(
    int subjectId, {
    BangumiCollectionType? type,
    int? rate,
    int? ep,
    int? vol,
    String? comment,
    bool? private,
    List<String>? tags,
    bool Function()? authScope,
  }) => addCollectionSubject(subjectId, authScope: authScope);
}

void main() {
  late BtDatabase db;
  late BtsBangumiCollection table;
  late BTBangumiLocalDataSourceImpl local;
  late _Remote remote;
  late BTBangumiRepositoryImpl repository;
  late BangumiAccountSession account;

  setUp(() {
    db = BtDatabase(NativeDatabase.memory());
    table = BtsBangumiCollection.forDatabase(db);
    local = BTBangumiLocalDataSourceImpl(db: table);
    remote = _Remote();
    account = (username: '1', generation: 0);
    repository = BTBangumiRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      accountSession: () => account,
    );
    addTearDown(db.close);
  });

  test('自定义用户名用于收藏请求，本地缓存仍归属数字 UID', () async {
    PackageInfo.setMockInitialValues(
      appName: 'BangumiToday',
      packageName: 'bangumi_today',
      version: '1.0.0',
      buildNumber: '46',
      buildSignature: '',
    );
    var user = BangumiUser(
      id: 1283034,
      username: 'configured_user',
      nickname: '测试用户',
      userGroup: BangumiLegacyUserGroupType.user,
      avatar: BangumiAvatar(large: '', medium: '', small: ''),
      sign: '',
    );
    var item = collectionFixture();
    await table.setOwner(user.id.toString());
    await local.insertCollection(item);
    remote.page = (_) async => _page([item]);
    remote.subject = (_) async => BTResponse.success(data: item);
    var container = ProviderContainer(
      overrides: [
        bgmUserStoreProvider.overrideWith(() => _UserStore(user)),
        bangumiLocalDataSourceProvider.overrideWithValue(local),
        bangumiRemoteDataSourceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);
    var repository = container.read(bangumiRepositoryProvider);

    expect((await repository.getCollectionSubjects()).code, 0);
    expect((await repository.syncCollections()).code, 0);
    expect(remote.usernames, [user.username, user.username]);
    expect(
      (await repository.getCollectionSubject(
        user.username,
        item.subjectId,
      )).code,
      0,
    );
    expect((await repository.refreshCollectionSubject(item.subjectId)).code, 0);
    expect(remote.subjectUsernames, [user.username, user.username]);

    await table.setOwner(user.id.toString());
    expect((await local.getCollections()).single.subjectId, item.subjectId);
  });

  test('升级绑定旧收藏，同账号保留，切换账号和退出清空', () async {
    await local.insertCollection(collectionFixture());
    await table.setOwner('1', adoptLegacy: true);
    expect(await local.getCollections(), hasLength(1));
    await table.setOwner('1');
    expect(await local.getCollections(), hasLength(1));
    await table.setOwner('2');
    expect(await local.getCollections(), isEmpty);
    await local.insertCollection(collectionFixture());
    await table.setOwner(null);
    expect(await local.getCollections(), isEmpty);
    await table.setOwner('1', adoptLegacy: true);
    expect(await local.getCollections(), isEmpty);
  });

  test('事务写入期间会话变化会回滚', () async {
    var current = true;
    expect(
      await local.writeScoped(() async {
        await local.insertCollection(collectionFixture());
        current = false;
      }, isCurrent: () => current),
      isFalse,
    );
    expect(await local.getCollections(), isEmpty);
  });

  for (var update in [false, true]) {
    test('${update ? '更新' : '新增'}收藏在本地缺失时读取真实记录落库', () async {
      remote.subject = (id) async => BTResponse.success(
        data: collectionFixture(
          id: id,
          type: update
              ? BangumiCollectionType.doing
              : BangumiCollectionType.wish,
        ),
      );
      var result = update
          ? await repository.updateCollectionSubject(
              536270,
              type: BangumiCollectionType.doing,
            )
          : await repository.addCollectionSubject(536270);
      expect(result.code, 0);
      expect(
        (await local.getCollection(536270))!.type,
        update ? BangumiCollectionType.doing : BangumiCollectionType.wish,
      );
      expect(remote.freshRead, isTrue);
    });
  }

  test('补写失败明确报告远端已保存而不是假成功', () async {
    var result = await repository.addCollectionSubject(536270);
    expect(result.code, isNot(0));
    expect(result.message, contains('收藏已保存'));
    expect(await local.getCollection(536270), isNull);
  });

  test('重新添加已有本地记录同步为想看并保留评分等字段', () async {
    var original = collectionFixture();
    await local.insertCollection(original);
    expect((await repository.addCollectionSubject(original.subjectId)).code, 0);
    var saved = (await local.getCollection(original.subjectId))!;
    expect(saved.type, BangumiCollectionType.wish);
    expect(saved.rate, original.rate);
    expect(saved.comment, original.comment);
    expect(saved.private, original.private);
    expect(saved.tags, original.tags);
  });

  test('远端写入失败保留本地状态', () async {
    var original = collectionFixture();
    await local.insertCollection(original);
    remote.failWrite = true;
    expect(
      (await repository.updateCollectionSubject(
        536270,
        type: BangumiCollectionType.collect,
      )).code,
      502,
    );
    expect((await local.getCollection(536270))!.toJson(), original.toJson());
  });

  for (var status in [0, 404]) {
    test('旧账号延迟$status不能覆盖或删除新账号收藏', () async {
      var pending = Completer<_Subject>();
      remote.subject = (_) => pending.future;
      var read = repository.getCollectionSubject('1', 536270);
      await Future<void>.delayed(Duration.zero);
      var oldScope = remote.lastScope!;
      account = (username: '2', generation: 1);
      await table.setOwner('2');
      await local.insertCollection(collectionFixture(epStatus: 5));
      pending.complete(
        status == 0
            ? BTResponse.success(data: collectionFixture())
            : BTResponse(code: status, message: 'not found', data: null),
      );
      expect((await read).code, 409);
      expect(oldScope(), isFalse);
      expect((await local.getCollection(536270))!.epStatus, 5);
    });
  }

  test('同账号退出再登录也拒绝旧会话响应', () async {
    var pending = Completer<_Subject>();
    remote.subject = (_) => pending.future;
    var read = repository.getCollectionSubject('1', 536270);
    await Future<void>.delayed(Duration.zero);
    account = (username: '1', generation: 2);
    await local.insertCollection(collectionFixture(epStatus: 4));
    pending.complete(BTResponse(code: 404, message: 'old', data: null));
    expect((await read).code, 409);
    expect((await local.getCollection(536270))!.epStatus, 4);
    account = (username: null, generation: 3);
    expect(await repository.getLocalCollections(), isEmpty);
    expect(await repository.getLocalCollection(536270), isNull);
    expect(await repository.getCollectedSubjectIds(), isEmpty);
  });

  test('旧404不能删除同账号刚更新的收藏', () async {
    await local.insertCollection(collectionFixture());
    var pending = Completer<_Subject>();
    remote.subject = (_) => pending.future;
    var read = repository.getCollectionSubject('1', 536270);
    await Future<void>.delayed(Duration.zero);
    expect(
      (await repository.updateCollectionSubject(
        536270,
        type: BangumiCollectionType.collect,
      )).code,
      0,
    );
    pending.complete(BTResponse(code: 404, message: 'old', data: null));
    expect((await read).code, 409);
    expect(
      (await local.getCollection(536270))!.type,
      BangumiCollectionType.collect,
    );
  });

  test('收藏写入期间拒绝旧状态读取、全量同步和重复写入', () async {
    await local.insertCollection(collectionFixture());
    var pending = Completer<BTResponse<void>>();
    remote.write = () => pending.future;
    var write = repository.updateCollectionSubject(
      536270,
      type: BangumiCollectionType.collect,
    );
    await Future<void>.delayed(Duration.zero);
    expect((await repository.getCollectionSubject('1', 536270)).code, 409);
    expect((await repository.syncCollections()).code, 409);
    expect(
      (await repository.updateCollectionSubject(
        536270,
        type: BangumiCollectionType.wish,
      )).code,
      409,
    );
    expect(remote.reads, 0);
    expect(remote.offsets, isEmpty);
    pending.complete(BTResponse(code: 0, message: 'saved', data: null));
    expect((await write).code, 0);
    expect(
      (await local.getCollection(536270))!.type,
      BangumiCollectionType.collect,
    );
  });

  test('完整分页收齐后一次性替换并移除取消收藏', () async {
    await local.insertCollection(collectionFixture(id: 999));
    remote.page = (offset) async {
      expect((await local.getCollections()).map((item) => item.subjectId), [
        999,
      ]);
      return _page(
        [collectionFixture(id: offset + 1)],
        total: 2,
        offset: offset,
      );
    };
    expect((await repository.syncCollections()).code, 0);
    expect(remote.offsets, [0, 1]);
    expect((await local.getCollections()).map((item) => item.subjectId), [
      1,
      2,
    ]);
  });

  test('远端全量为空删除本地已取消收藏', () async {
    await local.insertCollection(collectionFixture());
    expect((await repository.syncCollections()).code, 0);
    expect(await local.getCollections(), isEmpty);
  });

  test('分类刷新保留其他分类并核对分类迁移和真实取消', () async {
    await local.writeList([
      collectionFixture(id: 1),
      collectionFixture(id: 2),
      collectionFixture(id: 3, type: BangumiCollectionType.wish),
    ]);
    remote.subject = (id) async => id == 1
        ? BTResponse.success(
            data: collectionFixture(
              id: id,
              type: BangumiCollectionType.collect,
            ),
          )
        : BTResponse(code: 404, message: 'cancelled', data: null);
    expect(
      (await repository.syncCollections(
        type: BangumiCollectionType.doing,
      )).code,
      0,
    );
    expect((await local.getCollection(1))!.type, BangumiCollectionType.collect);
    expect(await local.getCollection(2), isNull);
    expect((await local.getCollection(3))!.type, BangumiCollectionType.wish);
  });

  test('分类迁移核对失败不删除旧分类记录', () async {
    await local.insertCollection(collectionFixture());
    remote.subject = (_) async =>
        BTResponse(code: 502, message: 'offline', data: null);
    expect(
      (await repository.syncCollections(
        type: BangumiCollectionType.doing,
      )).code,
      502,
    );
    expect(await local.getCollections(), hasLength(1));
  });

  for (var failure in ['空页', '重复条目', '总数变化', '错误偏移', '请求失败']) {
    test('分页$failure终止并完整保留旧快照', () async {
      await local.insertCollection(collectionFixture(id: 999));
      remote.page = (offset) async {
        if (offset == 0) return _page([collectionFixture(id: 1)], total: 2);
        return switch (failure) {
          '空页' => _page([], total: 2, offset: offset),
          '重复条目' => _page([collectionFixture(id: 1)], total: 2, offset: offset),
          '总数变化' => _page([collectionFixture(id: 2)], total: 3, offset: offset),
          '错误偏移' => _page([collectionFixture(id: 2)], total: 2, offset: 0),
          _ => BTResponse(code: 502, message: 'offline', data: null),
        };
      };
      expect((await repository.syncCollections()).code, isNot(0));
      expect(remote.offsets, [0, 1]);
      expect((await local.getCollections()).map((item) => item.subjectId), [
        999,
      ]);
    });
  }

  test('同步期间切换账号不继续分页或写入', () async {
    var pending = Completer<_Page>();
    remote.page = (_) => pending.future;
    var sync = repository.syncCollections();
    await Future<void>.delayed(Duration.zero);
    account = (username: '2', generation: 1);
    await local.insertCollection(collectionFixture(id: 999));
    pending.complete(_page([collectionFixture(id: 1)], total: 2));
    expect((await sync).code, 409);
    expect(remote.offsets, [0]);
    expect((await local.getCollections()).single.subjectId, 999);
  });

  test('同步期间更新收藏时不让旧快照覆盖新状态', () async {
    await local.insertCollection(collectionFixture());
    var pending = Completer<_Page>();
    remote.page = (_) => pending.future;
    var sync = repository.syncCollections();
    await Future<void>.delayed(Duration.zero);
    await repository.updateCollectionSubject(
      536270,
      type: BangumiCollectionType.collect,
    );
    pending.complete(_page([]));
    expect((await sync).code, 409);
    expect(
      (await local.getCollection(536270))!.type,
      BangumiCollectionType.collect,
    );
  });

  test('数据库监听在收藏新增、分类变化和删除后发布最新列表', () async {
    var updates = StreamIterator(
      repository.watchLocalCollections(type: BangumiCollectionType.doing),
    );
    addTearDown(updates.cancel);
    expect(await updates.moveNext(), isTrue);
    expect(updates.current, isEmpty);
    await local.insertCollection(collectionFixture());
    expect(await updates.moveNext(), isTrue);
    expect(updates.current, hasLength(1));
    await repository.updateCollectionSubject(
      536270,
      type: BangumiCollectionType.wish,
    );
    expect(await updates.moveNext(), isTrue);
    expect(updates.current, isEmpty);
  });
}
