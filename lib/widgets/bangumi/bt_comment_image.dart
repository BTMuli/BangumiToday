// Dart imports:
import 'dart:async';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Project imports:
import '../../request/bangumi/bangumi_api.dart';

/// 评论里的网络图片：加载失败时由使用方提供带重试的占位。
///
/// 重试会先清掉缓存里对应文件再重建图片组件，避免命中上次的失败结果。
class BtRetryableImage extends StatefulWidget {
  const BtRetryableImage({
    super.key,
    required this.url,
    required this.errorBuilder,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
    this.placeholder,
  });

  final String url;

  /// 失败时的占位，[retry] 为重新加载回调
  final Widget Function(BuildContext context, VoidCallback retry) errorBuilder;

  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget? placeholder;

  @override
  State<BtRetryableImage> createState() => _BtRetryableImageState();
}

class _BtRetryableImageState extends State<BtRetryableImage> {
  /// 重试次数：变化后图片组件会重建并发起新请求
  int _attempt = 0;

  Future<void> _retry() async {
    try {
      await DefaultCacheManager().removeFile(widget.url);
    } catch (_) {
      // 清理缓存失败不影响重新加载
    }
    if (!mounted) return;
    setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      key: ValueKey('${widget.url}#$_attempt'),
      imageUrl: widget.url,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      placeholder: (_, _) => widget.placeholder ?? const SizedBox.shrink(),
      errorWidget: (context, _, _) =>
          widget.errorBuilder(context, () => unawaited(_retry())),
    );
  }
}

/// 表情与图片地址：相对路径补当前图片域名，其余地址跟随镜像
String resolveBangumiCommentImage(String value) {
  if (value.startsWith('/')) return '${BtrBangumiApi.imageBaseUrl}$value';
  if (value.startsWith('//')) return 'https:$value';
  return BtrBangumiApi.rewriteUrl(value);
}

/// 链接地址：站点相对路径补当前站点域名，其余地址跟随镜像
String resolveBangumiCommentLink(String value) {
  if (value.startsWith('/')) return '${BtrBangumiApi.siteBaseUrl}$value';
  if (value.startsWith('//')) return 'https:$value';
  return BtrBangumiApi.rewriteUrl(value);
}
