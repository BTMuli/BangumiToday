// Project imports:
import 'playback_upscale.dart';

/// The catalog measures V3.1 Standard profiles offscreen, not our renderer.
class PlaybackJanaiBenchmarkCatalog {
  const PlaybackJanaiBenchmarkCatalog(this.generatedAt, this.samples);

  static const url = 'https://benchmarks.animejan.ai/';
  static const dataUrl = '${url}benchmarks.json';
  final DateTime generatedAt;
  final List<PlaybackJanaiBenchmarkSample> samples;

  factory PlaybackJanaiBenchmarkCatalog.fromJson(Map<String, dynamic> json) {
    var samples = <PlaybackJanaiBenchmarkSample>[];
    for (var item in json['submissions'] as List) {
      if (item is! Map<String, dynamic> ||
          item['backend'] != 'TensorRT' ||
          // Earlier versions use VapourSynth; future profiles need review.
          !RegExp(
            r'^3\.[4-7]\.\d+$',
          ).hasMatch(item['app_version'] as String? ?? '')) {
        continue;
      }
      var gpu = item['gpu'];
      var results = item['results'];
      if (gpu is! String || gpu.isEmpty || results is! Map<String, dynamic>) {
        continue;
      }
      var profiles = <PlaybackUpscaleMode, Map<String, double>>{};
      for (var (name, mode) in [
        ('Performance', PlaybackUpscaleMode.janaiSmooth),
        ('Balanced', PlaybackUpscaleMode.janaiQuality),
      ]) {
        var values = results[name];
        if (values is! Map<String, dynamic>) continue;
        profiles[mode] = {
          for (var entry in values.entries)
            if (entry.value is num &&
                (entry.value as num).isFinite &&
                ((entry.value as num) > 0 || entry.value == -1))
              entry.key: (entry.value as num).toDouble(),
        };
      }
      samples.add(PlaybackJanaiBenchmarkSample(gpu, profiles));
    }
    return PlaybackJanaiBenchmarkCatalog(
      DateTime.parse(json['generated_at'] as String).toUtc(),
      List.unmodifiable(samples),
    );
  }

  /// Preserve Ti, SUPER, VRAM variants and Laptop GPU in the identity.
  static String gpuKey(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\((r|tm)\)|[®™]'), '')
      .replaceFirst(RegExp(r'^(nvidia\s+)?(geforce\s+)?'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// ANGLE identifies the adapter actually presenting the video.
  static String rendererGpu(String renderer) {
    var angle = RegExp(
      r'^ANGLE \([^,]+, (.+?)(?: \(0x[\da-f]+\))? Direct3D11\b',
      caseSensitive: false,
    ).firstMatch(renderer);
    if (angle != null) return angle.group(1)!;
    return renderer.startsWith('NVIDIA ') ? renderer : '';
  }

  PlaybackJanaiRecommendation recommend({
    required String gpu,
    required int width,
    required int height,
    required double fps,
    double rate = 1,
    bool supported = true,
  }) {
    if (!supported) {
      return const PlaybackJanaiRecommendation('当前显卡或驱动不支持 AI 超分');
    }
    if (gpu.isEmpty) {
      return const PlaybackJanaiRecommendation('等待实际播放显卡');
    }
    if (width <= 0 || height <= 0 || !fps.isFinite || fps <= 0) {
      return const PlaybackJanaiRecommendation('等待片源分辨率与帧率');
    }
    if (!rate.isFinite || rate <= 0) {
      return const PlaybackJanaiRecommendation('等待播放倍率');
    }
    var resolution = width <= 1280 && height <= 720
        ? '1280x720'
        : width <= 1920 && height <= 1080
        ? '1920x1080'
        : null;
    if (resolution == null) {
      return const PlaybackJanaiRecommendation('AI 超分上限为 1080p');
    }
    var matches = samples.where((sample) => gpuKey(sample.gpu) == gpuKey(gpu));
    var estimates = <PlaybackUpscaleMode, PlaybackJanaiBenchmarkEstimate>{};
    for (var mode in [
      PlaybackUpscaleMode.janaiSmooth,
      PlaybackUpscaleMode.janaiQuality,
    ]) {
      var values = [
        for (var sample in matches) ?sample.profiles[mode]?[resolution],
      ];
      if (values.isEmpty) continue;
      var measured = values.where((value) => value > 0).toList()..sort();
      estimates[mode] = PlaybackJanaiBenchmarkEstimate(
        count: values.length,
        incomplete: values.length - measured.length,
        minimum: measured.firstOrNull,
        maximum: measured.lastOrNull,
      );
    }
    var target = fps * rate;
    var recommended =
        [PlaybackUpscaleMode.janaiQuality, PlaybackUpscaleMode.janaiSmooth]
            .where(
              (mode) => (estimates[mode]?.conservativeFps ?? 0) >= target * 2,
            )
            .firstOrNull;
    return PlaybackJanaiRecommendation(
      recommended != null
          ? '推荐 ${recommended.label}'
          : estimates.isEmpty
          ? '暂无同型号 TensorRT benchmark'
          : 'AI 档位余量不足，建议关闭 AI 超分',
      mode: recommended,
      estimates: estimates,
      reference: '$gpu · $resolution · ${target.toStringAsFixed(2)} fps',
      targetFps: target,
    );
  }
}

class PlaybackJanaiBenchmarkSample {
  const PlaybackJanaiBenchmarkSample(this.gpu, this.profiles);
  final String gpu;
  final Map<PlaybackUpscaleMode, Map<String, double>> profiles;
}

class PlaybackJanaiBenchmarkEstimate {
  const PlaybackJanaiBenchmarkEstimate({
    required this.count,
    required this.incomplete,
    required this.minimum,
    required this.maximum,
  });
  final int count;
  final int incomplete;
  final double? minimum;
  final double? maximum;
  // -1 represents a slow/failed cell, never an unmeasured or fast sample.
  double get conservativeFps => incomplete > 0 ? 0 : minimum ?? 0;
  String get label {
    if (minimum == null) return '$count 份样本均未完成测试';
    var range = minimum == maximum
        ? minimum!.toStringAsFixed(1)
        : '${minimum!.toStringAsFixed(1)}–${maximum!.toStringAsFixed(1)}';
    return '$range fps · $count 份样本'
        '${incomplete > 0 ? ' · $incomplete 份未完成' : ''}';
  }
}

class PlaybackJanaiRecommendation {
  const PlaybackJanaiRecommendation(
    this.label, {
    this.mode,
    this.estimates = const {},
    this.reference = '',
    this.targetFps = 0,
  });
  final String label;
  final PlaybackUpscaleMode? mode;
  final Map<PlaybackUpscaleMode, PlaybackJanaiBenchmarkEstimate> estimates;
  final String reference;
  final double targetFps;

  String description(PlaybackUpscaleMode profile) {
    var estimate = estimates[profile];
    if (estimate == null) {
      return estimates.isEmpty ? label : '该档位暂无同型号测试数据';
    }
    var headroom = estimate.incomplete > 0
        ? '暂不推荐'
        : estimate.conservativeFps >= targetFps * 2
        ? '有实时余量'
        : estimate.conservativeFps >= targetFps
        ? '实时余量有限'
        : '低于实时需求';
    return '${estimate.label} · $headroom';
  }
}
