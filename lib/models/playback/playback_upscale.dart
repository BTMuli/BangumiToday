// Dart imports:
import 'dart:math' as math;

/// Quality changes the CNN size, independently of the requested output size.
///
/// The first four modes install GLSL shader presets through the renderer; the
/// two `janai` modes enable the AnimeJaNai inference filter instead, which is a
/// fixed 2x chain fed by the pinned mpv runtime and the native shim.
enum PlaybackUpscaleMode {
  off('关闭', ''),
  light('轻量', '优先流畅'),
  standard('标准', '画质与性能均衡'),
  high('高质量', '1080p → 4K · 较高 GPU 开销'),
  janaiSmooth('AI 流畅', 'Performance 模型 · 需要 NVIDIA + TensorRT'),
  janaiQuality('AI 高质量', 'Balanced 模型 · 需要 NVIDIA + TensorRT');

  const PlaybackUpscaleMode(this.label, this.description);
  final String label;
  final String description;

  /// Whether this mode runs the AnimeJaNai inference filter.
  bool get isJanai => this == janaiSmooth || this == janaiQuality;

  /// The filter slot that selects the model, or null for shader modes.
  /// Slot 1 is the smooth (Performance) model, slot 2 the high quality one.
  int? get janaiSlot => switch (this) {
    janaiSmooth => 1,
    janaiQuality => 2,
    _ => null,
  };

  static PlaybackUpscaleMode parse(String? value) =>
      values.where((mode) => mode.name == value).firstOrNull ?? off;
}

typedef PlaybackPixels = ({int width, int height});
typedef PlaybackViewport = ({double width, double height, double dpr});
typedef PlaybackVideoSource = ({int width, int height, String? gamma});

PlaybackVideoSource? playbackVideoSource({
  int? width,
  int? height,
  int? rotation,
  String? gamma,
}) {
  if (width == null || height == null || width <= 0 || height <= 0) return null;
  var rotated = (rotation ?? 0) % 180 == 90;
  return (
    width: rotated ? height : width,
    height: rotated ? width : height,
    gamma: gamma,
  );
}

class PlaybackUpscalePlan {
  const PlaybackUpscalePlan(
    this.reason, {
    this.output,
    this.mode = PlaybackUpscaleMode.off,
  });
  final String reason;

  /// Final renderer texture size, independently of a filter's model output.
  final PlaybackPixels? output;
  final PlaybackUpscaleMode mode;
  bool get enabled => output != null;

  @override
  bool operator ==(Object other) =>
      other is PlaybackUpscalePlan &&
      reason == other.reason &&
      output == other.output &&
      mode == other.mode;

  @override
  int get hashCode => Object.hash(reason, output, mode);
}

bool playbackSoftwareRenderer(String renderer) {
  var text = renderer.toLowerCase();
  return [
    'software rasterizer',
    'software renderer',
    'llvmpipe',
    'softpipe',
    'swiftshader',
    'microsoft basic render',
    'warp',
    'mesa x11',
  ].any(text.contains);
}

PlaybackUpscalePlan playbackUpscalePlan({
  required PlaybackUpscaleMode mode,
  required PlaybackVideoSource? source,
  required PlaybackViewport? viewport,
  required String? renderer,
  bool previouslyEnabled = false,
  int? maximumTextureSize,
}) {
  if (mode == PlaybackUpscaleMode.off) {
    return const PlaybackUpscalePlan('已关闭');
  }
  if (source == null || source.width <= 0 || source.height <= 0) {
    return const PlaybackUpscalePlan('等待视频参数');
  }
  var gamma = source.gamma?.toLowerCase();
  if (['pq', 'st2084', 'hlg', 'arib-std-b67'].contains(gamma)) {
    return const PlaybackUpscalePlan('HDR 暂未开放');
  }
  if (![
    'bt.1886',
    'srgb',
    'linear',
    'gamma1.8',
    'gamma2.2',
    'gamma2.8',
    'prophoto',
  ].contains(gamma)) {
    return const PlaybackUpscalePlan('等待确认 SDR 色彩');
  }
  // The AI filter produces fixed 2x frames within its own 4K budget. The final
  // texture uses the same viewport policy as Anime4K; mpv scales the filtered
  // frame to that target when its dimensions differ from the model output.
  if (mode.isJanai && (source.width > 1920 || source.height > 1080)) {
    return const PlaybackUpscalePlan('AI 超分上限为 1080p，保持普通播放');
  }
  if (viewport == null ||
      [
        viewport.width,
        viewport.height,
        viewport.dpr,
      ].any((value) => !value.isFinite || value <= 0)) {
    return const PlaybackUpscalePlan('等待可见画面');
  }
  if (renderer == null || renderer.isEmpty) {
    return const PlaybackUpscalePlan('等待渲染器信息');
  }
  if (playbackSoftwareRenderer(renderer)) {
    return const PlaybackUpscalePlan('软件渲染器暂不支持');
  }
  var horizontal = viewport.width * viewport.dpr / source.width;
  var vertical = viewport.height * viewport.dpr / source.height;
  var demand = math.min(horizontal, vertical);
  if (!demand.isFinite || demand <= (previouslyEnabled ? 1.01 : 1.03)) {
    return const PlaybackUpscalePlan('当前无需放大');
  }
  // This is an output budget, not a claim about unknown driver limits or the
  // shader's intermediate allocations. Native failures still require fallback.
  var edge = math.min(4096, maximumTextureSize ?? 4096);
  var scale = [
    demand,
    4.0,
    edge / math.max(source.width, source.height),
    math.sqrt(3840 * 2160 / source.width / source.height),
  ].reduce(math.min);
  var output = (
    width: (source.width * scale).floor(),
    height: (source.height * scale).floor(),
  );
  if (output.width <= source.width || output.height <= source.height) {
    return const PlaybackUpscalePlan('输出预算不足，保持普通播放');
  }
  return PlaybackUpscalePlan(
    scale + 0.001 < demand ? '已配置 · 输出受预算限制' : '已配置',
    output: output,
    mode: mode,
  );
}
