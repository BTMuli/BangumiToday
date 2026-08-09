// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/theme/bt_theme.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/request_subject.dart';
import '../../../request/bangumi/bangumi_api.dart';
import '../../../store/nav_store.dart';
import '../../../ui/bt_icon.dart';
import '../../../utils/bangumi_utils.dart';
import '../../common/bt_card.dart';

/// Bangumi 条目卡片-搜索结果
class BscSearch extends ConsumerStatefulWidget {
  /// 结果
  final BangumiSubjectSearchData data;

  /// 标签点击回调
  final ValueChanged<String>? onTagTap;

  /// 构造
  const BscSearch(this.data, {super.key, this.onTagTap});

  @override
  ConsumerState<BscSearch> createState() => _BscSearchState();
}

/// Bangumi 条目卡片-搜索结果状态
class _BscSearchState extends ConsumerState<BscSearch> {
  /// 数据
  BangumiSubjectSearchData get subject => widget.data;

  /// label
  String get label => subject.type?.label ?? '条目';

  /// 构建无封面的卡片
  Widget buildCoverEmpty({String? err}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BtIcon(FluentIcons.photo_error, size: 28),
            Text(
              err ?? '无封面',
              style: TextStyle(
                color: FluentTheme.of(context).accentColor.darkest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡片封面
  Widget buildCover(String img) {
    if (img.isEmpty) return buildCoverEmpty();
    // bangumi 在线切图 https://github.com/bangumi/img-proxy
    var pathGet = Uri.parse(img).path;
    // 可能是以 /r/xxx/pic 开头，用正则进行替换为 /pic
    var rReg = RegExp(r'^/r/[^/]+/pic');
    if (rReg.hasMatch(pathGet)) pathGet = pathGet.replaceFirst(rReg, '/pic');
    return CachedNetworkImage(
      imageUrl: '${BtrBangumiApi.imageBaseUrl}/r/0x600$pathGet',
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, dp) => Center(
        child: ProgressRing(
          value: dp.progress == null ? 0 : dp.progress! * 100,
        ),
      ),
      errorWidget: (context, url, error) =>
          buildCoverEmpty(err: error.toString()),
    );
  }

  Widget buildTag(String name, int count) {
    return Tooltip(
      message: '$name ($count)',
      child: MouseRegion(
        cursor: widget.onTagTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTagTap == null ? null : () => widget.onTagTap!(name),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: FluentTheme.of(
                context,
              ).accentColor.withValues(alpha: 0.15),
              borderRadius: BTRadius.smallBR,
              border: Border.all(
                color: FluentTheme.of(
                  context,
                ).accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: FluentTheme.of(context).accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    var type = subject.type;
    if (type == null) return const SizedBox.shrink();

    var accentColor = FluentTheme.of(context).accentColor;
    return Tooltip(
      message: '类型：${type.label}',
      child: Container(
        key: ValueKey('subject-type-${subject.id}'),
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.16),
          borderRadius: BTRadius.smallBR,
          border: Border.all(
            color: accentColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Text(
          type.label,
          style: TextStyle(
            color: accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget buildTags() {
    var maxNum = 5;
    var tags = [...subject.tags];
    tags.sort((a, b) => b.count.compareTo(a.count));
    if (tags.length > maxNum) {
      tags = tags.sublist(0, maxNum);
    }
    return SizedBox(
      height: 24,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < tags.length; index++) ...[
              if (index > 0) SizedBox(width: 4),
              buildTag(tags[index].name, tags[index].count),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildAction(BuildContext context) {
    var paneTitle = subject.nameCn == '' ? subject.name : subject.nameCn;

    void openDetail({bool jump = true}) {
      ref
          .read(navStoreProvider)
          .addNavItemB(
            type: label,
            subject: subject.id,
            paneTitle: paneTitle,
            jump: jump,
          );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: _buildScoreWidget()),
        SizedBox(width: 8),
        Tooltip(
          message: '点击查看$label详情，长按后台添加',
          child: BTCard(
            key: ValueKey('subject-detail-action-${subject.id}'),
            useShadow: false,
            useAcrylic: false,
            padding: EdgeInsets.all(8),
            borderRadius: BTRadius.medium,
            onTap: openDetail,
            onLongPress: () => openDetail(jump: false),
            child: Icon(
              FluentIcons.open_in_new_tab,
              size: 16,
              color: FluentTheme.of(context).accentColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreWidget() {
    var score = subject.rating.score;
    var scoreLabel = getBangumiRateLabel(score);
    var scoreColor = _getScoreColor(score);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.15),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.favorite_star_fill, size: 14, color: scoreColor),
          SizedBox(width: 4),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scoreColor,
            ),
          ),
          SizedBox(width: 6),
          Text(
            scoreLabel,
            style: TextStyle(
              fontSize: 12,
              color: BTColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 8.0) return const Color(0xFF107C10);
    if (score >= 7.0) return const Color(0xFF0078D4);
    if (score >= 6.0) return const Color(0xFFFFB900);
    if (score >= 5.0) return const Color(0xFFFF8C00);
    return const Color(0xFFD13438);
  }

  /// 构建卡片信息
  Widget buildInfo(BuildContext context) {
    var name = subject.nameCn == '' ? subject.name : subject.nameCn;
    var subTitle = subject.nameCn == '' ? '' : subject.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: name,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (subject.type != null) ...[
                _buildTypeBadge(),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  name,
                  style: FluentTheme.of(context).typography.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (subTitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Tooltip(
            message: subTitle,
            child: Text(
              subTitle,
              style: FluentTheme.of(context).typography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const SizedBox(height: 4),
        _buildMetaInfo(),
        const SizedBox(height: 4),
        Expanded(child: buildTags()),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(child: _buildCollectionInfo()),
            const SizedBox(width: 8),
            buildAction(context),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaInfo() {
    var items = <Widget>[
      if (subject.date != null && subject.date!.isNotEmpty)
        _buildMetaItem(FluentIcons.calendar, subject.date!),
      if (subject.eps > 0) _buildMetaItem(FluentIcons.play, '${subject.eps}集'),
      if (subject.platform != null && subject.platform!.isNotEmpty)
        _buildMetaItem(FluentIcons.devices2, subject.platform!),
    ];
    return SizedBox(
      height: 22,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) SizedBox(width: 8),
              items[index],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: BTColors.textSecondary(context)),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: BTColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionInfo() {
    var collect = subject.collection.collect ?? 0;
    var wish = subject.collection.wish ?? 0;
    var doing = subject.collection.doing ?? 0;

    if (collect == 0 && wish == 0 && doing == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (collect > 0) ...[
          Icon(FluentIcons.heart_fill, size: 12, color: Colors.red),
          SizedBox(width: 3),
          Text(
            '$collect',
            style: TextStyle(
              fontSize: 11,
              color: BTColors.textSecondary(context),
            ),
          ),
          SizedBox(width: 10),
        ],
        if (wish > 0) ...[
          Icon(FluentIcons.favorite_star_fill, size: 12, color: Colors.orange),
          SizedBox(width: 3),
          Text(
            '$wish',
            style: TextStyle(
              fontSize: 11,
              color: BTColors.textSecondary(context),
            ),
          ),
          SizedBox(width: 10),
        ],
        if (doing > 0) ...[
          Icon(FluentIcons.play, size: 12, color: Colors.green),
          SizedBox(width: 3),
          Text(
            '$doing',
            style: TextStyle(
              fontSize: 11,
              color: BTColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return BTCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      useAcrylic: true,
      acrylicOpacity: 0.8,
      useReveal: true,
      useShadow: true,
      shadowLevel: BTShadowLevel.medium,
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.06),
      borderWidth: 1.5,
      child: SizedBox(
        height: 168,
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 168,
              child: buildCover(subject.images.common),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: buildInfo(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
