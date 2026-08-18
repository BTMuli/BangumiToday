// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/bangumi_utils.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/common/bt_card.dart';

/// 方案 A 身份带：封面左侧，标题评分标签贴在封面右侧。
class SdpIdentityBand extends StatelessWidget {
  const SdpIdentityBand({super.key, required this.subject, this.onTagTap});

  static const double coverWidth = 200;
  static const double coverHeight = 280;

  /// 封面 + 间距 + 最窄信息列；低于此宽度才上下叠。
  static const double _sideBySideMinWidth = coverWidth + 16 + 220;

  final BangumiSubject subject;
  final ValueChanged<String>? onTagTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var cover = _buildCover(context);
        var stacked = constraints.maxWidth < _sideBySideMinWidth;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cover,
              SizedBox(height: 12),
              _buildInfo(context, fillHeight: false),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cover,
            SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: coverHeight,
                child: _buildInfo(context, fillHeight: true),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCover(BuildContext context) {
    return SizedBox(
      key: const ValueKey('subject-identity-cover'),
      width: coverWidth,
      height: coverHeight,
      child: BtBangumiCover(
        imageUrl: subject.images.large,
        fit: BoxFit.scaleDown,
        width: coverWidth,
        height: coverHeight,
        maxRequestEdge: BangumiCoverUrl.detailMaxEdge,
        borderRadius: BTRadius.mediumBR,
        errorBuilder: (context, {err}) {
          return Container(
            width: coverWidth,
            height: coverHeight,
            decoration: BoxDecoration(
              color: BTColors.surfaceSecondary(context),
              borderRadius: BTRadius.mediumBR,
            ),
            child: Icon(
              FluentIcons.photo_error,
              color: BTColors.textTertiary(context),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfo(BuildContext context, {required bool fillHeight}) {
    var title = subject.nameCn.isEmpty ? subject.name : subject.nameCn;
    var tags = subject.tags.length > 8
        ? subject.tags.sublist(0, 8)
        : subject.tags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ID: ${subject.id}', style: BTTypography.caption(context)),
            SizedBox(width: 4),
            Tooltip(
              message: '前往Bangumi',
              child: IconButton(
                icon: BtIcon(FluentIcons.edge_logo, size: 14),
                onPressed: () async {
                  await launchUrlString(
                    '${BtrBangumiApi.siteBaseUrl}/subject/'
                    '${subject.id}',
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
                key: const ValueKey('subject-identity-copy-title'),
                icon: BtIcon(FluentIcons.copy, size: 14),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: title));
                  BtInfobar.success(context, '已复制标题: $title');
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: BTTypography.title(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subject.nameCn.isNotEmpty) ...[
          SizedBox(height: 2),
          Text(subject.name, style: BTTypography.caption(context)),
        ],
        SizedBox(height: 8),
        Text(_metaLine(), style: BTTypography.body(context)),
        SizedBox(height: 8),
        _buildScoreLine(context),
        if (tags.isNotEmpty) ...[
          SizedBox(height: 10),
          if (fillHeight)
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags.map((tag) => _buildTag(context, tag)).toList(),
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((tag) => _buildTag(context, tag)).toList(),
            ),
        ],
      ],
    );
  }

  String _metaLine() {
    var parts = <String>[];
    if (subject.date != null && subject.date!.isNotEmpty) {
      parts.add(subject.date!);
    }
    if (subject.totalEpisodes > 0) {
      parts.add('${subject.totalEpisodes} 话');
    } else if (subject.eps > 0) {
      parts.add('${subject.eps} 话');
    }
    if (subject.platform.isNotEmpty) parts.add(subject.platform);
    return parts.join(' · ');
  }

  Widget _buildScoreLine(BuildContext context) {
    var rating = subject.rating;
    if (rating.total == 0) {
      return Text('暂无评分', style: BTTypography.caption(context));
    }
    var label = getBangumiRateLabel(rating.score);
    return Text(
      '★ ${rating.score.toStringAsFixed(1)}  $label  ·  '
      '${rating.total} 人评分',
      key: const ValueKey('subject-identity-score'),
      style: BTTypography.bodyStrong(context),
    );
  }

  Widget _buildTag(BuildContext context, BangumiTag tag) {
    var accent = FluentTheme.of(context).accentColor;
    Widget child = Text(
      tag.name,
      style: TextStyle(fontSize: 11, color: accent),
    );
    if (onTagTap == null) {
      return Tooltip(
        message: '${tag.name} (${tag.count})',
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BTRadius.smallBR,
            color: accent.withValues(alpha: 0.1),
          ),
          child: child,
        ),
      );
    }
    return Tooltip(
      message: '点击搜索标签：${tag.name} (${tag.count})',
      child: BTCard(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        borderRadius: BTRadius.small,
        useAcrylic: false,
        useShadow: false,
        backgroundColor: accent.withValues(alpha: 0.1),
        borderColor: accent.withValues(alpha: 0.2),
        onTap: () => onTagTap!(tag.name),
        child: child,
      ),
    );
  }
}
