part of '../subject_rss_search_dialog.dart';

String _anibtUpdatedAt(int? milliseconds) {
  if (milliseconds == null) return '更新时间未知';
  var date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  return '更新 ${DateFormat('yyyy-MM-dd HH:mm').format(date)}';
}

/// 吸顶表头的固定高度；文本放大时按两行文本的增量抬高，避免截断。
double _stickyHeaderExtent(BuildContext context, double base) {
  var scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return base + (scale - 1) * 36;
}

/// 展开内容的外框，与 fluent_ui 的 Expander 内容区保持一致。
ShapeDecoration _contentDecoration(FluentThemeData theme) {
  return ShapeDecoration(
    color: theme.resources.cardBackgroundFillColorSecondary,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: theme.resources.cardStrokeColorDefault),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
    ),
  );
}

/// 条目内容区的实际底色；吸顶表头需与它合成才能既遮挡资源又不留色带。
Color _contentSurface(FluentThemeData theme) {
  return Color.alphaBlend(
    theme.resources.cardBackgroundFillColorSecondary,
    theme.menuColor,
  );
}

/// 固定的吸顶高度由 [SliverPersistentHeader] 要求。
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: extent, child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}

/// 表头卡片向上下各多铺的像素数。
///
/// 吸顶条之间、表头与其内容之间的边界在缩放不为整数时会被分别取整，留下一条
/// 1 物理像素宽、没有任何控件绘制的缝；缝里会露出更底层的内容。表头卡片多铺
/// 这么多像素后，这部分与相邻元素重叠，缝必然被不透明填充覆盖。
const _headerSeamExtent = 2.0;

/// 条目与字幕组共用的表头外观，沿用 Expander 表头的配色与箭头。
class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.child,
    required this.expanded,
    required this.onPressed,
    required this.base,
  });

  final Widget child;
  final bool expanded;
  final VoidCallback onPressed;

  /// 表头所在的底色。fluent 的卡片填充是半透明的，先与它合成才能整条遮住
  /// 吸顶后从下方滚过的资源。
  final Color base;

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    var shape = RoundedRectangleBorder(
      side: BorderSide(color: theme.resources.cardStrokeColorDefault),
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(6),
        bottom: Radius.circular(expanded ? 0 : 6),
      ),
    );
    return HoverButton(
      onPressed: onPressed,
      hitTestBehavior: HitTestBehavior.deferToChild,
      builder: (context, states) {
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // 卡片底纹与边框画在可溢出的一层里，向上下各多铺几个像素：
            // 两条吸顶条（或表头与其内容）的边界在缩放取整后会留下 1px 透明
            // 缝，多铺的部分就在缝的位置，且与相邻元素重叠，不会露底色。
            Positioned(
              top: -_headerSeamExtent,
              bottom: expanded ? -_headerSeamExtent : 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: Color.alphaBlend(
                    theme.resources.cardBackgroundFillColorDefault,
                    base,
                  ),
                  shape: shape,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsetsDirectional.only(start: 16),
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                children: [
                  Expanded(child: child),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 20,
                      end: 8,
                      top: 8,
                      bottom: 8,
                    ),
                    child: FocusBorder(
                      focused: states.isFocused,
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ButtonThemeData.uncheckedInputColor(
                            theme,
                            states,
                            transparentWhenNone: true,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: theme.fastAnimationDuration,
                          curve: theme.animationCurve,
                          child: const Icon(FluentIcons.chevron_down, size: 8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 条目表头：番剧名与站点信息，整条可点击展开。
class _ItemHeader extends StatelessWidget {
  const _ItemHeader({
    required this.title,
    required this.meta,
    required this.expanded,
    required this.onPressed,
  });

  final String title;
  final String meta;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    return _StickyHeader(
      expanded: expanded,
      onPressed: onPressed,
      base: theme.menuColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: title,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 字幕组表头：勾选框用于选中该字幕组，其余区域用于展开资源。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.selected,
    required this.onSelected,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    var subtitle = this.subtitle;
    return Row(
      children: [
        Checkbox(
          checked: selected,
          onChanged: onSelected == null
              ? null
              : (checked) => onSelected!(checked ?? false),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: title,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
