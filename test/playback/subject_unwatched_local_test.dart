// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/utils/subject_unwatched_local.dart';
import 'package:bangumi_today/domain/repositories/episode_mark_gateway.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';

EpisodeMarkEpisode _chapter(
  int id,
  double sort, {
  bool? done,
  int type = 0,
  double? withinSubject,
}) {
  return EpisodeMarkEpisode(
    id: id,
    type: type,
    sort: sort,
    name: 'EP$sort',
    withinSubject: withinSubject ?? sort,
    done: done,
  );
}

PlaybackItem _file(String name, {int subject = 1}) {
  return PlaybackItem(
    filePath: 'D:/videos/$name.mkv',
    title: name,
    subject: subject,
  );
}

void main() {
  test('汇总本地已匹配且未看的集数', () {
    var files = [_file('01'), _file('02'), _file('03')];
    var links = [
      for (var i = 0; i < files.length; i++)
        PlaybackEpisodeLink(
          filePath: files[i].filePath,
          subject: 1,
          episode: 100 + i + 1,
        ),
    ];
    var unwatched = selectUnwatchedLocalEpisodes(
      subject: 1,
      files: files,
      links: links,
      chapters: [
        _chapter(101, 1, done: true),
        _chapter(102, 2, done: false),
        _chapter(103, 3),
      ],
      watchedEpisodes: 1,
    );
    expect(unwatched.map((item) => item.label), ['2', '3']);
    expect(unwatched.map((item) => item.filePath), [
      files[1].filePath,
      files[2].filePath,
    ]);
    expect(formatUnwatchedEpisodeSummary(unwatched), '未看 2');
  });

  test('本地已播完的文件不算未看', () {
    var file = _file('02');
    var unwatched = selectUnwatchedLocalEpisodes(
      subject: 1,
      files: [file],
      links: [
        PlaybackEpisodeLink(filePath: file.filePath, subject: 1, episode: 102),
      ],
      chapters: [_chapter(102, 2)],
      watchedEpisodes: 0,
      localByPath: {
        file.key: PlaybackItem(
          filePath: file.filePath,
          title: file.title,
          subject: 1,
          completed: true,
          positionMs: 1000,
          durationMs: 1000,
        ),
      },
    );
    expect(unwatched, isEmpty);
  });
}
