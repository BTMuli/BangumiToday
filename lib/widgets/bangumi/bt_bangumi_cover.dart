// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../request/bangumi/bangumi_api.dart';

/// Bangumi 封面 URL：去掉已有 `r/` 前缀，再按最大边请求切图。
class BangumiCoverUrl {
  BangumiCoverUrl._();

  static const int thumbMaxEdge = 200;
  static const int gridMaxEdge = 400;
  static const int detailMaxEdge = 600;

  static String resolve(String source, {int maxEdge = gridMaxEdge}) {
    var raw = source.trim();
    if (raw.isEmpty) return '';
    var uri = Uri.tryParse(raw);
    var path = uri != null && uri.hasScheme ? uri.path : raw;
    if (!path.startsWith('/')) path = '/$path';
    path = path.replaceFirst(RegExp(r'^/r/[^/]+(?=/pic)'), '');
    return '${BtrBangumiApi.imageBaseUrl}/r/0x$maxEdge$path';
  }

  static int? cachePixels(double logical, double devicePixelRatio) {
    if (!logical.isFinite || logical <= 0 || devicePixelRatio <= 0) {
      return null;
    }
    return (logical * devicePixelRatio).round().clamp(1, 4096);
  }

  /// 只限制较长边，避免同时指定宽高把封面拉变形。
  static ({int? width, int? height}) memCacheSize({
    double? logicalWidth,
    double? logicalHeight,
    required double devicePixelRatio,
  }) {
    var pxW = logicalWidth == null
        ? null
        : cachePixels(logicalWidth, devicePixelRatio);
    var pxH = logicalHeight == null
        ? null
        : cachePixels(logicalHeight, devicePixelRatio);
    if (pxW != null && pxH != null) {
      if (pxW >= pxH) return (width: pxW, height: null);
      return (width: null, height: pxH);
    }
    return (width: pxW, height: pxH);
  }
}

/// 按布局像素限制解码尺寸的封面图。
class BtBangumiCover extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int maxRequestEdge;
  final BorderRadius? borderRadius;
  final double progressSize;
  final double progressStrokeWidth;
  final Widget Function(BuildContext context, {String? err}) errorBuilder;

  const BtBangumiCover({
    super.key,
    required this.imageUrl,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.maxRequestEdge = BangumiCoverUrl.gridMaxEdge,
    this.borderRadius,
    this.progressSize = 24,
    this.progressStrokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return errorBuilder(context);
    }

    Widget image = LayoutBuilder(
      builder: (context, constraints) {
        var dpr = MediaQuery.devicePixelRatioOf(context);
        var logicalW = width;
        if (logicalW == null &&
            constraints.maxWidth.isFinite &&
            constraints.maxWidth > 0) {
          logicalW = constraints.maxWidth;
        }
        var logicalH = height;
        if (logicalH == null &&
            constraints.maxHeight.isFinite &&
            constraints.maxHeight > 0) {
          logicalH = constraints.maxHeight;
        }
        var cache = BangumiCoverUrl.memCacheSize(
          logicalWidth: logicalW,
          logicalHeight: logicalH,
          devicePixelRatio: dpr,
        );
        return CachedNetworkImage(
          imageUrl: BangumiCoverUrl.resolve(imageUrl!, maxEdge: maxRequestEdge),
          fit: fit,
          width: width,
          height: height,
          memCacheWidth: cache.width,
          memCacheHeight: cache.height,
          progressIndicatorBuilder: (context, url, dp) => Center(
            child: SizedBox(
              width: progressSize,
              height: progressSize,
              child: ProgressRing(
                value: dp.progress == null ? 0 : dp.progress! * 100,
                strokeWidth: progressStrokeWidth,
              ),
            ),
          ),
          errorWidget: (context, url, error) =>
              errorBuilder(context, err: error.toString()),
        );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    if (width != null || height != null) {
      image = SizedBox(width: width, height: height, child: image);
    }
    return image;
  }
}
