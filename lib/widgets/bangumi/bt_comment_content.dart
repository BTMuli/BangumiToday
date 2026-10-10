// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/gestures.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/bangumi_comment_parser.dart';
import '../../core/utils/tool_func.dart';
import 'bt_comment_image.dart';
import 'comment_image_viewer.dart';

/// 渲染 bgm 评论正文：BBCode 子集 + bmoji 表情。
///
/// 表情包按 bgm 的图片路径加载，链接可点击；`[img]` 图片点击后交给
/// [BtCommentContent.onImageTap]（通常是图片弹窗），表情包只提供右键复制/另存，
/// `[mask]` 悬停或点击后显示，`[spoiler]` 折叠。
class BtCommentContent extends StatefulWidget {
  const BtCommentContent({
    super.key,
    required this.text,
    this.style,
    this.selectable = true,
    this.imageIndexBase = 0,
    this.onImageTap,
  });

  /// 原始正文
  final String text;

  /// 正文基础样式，默认使用主题正文样式
  final TextStyle? style;

  /// 是否允许选中文本
  final bool selectable;

  /// 本段正文的图片在整条评论图片列表中的起始下标
  final int imageIndexBase;

  /// 点击表情或 `[img]` 图片时回调，参数为整条评论里的图片下标
  final ValueChanged<int>? onImageTap;

  @override
  State<BtCommentContent> createState() => _BtCommentContentState();
}

class _BtCommentContentState extends State<BtCommentContent> {
  late List<BtCommentBlock> _blocks = _parse();
  final Map<String, TapGestureRecognizer> _recognizers = {};

  /// 本次 build 已渲染的图片数，用于把图片映射到整条评论的下标
  late int _imageCursor = widget.imageIndexBase;

  /// 接口返回的正文带 HTML 转义，解析前先还原
  List<BtCommentBlock> _parse() =>
      parseBangumiComment(replaceEscape(widget.text));

