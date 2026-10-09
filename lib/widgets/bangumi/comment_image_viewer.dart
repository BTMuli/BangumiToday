// Dart imports:
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:super_clipboard/super_clipboard.dart' as clipboard;
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/bangumi_comment_parser.dart';
import '../../core/utils/tool_func.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import 'bt_comment_image.dart';

/// 一条评论（含其回复）里的图片集合。
///
/// 只收集 `[img]` 图片（表情包不进弹窗），按渲染顺序记录各段正文的起始下标，
/// 负责把点击映射到整条评论的下标并打开图片弹窗。
class CommentImageSet {
  final List<String> _urls = [];

  /// 记录一段正文，返回该段正文第一张图片在整条评论里的下标。
  ///
  /// 与渲染一致，先还原接口返回的 HTML 转义再解析。
  int add(String text) {
    var base = _urls.length;
    _urls.addAll(
      bangumiCommentImageUrls(
        replaceEscape(text),
        kind: BtCommentImageKind.content,
      ),
    );
    return base;
  }

  int get length => _urls.length;

  bool get isEmpty => _urls.isEmpty;

  /// 打开图片弹窗，[index] 为整条评论里的图片下标
  Future<void> show(BuildContext context, int index) {
    return showCommentImageDialog(
      context,
      images: _urls.map(resolveBangumiCommentImage).toList(growable: false),
      index: index,
    );
  }
}

/// 评论图片的右键菜单：复制、另存为，内容图片额外提供浏览器打开。
class CommentImageContextMenu extends StatefulWidget {
  const CommentImageContextMenu({
    super.key,
    required this.url,
    required this.child,
    this.openInBrowser = false,
    this.tooltip,
  });

  /// 已解析的图片地址
  final String url;

  /// 是否提供「浏览器打开」，表情包不需要
  final bool openInBrowser;

  /// 悬停提示，如右键操作的说明
  final String? tooltip;

  final Widget child;

  @override
  State<CommentImageContextMenu> createState() =>
      _CommentImageContextMenuState();
}

class _CommentImageContextMenuState extends State<CommentImageContextMenu> {
  final FlyoutController _controller = FlyoutController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openMenu() {
    var color = FluentTheme.of(context).accentColor;
    _controller.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: Icon(FluentIcons.copy, color: color),
            text: const Text('复制图片'),
            onPressed: () => unawaited(_copy()),
          ),
          MenuFlyoutItem(
            leading: Icon(FluentIcons.save, color: color),
            text: const Text('另存为'),
            onPressed: () => unawaited(_save()),
          ),
          if (widget.openInBrowser)
            MenuFlyoutItem(
              leading: Icon(FluentIcons.link, color: color),
              text: const Text('浏览器打开'),
              onPressed: () => unawaited(launchUrlString(widget.url)),
            ),
        ],
      ),
    );
  }

  Future<void> _copy() => copyCommentImage(context, widget.url);

  Future<void> _save() => saveCommentImage(context, widget.url);

  @override
  Widget build(BuildContext context) {
    // 用 Listener 监听右键按下：不参与手势竞技场，不会抢掉图片的左键点击
    var child = Listener(
      onPointerDown: (event) {
        if (event.buttons & kSecondaryMouseButton != 0) _openMenu();
      },
      child: widget.child,
    );
    var tooltip = widget.tooltip;
    if (tooltip == null) {
      return FlyoutTarget(controller: _controller, child: child);
    }
    return FlyoutTarget(
      controller: _controller,
      child: Tooltip(message: tooltip, child: child),
    );
  }
}

/// 复制评论图片到剪贴板：统一转成 PNG，动图只复制首帧。
Future<void> copyCommentImage(BuildContext context, String url) async {
  try {
    var bytes = await _pngBytes(url);
    var systemClipboard = clipboard.SystemClipboard.instance;
    if (systemClipboard == null) {
      throw StateError('当前平台不支持复制图片到剪贴板');
    }
    var item = clipboard.DataWriterItem()..add(clipboard.Formats.png(bytes));
    await systemClipboard.write([item]);
    if (context.mounted) await BtInfobar.success(context, '图片已复制到剪贴板');
  } catch (error) {
    if (context.mounted) await BtInfobar.error(context, '复制图片失败：$error');
  }
}

