// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'package:bangumi_today/core/cache/cache_manager.dart';
import 'package:bangumi_today/core/cache/subject_cache.dart';
import 'package:bangumi_today/data/repositories/playback_cover_impl.dart';
import 'package:bangumi_today/data/repositories/playback_window_remote.dart';
import 'package:bangumi_today/domain/repositories/bangumi_repository.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import '../collections/collection_fixture.dart';

BangumiSubject _subject({String nameCn = '条目中文名'}) {
  var json = collectionFixture(id: 42).subject.toJson();
  json.addAll({
    'name': 'Original subject title',
    'name_cn': nameCn,
    'summary': '',
    'nsfw': false,
    'locked': false,
    'platform': 'TV',
    'infobox': <Object?>[],
    'total_episodes': 12,
    'rating': {'total': 0, 'count': <String, int>{}, 'score': 0},
    'collection': <String, Object?>{},
  });
  var subject = BangumiSubject.fromJson(json);
  subject.images.large = 'https://example.com/42.jpg';
  return subject;
}

class _Repository extends Fake implements BTBangumiRepository {
  BangumiSubject detail = _subject();
  BangumiUserSubjectCollection? collected;
  int detailReads = 0;
  int localReads = 0;
  bool failDetail = false;
  bool failLocal = false;
  Completer<void>? detailGate;
  final detailStarted = Completer<void>();

  @override
  Future<BTResponse<BangumiSubject>> getSubjectDetail(String id) async {
    detailReads++;
    if (!detailStarted.isCompleted) detailStarted.complete();
    await detailGate?.future;
    if (failDetail) throw StateError('offline');
    return BTResponse.success(data: detail);
  }

  @override
  Future<BangumiUserSubjectCollection?> getLocalCollection(
    int subjectId,
  ) async {
    localReads++;
    if (failLocal) throw StateError('local collection unavailable');
    return collected;
  }
}

