// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/providers/bangumi_providers.dart';
import 'package:bangumi_today/request/bangumi/bangumi_api.dart';
import 'package:bangumi_today/request/bangumi/bangumi_manager.dart';
import 'package:bangumi_today/store/bgm_user_hive.dart';

class _UserStore extends BgmUserStore {
  @override
  BgmUserState build() => const BgmUserState();

  void useAccount(int? id, {int generation = 0}) {
    state = BgmUserState(
      sessionGeneration: generation,
      user: id == null
          ? null
          : BangumiUser(
              id: id,
              username: 'user_$id',
              nickname: '用户 $id',
              userGroup: BangumiLegacyUserGroupType.user,
              avatar: BangumiAvatar(large: '', medium: '', small: ''),
              sign: '',
            ),
    );
  }
}

class _PendingRequest {
  _PendingRequest(this.options);

  final RequestOptions options;
  final response = Completer<ResponseBody>();
}

/// 挂起响应以制造真实的并发窗口，不访问网络或账号凭据。
class _Adapter implements HttpClientAdapter {
  final requests = <_PendingRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    var pending = _PendingRequest(options);
    requests.add(pending);
    return pending.response.future;
  }

  void release() {
    for (var index = 0; index < requests.length; index++) {
      var pending = requests[index];
      if (pending.response.isCompleted) continue;
      pending.response.complete(
        ResponseBody.fromString(
          jsonEncode({
            'total': index + 1,
            'limit': pending.options.queryParameters['limit'] ?? 100,
            'offset': pending.options.queryParameters['offset'] ?? 0,
            'data': <dynamic>[],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
    }
  }

  @override
  void close({bool force = false}) => release();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BangumiToday',
    packageName: 'bangumi_today',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  late ProviderContainer container;
  late _UserStore user;
  late BtrBangumiApi api;
  late _Adapter adapter;
  late String baseUrl;

  setUp(() {
    baseUrl = BtrBangumiApi.baseUrl;
    container = ProviderContainer(
      overrides: [bgmUserStoreProvider.overrideWith(_UserStore.new)],
    );
    user = container.read(bgmUserStoreProvider.notifier) as _UserStore;
    user.useAccount(1);
    api = container.read(bangumiApiProvider);
    adapter = _Adapter();
    api.client.dio.interceptors.clear();
    api.client.dio.httpClientAdapter = adapter;
  });

  tearDown(() {
    adapter.release();
    RequestManager.instance.cancelAll();
    api.client.dio.close(force: true);
    container.dispose();
    BtrBangumiApi.setBaseUrl(baseUrl);
  });

  Future<List<dynamic>> finish(List<Future<dynamic>> requests) async {
    await pumpEventQueue();
    adapter.release();
    return Future.wait(requests);
  }

  Future<dynamic> search() =>
      api.searchSubjects('同一关键词', cancelPrevious: false);

  var searches = <String, Future<dynamic> Function(BtrBangumiApi)>{
    '排序': (api) =>
        api.searchSubjects('同一关键词', sort: 'rank', cancelPrevious: false),
    '条目类型': (api) => api.searchSubjects(
      '同一关键词',
      type: [BangumiSubjectType.book],
      cancelPrevious: false,
    ),
    'NSFW': (api) =>
        api.searchSubjects('同一关键词', nsfw: true, cancelPrevious: false),
    '每页数量': (api) =>
        api.searchSubjects('同一关键词', limit: 20, cancelPrevious: false),
    '分页偏移': (api) =>
        api.searchSubjects('同一关键词', offset: 10, cancelPrevious: false),
    '日期': (api) => api.searchSubjects(
      '同一关键词',
      airdate: ['>=2026-10-01'],
      cancelPrevious: false,
    ),
    '评分': (api) =>
        api.searchSubjects('同一关键词', rating: ['>=8'], cancelPrevious: false),
    '排名': (api) =>
        api.searchSubjects('同一关键词', rank: ['<=100'], cancelPrevious: false),
  };

  for (var entry in searches.entries) {
    test('不同${entry.key}的搜索不会共用响应', () async {
      var results = await finish([search(), entry.value(api)]);
      expect(adapter.requests, hasLength(2));
      expect(results.map((result) => result.code), everyElement(0));
      expect(results.map((result) => result.data.total), [1, 2]);
    });
  }

  test('标签中的分隔符不会造成键冲突', () async {
    var results = await finish([
      api.searchSubjects('同一关键词', tag: ['a|b'], cancelPrevious: false),
      api.searchSubjects('同一关键词', tag: ['a', 'b'], cancelPrevious: false),
    ]);
    expect(adapter.requests, hasLength(2));
    expect(results.map((result) => result.data.total), [1, 2]);
  });

  test('完全相同的并发搜索继续合并', () async {
    var results = await finish([search(), search()]);
    expect(adapter.requests, hasLength(1));
    expect(results.map((result) => result.data.total), [1, 1]);
  });

  test('默认取消策略不会取消不同条件的搜索', () async {
    var results = await finish([
      api.searchSubjects('同一关键词'),
      api.searchSubjects('同一关键词', sort: 'score'),
    ]);
    expect(results.map((result) => result.code), everyElement(0));
    expect(adapter.requests, hasLength(2));
  });

  test('完全相同的搜索仍可取消前一次请求', () async {
    var results = await finish([
      api.searchSubjects('同一关键词'),
      api.searchSubjects('同一关键词'),
    ]);
    expect(results.first.code, isNot(0));
    expect(results.last.code, 0);
  });

  test('章节类型不同的收藏请求分别执行', () async {
    var results = await finish([
      api.getCollectionEpisodes(42, type: BangumiLegacyEpisodeType.main),
      api.getCollectionEpisodes(42, type: BangumiLegacyEpisodeType.sp),
    ]);
    expect(adapter.requests, hasLength(2));
    expect(results.map((result) => result.data.total), [1, 2]);
  });

  test('账号切换后不会复用旧账号的章节收藏请求', () async {
    var first = api.getCollectionEpisodes(42);
    await pumpEventQueue();
    user.useAccount(2);
    var results = await finish([first, api.getCollectionEpisodes(42)]);
    expect(adapter.requests, hasLength(2));
    expect(results.map((result) => result.data.total), [1, 2]);
  });

  test('同一账号重新登录后不会复用旧会话请求', () async {
    var first = api.getCollectionEpisodes(42);
    await pumpEventQueue();
    user.useAccount(1, generation: 1);
    var results = await finish([first, api.getCollectionEpisodes(42)]);
    expect(adapter.requests, hasLength(2));
    expect(results.map((result) => result.data.total), [1, 2]);
  });

  test('同一账号会话的相同章节收藏请求继续合并', () async {
    var results = await finish([
      api.getCollectionEpisodes(42),
      api.getCollectionEpisodes(42),
    ]);
    expect(adapter.requests, hasLength(1));
    expect(results.map((result) => result.data.total), [1, 1]);
  });

  test('账号切换也隔离 Next 评论请求', () async {
    var first = api.getSubjectComments(42);
    await pumpEventQueue();
    user.useAccount(2);
    var results = await finish([first, api.getSubjectComments(42)]);
    expect(adapter.requests, hasLength(2));
    expect(results.map((result) => result.data.total), [1, 2]);
  });

  test('登录后不会复用匿名搜索请求', () async {
    user.useAccount(null);
    var first = search();
    await pumpEventQueue();
    user.useAccount(1);
    var results = await finish([first, search()]);
    expect(adapter.requests, hasLength(2));
    expect(results.map((result) => result.data.total), [1, 2]);
  });

  test('切换站点后不会复用旧站点的请求', () async {
    BtrBangumiApi.setBaseUrl('https://api.bgm.tv');
    var first = api.getCollectionEpisodes(42);
    await pumpEventQueue();
    BtrBangumiApi.setBaseUrl('https://api.bangumi.vip');
    var results = await finish([first, api.getCollectionEpisodes(42)]);
    expect(adapter.requests, hasLength(2));
    expect(results.map((result) => result.data.total), [1, 2]);
  });
}
