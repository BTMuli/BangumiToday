import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

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
/// selecting unverified shaders. Cache successful verification for this Player.
class PlaybackAnime4kAssets {
  PlaybackAnime4kAssets(this.directory);
  final String directory;
  Future<List<String>>? _verified;

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
  };

  Future<List<String>> load() {
    var previous = _verified;
    if (previous != null) return previous;
    var work = _load();
    _verified = work;
    unawaited(
      work.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_verified, work)) _verified = null;
        },
      ),
    );
    return work;
  }

  Future<List<String>> _load() async {
    var manifest = jsonDecode(
      await File(path.join(directory, 'manifest.json')).readAsString(),
    );
    if (manifest is! Map ||
        manifest['version'] != '4.0.1' ||
        jsonEncode(manifest['presets']?['light']) !=
            jsonEncode(shaders.keys.toList()) ||
        jsonEncode(manifest['sha256']) != jsonEncode(shaders)) {
      throw const FormatException('Anime4K 资源清单与已验证版本不一致');
    }
    var result = <String>[];
    for (var entry in shaders.entries) {
      var file = File(path.join(directory, entry.key)).absolute;
      // mpv's Windows path list uses semicolons. Never let a bundled path become
      // multiple list entries; spaces and Unicode remain ordinary arguments.
      if (file.path.contains(RegExp('[;\r\n\u0000]'))) {
        throw const FormatException('Anime4K 安装路径包含不支持的分隔符');
      }
      if (sha256.convert(await file.readAsBytes()).toString() != entry.value) {
        throw FormatException('Anime4K 资源校验失败：${entry.key}');
      }
      result.add(file.path);
    }
    return List.unmodifiable(result);
  }
}
