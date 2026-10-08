/// Status from this Player's own native bridge, scoped to its configuration.
class PlaybackJanaiStatus {
  const PlaybackJanaiStatus({
    required this.phase,
    required this.backend,
    required this.reason,
    required this.backendReason,
    required this.frames,
    required this.gpuMilliseconds,
    this.gpuName = '',
    this.gpuVendor = 0,
    this.gpuSm = 0,
    this.gpuDriver = 0,
    this.buildLog = '',
    this.buildLines = const [],
  });

  final String phase;
  final String backend;
  final String reason;
  final String backendReason;
  final int frames;
  final double gpuMilliseconds;
  final String gpuName;
  final int gpuVendor;
  final int gpuSm;
  final int gpuDriver;
  final String buildLog;
  final List<String> buildLines;
  bool get preparing => phase == 'preparing';
  bool get active => phase == 'active' && frames > 0;
  String get label => preparing
      ? '正在准备 TensorRT 模型，准备期间正常播放'
      : phase == 'resources_missing'
      ? '需要下载 TensorRT 组件，当前正常播放'
      : active
      ? '${backend == 'tensorrt' ? 'TensorRT' : 'DirectML'} · '
            '${gpuMilliseconds.toStringAsFixed(1)} ms'
      : 'AI 模型尚未输出';

  static PlaybackJanaiStatus parse(String text) {
    var fields = <String, String>{};
    for (var line in text.split('\n')) {
      var index = line.indexOf('=');
      if (index > 0) {
        fields[line.substring(0, index)] = line.substring(index + 1).trim();
      }
    }
    if (fields['schemaVersion'] != '1' ||
        ![
          'preparing',
          'resources_missing',
          'configured',
          'active',
          'failed',
          'passthrough',
        ].contains(fields['phase']) ||
        !['none', 'directml', 'tensorrt'].contains(fields['backend']) ||
        (fields['phase'] == 'active' && fields['backend'] == 'none')) {
      throw const FormatException('无法识别的 AI 超分状态');
    }
    var frames = int.parse(fields['framesInferred']!);
    var elapsed = double.parse(fields['lastGpuMs']!);
    if (frames < 0 || !elapsed.isFinite || elapsed < 0) {
      throw const FormatException('无效的 AI 超分计数');
    }
    return PlaybackJanaiStatus(
      phase: fields['phase']!,
      backend: fields['backend']!,
      reason: fields['reason']!,
      backendReason: fields['backendReason']!,
      frames: frames,
      gpuMilliseconds: elapsed,
      gpuName: fields['gpuName'] ?? '',
      gpuVendor: int.parse(fields['gpuVendor'] ?? '0'),
      gpuSm: int.parse(fields['gpuSm'] ?? '0'),
      gpuDriver: int.parse(fields['gpuDriver'] ?? '0'),
      buildLog: fields['buildLog'] ?? '',
    );
  }

  PlaybackJanaiStatus withBuildLines(List<String> lines) => PlaybackJanaiStatus(
    phase: phase,
    backend: backend,
    reason: reason,
    backendReason: backendReason,
    frames: frames,
    gpuMilliseconds: gpuMilliseconds,
    gpuName: gpuName,
    gpuVendor: gpuVendor,
    gpuSm: gpuSm,
    gpuDriver: gpuDriver,
    buildLog: buildLog,
    buildLines: List.unmodifiable(lines),
  );
}
