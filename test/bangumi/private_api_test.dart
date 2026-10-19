// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';
import 'package:bangumi_today/core/services/bangumi_token_service.dart';
import 'package:bangumi_today/data/parsers/bangumi_private_parser.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/bangumi/bangumi_subject_browse.dart';
import 'package:bangumi_today/models/bangumi/request_subject.dart';
import 'package:bangumi_today/request/bangumi/bangumi_api.dart';
import 'package:bangumi_today/request/bangumi/bangumi_manager.dart';
import 'package:bangumi_today/store/app_store.dart';

dynamic fixture(String name) => jsonDecode(
  File('test/bangumi/fixtures/private_api/$name.json').readAsStringSync(),
);

Map<String, dynamic> collectedSubject() => {
  ...fixture('subject') as Map<String, dynamic>,
  'interest': {
    'id': 99,
    'type': 3,
    'rate': 8,
    'comment': '收藏备注',
    'tags': ['测试'],
    'epStatus': 4,
    'volStatus': 0,
    'private': true,
    'updatedAt': 1700000000,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BangumiToday',
    packageName: 'bangumi_today',
    version: '1',
    buildNumber: '1',
    buildSignature: '',
  );

  late BtrBangumiApi api;
  late String originalUrl;
  late BangumiRequestAccount account;
  late List<RequestOptions> requests;
  late FutureOr<dynamic> Function(RequestOptions) respond;

  setUp(() {
    originalUrl = BtrBangumiApi.baseUrl;
    BtrBangumiApi.setBaseUrl(BTAppConstants.officialBangumiApiBaseUrl);
    BtrBangumiApi.setUsePrivateApi(true);
    account = (userId: 42, generation: 1);
    var tokens = BangumiTokenService(
      readAccessToken: () => 'test-token',
      readRefreshToken: () => null,
      readExpireTime: () => DateTime.now().add(const Duration(days: 7)),
      readGeneration: () => account.generation,
      now: DateTime.now,
      refreshToken: (_) async =>
          BTResponse.error(code: 400, message: '', data: null),
      writeTokenSet:
          ({
            required accessToken,
            required refreshToken,
            required expiresIn,
            required expectedGeneration,
            required expectedRefreshToken,
          }) async => false,
    );
    api = BtrBangumiApi(
      tokenService: tokens,
      accountSession: () => account,
      accountUsername: () => 'tester',
    );
    requests = [];
    respond = (_) => <String, dynamic>{};
    api.client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          try {
            var data = await respond(options);
            handler.resolve(
              Response(requestOptions: options, data: data, statusCode: 200),
            );
          } catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
      ),
    );
  });
  tearDown(() {
    RequestManager.instance.cancelAll();
    api.client.dispose();
    BtrBangumiApi.setBaseUrl(originalUrl);
    BtrBangumiApi.setUsePrivateApi(false);
  });

  test('preference defaults off and participates in settings equality', () {
    const settings = BTAppSettings();
    expect(settings.bangumiUsePrivateApi, isFalse);
    var enabled = settings.copyWith(bangumiUsePrivateApi: true);
    expect(enabled, isNot(settings));
    expect(
      enabled
          .copyWith(bangumiUrl: BTAppConstants.bangumiVipApiBaseUrl)
          .bangumiUsePrivateApi,
      isTrue,
    );
  });

  test(
    'official API always uses private mode, even with preference off',
    () async {
      BtrBangumiApi.setUsePrivateApi(false);
      expect(BtrBangumiApi.usePrivateApi, isTrue);
      expect(
        (await api.updateCollectionEpisode(
          type: BangumiEpisodeCollectionType.done,
          episode: 522,
        )).code,
        0,
      );
      expect(requests.single.uri.host, 'next.bgm.tv');
      expect(requests.single.method, 'PATCH');
    },
  );

  test(
    'nonofficial API defaults to legacy and can enable private mode',
    () async {
      BtrBangumiApi.setUsePrivateApi(
        const BTAppSettings().bangumiUsePrivateApi,
      );
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiVipApiBaseUrl);
      expect(BtrBangumiApi.usePrivateApi, isFalse);
      expect(
        (await api.updateCollectionEpisode(
          type: BangumiEpisodeCollectionType.done,
          episode: 522,
        )).code,
        0,
      );
      expect(requests.single.uri.host, 'api.bangumi.vip');
      expect(requests.single.method, 'PUT');

      BtrBangumiApi.setUsePrivateApi(true);
      expect(BtrBangumiApi.usePrivateApi, isTrue);
      expect(
        (await api.updateCollectionEpisode(
          type: BangumiEpisodeCollectionType.done,
          episode: 522,
        )).code,
        0,
      );
      expect(
        requests.last.uri.toString(),
        'https://api.bangumi.vip/p1/collections/episodes/522',
      );
      expect(requests.last.method, 'PATCH');

      BtrBangumiApi.setUsePrivateApi(false);
      expect(BtrBangumiApi.usePrivateApi, isFalse);
      BtrBangumiApi.setBaseUrl(BTAppConstants.officialBangumiApiBaseUrl);
      expect(BtrBangumiApi.usePrivateApi, isTrue);
      BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiVipApiBaseUrl);
      expect(BtrBangumiApi.usePrivateApi, isFalse);
    },
  );

  test('private reads and writes follow the selected API mirror', () async {
    respond = (options) => switch (options.uri.path) {
      '/p1/subjects/8' => fixture('subject'),
      '/p1/subjects/8/comments' => {'total': 0, 'data': <dynamic>[]},
      _ => null,
    };
    for (var origin in [
      BTAppConstants.bgmapiBangumiApiBaseUrl,
      BTAppConstants.bangumiVipApiBaseUrl,
      BTAppConstants.anibtBangumiApiBaseUrl,
      'http://api.example.test:8081',
    ]) {
      BtrBangumiApi.setBaseUrl(origin);
      BtrBangumiApi.setUsePrivateApi(false);
      expect(BtrBangumiApi.usePrivateApi, isFalse);
      BtrBangumiApi.setUsePrivateApi(true);

      expect((await api.getSubjectDetail('8')).code, 0);
      expect((await api.getSubjectComments(8)).code, 0);
      expect(
        (await api.updateCollectionEpisode(
          type: BangumiEpisodeCollectionType.done,
          episode: 522,
        )).code,
        0,
      );
      expect(requests.map((request) => request.uri.toString()), [
        '$origin/p1/subjects/8',
        '$origin/p1/subjects/8/comments?limit=20&offset=0',
        '$origin/p1/collections/episodes/522',
      ]);
      requests.clear();
    }
  });

  test('watched writes use PATCH, bearer auth and never batch mark', () async {
    respond = (_) => null; // A valid empty write response.
    var result = await api.updateCollectionEpisode(
      type: BangumiEpisodeCollectionType.done,
      episode: 522,
    );
    expect(result.code, 0);
    var request = requests.single;
    expect(
      request.uri.toString(),
      'https://next.bgm.tv/p1/collections/episodes/522',
    );
    expect(request.method, 'PATCH');
    expect(request.data, {'type': 2, 'batch': false});
    expect(request.headers['Authorization'], 'Bearer test-token');
  });

  test('expired auth scope prevents a write', () async {
    var result = await api.updateCollectionEpisode(
      type: BangumiEpisodeCollectionType.done,
      episode: 522,
      authScope: () => false,
    );
    expect(result.code, 499);
    expect(requests, isEmpty);
  });

  test('HTML and JSON errors cannot become successful writes', () async {
    for (var body in [
      '<html><title>502 Bad Gateway</title></html>',
      {'error': 'permission denied'},
    ]) {
      respond = (_) => body;
      var result = await api.updateCollectionEpisode(
        type: BangumiEpisodeCollectionType.done,
        episode: 522,
      );
      expect(result.code, isNot(0));
    }
  });

  test('full subject, collection and infobox retain their meanings', () {
    var subject = BangumiPrivateParser.subject(fixture('subject'));
    expect(subject.id, 8);
    expect(subject.nameCn, 'Code Geass 反叛的鲁路修R2');
    expect(subject.date, '2008-04-06');
    expect(subject.platform, 'TV');
    expect(subject.rating.count.keys, [for (var i = 1; i <= 10; i++) '$i']);
    expect(subject.infobox.first.key, '中文名');
    expect(subject.infobox.first.value.first['v'], subject.nameCn);
    var collection = BangumiPrivateParser.subjectCollection(collectedSubject());
    expect(collection.epStatus, 4);
    expect(collection.private, isTrue);
    expect(collection.tags, ['测试']);
    expect(
      DateTime.parse(collection.updatedAt).millisecondsSinceEpoch,
      1700000000000,
    );
  });

  test('calendar supports slim subjects without inventing air dates', () async {
    respond = (_) => fixture('calendar');
    var response = await api.getToday(useCache: false);
    expect(response.code, 0);
    var days = response.data as List<BangumiCalendarRespData>;
    expect(days, hasLength(7));
    expect(days.first.items.single.name, isNotEmpty);
    expect(days.first.items.single.airDate, '');
    expect(requests.single.uri.path, '/p1/calendar');
  });

  test('browse defaults to trends and treats total as a page count', () async {
    var slim = (fixture('calendar')['1'] as List).first['subject'];
    respond = (_) => {
      'data': [slim],
      'total': 42,
    };
    var response = await api.getSubjectBrowse();
    expect(response.code, 0);
    var page = response.data!;
    expect(page.totalPages, 42);
    expect(BangumiSubjectBrowsePage.pageSize, 24);
    var item = page.items.single;
    expect(item.info, slim['info']);
    expect(item.subject.nameCn, slim['nameCN']);
    expect(item.subject.metaTags, slim['metaTags']);
    expect(item.subject.rating.count['1'], slim['rating']['count'][0]);
    expect(requests.single.uri.path, '/p1/subjects');
    expect(requests.single.queryParameters, {
      'type': 2,
      'sort': 'trends',
      'page': 1,
    });
  });

  test('browse keeps rank pagination and accepts an absent cover', () async {
    var slim = Map<String, dynamic>.from(
      (fixture('calendar')['1'] as List).first['subject'],
    )..remove('images');
    respond = (_) => {
      'data': [slim],
      'total': 18,
    };
    var response = await api.getSubjectBrowse(
      sort: BangumiSubjectBrowseSort.rank,
      page: 2,
    );
    expect(response.code, 0);
    expect(response.data!.totalPages, 18);
    expect(response.data!.items.single.subject.images.large, isEmpty);
    expect(requests.single.queryParameters, {
      'type': 2,
      'sort': 'rank',
      'page': 2,
    });
  });

  test('browse forwards year and month time filters', () async {
    respond = (_) => {'data': [], 'total': 0};
    var response = await api.getSubjectBrowse(
      sort: BangumiSubjectBrowseSort.rank,
      page: 3,
      year: 2024,
      month: 3,
    );
    expect(response.code, 0);
    expect(requests.single.queryParameters, {
      'type': 2,
      'sort': 'rank',
      'page': 3,
      'year': 2024,
      'month': 3,
    });
  });

  test('browse omits the month when only the year is set', () async {
    respond = (_) => {'data': [], 'total': 0};
    await api.getSubjectBrowse(year: 2024);
    expect(requests.single.queryParameters, {
      'type': 2,
      'sort': 'trends',
      'page': 1,
      'year': 2024,
    });
  });

  test('browse time labels year and month', () {
    expect(BangumiSubjectBrowseTime.all.label, '全部时间');
    expect(const BangumiSubjectBrowseTime(year: 2024).label, '2024年');
    expect(
      const BangumiSubjectBrowseTime(year: 2024, month: 3).label,
      '2024年3月',
    );
    expect(
      const BangumiSubjectBrowseTime(year: 2024, month: 3),
      const BangumiSubjectBrowseTime(year: 2024, month: 3),
    );
    expect(
      const BangumiSubjectBrowseTime(year: 2024),
      isNot(const BangumiSubjectBrowseTime(year: 2024, month: 3)),
    );
  });

  test('browse uses Next when a mirror retains legacy search mode', () async {
    BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiVipApiBaseUrl);
    BtrBangumiApi.setUsePrivateApi(false);
    respond = (_) => {'data': [], 'total': 0};
    var response = await api.getSubjectBrowse();
    expect(response.code, 0);
    expect(response.data!.totalPages, 0);
    expect(response.data!.items, isEmpty);
    expect(requests.single.uri.host, 'next.bangumi.vip');
    expect(requests.single.uri.path, '/p1/subjects');
  });

  test(
    'browse reports non-JSON failures without exposing a partial page',
    () async {
      respond = (_) => '<html>Service unavailable</html>';
      var response = await api.getSubjectBrowse();
      expect(response.code, isNot(0));
      expect(response.data, isNull);
    },
  );

  test('search maps filters and preserves requested pagination', () async {
    var slim = (fixture('calendar')['1'] as List).first['subject'];
    respond = (_) => {
      'data': [slim],
      'total': 15,
    };
    var response = await api.searchSubjects(
      '鲁路修',
      tag: ['原创'],
      airdate: ['>=2008-01-01'],
      limit: 5,
      offset: 10,
    );
    expect(response.code, 0);
    expect(response.data.offset, 10);
    expect(response.data.limit, 5);
    expect(response.data.total, 15);
    expect(requests.single.uri.path, '/p1/search/subjects');
    expect(requests.single.data['filter']['tags'], ['原创']);
    expect(requests.single.data['filter']['date'], ['>=2008-01-01']);
    expect(requests.single.data['filter'].containsKey('tag'), isFalse);
  });

  test('an unspecified NSFW filter is omitted from private search', () async {
    respond = (_) => {'data': [], 'total': 0};
    expect((await api.searchSubjects('测试', nsfw: null)).code, 0);
    expect(requests.single.data['filter'].containsKey('nsfw'), isFalse);
  });

  test(
    'own collections, single collection and profile use private reads',
    () async {
      respond = (request) => switch (request.uri.path) {
        '/p1/collections/subjects' => {
          'data': [collectedSubject()],
          'total': 1,
        },
        '/p1/subjects/8' => collectedSubject(),
        '/p1/me' => {
          'id': 42,
          'username': 'tester',
          'nickname': '测试',
          'group': 10,
          'sign': '',
          'avatar': {'large': '', 'medium': '', 'small': ''},
        },
        _ => throw StateError('unexpected path'),
      };
      var list = await api.getCollectionSubjects(username: 'tester', limit: 50);
      expect(list.code, 0);
      expect(list.data.data.single.epStatus, 4);
      expect((await api.getCollectionSubject('tester', 8)).code, 0);
      expect((await api.getUserInfo()).data.id, 42);
      respond = (_) => fixture('subject');
      expect((await api.getCollectionSubject('tester', 8)).code, 404);
    },
  );

  test(
    'book progress uses camelCase; mixed writes retain the public contract',
    () async {
      expect((await api.updateCollectionSubject(8, ep: 4, vol: 1)).code, 0);
      expect(requests.last.uri.path, '/p1/collections/subjects/8');
      expect(requests.last.data, {'epStatus': 4, 'volStatus': 1});
      expect(
        (await api.updateCollectionSubject(8, rate: 8, comment: '测试')).code,
        0,
      );
      expect(requests.last.method, 'PUT');
      expect(requests.last.data, {'rate': 8, 'comment': '测试'});
      expect((await api.updateCollectionSubject(8, ep: 4, rate: 8)).code, 0);
      expect(requests.last.uri.path, '/v0/users/-/collections/8');
    },
  );

  test(
    'chapter pages filter specials and preserve local season numbering',
    () async {
      var main = (fixture('episodes')['data'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      main[0]['sort'] = 13;
      main[1]['sort'] = 14;
      main[1]['collection'] = {'status': 2};
      var special = {...main[0], 'id': 900, 'type': 1, 'sort': 1};
      respond = (request) => request.uri.path == '/p1/episodes/523'
          ? main[1]
          : {
              'total': 3,
              'data': request.queryParameters['offset'] == 0
                  ? [main[0], special]
                  : [main[1]],
            };
      var response = await api.getEpisodeList(
        8,
        type: BangumiLegacyEpisodeType.main,
        limit: 1,
        offset: 1,
      );
      expect(response.code, 0);
      var page = response.data as BangumiPageT<BangumiEpisode>;
      expect(page.total, 2);
      expect(page.data.single.sort, 14);
      expect(page.data.single.ep, 2);
      var progress = await api.getCollectionEpisode(523);
      expect(progress.code, 0);
      expect(progress.data.type, BangumiEpisodeCollectionType.done);
      expect(progress.data.episode.ep, 2);
    },
  );

  test('incomplete and duplicate episode pages remain failures', () async {
    var row = (fixture('episodes')['data'] as List).first;
    for (var data in [
      <dynamic>[],
      [row, row],
    ]) {
      respond = (_) => {'total': 2, 'data': data};
      expect((await api.getEpisodeList(8)).code, 409);
    }
  });

  test('switching mode during a request discards its result', () async {
    BtrBangumiApi.setBaseUrl(BTAppConstants.bangumiVipApiBaseUrl);
    respond = (_) {
      BtrBangumiApi.setUsePrivateApi(false);
      return {'data': [], 'total': 0};
    };
    expect((await api.getEpisodeList(8)).code, 499);
  });

  test('characters and staff unwrap their nested private shapes', () async {
    respond = (request) => request.uri.path.endsWith('/characters')
        ? {'data': fixture('characters')['data'], 'total': 1}
        : {'data': fixture('staff')['data'], 'total': 1};
    var characters = await api.getSubjectCharacters(8);
    expect(characters.code, 0);
    expect(characters.data!.single.name, 'C.C.');
    expect(characters.data!.single.actors, isNotEmpty);
    var staff = await api.getSubjectPersons(8);
    expect(staff.code, 0);
    expect(staff.data!.single.relation, '分镜');
  });

  test('collection chapter pages use embedded watched status', () async {
    var rows = (fixture('episodes')['data'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    rows[1]['collection'] = {'status': 2};
    respond = (_) => {'data': rows, 'total': rows.length};
    var response = await api.getCollectionEpisodes(8, limit: 1, offset: 1);
    expect(response.code, 0);
    expect(response.data.offset, 1);
    expect(response.data.total, 2);
    expect(response.data.data.single.type, BangumiEpisodeCollectionType.done);
    expect(requests.single.uri.path, '/p1/subjects/8/episodes');
  });

  test('changing account stops a multi-page private request', () async {
    respond = (_) {
      account = (userId: 43, generation: 2);
      return {'data': fixture('episodes')['data'], 'total': 3};
    };
    expect((await api.getEpisodeList(8)).code, 499);
    expect(requests, hasLength(1));
  });

  test('related subjects consume all private pages', () async {
    var row = {
      'subject': fixture('calendar')['1'][0]['subject'],
      'relation': {'cn': '续集'},
      'order': 0,
    };
    respond = (request) => {
      'data': [row],
      'total': 2,
    };
    var response = await api.getSubjectRelations(8);
    expect(response.code, 0);
    expect(response.data, hasLength(2));
    expect(response.data.first.relation, '续集');
    expect(requests.map((e) => e.queryParameters['offset']), [0, 1]);
  });
}
