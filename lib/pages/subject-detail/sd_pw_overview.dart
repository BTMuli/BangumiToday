import 'package:flutter/foundation.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/theme/bt_theme.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import 'sd_pw_rate_chart.dart';

class SdpOverviewWidget extends StatelessWidget {
  final BangumiSubject item;

  const SdpOverviewWidget(this.item, {super.key});

  Widget buildCoverError(BuildContext context, {String? err}) {
    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.photo_error,
              size: 32,
              color: BTColors.textTertiary(context),
            ),
            SizedBox(height: 8),
            Text(
              err ?? '无封面',
              style: BTTypography.body(context).copyWith(
                color: BTColors.textTertiary(context),
                fontSize: err == null ? 14 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCover(BuildContext context, BangumiImages images) {
    if (images.large == '') {
      return buildCoverError(context);
    }
    var pathGet = Uri.parse(images.large).path;
    var link = '${BtrBangumiApi.imageBaseUrl}/r/0x600$pathGet';
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 400, maxHeight: 280),
      child: ClipRRect(
        borderRadius: BTRadius.mediumBR,
        child: CachedNetworkImage(
          imageUrl: link,
          fit: BoxFit.scaleDown,
          progressIndicatorBuilder: (context, url, dp) => Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: ProgressRing(
                value: dp.progress == null ? 0 : dp.progress! * 100,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) =>
              buildCoverError(context, err: error.toString()),
        ),
      ),
    );
  }

  Widget buildCollectionInfoBadge(
    BuildContext context,
    BangumiCollectionType type,
    int? count,
  ) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Tooltip(
      message: type.label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BTRadius.smallBR,
          color: accentColor.withValues(alpha: 0.15),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            BtIcon(type.icon, size: 14),
            SizedBox(width: 4),
            Text(
              count?.toString() ?? '0',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTag(BuildContext context, String text) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BTRadius.smallBR,
        color: accentColor.withValues(alpha: 0.1),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: accentColor)),
    );
  }

  Widget buildInfo(BuildContext context) {
    var showTags = item.tags.length > 10 ? item.tags.sublist(0, 10) : item.tags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ID: ${item.id}', style: BTTypography.caption(context)),
            SizedBox(width: 8),
            Tooltip(
              message: '前往Bangumi',
              child: IconButton(
                icon: BtIcon(FluentIcons.edge_logo, size: 14),
                onPressed: () async {
                  await launchUrlString(
                    '${BtrBangumiApi.siteBaseUrl}/subject/${item.id}',
                  );
                },
                onLongPress: () async {
                  if (!kDebugMode) return;
                  await showRespErr(
                    BTResponse.success(data: item),
                    context,
                    title: '详细数据，ID: ${item.id}',
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 6),

        if (item.nameCn == '') ...[
          Text(item.name, style: BTTypography.title(context)),
        ] else ...[
          Text(item.nameCn, style: BTTypography.title(context)),
          SizedBox(height: 2),
          Text(item.name, style: BTTypography.caption(context)),
        ],
        SizedBox(height: 8),

        _buildInfoRow(context, '首播', item.date),
        _buildInfoRow(context, '集数', '${item.eps}/${item.totalEpisodes}'),
        _buildInfoRow(context, '平台', item.platform),
        SizedBox(height: 8),

        Text('收藏情况', style: BTTypography.bodyStrong(context)),
        SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            buildCollectionInfoBadge(
              context,
              BangumiCollectionType.wish,
              item.collection.wish,
            ),
            buildCollectionInfoBadge(
              context,
              BangumiCollectionType.doing,
              item.collection.doing,
            ),
            buildCollectionInfoBadge(
              context,
              BangumiCollectionType.collect,
              item.collection.collect,
            ),
            buildCollectionInfoBadge(
              context,
              BangumiCollectionType.onHold,
              item.collection.onHold,
            ),
            buildCollectionInfoBadge(
              context,
              BangumiCollectionType.dropped,
              item.collection.dropped,
            ),
          ],
        ),
        SizedBox(height: 8),

        if (showTags.isNotEmpty) ...[
          Text('标签', style: BTTypography.bodyStrong(context)),
          SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: showTags.map((e) => buildTag(context, e.name)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: BTTypography.caption(
                context,
              ).copyWith(color: BTColors.textSecondary(context)),
            ),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(value, style: BTTypography.body(context))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCover(context, item.images),
        SizedBox(width: 16),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(right: 12),
              scrollDirection: Axis.vertical,
              child: buildInfo(context),
            ),
          ),
        ),
        SizedBox(width: 12),
        Flexible(child: SdpRateChartWidget(item.rating)),
      ],
    );
  }
}
