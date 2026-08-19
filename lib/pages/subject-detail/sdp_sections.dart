// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../utils/tool_func.dart';
import 'sdp_view_data.dart';

Widget sdpSurfaceCard(BuildContext context, Widget child) {
  var isDark = FluentTheme.of(context).brightness == Brightness.dark;
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark
          ? BTColors.surfaceSecondary(context)
          : BTColors.surfacePrimary(context),
      borderRadius: BTRadius.largeBR,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
      ),
      boxShadow: BTTheme.shadow(context, level: BTShadowLevel.medium),
    ),
    child: child,
  );
}

class SdpSection extends StatefulWidget {
  const SdpSection({
    super.key,
    required this.icon,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget content;
  final bool initiallyExpanded;

  @override
  State<SdpSection> createState() => _SdpSectionState();
}

class _SdpSectionState extends State<SdpSection> {
  /// Fluent [Expander] still builds [content] when collapsed; keep the
  /// heavy children (剧集 / 关联 / 图表) out of the tree until first open.
  late bool _contentMounted = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Expander(
      initiallyExpanded: widget.initiallyExpanded,
      leading: Icon(
        widget.icon,
        size: 18,
        color: FluentTheme.of(context).accentColor,
      ),
      header: Text(widget.title, style: BTTypography.subtitle(context)),
      onStateChanged: (open) {
        if (open && !_contentMounted) {
          setState(() => _contentMounted = true);
        }
      },
      content: _contentMounted ? widget.content : const SizedBox.shrink(),
    );
  }
}

class SdpSummaryBody extends StatelessWidget {
  const SdpSummaryBody({super.key, required this.view});

  final SubjectDetailViewData view;

  @override
  Widget build(BuildContext context) {
    var summary = view.subject.summary;
    if (summary.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              FluentIcons.error_badge,
              size: 16,
              color: BTColors.textTertiary(context),
            ),
            SizedBox(width: 8),
            Text('暂无简介', style: BTTypography.body(context)),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: SelectableText(
        summary,
        style: BTTypography.body(context),
        contextMenuBuilder: view.contextMenuBuilder,
      ),
    );
  }
}

class SdpInfoboxBody extends StatelessWidget {
  const SdpInfoboxBody({super.key, required this.view});

  final SubjectDetailViewData view;

  @override
  Widget build(BuildContext context) {
    var infobox = view.subject.infobox;
    if (infobox.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              FluentIcons.info,
              size: 16,
              color: BTColors.textTertiary(context),
            ),
            SizedBox(width: 8),
            Text('暂无其他信息', style: BTTypography.body(context)),
          ],
        ),
      );
    }
    var children = <Widget>[];
    for (var item in infobox) {
      children.add(_buildItem(context, item));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildItem(BuildContext context, BangumiInfoBoxItem item) {
    String value;
    if (item.value is List) {
      var list = item.value as List;
      value = list
          .map((e) => e['k'] != null ? '${e['k']}: ${e['v']}' : e['v'])
          .toList()
          .map((e) => replaceEscape(e as String))
          .join('\n');
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.key, style: BTTypography.bodyStrong(context)),
            SizedBox(height: 2),
            SelectableText(
              value,
              style: BTTypography.body(context),
              contextMenuBuilder: view.contextMenuBuilder,
            ),
          ],
        ),
      );
    }
    value = replaceEscape(item.value as String);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(item.key, style: BTTypography.bodyStrong(context)),
          ),
          SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: BTTypography.body(context),
              contextMenuBuilder: view.contextMenuBuilder,
            ),
          ),
        ],
      ),
    );
  }
}
