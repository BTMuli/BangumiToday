// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../ui/bt_icon.dart';
import 'sd_pw_rate_chart.dart';
import 'sdp_sections.dart';

/// 评分柱状图 + 社区收藏数，供折叠节使用。
class SdpScoreHeatSection extends StatelessWidget {
  const SdpScoreHeatSection({super.key, required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _badge(
              context,
              BangumiCollectionType.wish,
              subject.collection.wish,
            ),
            _badge(
              context,
              BangumiCollectionType.doing,
              subject.collection.doing,
            ),
            _badge(
              context,
              BangumiCollectionType.collect,
              subject.collection.collect,
            ),
            _badge(
              context,
              BangumiCollectionType.onHold,
              subject.collection.onHold,
            ),
            _badge(
              context,
              BangumiCollectionType.dropped,
              subject.collection.dropped,
            ),
          ],
        ),
        SizedBox(height: 12),
        if (subject.rating.count.isEmpty)
          Text('暂无评分分布', style: BTTypography.caption(context))
        else
          SdpRateChartWidget(subject.rating),
      ],
    );
  }

  Widget _badge(BuildContext context, BangumiCollectionType type, int? count) {
    var accent = FluentTheme.of(context).accentColor;
    return Tooltip(
      message: type.label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BTRadius.smallBR,
          color: accent.withValues(alpha: 0.15),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BtIcon(type.icon, size: 14),
            SizedBox(width: 4),
            Text('${count ?? 0}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class SdpScoreHeatExpander extends StatelessWidget {
  const SdpScoreHeatExpander({
    super.key,
    required this.subject,
    this.initiallyExpanded = false,
  });

  final BangumiSubject subject;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return SdpSection(
      icon: FluentIcons.chart,
      title: '评分与热度',
      initiallyExpanded: initiallyExpanded,
      content: SdpScoreHeatSection(subject: subject),
    );
  }
}
