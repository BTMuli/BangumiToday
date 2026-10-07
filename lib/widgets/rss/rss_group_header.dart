// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';

/// 组名靠近展开入口，资源总数与待处理数量独立显示。
class RssGroupHeader extends StatelessWidget {
  const RssGroupHeader({
    super.key,
    required this.name,
    required this.count,
    this.pendingCount = 0,
  });

  final String name;
  final int count;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var badges = Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _badge(context, '$count 条资源'),
            if (pendingCount > 0)
              _badge(context, '$pendingCount 条更新', highlighted: true),
          ],
        );
        var title = Tooltip(
          message: name,
          child: Text(
            name,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BTTypography.bodyStrong(context),
          ),
        );
        if (constraints.maxWidth < 360) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 6), badges],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            badges,
          ],
        );
      },
    );
  }

  Widget _badge(
    BuildContext context,
    String label, {
    bool highlighted = false,
  }) {
    var theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? theme.accentColor.withValues(alpha: 0.16)
            : theme.resources.subtleFillColorSecondary,
        borderRadius: BTRadius.smallBR,
      ),
      child: Text(
        label,
        style: BTTypography.caption(context).copyWith(
          color: highlighted
              ? theme.accentColor
              : BTColors.textSecondary(context),
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
