// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/episode_mark_service.dart';
import 'package:bangumi_today/data/repositories/playback_library_impl.dart';
import 'package:bangumi_today/domain/repositories/episode_mark_gateway.dart';
import 'package:bangumi_today/domain/repositories/playback_episode_links.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';

PlaybackItem _item(String name, {int? subject = 42}) =>
    PlaybackItem(filePath: 'D:/Anime/$name.mkv', title: name, subject: subject);

final _items = [_item('Show - 01'), _item('Show - 02'), _item('Show - 03')];

EpisodeMarkEpisode _chapter(int number) => EpisodeMarkEpisode(
  id: 100 + number,
  type: 0,
  sort: number.toDouble(),
  withinSubject: number.toDouble(),
  name: 'episode $number',
  done: false,
);

class _Gateway extends Fake implements EpisodeMarkGateway {
  List<EpisodeMarkEpisode> chapters = [_chapter(1), _chapter(2), _chapter(3)];
  int progressReads = 0;
  int publicReads = 0;
  bool failProgress = false;
  bool failPublic = false;
  Completer<void>? progressGate;
  final progressStarted = Completer<void>();

  EpisodeMarkPage get page => EpisodeMarkPage(
    total: chapters.length,
    offset: 0,
    episodes: List.of(chapters),
  );

  @override
  Future<EpisodeMarkPage> progress(int subject, int offset) async {
    progressReads++;
    if (!progressStarted.isCompleted) progressStarted.complete();
    await progressGate?.future;
    if (failProgress) throw StateError('not collected');
    return page;
  }

  @override
  Future<EpisodeMarkPage> episodes(int subject, int offset) async {
    publicReads++;
    if (failPublic) throw StateError('offline');
    return page;
  }
}

class _Links extends Fake implements PlaybackEpisodeLinks {
  final values = <String, PlaybackEpisodeLink>{};
  List<PlaybackEpisodeRule> rules = [];

  @override
  Future<Map<String, PlaybackEpisodeLink>> readAll() async => Map.of(values);

  @override
  Future<List<PlaybackEpisodeRule>> readRules() async => List.of(rules);

  @override
  Stream<Map<String, PlaybackEpisodeLink>> watchAll() => const Stream.empty();

  @override
  Stream<List<PlaybackEpisodeRule>> watchRules() => const Stream.empty();
}

PlaybackLibraryImpl _library(
  EpisodeMarkService service,
  _Gateway gateway,
  _Links links,
) => PlaybackLibraryImpl(
  tasks: () => [],
  taskFiles: (_, _) => throw StateError('unexpected file lookup'),
  links: links,
  knownEpisodes: service.knownChapters,
  episodes: (subject) async =>
      await service.chaptersForPlayback(subject) ??
      (await gateway.episodes(subject, 0)).episodes,
);

