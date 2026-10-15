// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';
import 'package:bangumi_today/providers/playback_episode_link_providers.dart';
import 'package:bangumi_today/providers/subject_playback_providers.dart';

PlaybackItem _file(int number, {bool completed = false}) => PlaybackItem(
  filePath: 'D:/Anime/Show - ${number.toString().padLeft(2, '0')}.mkv',
  title: 'Show - $number',
  subject: 42,
  positionMs: 300000,
  durationMs: 1200000,
  completed: completed,
);

BangumiEpisode _chapter(int number, {double? sort}) => BangumiEpisode(
  id: 100 + number,
  type: BangumiEpType.main,
  name: 'episode $number',
  nameCn: '',
  sort: sort ?? number.toDouble(),
  ep: number.toDouble(),
  airDate: '',
  comment: 0,
  duration: '',
  desc: '',
  disc: 0,
  durationSeconds: 0,
);

class _Progress extends Notifier<Map<int, bool>> {
  @override
  Map<int, bool> build() => {};

  void update(Map<int, bool> value) => state = value;
}

void main() {
  late List<PlaybackItem> files;
  late List<BangumiEpisode> chapters;
  late Map<String, PlaybackEpisodeLink> manual;
  late Map<int, bool> progress;
  PlaybackItem? previous;
  int fileReads = 0;
  int chapterReads = 0;

  setUp(() {
    files = [_file(1), _file(2), _file(3)];
    chapters = [_chapter(1), _chapter(2), _chapter(3)];
    manual = {};
    progress = {};
    previous = _file(1);
    fileReads = chapterReads = 0;
  });

  ProviderContainer container({
    NotifierProvider<_Progress, Map<int, bool>>? states,
  }) {
    var result = ProviderContainer(
      overrides: [
        subjectPlaybackHistoryProvider(
          42,
        ).overrideWith((ref) => Stream.value(previous)),
        subjectPlaybackFilesProvider(42).overrideWith((ref) async {
          fileReads++;
          return files;
        }),
        subjectFileEpisodesProvider(42).overrideWith((ref) async {
          chapterReads++;
          return chapters;
        }),
        playbackEpisodeLinkSnapshotProvider.overrideWith(
          (ref) => Stream.value(manual),
        ),
        playbackEpisodeRuleSnapshotProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        subjectEpisodeProgressProvider(
          42,
        ).overrideWith((ref) => states == null ? progress : ref.watch(states)),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  Future<PlaybackItem?> choose({int watchedEpisodes = 0}) async {
    var instance = container();
    var provider = subjectContinuePlaybackItemProvider((
      subject: 42,
      watchedEpisodes: watchedEpisodes,
    ));
    var subscription = instance.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    return instance.read(provider.future);
  }

  test('第1集有记录且已标记看过时选择自动关联的第2集', () async {
    progress = {101: true, 102: false};

    var selected = await choose();
    expect(selected?.key, files[1].key);
    expect(fileReads, 1);
    expect(chapterReads, 1);
  });

  test('本地历史已播完时也选择下一集，无需账号进度', () async {
    previous = _file(1, completed: true);

    expect((await choose())?.key, files[1].key);
  });

  test('章节状态尚未加载时按已有账号进度跳过历史章节', () async {
    expect((await choose(watchedEpisodes: 1))?.key, files[1].key);
  });

  test('未看完的历史章节保留续播位置', () async {
    var selected = await choose();

    expect(selected, same(previous));
    expect(selected?.resumePosition, const Duration(minutes: 5));
  });

  test('明确标记未看过时不被汇总话数覆盖', () async {
    progress = {101: false};

    expect(await choose(watchedEpisodes: 1), same(previous));
  });

  test('没有历史时仍按账号观看进度选择首个未看章节', () async {
    previous = null;

    expect((await choose(watchedEpisodes: 1))?.key, files[1].key);
  });

  test('没有可播放文件时不加载章节数据', () async {
    files = [];

    expect(await choose(), isNull);
    expect(chapterReads, 0);
  });

  test('历史文件已不可用时选择现有匹配章节', () async {
    previous = _file(1, completed: true);
    files = [_file(2), _file(3)];

    expect((await choose(watchedEpisodes: 1))?.key, files[0].key);
  });

  test('下一集已看过时继续跳过，不重播其他已看章节', () async {
    progress = {101: true, 102: true, 103: false};

    expect((await choose())?.key, files[2].key);
  });

  test('同集修订版不能被当作下一集', () async {
    var alternate = PlaybackItem(
      filePath: 'D:/Anime/Show - 01v2.mkv',
      title: 'Show - 01v2',
      subject: 42,
    );
    files.insert(1, alternate);
    previous = _file(1, completed: true);

    expect((await choose())?.key, _file(2).key);
  });

  test('手动排除的自动匹配文件不会用于继续播放', () async {
    previous = _file(1, completed: true);
    manual[files[1].key] = PlaybackEpisodeLink(
      filePath: files[1].filePath,
      subject: 42,
      episode: null,
    );

    expect((await choose())?.key, files[2].key);
  });

  test('续作使用条目内话数判断观看进度', () async {
    chapters = [
      _chapter(1, sort: 26),
      _chapter(2, sort: 27),
      _chapter(3, sort: 28),
    ];
    files = [
      for (var number in [1, 2, 3])
        PlaybackItem(
          filePath: 'D:/Anime/Show.S02E0$number.mkv',
          title: 'Show S02E0$number',
          subject: 42,
        ),
    ];
    previous = files[0];

    expect((await choose(watchedEpisodes: 1))?.key, files[1].key);
  });

  test('没有后续可播放章节时不自动重播已看完的记录', () async {
    previous = _file(1, completed: true);
    files = [_file(1)];

    expect(await choose(), isNull);
  });

  test('全部标记看完时不选择任意已看章节', () async {
    progress = {101: true, 102: true, 103: true};

    expect(await choose(), isNull);
  });

  test('章节标记变化后更新选择，同时复用文件和章节数据', () async {
    var states = NotifierProvider<_Progress, Map<int, bool>>(_Progress.new);
    var instance = container(states: states);
    var provider = subjectContinuePlaybackItemProvider((
      subject: 42,
      watchedEpisodes: 0,
    ));
    var subscription = instance.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    expect((await instance.read(provider.future))?.key, files[0].key);

    instance.read(states.notifier).update({101: true, 102: false});
    await instance.pump();
    expect((await instance.read(provider.future))?.key, files[1].key);
    expect(fileReads, 1);
    expect(chapterReads, 1);
  });
}
