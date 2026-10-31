// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/utils/playback_episode_rule_generator.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';
import 'package:bangumi_today/pages/playback/playback_label.dart';
import 'package:bangumi_today/providers/playback_episode_link_providers.dart';

const _filename =
    '[LoliHouse] takt op.Destiny - 12 [WebRip 1080p HEVC-10bit AAC].mkv';
const _item = PlaybackItem(
  filePath: 'D:/Anime/$_filename',
  title: _filename,
  subject: 1,
);

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

    changes.add([_rule(file: file)]);
    await container.pump();
    expect(subscription.read().episodeNumber, '12');

    changes.add([_rule(file: file, offset: -11)]);
    await container.pump();
    expect(subscription.read().episodeNumber, '1');

    changes.add([]);
    await container.pump();
    expect(subscription.read().episodeNumber, isNull);
  });
}
