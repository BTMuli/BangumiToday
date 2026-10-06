// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/bangumi_utils.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/common/bt_card.dart';
import 'subject_detail_rate_chart.dart';
import 'subject_detail_view_data.dart';

/// 封面、标题、收藏操作与评分的紧凑概览。
class SubjectDetailOverview extends StatelessWidget {
  const SubjectDetailOverview({
    super.key,
    required this.view,
    required this.onShowEpisodes,
  });

  final SubjectDetailViewData view;
  final VoidCallback onShowEpisodes;

  BangumiSubject get subject => view.subject;

  String get title => subject.nameCn.isEmpty ? subject.name : subject.nameCn;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var wide = constraints.maxWidth >= 760;
        var coverWidth = constraints.maxWidth < 480 ? 80.0 : 112.0;
        var identity = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCover(context, coverWidth),
            const SizedBox(width: 18),
            Expanded(child: _buildIdentity(context, showActions: wide)),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 24),
                  SizedBox(width: 136, child: _buildRating(context)),
                ],
              )
            else ...[
              identity,
              const SizedBox(height: 14),
              _buildActions(context),
              const SizedBox(height: 14),
              _buildRating(context, compact: true),
            ],
            const SizedBox(height: 18),
            _buildTags(context),
            const SizedBox(height: 12),
            _buildCollectionCounts(context),
            const SizedBox(height: 16),
            Container(height: 1, color: BTColors.divider(context)),
          ],
        );
      },
    );
  }

  Widget _buildCover(BuildContext context, double width) {
    return BtBangumiCover(
      imageUrl: subject.images.large,
      fit: BoxFit.cover,
      width: width,
      height: width * 1.4,
      maxRequestEdge: BangumiCoverUrl.detailMaxEdge,
      borderRadius: BTRadius.mediumBR,
      errorBuilder: (context, {err}) => Container(
        width: width,
        height: width * 1.4,
        decoration: BoxDecoration(
          color: BTColors.surfaceSecondary(context),
          borderRadius: BTRadius.mediumBR,
        ),
        child: Icon(
          FluentIcons.photo_error,
          color: BTColors.textTertiary(context),
        ),
      ),
    );
  }

  Widget _buildIdentity(BuildContext context, {bool showActions = false}) {
    var total = subject.totalEpisodes > 0 ? subject.totalEpisodes : subject.eps;
    var metadata = <String>[
      if (subject.date?.isNotEmpty == true) '首播 ${subject.date}',
      if (subject.platform.isNotEmpty) subject.platform,
      if (total > 0) '共 $total 集',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(metadata.join(' · '), style: BTTypography.caption(context)),
        const SizedBox(height: 8),
        SelectableText(
          title,
          style: BTTypography.subtitle(
            context,
          ).copyWith(fontSize: 22, fontWeight: FontWeight.w600),
          contextMenuBuilder: view.contextMenuBuilder,
        ),
        if (subject.nameCn.isNotEmpty && subject.name != subject.nameCn) ...[
          const SizedBox(height: 6),
          Tooltip(
            message: subject.name,
            child: Text(
              subject.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BTTypography.caption(context),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Bangumi ${subject.id}', style: BTTypography.caption(context)),
            Tooltip(
              message: '前往 Bangumi',
              child: IconButton(
                icon: const Icon(FluentIcons.edge_logo, size: 14),
                onPressed: () async {
                  await launchUrlString(
                    '${BtrBangumiApi.siteBaseUrl}/subject/${subject.id}',
                  );
                },
                onLongPress: () async {
                  if (!kDebugMode) return;
                  await showRespErr(
                    BTResponse.success(data: subject),
                    context,
                    title: '详细数据，ID: ${subject.id}',
                  );
                },
              ),
            ),
            Tooltip(
              message: '复制标题',
              child: IconButton(
                icon: const Icon(FluentIcons.copy, size: 14),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: title));
                  if (context.mounted) {
                    await BtInfobar.success(context, '已复制标题');
                  }
                },
              ),
            ),
          ],
        ),
        if (showActions) ...[
          const SizedBox(height: 12),
          _buildActions(context),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return ListenableBuilder(
      listenable: view.collectProvider,
      builder: (context, _) {
        var total = subject.totalEpisodes > 0
            ? subject.totalEpisodes
            : subject.eps;
        var done = view.collectProvider.epStatus;
        var progress = total > 0 ? '$done / $total' : '$done';
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (view.user != null) ...[
              view.buildCollection(compact: true),
              Button(onPressed: onShowEpisodes, child: Text('观看进度 $progress')),
            ] else
              Text('登录后可收藏和记录进度', style: BTTypography.caption(context)),
          ],
        );
      },
    );
  }

  Widget _buildRating(BuildContext context, {bool compact = false}) {
    var rating = subject.rating;
    var children = <Widget>[
      Text(
        rating.total == 0 ? '暂无评分' : rating.score.toStringAsFixed(1),
        style: BTTypography.subtitle(context).copyWith(
          fontSize: rating.total == 0 ? 16 : 30,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (rating.total > 0) ...[
        Text(
          getBangumiRateLabel(rating.score),
          style: BTTypography.body(context),
        ),
        Text('${rating.total} 人评分', style: BTTypography.caption(context)),
        HyperlinkButton(
          onPressed: rating.count.isEmpty
              ? null
              : () async {
                  await showDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    dismissWithEsc: true,
                    builder: (dialogContext) => ContentDialog(
                      constraints: const BoxConstraints(maxWidth: 600),
                      title: const Text('评分分布'),
                      content: SubjectDetailRateChart(rating),
                      actions: [
                        Button(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('关闭'),
                        ),
                      ],
                    ),
                  );
                },
          child: const Text('评分分布'),
        ),
      ],
    ];
    if (compact) {
      return Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }
    return Container(
      padding: const EdgeInsets.only(left: 20),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: BTColors.divider(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTags(BuildContext context) {
    var tags = subject.tags.take(8);
    var accent = FluentTheme.of(context).accentColor;
    var dark = FluentTheme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var tag in tags)
          Tooltip(
            message: '点击搜索标签：${tag.name} (${tag.count})',
            child: BTCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              borderRadius: BTRadius.small,
              useAcrylic: false,
              useShadow: false,
              backgroundColor: Color.alphaBlend(
                accent.withValues(alpha: dark ? 0.18 : 0.12),
                BTColors.surfaceSecondary(context),
              ),
              borderColor: accent.withValues(alpha: dark ? 0.35 : 0.25),
              onTap: () => view.onTagTap(tag.name),
              child: Text(tag.name, style: BTTypography.body(context)),
            ),
          ),
      ],
    );
  }

  Widget _buildCollectionCounts(BuildContext context) {
    var collection = subject.collection;
    return Text(
      '想看 ${collection.wish ?? 0} · 在看 ${collection.doing ?? 0} · '
      '看过 ${collection.collect ?? 0} · 搁置 ${collection.onHold ?? 0} · '
      '抛弃 ${collection.dropped ?? 0}',
      style: BTTypography.caption(context),
    );
  }
}
