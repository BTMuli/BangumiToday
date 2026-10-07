// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../models/playback/playback_upscale.dart';

abstract final class PlaybackAssets {
  static String directory({
    required String executable,
    required String operatingSystem,
  }) {
    var paths = path.Context(
      style: operatingSystem == 'windows'
          ? path.Style.windows
          : path.Style.posix,
    );
    var directory = paths.dirname(executable);
    return paths.normalize(switch (operatingSystem) {
      'windows' => paths.join(directory, 'data', 'flutter_assets', 'assets'),
      'macos' => paths.join(
        directory,
        '..',
        'Frameworks',
        'App.framework',
        'Resources',
        'flutter_assets',
        'assets',
      ),
      _ => throw UnsupportedError('不支持的平台：$operatingSystem'),
    });
  }
}

/// Fixed upstream order and hashes prevent a modified manifest from silently
/// selecting different shaders. Cache successful verification per Player/mode.
class PlaybackAnime4kAssets {
  PlaybackAnime4kAssets(this.directory);
  final String directory;
  final _verified = <PlaybackUpscaleMode, Future<List<String>>>{};

  static const presets = {
    PlaybackUpscaleMode.light: [
      'Anime4K_Clamp_Highlights.glsl',
      'Anime4K_Restore_CNN_M.glsl',
      'Anime4K_Upscale_CNN_x2_M.glsl',
      'Anime4K_AutoDownscalePre_x2.glsl',
      'Anime4K_AutoDownscalePre_x4.glsl',
      'Anime4K_Upscale_CNN_x2_S.glsl',
    ],
    // Application-defined middle preset, using upstream L/L/M variants.
    PlaybackUpscaleMode.standard: [
      'Anime4K_Clamp_Highlights.glsl',
      'Anime4K_Restore_CNN_L.glsl',
      'Anime4K_Upscale_CNN_x2_L.glsl',
      'Anime4K_AutoDownscalePre_x2.glsl',
      'Anime4K_AutoDownscalePre_x4.glsl',
      'Anime4K_Upscale_CNN_x2_M.glsl',
    ],
    // Official Mode A HQ. At 1080p -> 2160p, the second upscale's WHEN skips
    // execution: the first x2 pass already produces the requested 4K image.
    PlaybackUpscaleMode.high: [
      'Anime4K_Clamp_Highlights.glsl',
      'Anime4K_Restore_CNN_VL.glsl',
      'Anime4K_Upscale_CNN_x2_VL.glsl',
      'Anime4K_AutoDownscalePre_x2.glsl',
      'Anime4K_AutoDownscalePre_x4.glsl',
      'Anime4K_Upscale_CNN_x2_M.glsl',
    ],
  };

  static const shaders = {
    'Anime4K_Clamp_Highlights.glsl':
        '8c5fb67c76bed3021f8a27b050c3b97a6ac1b284f9ce91c04189015c354c0217',
    'Anime4K_Restore_CNN_M.glsl':
        '67ea3ed26539e8de3b7d307688535d2ff17e8d147e11dda0247da7770dbecf41',
    'Anime4K_Upscale_CNN_x2_M.glsl':
        '716e02098a68f0d648761f2b96b4dd139e1cb09b174bb369fca3aa34328fff7e',
    'Anime4K_AutoDownscalePre_x2.glsl':
        '9141668ced0b26512253e6396e805820716f35b57c92950d9da489f8b96a7ba4',
    'Anime4K_AutoDownscalePre_x4.glsl':
        'dadb7b713cfa1d810c55b5deff616072f3390e546fed1e6a54f80ea555f7b95d',
    'Anime4K_Upscale_CNN_x2_S.glsl':
        '4c53ec2e287908f7ee7bcb266b0170421626d663576468b7d7dafc62962649a4',
    'Anime4K_Restore_CNN_L.glsl':
        'd6efe215e6ee8af1ec560478a91afc1df83fac4ba43b2c806ee61ca2267ed674',
    'Anime4K_Upscale_CNN_x2_L.glsl':
        'db1fedf7be82f6fd9034e6bf39b64daf2b7576988bb584ec38f24f5236b1cd97',
    'Anime4K_Restore_CNN_VL.glsl':
        '35036722733305cd4d4e57660b883bbe2569ba2914033c254327107d7b77e35e',
    'Anime4K_Upscale_CNN_x2_VL.glsl':
        '5638fe31c37c151a3443fea3451a3ef91af073f4dbb9615f6c0d1e29db11493d',
  };

  Future<List<String>> load(PlaybackUpscaleMode mode) {
    // The AnimeJaNai modes install a native filter chain instead of shader
    // presets, so they need no renderer assets.
    if (mode == PlaybackUpscaleMode.off || mode.isJanai) {
      return Future.value(const []);
    }
    var previous = _verified[mode];
    if (previous != null) return previous;
    var work = _load(mode);
    _verified[mode] = work;
    unawaited(
      work.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_verified[mode], work)) _verified.remove(mode);
        },
      ),
    );
    return work;
  }

  Future<List<String>> _load(PlaybackUpscaleMode mode) async {
    var manifest = jsonDecode(
      await File(path.join(directory, 'manifest.json')).readAsString(),
    );
    if (manifest is! Map ||
        manifest['version'] != '4.0.1' ||
        jsonEncode(manifest['presets']) !=
            jsonEncode({
              for (var entry in presets.entries) entry.key.name: entry.value,
            }) ||
        jsonEncode(manifest['sha256']) != jsonEncode(shaders)) {
      throw const FormatException('Anime4K 资源清单与已验证版本不一致');
    }
    var result = <String>[];
    for (var name in presets[mode]!) {
      var file = File(path.join(directory, name)).absolute;
      // mpv's Windows path list uses semicolons. A bundled path must remain
      // one list entry; spaces and Unicode remain ordinary arguments.
      if (file.path.contains(RegExp('[;\r\n\u0000]'))) {
        throw const FormatException('Anime4K 安装路径包含不支持的分隔符');
      }
      if (sha256.convert(await file.readAsBytes()).toString() !=
          shaders[name]) {
        throw FormatException('Anime4K 资源校验失败：$name');
      }
      result.add(file.path);
    }
    return List.unmodifiable(result);
  }
}
