// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/episode_mark_service.dart';
import 'package:bangumi_today/core/utils/playback_episode_files.dart';
import 'package:bangumi_today/domain/repositories/episode_mark_gateway.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';

const _demiFile =
    '[Lilith-Raws] Demi-chan wa Kataritai - '
    '13 [Baha][WEB-DL][1080p][AVC AAC][CHT][MKV].mkv';
const _special = EpisodeMarkEpisode(
  id: 1013,
  type: 1,
  sort: 13,
  withinSubject: 1,
  name: '亚人酱的暑假',
);

EpisodeMarkEpisode _main(int number, {double? sort}) => EpisodeMarkEpisode(
  id: 100 + number,
  type: 0,
  sort: sort ?? number.toDouble(),
  withinSubject: number.toDouble(),
  name: 'episode $number',
);

PlaybackItem _item(String name) =>
    PlaybackItem(filePath: 'D:/Anime/$name', title: name, subject: 42);

void main() {
  late List<EpisodeMarkEpisode> chapters;

  setUp(() {
    chapters = [for (var number = 1; number <= 12; number++) _main(number)];
    chapters.add(_special);
  });

  test('亚人酱第13集按播出编号自动匹配特别篇', () {
    expect(
      EpisodeMarkService.matchingEpisode(_item(_demiFile), chapters)?.id,
      _special.id,
    );
  });

  test('同目录的12集正篇和第13集特别篇都能自动关联', () {
    var files = [
      for (var number = 1; number <= 13; number++)
        _item(_demiFile.replaceFirst(' - 13 ', ' - $number ')),
    ];
    var matched = resolvePlaybackEpisodeFiles(
      subject: 42,
      files: files.map((file) => file.filePath),
      episodes: chapters,
      manualLinks: const {},
    );

    expect(matched.length, 13);
    for (var number = 1; number <= 13; number++) {
      expect(
        matched[files[number - 1].key]?.episode,
        number == 13 ? _special.id : 100 + number,
      );
    }
  });

  test('特别篇条目内编号不会与正篇第1集冲突', () {
    expect(
      EpisodeMarkService.matchingEpisode(
        _item('Demi-chan wa Kataritai - 01.mkv'),
        chapters,
      )?.id,
      101,
    );
    expect(
      EpisodeMarkService.matchingEpisode(
        _item('Demi-chan wa Kataritai - 01.mkv'),
        [_special],
      ),
      isNull,
    );
  });

  for (var sort in [13.0, 25.0]) {
    test('特别篇编号与正篇${sort == 13 ? '播出' : '条目内'}编号冲突时不匹配', () {
      chapters.add(_main(13, sort: sort));

      expect(
        EpisodeMarkService.matchingEpisode(_item(_demiFile), chapters),
        isNull,
      );
    });
  }

  test('多个特别篇具有相同播出编号时不匹配', () {
    chapters.add(
      const EpisodeMarkEpisode(id: 999, type: 1, sort: 13, name: '另一个特别篇'),
    );

    expect(
      EpisodeMarkService.matchingEpisode(_item(_demiFile), chapters),
      isNull,
    );
  });

  test('章节列表不完整时不推断特别篇，已有正篇观察仍可使用', () {
    expect(
      EpisodeMarkService.matchingEpisode(_item(_demiFile), [
        _special,
      ], complete: false),
      isNull,
    );
    expect(
      EpisodeMarkService.matchingEpisode(
        _item('Demi-chan wa Kataritai - 01.mkv'),
        [_main(1)],
        complete: false,
      )?.id,
      101,
    );
  });

  test('明确的季集编号继续优先使用正篇条目内编号', () {
    expect(
      EpisodeMarkService.matchingEpisode(_item('Show.S02E13.mkv'), [
        _main(13, sort: 25),
        _special,
      ])?.id,
      113,
    );
  });

  test('相同编号的OP、ED等章节不参与普通集数匹配', () {
    for (var type in [2, 3, 4, 5, 6]) {
      expect(
        EpisodeMarkService.matchingEpisode(_item(_demiFile), [
          EpisodeMarkEpisode(id: 999, type: type, sort: 13, name: 'extra'),
        ]),
        isNull,
      );
    }
  });

  test('特典、合集和无编号文件不因特别篇编号而自动关联', () {
    for (var name in [
      'Demi-chan wa Kataritai SP13.mkv',
      'Demi-chan wa Kataritai NCOP - 13.mkv',
      'Extras/Demi-chan wa Kataritai - 13.mkv',
      'Demi-chan wa Kataritai - 01-13.mkv',
      'Demi-chan wa Kataritai.mkv',
    ]) {
      expect(
        EpisodeMarkService.matchingEpisode(_item(name), [_special]),
        isNull,
        reason: name,
      );
    }
  });

  test('手动修正、排除及其他条目关联优先于特别篇自动匹配', () {
    var item = _item(_demiFile);
    for (var (subject, episode) in [(42, 101), (42, null), (99, 113)]) {
      var matched = resolvePlaybackEpisodeFiles(
        subject: 42,
        files: [item.filePath],
        episodes: chapters,
        manualLinks: {
          item.key: PlaybackEpisodeLink(
            filePath: item.filePath,
            subject: subject,
            episode: episode,
          ),
        },
      );

      expect(matched[item.key]?.episode, subject == 42 ? episode : null);
    }
  });
}
