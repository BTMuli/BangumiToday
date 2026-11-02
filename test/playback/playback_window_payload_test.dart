// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/playback_window_protocol.dart';
import 'package:bangumi_today/models/app/bangumi_mirror.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_episode.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';
import 'package:bangumi_today/pages/playback/playback_label.dart';

BangumiMirrorCatalog _sampleCatalog() => const BangumiMirrorCatalog()
    .save(
      BangumiMirrorType.api,
      BangumiMirror(name: '旧 API', url: 'https://old-api.example.test'),
    )
    .save(
      BangumiMirrorType.api,
      BangumiMirror(name: '自定义 API', url: 'https://api.example.test'),
      originalUrl: 'https://old-api.example.test',
    )
    .save(
      BangumiMirrorType.image,
      BangumiMirror(name: '自定义图片', url: 'https://img.example.test'),
    );

/// 主窗口 `PlaybackWindowService._presentation()` 下发的载荷。
Map<String, Object?> _presentationPayload() => {
  'theme': 'system',
  'accent': 0xFF0078D4,
  'bangumiUrl': 'https://api.bgm.tv',
  'bangumiUsePrivateApi': true,
  'bangumiSiteUrl': 'https://bgm.tv',
  'bangumiImageUrl': 'https://lain.bgm.tv',
  'bangumiMirrorCatalog': _sampleCatalog().toJson(),
  'episodeRules': [
    PlaybackEpisodeRule(
      id: 'takt',
      subject: 1,
      pattern: r'^\[LoliHouse\] takt op\.Destiny - (\d+) .*$',
      offset: -11,
      type: 0,
      exampleFile: '[LoliHouse] takt op.Destiny - 12 [1080p].mkv',
    ).toJson(),
  ],
  'episodeLinks': [
    const PlaybackEpisodeLink(
      filePath: 'D:/Anime/Show - 02.mkv',
      subject: 1,
      episode: 1013,
    ).toJson(),
  ],
  'episodes': {'revision': 1, 'items': const <Object?>[]},
};

/// 使用真实编解码器生成跨引擎载荷，包括所有嵌套映射。
Object? _codecRoundTrip(Object? value) {
  const codec = StandardMessageCodec();
  return codec.decodeMessage(codec.encodeMessage(value));
}

void main() {
  group('playback window payload', () {
    test(
      'manual links and chapter metadata label child-window specials as 13',
      () {
        var body = playbackMap(_codecRoundTrip(_presentationPayload()));
        var links = [
          for (var value in body['episodeLinks'] as List)
            PlaybackEpisodeLink.fromJson(playbackMap(value)),
        ];
        // The host's episodes.chapters reply also crosses StandardMessageCodec.
        var chapters =
            _codecRoundTrip([
                  {
                    'id': 1013,
                    'type': 1,
                    'name': 'Special',
                    'name_cn': '特别篇',
                    'sort': 13.0,
                    'ep': 1.0,
                    'airdate': '',
                    'comment': 0,
                    'duration': '',
                    'desc': '',
                    'disc': 0,
                    'duration_seconds': 0,
                  },
                ])
                as List;
        var label = PlaybackLabel.fromItem(
          const PlaybackItem(
            filePath: 'D:/Anime/Show - 02.mkv',
            title: 'Show - 02.mkv',
            subject: 1,
          ),
          manualLink: links.single,
          chapters: [
            for (var chapter in chapters)
              BangumiEpisode.fromJson(playbackMap(chapter)),
          ],
        );
        expect(label.episodeNumber, '13');
      },
    );

    test('episode rules survive the codec and label child-window items', () {
      var body = playbackMap(_codecRoundTrip(_presentationPayload()));
      var rules = [
        for (var value in body['episodeRules'] as List)
          PlaybackEpisodeRule.fromJson(playbackMap(value)),
      ];
      var label = PlaybackLabel.fromItem(
        const PlaybackItem(
          filePath: 'D:/Anime/[LoliHouse] takt op.Destiny - 12 [1080p].mkv',
          title: '[LoliHouse] takt op.Destiny - 12 [1080p].mkv',
          subject: 1,
        ),
        rules: rules,
      );

      expect(label.episodeNumber, '1');
      expect(rules.single.type, 0);
      expect(rules.single.id, 'takt');
    });

    test('mirror catalog survives the cross-engine payload', () {
      var body = playbackMap(_codecRoundTrip(_presentationPayload()));
      var catalog = BangumiMirrorCatalog.fromJson(
        playbackMap(body['bangumiMirrorCatalog']),
      );
      expect(catalog, _sampleCatalog());
    });

    test('fromJson accepts catalogs decoded directly by the codec', () {
      var delivered = _codecRoundTrip(_sampleCatalog().toJson());
      expect(
        BangumiMirrorCatalog.fromJson(delivered as Map<Object?, Object?>),
        _sampleCatalog(),
      );
    });

    test('fromJson still accepts the JSON-decoded database shape', () {
      var decoded = jsonDecode(jsonEncode(_sampleCatalog().toJson()));
      expect(BangumiMirrorCatalog.fromJson(decoded), _sampleCatalog());
    });

    test('an empty mirror catalog survives the codec round trip', () {
      var delivered = _codecRoundTrip(const BangumiMirrorCatalog().toJson());
      expect(
        BangumiMirrorCatalog.fromJson(delivered as Map<Object?, Object?>),
        const BangumiMirrorCatalog(),
      );
    });

    test('playbackMap keeps the values the player window reads', () {
      var body = playbackMap(_codecRoundTrip(_presentationPayload()));
      expect(body['theme'], 'system');
      expect(body['accent'], 0xFF0078D4);
      expect(body['bangumiUsePrivateApi'], isTrue);
      expect(playbackMap(body['episodes'])['revision'], 1);
    });
  });
}