  @override
  void didUpdateWidget(BtCommentContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _blocks = _parse();
    }
  }

  @override
  void dispose() {
    for (var recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  /// 同一链接复用识别器，避免每次重建都申请手势
  TapGestureRecognizer _recognizer(String link) {
    return _recognizers.putIfAbsent(link, () {
      var recognizer = TapGestureRecognizer();
      recognizer.onTap = () => unawaited(launchUrlString(link));
      return recognizer;
    });
  }

  @override
  Widget build(BuildContext context) {
    var style =
        widget.style ?? BTTypography.body(context).copyWith(height: 1.6);
    _imageCursor = widget.imageIndexBase;
    var content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildBlocks(context, _blocks, style),
    );
    if (!widget.selectable) return content;
    // 只保留拖拽选中，右键不弹选择菜单
    return SelectionArea(
      contextMenuBuilder: (_, _) => const SizedBox.shrink(),
      child: content,
    );
  }

  List<Widget> _buildBlocks(
    BuildContext context,
    List<BtCommentBlock> blocks,
    TextStyle style,
  ) {
    var widgets = <Widget>[];
    for (var block in blocks) {
      switch (block) {
        case BtCommentParagraph(:var spans):
          widgets.add(_buildParagraph(context, spans, style));
        case BtCommentQuote(:var blocks, :var title):
          widgets.add(_buildQuote(context, blocks, style, title));
        case BtCommentCode(:var text):
          widgets.add(_buildCode(context, text, style));
        case BtCommentSpoiler(:var blocks, :var title):
          widgets.add(_buildSpoiler(context, blocks, style, title));
      }
    }
    return widgets;
  }

  Widget _buildParagraph(
    BuildContext context,
    List<BtCommentSpan> spans,
    TextStyle style,
  ) {
    var children = <InlineSpan>[];
    for (var span in spans) {
      if (span.isImage) {
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _buildImage(context, span),
          ),
        );
        continue;
      }
      var link = span.link == null
          ? null
          : resolveBangumiCommentLink(span.link!);
      var textStyle = _spanStyle(context, span, style, linked: link != null);
      if (span.masked) {
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _MaskedText(text: span.text, style: textStyle),
          ),
        );
        continue;
      }
      children.add(
        TextSpan(
          text: span.text,
          style: textStyle,
          recognizer: link == null ? null : _recognizer(link),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(TextSpan(style: style, children: children)),
    );
  }

  Widget _buildImage(BuildContext context, BtCommentSpan span) {
    var url = resolveBangumiCommentImage(span.imageUrl!);
    if (url == null) {
      return Tooltip(
        message: '图片地址无效',
        child: Icon(
          FluentIcons.photo_error,
          size: 18,
          color: BTColors.textTertiary(context),
        ),
      );
    }
    switch (span.imageKind) {
      case BtCommentImageKind.legacySmile:
        return _SmileImage(url: url, width: 18, height: 18, pixelated: true);
      case BtCommentImageKind.dynamicSmile:
        return _SmileImage(url: url, width: 46, height: 34, pixelated: false);
      case BtCommentImageKind.content:
      case null:
        // 只有内容图片进弹窗，下标与图片集合的收集顺序保持一致
        var index = _imageCursor++;
        var onTap = widget.onImageTap == null
            ? null
            : () => widget.onImageTap!(index);
        return _ContentImage(url: url, onTap: onTap);
    }
  }

  Widget _buildQuote(
    BuildContext context,
    List<BtCommentBlock> blocks,
    TextStyle style,
    String? title,
  ) {
    var accent = FluentTheme.of(context).accentColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.55), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                title,
                style: BTTypography.caption(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ..._buildBlocks(context, blocks, style),
        ],
      ),
    );
  }

  Widget _buildCode(BuildContext context, String text, TextStyle style) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          text.replaceAll('\r\n', '\n'),
          style: style.copyWith(
            fontFamily: 'Consolas',
            fontFamilyFallback: const ['Courier New', 'monospace'],
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSpoiler(
    BuildContext context,
    List<BtCommentBlock> blocks,
    TextStyle style,
    String? title,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Expander(
        header: Text(title ?? '剧透内容', style: BTTypography.bodyStrong(context)),
        headerBackgroundColor: WidgetStateColor.transparent,
        contentPadding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildBlocks(context, blocks, style),
        ),
      ),
    );
  }

  TextStyle _spanStyle(
    BuildContext context,
    BtCommentSpan span,
    TextStyle base, {
    required bool linked,
  }) {
    var style = base;
    if (span.size != null) style = style.copyWith(fontSize: span.size);
    var color = parseBangumiCommentColor(span.color);
    if (color == null && linked) {
      color = FluentTheme.of(context).accentColor;
    }
    if (color != null) style = style.copyWith(color: color);
    if (span.bold) {
      style = style.copyWith(fontWeight: FontWeight.w600);
    }
    var decorations = <TextDecoration>[
      if (span.underline) TextDecoration.underline,
      if (span.strike) TextDecoration.lineThrough,
    ];
    if (decorations.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(decorations));
    }
    return style;
  }
}

/// 表情图片：像素风关闭插值，动态表情按比例缩放。
///
/// 表情包不进图片弹窗，只提供右键复制 / 另存；加载失败时点击重试。
class _SmileImage extends StatelessWidget {
  const _SmileImage({
    required this.url,
    required this.width,
    required this.height,
    required this.pixelated,
  });

  final String url;
  final double width;
  final double height;
  final bool pixelated;

