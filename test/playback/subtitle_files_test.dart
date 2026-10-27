// Dart imports:
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'package:bangumi_today/core/services/playback_subtitle_files.dart';
import 'package:bangumi_today/core/services/playback_window_data_host.dart';
import 'package:bangumi_today/core/services/playback_window_protocol.dart';
import 'package:bangumi_today/data/repositories/playback_window_remote.dart';
import 'package:bangumi_today/domain/repositories/playback_cover.dart';
import 'package:bangumi_today/domain/repositories/playback_history.dart';
import 'package:bangumi_today/domain/repositories/playback_library.dart';
import 'package:bangumi_today/domain/repositories/playback_settings.dart';
import 'package:bangumi_today/domain/repositories/playback_subjects.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';
import 'package:bangumi_today/models/playback/playback_subtitle.dart';

PlaybackItem _video(String name) =>
    PlaybackItem(filePath: path.absolute('videos/$name'), title: name);

class _Settings extends PlaybackSettingsStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key] ?? '';

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _UnusedPlaybackData extends Fake
    implements
        PlaybackLibrary,
        PlaybackHistoryStore,
        PlaybackSubjectResolver,
        PlaybackCoverResolver {}

RemotePlaybackSettings _remoteSettings(PlaybackSettingsStore settings) {
  const identity = PlaybackWindowIdentity('subtitle-settings-test');
  const codec = StandardMessageCodec();
  var unused = _UnusedPlaybackData();
  var host = PlaybackWindowDataHost(
    identity: identity,
    library: unused,
    history: unused,
    settings: settings,
    subjects: unused,
    cover: unused,
    onCoverResolved: () {},
    onHistoryChanged: () {},
  );
  addTearDown(host.close);
  var sequence = 0;
  return RemotePlaybackSettings((method, body) async {
    var request = codec.decodeMessage(
      codec.encodeMessage(identity.request(++sequence, body)),
    );
    var reply = await host.handle(method, request);
    return codec.decodeMessage(codec.encodeMessage(reply));
  });
}

