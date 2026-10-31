// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/utils/playback_episode_rule_generator.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';

const _yozakuraFile =
    'Yozakura-san.Chi.no.Daisakusen.S02E13.1080p.AMZN.WEB-DL.'
    'JPN.DDP2.0.H.264-ToonsHub.mkv';

void main() {
  group('剧集匹配规则的数字候选', () {
    test('takt op.Destiny 从03和10bit中优先推断集数03', () {
      const file =
          '[Nekomoe kissaten&LoliHouse] takt op.Destiny - '
          '03 [WebRip 1080p HEVC-10bit AAC].mkv';

      expect(episodeRuleNumbers(file).map((number) => number.text), [
        '03',
        '10',
      ]);
      expect(suggestEpisodeRuleNumber(file, 1)?.text, '03');
      expect(suggestEpisodeRuleNumber(file, 3)?.text, '03');
    });

    test('点号分隔的分辨率不会并入 S02E13 的集数', () {
      var numbers = episodeRuleNumbers(_yozakuraFile);

      expect(numbers.map((number) => number.text), ['02', '13']);
      expect(suggestEpisodeRuleNumber(_yozakuraFile, 13)?.text, '13');
      expect(suggestEpisodeRuleNumber(_yozakuraFile, 1)?.text, '13');
    });

    for (var resolution in [
      '360p',
      '480p',
      '576i',
      '720p',
      '1080p',
      '1080i',
      '1440p',
      '2160p',
      '4320p',
      '1080P',
    ]) {
      test('$resolution 与前面的整数或小数集数分开', () {
        for (var episode in ['13', '13.5']) {
          var file = 'Anime.S02E$episode.$resolution.WEB-DL.mkv';

          expect(episodeRuleNumbers(file).map((number) => number.text), [
            '02',
            episode,
          ]);
        }
      });
    }

    test('忽略完整路径和扩展名后仍保留原文件名中的数字位置', () {
      var file = '"D:\\Anime\\2026\\Anime.2160p.S02E13.1080p.mkv"';
      var name = PlaybackEpisodeRule.filename(file);
      var numbers = episodeRuleNumbers(file);

      expect(numbers.map((number) => number.text), ['02', '13']);
      for (var number in numbers) {
        expect(name.substring(number.start, number.end), number.text);
      }
      expect(numbers.last.start, name.indexOf('13'));
      expect(numbers.last.end, name.indexOf('13') + 2);
    });

    test('修订文件仍能选出常见整数和小数集数', () {
      for (var episode in ['13', '13.5']) {
        var file = '[Group] Anime - ${episode}v2 [1080p].mkv';
        var number = suggestEpisodeRuleNumber(file, double.parse(episode));

        expect(number?.text, episode);
        expect(number?.number, double.parse(episode));
      }
    });

    test('没有分辨率标记的小数不按分辨率拆分', () {
      expect(episodeRuleNumbers('Anime [13.1080].mkv').single.text, '13.1080');
    });

    test('标题和集数重复时仍需明确选择数字位置', () {
      var file = '[13] $_yozakuraFile';

      expect(episodeRuleNumbers(file).map((number) => number.text), [
        '13',
        '02',
        '13',
      ]);
      expect(suggestEpisodeRuleNumber(file, 13), isNull);
    });
  });

  group('生成剧集匹配规则', () {
    test('生成的规则匹配样例和后续剧集，保留季号及分辨率', () {
      var number = episodeRuleNumbers(
        _yozakuraFile,
      ).singleWhere((number) => number.number == 13);
      var rule = PlaybackEpisodeRule(
        id: 'yozakura',
        subject: 1,
        pattern: generateEpisodeRulePattern(_yozakuraFile, number),
        offset: 0,
        type: 0,
        exampleFile: _yozakuraFile,
      );

      expect(rule.numberFor(_yozakuraFile), 13);
      expect(rule.numberFor(_yozakuraFile.replaceFirst('E13', 'E14')), 14);
      expect(rule.numberFor(_yozakuraFile.replaceFirst('E13', 'E13.5')), 13.5);
      expect(rule.numberFor(_yozakuraFile.replaceFirst('S02', 'S03')), isNull);
      expect(
        rule.numberFor(_yozakuraFile.replaceFirst('1080p', '720p')),
        isNull,
      );
    });

    test('小数集数后的分辨率不会影响规则及集数偏移', () {
      const file = 'Anime.S02E13.5.1080p.WEB-DL.mkv';
      var number = episodeRuleNumbers(
        file,
      ).singleWhere((number) => number.number == 13.5);
      var rule = PlaybackEpisodeRule(
        id: 'fractional',
        subject: 1,
        pattern: generateEpisodeRulePattern(file, number),
        offset: -12,
        type: 0,
        exampleFile: file,
      );

      expect(rule.numberFor(file), 1.5);
      expect(rule.numberFor(file.replaceFirst('E13.5', 'E14')), 2);
      expect(rule.numberFor(file.replaceFirst('E13.5', 'E14.5v2')), 2.5);
    });
  });
}
