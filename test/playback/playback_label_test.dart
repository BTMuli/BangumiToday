// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/utils/playback_episode_rule_generator.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_episode.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';
import 'package:bangumi_today/pages/playback/playback_label.dart';
import 'package:bangumi_today/providers/playback_episode_link_providers.dart';
import 'package:bangumi_today/providers/subject_playback_providers.dart';
import 'package:bangumi_today/store/playback_store.dart';

const _filename =
    '[LoliHouse] takt op.Destiny - 12 [WebRip 1080p HEVC-10bit AAC].mkv';
const _item = PlaybackItem(
  filePath: 'D:/Anime/$_filename',
  title: _filename,
  subject: 1,
);

BangumiEpisode _chapter({double sort = 13}) => BangumiEpisode.fromJson({
  'id': 1013,
  'type': 1,
  'name': 'Special',
  'name_cn': '特别篇',
  'sort': sort,
  'ep': 1,
  'airdate': '',
  'comment': 0,
  'duration': '',
  'desc': '',
  'disc': 0,
  'duration_seconds': 0,
});

class _PlaylistStore extends ChangeNotifier implements PlaybackStore {
  _PlaylistStore(this.playlist);

  @override
  final List<PlaybackItem> playlist;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _flush(ProviderContainer container) async {
  await container.pump();
  // Rebuilding a label resumes its upstream streams; deliver queued events
  // before flushing the resulting label and playlist updates.
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}

PlaybackEpisodeRule _rule({
  String file = _filename,
  double number = 12,
  double offset = 0,
  int subject = 1,
  int type = 0,
}) => PlaybackEpisodeRule(
  id: '$subject:$offset:$type',
  subject: subject,
  pattern: generateEpisodeRulePattern(
    file,
    episodeRuleNumbers(file).singleWhere((value) => value.number == number),
  ),
  offset: offset,
  type: type,
  exampleFile: file,
);

void main() {
  group('播放集数标签', () {
    test('手动关联特别篇后使用播出编号13，覆盖文件名2和匹配规则', () {
      const file = 'Anime - 02.mkv';
      const item = PlaybackItem(filePath: file, title: file, subject: 1);
      var label = PlaybackLabel.fromItem(
        item,
        manualLink: const PlaybackEpisodeLink(
          filePath: file,
          subject: 1,
          episode: 1013,
        ),
        chapters: [_chapter()],
        rules: [_rule(file: file, number: 2, offset: -1)],
      );

      expect(label.episodeNumber, '13');
      expect(label.episode, '第 13 集');
      expect(label.title, 'Anime');
    });

    test('手动关联保留小数编号；排除、失效或跨条目关联不回退到文件名', () {
      var link = PlaybackEpisodeLink(
        filePath: _item.filePath,
        subject: 1,
        episode: 1013,
      );
      expect(
        PlaybackLabel.fromItem(
          _item,
          manualLink: link,
          chapters: [_chapter(sort: 12.5)],
        ).episodeNumber,
        '12.5',
      );
      for (var link in [
        link,
        PlaybackEpisodeLink(
          filePath: _item.filePath,
          subject: 1,
          episode: null,
        ),
        PlaybackEpisodeLink(
          filePath: _item.filePath,
          subject: 2,
          episode: 1013,
        ),
      ]) {
        var label = PlaybackLabel.fromItem(
          _item,
          manualLink: link,
          rules: [_rule()],
        );
        expect(label.episodeNumber, isNull);
        expect(label.episode, isNull);
      }
    });

    test('匹配规则可识别标题中含 op 的剧集，并覆盖整季同格式文件', () {
      var rule = _rule();
      for (var number = 1; number <= 12; number++) {
        var file = _filename.replaceFirst(' - 12 ', ' - $number ');
        var label = PlaybackLabel.fromItem(
          PlaybackItem(filePath: 'D:/Anime/$file', title: file, subject: 1),
          rules: [rule],
        );

        expect(label.episodeNumber, '$number');
        expect(label.episode, '第 $number 集');
        expect(label.details, '1080P · MKV');
      }
    });

    test('规则优先于文件名显示编号，应用偏移并保留小数', () {
      const file = 'Anime.S02E13.5.1080p.mkv';
      var item = const PlaybackItem(
        filePath: 'D:/Anime/$file',
        title: file,
        subject: 1,
      );
      var rule = _rule(file: file, number: 13.5, offset: -12);
      var label = PlaybackLabel.fromItem(item, rules: [rule]);

      expect(label.episodeNumber, '1.5');
      expect(label.episode, '第 1.5 集');
    });

    test('其他番剧和未关联文件不能使用此规则', () {
      var original = PlaybackLabel.fromItem(_item).episodeNumber;
      expect(
        PlaybackLabel.fromItem(
          _item,
          rules: [_rule(subject: 2, offset: -11)],
        ).episodeNumber,
        original,
      );
      expect(
        PlaybackLabel.fromItem(
          const PlaybackItem(filePath: _filename, title: _filename),
          rules: [_rule(offset: -11)],
        ).episodeNumber,
        original,
      );
    });

    test('没有适用规则时保留文件名解析', () {
      const file = 'Other Anime - 03 [1080p].mkv';
      var label = PlaybackLabel.fromItem(
        const PlaybackItem(filePath: file, title: file, subject: 1),
        rules: [_rule()],
      );

      expect(label.episodeNumber, '3');
      expect(label.title, 'Other Anime');
    });

    test('规则冲突或无法提取编号时不显示猜测的集数', () {
      const file = 'Anime - 12.mkv';
      const item = PlaybackItem(filePath: file, title: file, subject: 1);
      var rule = _rule(file: file);
      var invalid = PlaybackEpisodeRule(
        id: 'invalid',
        subject: 1,
        pattern: r'^Anime - \d+$',
        offset: 0,
        type: 0,
        exampleFile: file,
      );
      for (var rules in [
        [rule, _rule(file: file, offset: 1)],
        [rule, _rule(file: file, type: 1)],
        [invalid],
        [rule, invalid],
        [_rule(file: file, offset: -12)],
      ]) {
        var label = PlaybackLabel.fromItem(item, rules: rules);
        expect(label.episodeNumber, isNull);
        expect(label.episode, isNull);
      }
      expect(
        PlaybackLabel.fromItem(item, rules: [rule, rule]).episodeNumber,
        '12',
      );
    });
  });

  test('规则新增、修改和删除时标签自动更新', () async {
    const file = 'Anime release12.mkv';
    const item = PlaybackItem(filePath: file, title: file, subject: 1);
    var changes = StreamController<List<PlaybackEpisodeRule>>();
    var container = ProviderContainer(
      overrides: [
        playbackEpisodeLinkSnapshotProvider.overrideWith(
          (ref) => Stream.value(const {}),
        ),
        playbackEpisodeRuleSnapshotProvider.overrideWith(
          (ref) => changes.stream,
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await changes.close();
    });
    var subscription = container.listen(playbackLabelProvider(item), (_, _) {});
    addTearDown(subscription.close);
    expect(subscription.read().episodeNumber, isNull);
    await _flush(container);

    changes.add([_rule(file: file)]);
    await _flush(container);
    expect(subscription.read().episodeNumber, '12');

    changes.add([_rule(file: file, offset: -11)]);
    await _flush(container);
    expect(subscription.read().episodeNumber, '1');

    changes.add([]);
    await _flush(container);
    expect(subscription.read().episodeNumber, isNull);
  });

  test('修正新增、更改和移除后，标签、列表顺序与当前集定位同步更新', () async {
    const special = PlaybackItem(
      filePath: 'D:/Anime/A - 02.mkv',
      title: 'A - 02.mkv',
      subject: 1,
    );
    var items = [
      special,
      for (var number = 1; number <= 12; number++)
        PlaybackItem(
          filePath: 'D:/Anime/Show - $number.mkv',
          title: 'Show - $number.mkv',
          subject: 1,
        ),
    ];
    var changes = StreamController<Map<String, PlaybackEpisodeLink>>();
    var chapterLoad = Completer<List<BangumiEpisode>>();
    var container = ProviderContainer(
      overrides: [
        playbackStoreProvider.overrideWith((ref) => _PlaylistStore(items)),
        playbackEpisodeLinkSnapshotProvider.overrideWith(
          (ref) => changes.stream,
        ),
        playbackEpisodeRuleSnapshotProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        subjectFileEpisodesProvider.overrideWith(
          (ref, subject) => chapterLoad.future,
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await changes.close();
    });
    var subscription = container.listen(playbackPlaylistProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(container.read(playbackLabelProvider(special)).episodeNumber, '2');

    void associate(int episode) => changes.add({
      special.key: PlaybackEpisodeLink(
        filePath: special.filePath,
        subject: 1,
        episode: episode,
      ),
    });

    associate(1013);
    await _flush(container);
    // Metadata is pending: never keep showing the stale filename number.
    expect(
      container.read(playbackLabelProvider(special)).episodeNumber,
      isNull,
    );
    chapterLoad.complete([_chapter(), _chapter(sort: 12.5)..id = 1014]);
    await _flush(container);
    expect(container.read(playbackLabelProvider(special)).episodeNumber, '13');
    var playlist = subscription.read();
    expect(playlist.indices, [...List.generate(12, (index) => index + 1), 0]);
    expect(playlist.positionOf(1), 0);
    expect(playlist.positionOf(12), 11);
    expect(playlist.positionOf(0), 12);
    expect(playlist.indices[playlist.positionOf(12) + 1], 0);

    associate(1014);
    await _flush(container);
    expect(
      container.read(playbackLabelProvider(special)).episodeNumber,
      '12.5',
    );
    expect(subscription.read().indices.last, 0);

    changes.add({});
    await _flush(container);
    expect(container.read(playbackLabelProvider(special)).episodeNumber, '2');
    expect(subscription.read().indices.take(3), [1, 0, 2]);
  });
}
