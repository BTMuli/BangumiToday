// Dart imports:
import 'dart:async';
import 'dart:math' as math;

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/services/bt_engine_client.dart';
import '../../core/theme/bt_theme.dart';
import '../../store/bt_download_store.dart';
import 'download_rate_history.dart';

final downloadRateGraphsVisibleProvider =
    NotifierProvider<DownloadRateGraphsVisible, bool>(
      DownloadRateGraphsVisible.new,
    );

class DownloadRateGraphsVisible extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final _rateHistoryProvider = Provider.autoDispose<DownloadRateHistory>((ref) {
  var history = DownloadRateHistory();
  void sample() {
    var store = ref.read(btDownloadStoreProvider);
    history.record({
      if (store.engineState == BtEngineClientState.ready)
        for (var task in store.tasks)
          task.id: (download: task.downloadRate, upload: task.uploadRate),
    }, history.elapsed);
  }

  sample();
  var timer = Timer.periodic(const Duration(seconds: 1), (_) => sample());
  ref.onDispose(() {
    timer.cancel();
    history.dispose();
  });
  return history;
});

class DownloadRateBackground extends ConsumerStatefulWidget {
  const DownloadRateBackground({required this.child, this.taskIds, super.key});

  final Widget child;

  /// null 为全部任务；条目分组与单个任务使用同一批采样的子集。
  final List<String>? taskIds;

  static const pixelsPerSecond = 8.0;
  // 左侧额外保留四个采样间隔，端点在容器之外过渡，最后再裁剪。
  static const transitionWidth = pixelsPerSecond * 4;

  static Color downloadColor(BuildContext context) {
    return FluentTheme.of(context).brightness == Brightness.dark
        ? const Color(0xFF67B9F0)
        : BTColors.info;
  }

  @override
  ConsumerState<DownloadRateBackground> createState() =>
      _DownloadRateBackgroundState();
}

