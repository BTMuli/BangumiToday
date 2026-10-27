// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/bangumi_utils.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/request_subject.dart';
import '../../store/nav_store.dart';
import '../../ui/bt_icon.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/common/bt_card.dart';

/// Bangumi 条目卡片-搜索结果
class SubjectCardSearch extends ConsumerStatefulWidget {
  static const double height = 216;
  static const double coverWidth = 144;

  /// 结果
  final BangumiSubjectSearchData data;

  /// 标签点击回调
  final ValueChanged<String>? onTagTap;

  /// 标签长按回调。
  final ValueChanged<String>? onTagLongPress;
  final ValueChanged<String>? onMetaTagTap;
  final ValueChanged<String>? onMetaTagLongPress;

  /// 构造
  const SubjectCardSearch(
    this.data, {
    super.key,
    this.onTagTap,
    this.onTagLongPress,
    this.onMetaTagTap,
    this.onMetaTagLongPress,
  });

  @override
  ConsumerState<SubjectCardSearch> createState() => _SubjectCardSearchState();
}

/// Bangumi 条目卡片-搜索结果状态
class _SubjectCardSearchState extends ConsumerState<SubjectCardSearch> {
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
    return BtBangumiCover(
      imageUrl: img,
      width: SubjectCardSearch.coverWidth,
      height: SubjectCardSearch.height,
      errorBuilder: (context, {err}) => buildCoverEmpty(err: err),
    );
  }

  Widget buildTag(String name, {int? count, bool isMeta = false}) {
    var onTap = isMeta ? widget.onMetaTagTap : widget.onTagTap;
    var onLongPress = isMeta
        ? widget.onMetaTagLongPress
        : widget.onTagLongPress;
    var actions = [
      if (onTap != null) '点击搜索该标签',
      if (onLongPress != null) '长按添加到当前搜索',
    ];
    return Tooltip(
      message: [
        '${isMeta ? '公共标签' : '普通标签'}：$name'
            '${count == null ? '' : ' ($count)'}',
        ...actions,
      ].join('\n'),
      child: MouseRegion(
        cursor: onTap == null && onLongPress == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap == null ? null : () => onTap(name),
          onLongPress: onLongPress == null ? null : () => onLongPress(name),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMeta ? FluentIcons.tag_group : FluentIcons.tag,
                  size: 10,
                  color: FluentTheme.of(context).accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    color: FluentTheme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
    var tags = [...subject.tags];
    tags.sort((a, b) => b.count.compareTo(a.count));
    var metaTags = subject.metaTags.toSet();
    var counts = {for (var tag in tags) tag.name: tag.count};
    var chips = [
      for (var tag in metaTags) buildTag(tag, count: counts[tag], isMeta: true),
      for (var tag in tags.where((tag) => !metaTags.contains(tag.name)))
        buildTag(tag.name, count: tag.count),
    ];
    return SizedBox(
      height: 24,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < chips.length; index++) ...[
              if (index > 0) SizedBox(width: 4),
              chips[index],
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
          .read(navStoreProvider.notifier)
          .addNavItemB(
            type: label,
            subject: subject.id,
            paneTitle: paneTitle,
            jump: jump,
          );
    }

    var rank = subject.rating.rank;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildScoreWidget(),
              if (subject.rating.total > 0)
                Text(
                  '${subject.rating.total} 人评分',
                  style: BTTypography.caption(context),
                ),
              _buildMetaItem(
                FluentIcons.bar_chart4,
                rank != null && rank > 0 ? '排名 #$rank' : '未上榜',
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Tooltip(
          message: '点击查看$label详情，长按后台添加',
          child: GestureDetector(
            onLongPress: () => openDetail(jump: false),
            child: IconButton(
              key: ValueKey('subject-detail-action-${subject.id}'),
              onPressed: openDetail,
              icon: Icon(
                FluentIcons.open_in_new_tab,
                size: 16,
                color: FluentTheme.of(context).accentColor,
                semanticLabel: '查看$label详情',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreWidget() {
    var score = subject.rating.score;
    var rated = subject.rating.total > 0;
    var scoreLabel = getBangumiRateLabel(score);
    var scoreColor = rated
        ? _getScoreColor(score)
        : BTColors.textSecondary(context);

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
            rated ? score.toStringAsFixed(1) : '暂无评分',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scoreColor,
            ),
          ),
          if (rated) ...[
            SizedBox(width: 6),
            Text(
              scoreLabel,
              style: TextStyle(
                fontSize: 12,
                color: BTColors.textSecondary(context),
              ),
            ),
          ],
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
    var subTitle = subject.name == name ? '' : subject.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: name,
          child: Text.rich(
            TextSpan(
              children: [
                if (subject.type != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildTypeBadge(),
                    ),
                  ),
                TextSpan(text: name),
              ],
            ),
            style: FluentTheme.of(context).typography.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subject.info.trim().isNotEmpty)
                Flexible(child: _buildExcerpt(subject.info))
              else if (subject.date?.isNotEmpty == true ||
                  subject.eps > 0 ||
                  subject.platform?.isNotEmpty == true ||
                  subject.volumes > 0)
                _buildMetaInfo(),
              if (subject.summary.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Flexible(child: _buildExcerpt(subject.summary)),
              ],
              if (subject.metaTags.isNotEmpty || subject.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                buildTags(),
              ],
              if ((subject.collection.collect ?? 0) > 0 ||
                  (subject.collection.wish ?? 0) > 0 ||
                  (subject.collection.doing ?? 0) > 0) ...[
                const SizedBox(height: 6),
                _buildCollectionInfo(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        buildAction(context),
      ],
    );
  }

  Widget _buildExcerpt(String value) => Tooltip(
    message: value,
    child: Text(
      value.replaceAll(RegExp(r'\s+'), ' ').trim(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: BTTypography.caption(context).copyWith(height: 1.35),
    ),
  );

  Widget _buildMetaInfo() {
    var episodeUnit = switch (subject.type) {
      BangumiSubjectType.book => '话',
      BangumiSubjectType.music => '曲',
      _ => '集',
    };
    var items = <Widget>[
      if (subject.date != null && subject.date!.isNotEmpty)
        _buildMetaItem(FluentIcons.calendar, subject.date!),
      if (subject.eps > 0)
        _buildMetaItem(FluentIcons.play, '${subject.eps}$episodeUnit'),
      if (subject.volumes > 0)
        _buildMetaItem(FluentIcons.bookmarks, '${subject.volumes}卷'),
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

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        if (collect > 0) _buildMetaItem(FluentIcons.heart_fill, '完成 $collect'),
        if (wish > 0)
          _buildMetaItem(FluentIcons.favorite_star_fill, '计划 $wish'),
        if (doing > 0) _buildMetaItem(FluentIcons.play, '进行中 $doing'),
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
        height: SubjectCardSearch.height,
        child: Row(
          children: [
            SizedBox(
              width: SubjectCardSearch.coverWidth,
              height: SubjectCardSearch.height,
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