void main() {
  late _Gateway gateway;
  late _Links links;
  late EpisodeMarkService service;
  late PlaybackLibraryImpl library;
  String? account;

  setUp(() {
    account = 'account';
    gateway = _Gateway();
    links = _Links();
    service = EpisodeMarkService(
      gateway: gateway,
      accountSession: () => account,
      links: links,
    );
    library = _library(service, gateway, links);
  });

  tearDown(() => service.close());

  test('连续切集复用已经匹配的完整章节，不重复请求', () async {
    await service.syncItems(_items);

    await library.prepareNextEpisode(_items, 0);
    expect(await library.nextEpisodeIndex(_items, 0), 1);
    await library.prepareNextEpisode(_items, 1);
    expect(await library.nextEpisodeIndex(_items, 1), 2);
    await library.prepareNextEpisode(_items, 2);
    expect(await library.nextEpisodeIndex(_items, 2), isNull);

    expect(gateway.progressReads, 1);
    expect(gateway.publicReads, 0);
  });

  test('播放预加载与列表匹配并发时共用正在进行的请求', () async {
    gateway.progressGate = Completer<void>();
    var preparing = library.prepareNextEpisode(_items, 0);
    await gateway.progressStarted.future;
    var syncing = service.syncItems(_items);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.progressReads, 1);
    expect(gateway.publicReads, 0);

    gateway.progressGate!.complete();
    await Future.wait([preparing, syncing]);
    expect(await library.nextEpisodeIndex(_items, 0), 1);
    expect(gateway.progressReads, 1);
  });

  test('未登录时公开章节只加载一次，连续切集复用结果', () async {
    account = null;
    await library.prepareNextEpisode(_items, 0);
    expect(await library.nextEpisodeIndex(_items, 0), 1);
    await library.prepareNextEpisode(_items, 1);
    expect(await library.nextEpisodeIndex(_items, 1), 2);

    expect(gateway.progressReads, 0);
    expect(gateway.publicReads, 1);
  });

  test('进度不可用时公开章节仍支持切集且不逐集请求', () async {
    gateway.failProgress = true;
    await library.prepareNextEpisode(_items, 0);
    expect(await library.nextEpisodeIndex(_items, 0), 1);
    await library.prepareNextEpisode(_items, 1);
    expect(await library.nextEpisodeIndex(_items, 1), 2);

    expect(gateway.progressReads, 1);
    expect(gateway.publicReads, 1);
  });

  test('章节加载失败不会永久缓存，结束时可以重试', () async {
    account = null;
    gateway.failPublic = true;
    await expectLater(library.prepareNextEpisode(_items, 0), throwsStateError);
    gateway.failPublic = false;

    expect(await library.nextEpisodeIndex(_items, 0), 1);
    expect(gateway.publicReads, 2);
  });

  test('预加载后排除下一集或当前集立即生效', () async {
    account = null;
    await library.prepareNextEpisode(_items, 0);
    links.values[_items[1].key] = PlaybackEpisodeLink(
      filePath: _items[1].filePath,
      subject: 42,
      episode: null,
    );
    expect(await library.nextEpisodeIndex(_items, 0), 2);
    links.values[_items[0].key] = PlaybackEpisodeLink(
      filePath: _items[0].filePath,
      subject: 42,
      episode: null,
    );
    expect(await library.nextEpisodeIndex(_items, 0), isNull);
    expect(gateway.publicReads, 1);
  });

  test('预加载后修改匹配规则立即生效', () async {
    account = null;
    await library.prepareNextEpisode(_items, 0);
    links.rules = [
      PlaybackEpisodeRule(
        id: 'show',
        subject: 42,
        pattern: r'^Show - (\d+)$',
        offset: 10,
        type: 0,
        exampleFile: _items[0].filePath,
      ),
    ];

    expect(await library.nextEpisodeIndex(_items, 0), isNull);
    expect(gateway.publicReads, 1);
  });

  test('跳过同集版本和未匹配文件，按章节顺序切集', () async {
    var items = [
      _items[0],
      _item('Show - 01v2'),
      _item('Extras'),
      _items[2],
      _items[1],
    ];
    await library.prepareNextEpisode(items, 0);

    expect(await library.nextEpisodeIndex(items, 0), 4);
    expect(await library.nextEpisodeIndex(items, 4), 3);
  });

  test('部分章节观察不能代替完整章节匹配', () async {
    service.observeProgress(42, [_chapter(1)], account: account);
    expect(service.knownChapters(42), isNull);

    await library.prepareNextEpisode(_items, 0);
    expect(await library.nextEpisodeIndex(_items, 0), 1);
    expect(gateway.progressReads, 1);
    expect(gateway.publicReads, 0);
  });

  test('手动刷新后的完整章节优先于之前预加载的数据', () async {
    await library.prepareNextEpisode(_items, 0);
    gateway.chapters = [_chapter(1), _chapter(3)];
    await service.syncItems(_items, refresh: true);

    expect(await library.nextEpisodeIndex(_items, 0), 2);
    expect(gateway.progressReads, 2);
    expect(gateway.publicReads, 0);
  });

  test('刷新播放目录后重新加载兜底章节', () async {
    account = null;
    await library.prepareNextEpisode(_items, 0);
    await library.discoverFiles(const []);
    await library.prepareNextEpisode(_items, 0);

    expect(gateway.publicReads, 2);
  });

  test('过期预加载失败不能清除刷新后的章节', () async {
    account = null;
    var old = Completer<List<EpisodeMarkEpisode>>();
    var reads = 0;
    library = PlaybackLibraryImpl(
      tasks: () => [],
      taskFiles: (_, _) => throw StateError('unexpected file lookup'),
      links: links,
      episodes: (_) {
        reads++;
        return reads == 1 ? old.future : Future.value(gateway.chapters);
      },
    );
    var failed = expectLater(
      library.prepareNextEpisode(_items, 0),
      throwsStateError,
    );
    await library.discoverFiles(const []);
    await library.prepareNextEpisode(_items, 0);
    old.completeError(StateError('old request failed'));
    await failed;

    expect(await library.nextEpisodeIndex(_items, 0), 1);
    expect(reads, 2);
  });
}
