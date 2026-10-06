// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/tool_func.dart';
import '../../models/bangumi/bangumi_model.dart';
import 'subject_detail_view_data.dart';

class SubjectDetailSummaryBody extends StatelessWidget {
  const SubjectDetailSummaryBody({super.key, required this.view});

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

class SubjectDetailInfoboxBody extends StatelessWidget {
  const SubjectDetailInfoboxBody({super.key, required this.view});

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