void main() {
  late Directory tempRoot;
  late Directory cacheDirectory;
  late _Repository repository;
  late BangumiPlaybackCoverResolver resolver;

  setUpAll(() async {
    tempRoot = Directory(
      path.join(Directory.current.path, 'temp', 'playback-title-check'),
    );
    await tempRoot.create(recursive: true);
    cacheDirectory = await tempRoot.createTemp('cache-');
    Hive.init(cacheDirectory.path);
    await BTCacheManager.instance.init();
  });

  setUp(() async {
    await BTCacheManager.instance.clear();
    repository = _Repository();
    resolver = BangumiPlaybackCoverResolver(repository);
  });

  tearDownAll(() async {
    await Hive.close();
    if (!path.isWithin(tempRoot.absolute.path, cacheDirectory.absolute.path)) {
      throw StateError('test cache must remain inside its temporary directory');
    }
    await cacheDirectory.delete(recursive: true);
    if (await tempRoot.list().isEmpty) await tempRoot.delete();
  });

  test('已有中文详情缓存直接展示条目名，不重复读取详情或收藏', () async {
    await BgmSubjectCache().write(_subject());

    expect(await resolver.hydrate(42), isTrue);
    expect(resolver.nameOf(42), '条目中文名');
    expect(await resolver.resolve(42), 'https://example.com/42.jpg');
    expect(repository.detailReads, 0);
    expect(repository.localReads, 0);
  });

  test('缓存没有中文译名时仍使用条目原名', () async {
    await BgmSubjectCache().write(_subject(nameCn: ''));

    expect(await resolver.hydrate(42), isTrue);
    expect(resolver.nameOf(42), 'Original subject title');
    expect(await resolver.resolve(42), 'https://example.com/42.jpg');
    expect(repository.detailReads, 0);
  });

  test('缺少详情缓存时复用本地收藏的条目名称', () async {
    repository.collected = collectionFixture(id: 42);

    expect(await resolver.resolve(42), isNull);
    expect(resolver.nameOf(42), repository.collected!.subject.nameCn);
    expect(resolver.contains(42), isTrue);
    expect(repository.detailReads, 0);
    expect(repository.localReads, 1);
  });

  test('收藏中的中文名优先于缓存原名，同时保留已有封面', () async {
    await BgmSubjectCache().write(_subject(nameCn: ''));
    repository.collected = collectionFixture(id: 42);

    expect(await resolver.resolve(42), 'https://example.com/42.jpg');
    expect(resolver.nameOf(42), repository.collected!.subject.nameCn);
    expect(repository.detailReads, 0);
  });

  test('本地收藏读取失败不会丢弃可用的条目原名', () async {
    await BgmSubjectCache().write(_subject(nameCn: ''));
    repository.failLocal = true;

    expect(await resolver.hydrate(42), isTrue);
    expect(resolver.nameOf(42), 'Original subject title');
    expect(repository.detailReads, 0);
  });

  test('纯本地加载未命中时不会自行请求详情', () async {
    expect(await resolver.hydrate(42), isFalse);
    expect(resolver.contains(42), isFalse);
    expect(repository.detailReads, 0);
  });

  test('没有本地信息时只解析一次，原名结果也能持久复用', () async {
    repository.detail = _subject(nameCn: '');
    expect(await resolver.resolve(42), 'https://example.com/42.jpg');
    expect(resolver.nameOf(42), 'Original subject title');
    expect(await resolver.resolve(42), 'https://example.com/42.jpg');
    var reopened = BangumiPlaybackCoverResolver(repository);
    expect(await reopened.resolve(42), 'https://example.com/42.jpg');
    expect(reopened.nameOf(42), 'Original subject title');
    expect(repository.detailReads, 1);
  });

  test('同一条目的并发解析共用请求，所有调用都能等待名称返回', () async {
    repository.detailGate = Completer<void>();
    var first = resolver.resolve(42);
    var second = resolver.resolve(42);
    expect(identical(first, second), isTrue);
    await repository.detailStarted.future;
    expect(repository.detailReads, 1);
    repository.detailGate!.complete();

    expect(
      await Future.wait([first, second]).timeout(const Duration(seconds: 2)),
      ['https://example.com/42.jpg', 'https://example.com/42.jpg'],
    );
    expect(resolver.nameOf(42), '条目中文名');
  });

  test('详情失败不永久缓存空名称，刷新时可以重试', () async {
    repository.failDetail = true;
    expect(await resolver.resolve(42), isNull);
    expect(resolver.contains(42), isFalse);
    repository.failDetail = false;

    expect(await resolver.resolve(42), 'https://example.com/42.jpg');
    expect(resolver.nameOf(42), '条目中文名');
    expect(repository.detailReads, 2);
  });

  test('独立播放器并发解析完成后返回，不会等待任务自身', () async {
    var reply = Completer<Object?>();
    var calls = 0;
    var remote = RemotePlaybackCover((_, _) {
      calls++;
      return reply.future;
    });
    var first = remote.resolve(42);
    var second = remote.resolve(42);
    expect(identical(first, second), isTrue);
    reply.complete({'name': '条目中文名', 'url': 'cover.jpg'});

    expect(
      await Future.wait([first, second]).timeout(const Duration(seconds: 2)),
      ['cover.jpg', 'cover.jpg'],
    );
    expect(remote.nameOf(42), '条目中文名');
    expect(await remote.resolve(42), 'cover.jpg');
    expect(calls, 1);
  });

  test('独立播放器的空名称不永久占用缓存', () async {
    var calls = 0;
    var remote = RemotePlaybackCover((_, _) async {
      calls++;
      return calls == 1
          ? {'name': null, 'url': null}
          : {'name': '条目中文名', 'url': 'cover.jpg'};
    });

    expect(await remote.resolve(42), isNull);
    expect(remote.contains(42), isFalse);
    expect(await remote.resolve(42), 'cover.jpg');
    expect(remote.nameOf(42), '条目中文名');
    expect(calls, 2);
  });

  test('独立播放器通信失败后能重新解析名称', () async {
    var calls = 0;
    var remote = RemotePlaybackCover((_, _) async {
      calls++;
      if (calls == 1) throw StateError('channel unavailable');
      return {'name': '条目中文名', 'url': null};
    });

    await expectLater(remote.resolve(42), throwsStateError);
    expect(await remote.resolve(42), isNull);
    expect(remote.nameOf(42), '条目中文名');
    expect(calls, 2);
  });
}
