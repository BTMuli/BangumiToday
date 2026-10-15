// Dart imports:
import 'dart:convert';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/playback_window_protocol.dart';
import 'package:bangumi_today/models/app/bangumi_mirror.dart';

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
  'bangumiSiteUrl': 'https://bgm.tv',
  'bangumiImageUrl': 'https://lain.bgm.tv',
  'bangumiMirrorCatalog': _sampleCatalog().toJson(),
  'episodes': {'revision': 1, 'items': const <Object?>[]},
};

/// 使用真实编解码器生成跨引擎载荷，包括所有嵌套映射。
Object? _codecRoundTrip(Object? value) {
  const codec = StandardMessageCodec();
  return codec.decodeMessage(codec.encodeMessage(value));
}

void main() {
  group('playback window payload', () {
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
      expect(playbackMap(body['episodes'])['revision'], 1);
    });
  });
}