  @override
  Widget build(BuildContext context) {
    return CommentImageContextMenu(
      url: url,
      tooltip: '右键可复制或另存为',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: SizedBox(
          width: width,
          height: height,
          child: BtRetryableImage(
            url: url,
            fit: BoxFit.contain,
            filterQuality: pixelated
                ? FilterQuality.none
                : FilterQuality.medium,
            errorBuilder: (context, retry) => Tooltip(
              message: '表情加载失败，点击重试',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: retry,
                  child: Icon(
                    FluentIcons.refresh,
                    size: 12,
                    color: BTColors.textTertiary(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `[img]` 图片：限宽限高，点击打开图片弹窗，右键可复制 / 另存 / 浏览器打开。
class _ContentImage extends StatelessWidget {
  const _ContentImage({required this.url, this.onTap});

  final String url;

  /// 点击后打开图片弹窗
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    var image = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 200),
        child: BtRetryableImage(
          url: url,
          placeholder: const SizedBox(width: 120, height: 90),
          errorBuilder: (context, retry) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.photo_error,
                size: 14,
                color: BTColors.textTertiary(context),
              ),
              const SizedBox(width: 6),
              Text('图片加载失败', style: BTTypography.caption(context)),
              const SizedBox(width: 4),
              Tooltip(
                message: '重新加载图片',
                child: Semantics(
                  label: '重新加载图片',
                  child: IconButton(
                    icon: const Icon(FluentIcons.refresh, size: 12),
                    onPressed: retry,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    var label = onTap == null ? '右键可复制或另存为' : '点击查看大图，右键可复制或另存为';
    return CommentImageContextMenu(
      url: url,
      openInBrowser: true,
      tooltip: label,
      child: Semantics(
        label: label,
        button: onTap != null,
        child: MouseRegion(
          cursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: onTap == null
              ? image
              : GestureDetector(onTap: onTap, child: image),
        ),
      ),
    );
  }
}

/// `[mask]` 遮挡文本：悬停或点击后显示
class _MaskedText extends StatefulWidget {
  const _MaskedText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_MaskedText> createState() => _MaskedTextState();
}

class _MaskedTextState extends State<_MaskedText> {
  var _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (_revealed) return Text(widget.text, style: widget.style);
    var label = '点击查看被遮挡的内容';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _revealed = true),
          child: GestureDetector(
            onTap: () => setState(() => _revealed = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: BTColors.textSecondary(context).withValues(alpha: 0.35),
                borderRadius: BTRadius.smallBR,
              ),
              child: Text(
                widget.text,
                style: widget.style.copyWith(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 常见 CSS 颜色名，够覆盖吐槽里出现的颜色
const Map<String, Color> _cssColors = {
  'red': Color(0xFFE53935),
  'orange': Color(0xFFFB8C00),
  'yellow': Color(0xFFFDD835),
  'green': Color(0xFF43A047),
  'blue': Color(0xFF1E88E5),
  'purple': Color(0xFF8E24AA),
  'pink': Color(0xFFEC407A),
  'brown': Color(0xFF6D4C41),
  'gray': Color(0xFF757575),
  'grey': Color(0xFF757575),
  'black': Color(0xFF000000),
  'white': Color(0xFFFFFFFF),
  'cyan': Color(0xFF00ACC1),
  'teal': Color(0xFF00897B),
  'navy': Color(0xFF1A237E),
  'olive': Color(0xFF827717),
  'maroon': Color(0xFF880E4F),
  'magenta': Color(0xFFD81B60),
  'silver': Color(0xFFBDBDBD),
  'lime': Color(0xFF7CB342),
};

/// 解析 `[color=..]`：支持 CSS 颜色名与 #rgb/#rrggbb/#aarrggbb
Color? parseBangumiCommentColor(String? value) {
  if (value == null) return null;
  var text = value.trim().toLowerCase();
  if (text.isEmpty) return null;
  var named = _cssColors[text];
  if (named != null) return named;
  if (!text.startsWith('#')) return null;
  var hex = text.substring(1);
  if (hex.length == 3) {
    hex = hex.split('').map((char) => '$char$char').join();
  }
  if (hex.length == 6) {
    var rgb = int.tryParse(hex, radix: 16);
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }
  if (hex.length == 8) {
    var argb = int.tryParse(hex, radix: 16);
    return argb == null ? null : Color(argb);
  }
  return null;
}
