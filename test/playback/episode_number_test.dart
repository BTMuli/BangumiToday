// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/utils/episode_num_extractor.dart';
import 'package:bangumi_today/core/utils/playback_episode_number.dart';

void main() {
  group('标题缩写与片头片尾标记的上下文', () {
    for (var file in [
      '[Group] Prelude op.Afterlife - 03 [1080p].mkv',
      '[Group] Another ed.World [03] [1080p].mkv',
      'ANOTHER OP.WORLD - 03 [1080p].mkv',
      'Another ed.World S02E03 [1080p].mkv',
      'Another op.World 2x03 [1080p].mkv',
      'Another op.World Episode 03 [1080p].mkv',
      'Another ed.World 第03话 [1080p].mkv',
      'Another op.World of Music - 03 [1080p].mkv',
      '序曲 op.World - 03 [1080p].mkv',
    ]) {
      test('标题中的连写缩写不会阻止第03集匹配：$file', () {
        var number = extractEpisodeNumber(file);

        expect(isPlaybackExtra(file), isFalse);
        expect(number.kind, EpisodeNumberKind.single);
        expect(number.number, 3);
        expect(PlaybackEpisodeNumber.fromPath(file)?.number, 3);
      });
    }

    for (var file in [
      'Another OP - 03.mkv',
      'Another ed - 03.mkv',
      'Another OP01.Theme - 03.mkv',
      'Another NCOP.Theme - 03.mkv',
      'Another NCED02.Theme - 03.mkv',
      'Another [OP.Theme] - 03.mkv',
      'Another 【ED.Theme】 - 03.mkv',
      'Another (OP.Theme) - 03.mkv',
      '[Another OP.Theme] - 03.mkv',
      'Another - OP.Theme - 03.mkv',
      'Another.OP.Theme - 03.mkv',
      'OP.Theme - 03.mkv',
      'Another - 03 OP.Theme.mkv',
      'Another OP.WEB-DL - 03.mkv',
      'Another ED.WebRip - 03.mkv',
      'Another OP.BDRip - 03.mkv',
      'Another OP.HEVC - 03.mkv',
      'Another ED.AAC - 03.mkv',
      'Another OP.1080p - 03.mkv',
      'Another op.World.mkv',
      'Another op.World 03.mkv',
      'Another op.World [1080].mkv',
      'Another op.World [2026].mkv',
      'Another op.World [00].mkv',
      'Another op.World - 03 [OP].mkv',
      'Another ed.World - 03 [NCED].mkv',
      'Extras/Another op.World - 03.mkv',
    ]) {
      test('真实标记及证据不足的文件继续排除：$file', () {
        expect(isPlaybackExtra(file), isTrue);
        expect(extractEpisodeNumber(file).kind, EpisodeNumberKind.special);
        expect(PlaybackEpisodeNumber.fromPath(file), isNull);
      });
    }
  });
}