void main() {
  test('只接受支持的字幕扩展名，忽略无扩展名文件', () {
    expect(PlaybackSubtitleFiles.isSubtitle('readme'), isFalse);
    expect(PlaybackSubtitleFiles.isSubtitle('fonts/font.ttf'), isFalse);
    expect(PlaybackSubtitleFiles.isSubtitle('episode.ASS'), isTrue);
    expect(PlaybackSubtitleFiles.isSubtitle('episode.srt'), isTrue);
  });

  test('整季同名字幕按集关联，保留每集全部语言', () {
    var first = _video('[Group] Show - 01 [1080p].mkv');
    var second = _video('[Group] Show - 02 [1080p].mkv');
    var files = [
      'subs/[Group] Show - 01 [1080p].chs.ass',
      'subs/[Group] Show - 01 [1080p].cht.ass',
      'subs/[Group] Show - 02 [1080p].zh-Hans.srt',
    ];
    var result = PlaybackSubtitleFiles.match(files, [first, second]);
    expect(result.matches[first.key], files.take(2));
    expect(result.matches[second.key], [files.last]);
    expect(result.matchedFiles, 3);
    expect(result.unmatchedFiles, 0);
  });

  test('字幕组和画质不同仍可按片名及集数匹配', () {
    var video = _video('[Group A] Show - 02 [1080p].mkv');
    var file = 'subs/[Group B] Show [02] [720p].简日.ass';
    var result = PlaybackSubtitleFiles.match([file], [video]);
    expect(result.matches[video.key], [file]);
  });

  test('纯集数和中文集数字幕支持多个剧集', () {
    var first = _video('Show - 01.mkv');
    var second = _video('Show - 02.mkv');
    var files = ['subs/01.chs.ass', 'subs/第02集.繁体.ass'];
    var result = PlaybackSubtitleFiles.match(files, [first, second]);
    expect(result.matches[first.key], [files.first]);
    expect(result.matches[second.key], [files.last]);
  });

  test('同季不同集和不同季同集均不混配', () {
    var first = _video('Show S01E01.mkv');
    var second = _video('Show S02E01.mkv');
    var files = [
      'subs/Show.S02E01.chs.ass',
      'subs/Show.S01E02.chs.ass',
      'subs/01.chs.ass',
    ];
    var result = PlaybackSubtitleFiles.match(files, [first, second]);
    expect(result.matches[first.key], isNull);
    expect(result.matches[second.key], [files.first]);
    expect(result.unmatchedFiles, 2);
  });

  test('同集号对应多个视频时跳过，同名文件仍能精确匹配', () {
    var first = _video('[Group A] Show - 01.mkv');
    var second = _video('[Group B] Show - 01.mkv');
    var files = ['subs/01.chs.ass', 'subs/[Group B] Show - 01.chs.ass'];
    var result = PlaybackSubtitleFiles.match(files, [first, second]);
    expect(result.matches[first.key], isNull);
    expect(result.matches[second.key], [files.last]);
    expect(result.unmatchedFiles, 1);
  });

  test('不同番剧、范围字幕和特典不会仅因集号相同而匹配', () {
    var video = _video('Show - 01.mkv');
    var files = [
      'subs/Another Show - 01.chs.ass',
      'subs/Show - 01-02.chs.ass',
      'subs/Show NCOP01.chs.ass',
      'subs/Show - 010.chs.ass',
    ];
    var result = PlaybackSubtitleFiles.match(files, [video]);
    expect(result.matches, isEmpty);
    expect(result.unmatchedFiles, files.length);
  });

  test('电影与特典支持同名字幕，语言词片名优先完整匹配', () {
    var movie = _video('Movie.mkv');
    var english = _video('Movie English.mkv');
    var extra = _video('Show NCOP01.mkv');
    var files = [
      'subs/Movie.chs.ass',
      'subs/Movie English.chs.ass',
      'subs/Show NCOP01.chs.ass',
    ];
    var result = PlaybackSubtitleFiles.match(files, [movie, english, extra]);
    expect(result.matches[movie.key], [files[0]]);
    expect(result.matches[english.key], [files[1]]);
    expect(result.matches[extra.key], [files[2]]);
  });

  test('重复路径不会重复导入，大小写扩展名可匹配', () {
    var video = _video('Show - 01.mkv');
    var files = ['subs/SHOW - 01.CHS.ASS', 'subs/SHOW - 01.CHS.ASS'];
    var result = PlaybackSubtitleFiles.match(files, [video, video]);
    expect(result.matches[video.key], [files.first]);
    expect(result.files, [files.first]);
  });

  test('小数集数与整数集数分别匹配', () {
    var first = _video('Show - 13.mkv');
    var recap = _video('Show - 13.5.mkv');
    var files = ['subs/13.chs.ass', 'subs/13.5.chs.ass'];
    var result = PlaybackSubtitleFiles.match(files, [first, recap]);
    expect(result.matches[first.key], [files.first]);
    expect(result.matches[recap.key], [files.last]);
  });

  group('导入后的自动轨道选择', () {
    PlaybackSubtitleMetadata track(
      String id,
      String? title, {
      bool isDefault = false,
    }) => (id: id, title: title, language: null, isDefault: isDefault);

    test('同语言优先导入字幕，语言优先级保持简中优于繁中', () {
      var tracks = [
        track('1', '简体中文', isDefault: true),
        track('2', '02.chs.ass'),
        track('3', '02.cht.ass'),
      ];
      expect(preferredPlaybackSubtitle(tracks, imported: {'2', '3'}), '2');
      expect(preferredPlaybackSubtitle(tracks, imported: {'3'}), '1');
      expect(preferredPlaybackSubtitle(tracks), '1');
    });

    test('语言未知时可选导入字幕，普通未知轨道仍保持关闭', () {
      var tracks = [
        track('auto', null),
        track('no', null),
        track('1', '01.ass'),
      ];
      expect(preferredPlaybackSubtitle(tracks, imported: {'1'}), '1');
      expect(preferredPlaybackSubtitle(tracks), 'no');
      expect(preferredPlaybackSubtitle(tracks, imported: {'auto', 'no'}), 'no');
    });

    test('导入轨道的默认标记只在同一语言内生效', () {
      var tracks = [
        track('1', '01.chs.ass'),
        track('2', '01.chs.ass', isDefault: true),
        track('3', '01.cht.ass', isDefault: true),
      ];
      expect(preferredPlaybackSubtitle(tracks, imported: {'1', '2', '3'}), '2');
    });
  });

  test('独立窗口读写含中文、空格和方括号的视频字幕关联', () async {
    var settings = _Settings();
    var remote = _remoteSettings(settings);
    var subtitles = PlaybackSubtitleFiles(remote);
    var video = _video(
      '剃须。 然后捡到女高中生。/[BDRip]/'
      '[Nekomoe kissaten] Higehiro [01][BDRip 1080p HEVC-10bit FLAC].mkv',
    );
    expect(await subtitles.read(video), isEmpty);
    var key = '${PlaybackSubtitleFiles.settingsKeyPrefix}${video.key}';
    var files = [path.absolute('字幕/第一集.chs.ass')];
    await remote.write(key, jsonEncode(files));
    expect(await subtitles.read(video), files);
    expect(await PlaybackSubtitleFiles(settings).read(video), files);
  });

  test('独立窗口允许原有配置，继续拒绝其他配置和不完整字幕键', () async {
    var settings = _Settings();
    var remote = _remoteSettings(settings);
    await remote.write('playbackRememberedRate', '1.5');
    expect(await remote.read('playbackRememberedRate'), '1.5');
    for (var key in [
      'bangumiToken',
      PlaybackSubtitleFiles.settingsKeyPrefix,
      'playbackSubtitlesOther:video.mkv',
    ]) {
      await expectLater(remote.read(key), throwsStateError);
      await expectLater(remote.write(key, '[]'), throwsStateError);
      expect(settings.values.containsKey(key), isFalse);
    }
  });

  for (var remote in [false, true]) {
    group(remote ? '独立窗口目录扫描与关联存储' : '目录扫描与关联存储', () {
      late Directory directory;

      setUp(() async {
        var parent = Directory(path.absolute('temp/subtitle-directory-check'));
        await parent.create(recursive: true);
        directory = await parent.createTemp('fixtures-');
      });

      tearDown(() async {
        var parent = directory.parent;
        await directory.delete(recursive: true);
        if (await parent.list().isEmpty) await parent.delete();
      });

      test('递归扫描子目录并持久保存多集关联，重复导入合并去重', () async {
        var first = _video('Show - 01.mkv');
        var second = _video('Show - 02.mkv');
        var settings = _Settings();
        var subtitles = PlaybackSubtitleFiles(
          remote ? _remoteSettings(settings) : settings,
        );
        var nested = await Directory(path.join(directory.path, '简体')).create();
        var firstSubtitle = await File(
          path.join(nested.path, '01.chs.ass'),
        ).writeAsString('');
        var secondSubtitle = await File(
          path.join(directory.path, '02.chs.srt'),
        ).writeAsString('');
        await File(path.join(directory.path, 'README')).writeAsString('');
        await File(path.join(nested.path, 'font.ttf')).writeAsString('');

        var result = await subtitles.importDirectory(directory.path, [
          first,
          second,
        ]);
        expect(result.files, hasLength(2));
        expect(result.matches, hasLength(2));
        var reopened = PlaybackSubtitleFiles(
          remote ? _remoteSettings(settings) : settings,
        );
        expect(await reopened.read(first), [firstSubtitle.path]);
        expect(await reopened.read(second), [secondSubtitle.path]);

        var traditional = await File(
          path.join(directory.path, '01.cht.ass'),
        ).writeAsString('');
        await reopened.importDirectory(directory.path, [first, second]);
        expect(await reopened.read(first), [
          firstSubtitle.path,
          traditional.path,
        ]);
        expect(await reopened.read(second), [secondSubtitle.path]);
      });

      test('空目录和未匹配文件不写入关联', () async {
        var settings = _Settings();
        var subtitles = PlaybackSubtitleFiles(
          remote ? _remoteSettings(settings) : settings,
        );
        var video = _video('Show - 01.mkv');
        var empty = await subtitles.importDirectory(directory.path, [video]);
        expect(empty.files, isEmpty);
        await File(path.join(directory.path, '03.chs.ass')).writeAsString('');
        var unmatched = await subtitles.importDirectory(directory.path, [
          video,
        ]);
        expect(unmatched.unmatchedFiles, 1);
        expect(settings.values, isEmpty);
      });
    });
  }
}