class _DownloadRateBackgroundState extends ConsumerState<DownloadRateBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll;
  final DownloadRateScale _downloadScale = DownloadRateScale();
  final DownloadRateScale _uploadScale = DownloadRateScale();
  DownloadRateHistory? _history;
  var _animate = false;
  var _visible = true;

  @override
  void initState() {
    super.initState();
    _scroll = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant DownloadRateBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.taskIds, widget.taskIds)) _syncAnimation();
  }

  void _syncAnimation() {
    var active =
        _animate &&
        _visible &&
        (_history?.hasActivityFor(widget.taskIds) ?? false);
    if (active && !_scroll.isAnimating) {
      _scroll.repeat();
    } else if (!active && _scroll.isAnimating) {
      _scroll.stop();
    }
  }

  @override
  void dispose() {
    _history?.removeListener(_syncAnimation);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var visible = ref.watch(downloadRateGraphsVisibleProvider);
    if (_visible != visible) {
      _visible = visible;
      _syncAnimation();
    }
    var history = ref.watch(_rateHistoryProvider);
    if (_history != history) {
      _history?.removeListener(_syncAnimation);
      _history = history..addListener(_syncAnimation);
      _syncAnimation();
    }
    var dark = FluentTheme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        history.retainFor(
          Duration(
            milliseconds:
                ((constraints.maxWidth +
                            DownloadRateBackground.transitionWidth) /
                        DownloadRateBackground.pixelsPerSecond *
                        1000)
                    .ceil() +
                2000,
          ),
        );
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: !_visible
                  ? const SizedBox.shrink()
                  : IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _RateHistoryPainter(
                            history: history,
                            animation: _scroll,
                            animate: _animate,
                            downloadScale: _downloadScale,
                            uploadScale: _uploadScale,
                            taskIds: widget.taskIds,
                            downloadColor: DownloadRateBackground.downloadColor(
                              context,
                            ),
                            uploadColor: BTColors.successLight(context),
                            dark: dark,
                          ),
                          willChange: true,
                        ),
                      ),
                    ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _RateHistoryPainter extends CustomPainter {
  _RateHistoryPainter({
    required this.history,
    required this.animation,
    required this.animate,
    required this.downloadScale,
    required this.uploadScale,
    required this.taskIds,
    required this.downloadColor,
    required this.uploadColor,
    required this.dark,
  }) : super(repaint: Listenable.merge([history, animation]));

  final DownloadRateHistory history;
  final AnimationController animation;
  final bool animate;
  final DownloadRateScale downloadScale;
  final DownloadRateScale uploadScale;
  final List<String>? taskIds;
  final Color downloadColor;
  final Color uploadColor;
  final bool dark;
  Size? _cachedSize;
  var _cachedRevision = -1;
  Path? _download;
  Path? _upload;
  Path? _area;
  Paint? _areaPaint;
  var _downloadPathScale = 1024.0;
  var _uploadPathScale = 1024.0;

  void _preparePaths(Size size) {
    if (_cachedSize == size && _cachedRevision == history.revision) return;
    _cachedSize = size;
    _cachedRevision = history.revision;
    _download = _upload = _area = null;
    var latest = history.frames.last.elapsed;
    var points = <({double x, DownloadRateSample rates})>[];
    var downloadPeak = 0;
    var uploadPeak = 0;
    for (var frame in history.frames) {
      var age =
          (latest - frame.elapsed).inMicroseconds /
          Duration.microsecondsPerSecond;
      var x = size.width - age * DownloadRateBackground.pixelsPerSecond;
      if (x < -DownloadRateBackground.transitionWidth) continue;
      var rates = frame.ratesFor(taskIds);
      downloadPeak = math.max(downloadPeak, rates.download);
      uploadPeak = math.max(uploadPeak, rates.upload);
      points.add((x: x, rates: rates));
    }
    if ((downloadPeak == 0 && uploadPeak == 0) || points.length < 2) return;

    var bottom = size.height - 3;
    var height = size.height * 0.68;
    _downloadPathScale = math.max(downloadPeak * 1.15, 1024.0);
    _uploadPathScale = math.max(uploadPeak * 1.15, 1024.0);
    var elapsed = history.elapsed;
    downloadScale.update(_downloadPathScale, elapsed);
    uploadScale.update(_uploadPathScale, elapsed);
    var download = Path();
    var upload = Path();
    for (var i = 0; i < points.length; i++) {
      var point = points[i];
      var downY = bottom - point.rates.download / _downloadPathScale * height;
      var upY = bottom - point.rates.upload / _uploadPathScale * height;
      if (i == 0) {
        download.moveTo(point.x, downY);
        upload.moveTo(point.x, upY);
      } else {
        var previous = points[i - 1];
        var middleX = (previous.x + point.x) / 2;
        // 控制点保持在相邻采样的范围内，平滑转折且不产生额外峰值。
        download.cubicTo(
          middleX,
          bottom - previous.rates.download / _downloadPathScale * height,
          middleX,
          downY,
          point.x,
          downY,
        );
        upload.cubicTo(
          middleX,
          bottom - previous.rates.upload / _uploadPathScale * height,
          middleX,
          upY,
          point.x,
          upY,
        );
      }
    }
    _download = download;
    _upload = upload;
    _area = Path.from(download)
      ..lineTo(points.last.x, bottom)
      ..lineTo(points.first.x, bottom)
      ..close();
    _areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          downloadColor.withValues(alpha: dark ? 0.15 : 0.10),
          downloadColor.withValues(alpha: 0.015),
        ],
      ).createShader(Offset.zero & size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || history.frames.isEmpty) return;
    _preparePaths(size);
    if (_download == null) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    var bottom = size.height - 3;
    var height = size.height * 0.68;
    var grid = Paint()
      ..color = downloadColor.withValues(alpha: dark ? 0.055 : 0.035)
      ..strokeWidth = 0.5;
    for (var i = 0; i < 3; i++) {
      var y = bottom - height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var x = size.width; x >= 0; x -= 40) {
      canvas.drawLine(Offset(x, bottom - height), Offset(x, bottom), grid);
    }

    var elapsed = history.elapsed;
    if (animate && animation.isAnimating) {
      canvas.translate(
        history.scrollSecondsAt(elapsed) *
            DownloadRateBackground.pixelsPerSecond,
        0,
      );
    }
    // 各自平滑调整纵轴，变换缓存路径后再描边，保持线宽一致。
    Path scaled(Path path, double pathScale, DownloadRateScale viewportScale) {
      var factor = animate ? pathScale / viewportScale.valueAt(elapsed) : 1.0;
      if (factor == 1) return path;
      var transform = Matrix4.identity()
        ..setEntry(1, 1, factor)
        ..setEntry(1, 3, bottom * (1 - factor));
      return path.transform(transform.storage);
    }

    canvas.drawPath(
      scaled(_area!, _downloadPathScale, downloadScale),
      _areaPaint!,
    );
    void stroke(Path path, Color color, double opacity) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    stroke(
      scaled(_download!, _downloadPathScale, downloadScale),
      downloadColor,
      dark ? 0.42 : 0.28,
    );
    stroke(
      scaled(_upload!, _uploadPathScale, uploadScale),
      uploadColor,
      dark ? 0.48 : 0.32,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RateHistoryPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.animation != animation ||
        oldDelegate.animate != animate ||
        oldDelegate.downloadScale != downloadScale ||
        oldDelegate.uploadScale != uploadScale ||
        !listEquals(oldDelegate.taskIds, taskIds) ||
        oldDelegate.downloadColor != downloadColor ||
        oldDelegate.uploadColor != uploadColor ||
        oldDelegate.dark != dark;
  }
}