/// 另存评论图片：弹系统另存为对话框，写出原始字节。
Future<void> saveCommentImage(BuildContext context, String url) async {
  try {
    var file = await DefaultCacheManager().getSingleFile(url);
    var bytes = await file.readAsBytes();
    var location = await getSaveLocation(
      suggestedName: _suggestedName(url, bytes),
    );
    if (location == null) return;
    await File(location.path).writeAsBytes(bytes, flush: true);
    if (context.mounted) {
      await BtInfobar.success(context, '图片已保存到 ${location.path}');
    }
  } catch (error) {
    if (context.mounted) await BtInfobar.error(context, '保存图片失败：$error');
  }
}

/// 评论图片弹窗：同一评论下的图片可左右切换。
///
/// 支持复制图片、在浏览器中打开与下载（另存为）；点击弹窗外部关闭。
Future<void> showCommentImageDialog(
  BuildContext context, {
  required List<String> images,
  required int index,
}) {
  if (images.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CommentImageDialog(images: images, initialIndex: index),
  );
}

class _CommentImageDialog extends StatefulWidget {
  const _CommentImageDialog({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_CommentImageDialog> createState() => _CommentImageDialogState();
}

class _CommentImageDialogState extends State<_CommentImageDialog> {
  late int _index = widget.initialIndex.clamp(0, widget.images.length - 1);

  /// 复制或下载进行中
  bool _busy = false;

  /// 当前图片的原始尺寸，用于按比例决定弹窗大小
  Size? _intrinsic;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// 缩放与平移状态，切换图片时复位
  final TransformationController _transform = TransformationController();

  String get _url => widget.images[_index];

  bool get _hasMultiple => widget.images.length > 1;

  @override
  void initState() {
    super.initState();
    _resolveIntrinsic();
  }

  @override
  void dispose() {
    _transform.dispose();
    _releaseStream();
    super.dispose();
  }

  void _releaseStream() {
    var listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
    _stream = null;
  }

  /// 读取原图尺寸：拿到后弹窗按图片比例收缩
  void _resolveIntrinsic() {
    _releaseStream();
    _intrinsic = null;
    var url = _url;
    late ImageStreamListener listener;
    var stream = CachedNetworkImageProvider(
      url,
    ).resolve(ImageConfiguration.empty);
    listener = ImageStreamListener((info, _) {
      if (!mounted || url != _url) return;
      setState(() {
        _intrinsic = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
      _releaseStream();
    }, onError: (_, _) => _releaseStream());
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _previous() {
    if (!_hasMultiple) return;
    setState(() {
      _index = (_index - 1 + widget.images.length) % widget.images.length;
    });
    _resetView();
  }

  void _next() {
    if (!_hasMultiple) return;
    setState(() => _index = (_index + 1) % widget.images.length);
    _resetView();
  }

  /// 切换图片时复位缩放与平移，并重新读取原图尺寸
  void _resetView() {
    _transform.value = Matrix4.identity();
    _resolveIntrinsic();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.sizeOf(context);
    var maxBox = Size(
      (size.width * 0.7).clamp(280.0, 960.0),
      (size.height * 0.62).clamp(200.0, 620.0),
    );
    var fitted = _fitSize(_intrinsic, maxBox);
    var innerWidth = fitted.width.clamp(260.0, maxBox.width);
    var content = Size(innerWidth, fitted.height);
    // 四周内边距统一 16：ContentDialog 的 padding 只包住标题与内容，
    // 操作区要单独给，否则按钮会贴住右侧与底部。
    var dialogWidth = content.width + 32;
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return ContentDialog(
      style: const ContentDialogThemeData(
        padding: EdgeInsetsDirectional.all(16),
        titlePadding: EdgeInsetsDirectional.only(bottom: 16),
        bodyPadding: EdgeInsetsDirectional.zero,
        actionsPadding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      ),
      constraints: BoxConstraints(
        maxWidth: dialogWidth,
        maxHeight: content.height + 220,
      ),
      title: _buildTitle(context),
      content: SizedBox.fromSize(
        size: content,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            // 比弹窗底色更深，图片不满框时能看出画框范围
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BTRadius.mediumBR,
          ),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
              const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
            },
            child: Focus(autofocus: true, child: _buildImage(context, content)),
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BtDialogAction(
              text: '复制图片',
              onPressed: () => unawaited(_copy()),
              isPrimary: false,
            ),
            const SizedBox(width: 8),
            BtDialogAction(
              text: '浏览器打开',
              onPressed: () => unawaited(launchUrlString(_url)),
              isPrimary: false,
            ),
            const SizedBox(width: 8),
            BtDialogAction(
              text: '下载',
              onPressed: () => unawaited(_download()),
              isPrimary: false,
            ),
          ],
        ),
      ],
    );
  }

  /// 标题栏：计数靠左，切换按钮紧邻放在右侧
  Widget _buildTitle(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('图片 ${_index + 1} / ${widget.images.length}')),
        if (_busy) ...[
          const SizedBox.square(
            dimension: 16,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
        ],
        if (_hasMultiple) ...[
          _buildNavButton(
            icon: FluentIcons.chevron_left,
            label: '上一张',
            onPressed: _previous,
          ),
          _buildNavButton(
            icon: FluentIcons.chevron_right,
            label: '下一张',
            onPressed: _next,
          ),
        ],
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: IconButton(icon: Icon(icon, size: 16), onPressed: onPressed),
      ),
    );
  }

  Widget _buildImage(BuildContext context, Size content) {
    return InteractiveViewer(
      transformationController: _transform,
      maxScale: 6,
      // 滚轮/触控板缩放，拖拽平移
      trackpadScrollCausesScale: true,
      child: BtRetryableImage(
        url: _url,
        fit: BoxFit.contain,
        placeholder: const Center(child: ProgressRing()),
        errorBuilder: (context, retry) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.photo_error,
                size: 28,
                color: BTColors.textTertiary(context),
              ),
              const SizedBox(height: 8),
              Text('图片加载失败', style: BTTypography.body(context)),
              const SizedBox(height: 8),
              Button(onPressed: retry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }

  /// 等比缩放：小图最多放大 2 倍，避免像素表情被拉花
  Size _fitSize(Size? intrinsic, Size maxBox) {
    if (intrinsic == null || intrinsic.width <= 0 || intrinsic.height <= 0) {
      return Size(maxBox.width * 0.7, maxBox.height * 0.7);
    }
    var scale = math.min(
      maxBox.width / intrinsic.width,
      maxBox.height / intrinsic.height,
    );
    scale = scale.clamp(0.05, 2.0);
    return Size(intrinsic.width * scale, intrinsic.height * scale);
  }

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await copyCommentImage(context, _url);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await saveCommentImage(context, _url);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// 复制用字节：非 PNG 统一转 PNG，兼容 GIF / JPEG 与剪贴板消费方
Future<Uint8List> _pngBytes(String url) async {
  var file = await DefaultCacheManager().getSingleFile(url);
  var bytes = await file.readAsBytes();
  if (_isPng(bytes)) return bytes;
  var codec = await ui.instantiateImageCodec(bytes);
  try {
    var frame = await codec.getNextFrame();
    try {
      var data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('图片转换失败');
      return data.buffer.asUint8List();
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// 另存为的默认文件名：沿用原图名，缺后缀时按字节补上
String _suggestedName(String url, Uint8List bytes) {
  var segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
  var name = segments.isEmpty ? '' : segments.last;
  if (name.isEmpty || name == '/') name = 'bangumi-image';
  if (!name.contains('.')) name = '$name.${_extension(bytes)}';
  return name;
}

bool _isPng(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47];
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}

String _extension(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
  if (bytes.length >= 4 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return 'gif';
  }
  if (bytes.length >= 12 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'webp';
  }
  return 'png';
}
