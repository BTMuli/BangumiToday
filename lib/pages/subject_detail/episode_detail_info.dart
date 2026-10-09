// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/tool_func.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import 'episode_detail_page.dart';
import 'subject_detail_colors.dart';

/// 剧集信息卡：章节信息固定在左，简介在右侧独立滚动。
///
/// 作为剧集详情页的页头固定展示，吐槽列表在卡片下方滚动。
class EpisodeDetailOverview extends StatelessWidget {
  const EpisodeDetailOverview({
    super.key,
    required this.data,
    required this.maxHeight,
    required this.onOpenSubject,
    required this.onOpenEpisode,
    this.previous,
    this.next,
  });

  final BangumiEpisodeDetail data;

  /// 页头为信息卡预留的最大高度
  final double maxHeight;

  /// 跳转到所属条目
  final EpisodeSubjectJump onOpenSubject;

  /// 切换到相邻章节
  final ValueChanged<int> onOpenEpisode;

  /// 上一集，没有时按钮禁用
  final EpisodeNeighbor? previous;

  /// 下一集，没有时按钮禁用
  final EpisodeNeighbor? next;

  String get _name => data.name.trim();

  String get _nameCn => data.nameCn.trim();

  /// 当前用户的章节收藏状态；接口不带 collection 时不显示
  String? get _collectionLabel => data.collection?.status.label;

  @override
  Widget build(BuildContext context) {
    var subject = data.subject;
    // 卡片上下内边距各 16，简介滚动列表要扣掉这部分高度
    var scrollHeight = maxHeight - 32;
    if (scrollHeight < 120) scrollHeight = 120;
    return ConstrainedBox(
      // 正常窗口下剧集信息不会触到上限；窗口极矮时裁掉超出部分，
      // 避免页头把正文挤出可视区。
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SubjectDetailColors.card(context),
          borderRadius: BTRadius.mediumBR,
          border: Border.all(color: BTColors.divider(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubjectCover(context, subject?.images),
            const SizedBox(width: 16),
            // 剧集信息：内容自适应，不滚动
            Expanded(
              flex: 3,
              child: ClipRect(child: _buildIdentity(context, subject)),
            ),
            const SizedBox(width: 16),
            // 简介：占右侧剩余空间，「简介」标题固定，只有内容滚动
            Expanded(
              flex: 2,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: scrollHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('简介', style: BTTypography.bodyStrong(context)),
                    const SizedBox(height: 6),
                    Flexible(
                      child: SingleChildScrollView(
                        primary: false,
                        child: _buildDescription(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 上一集 / 下一集按钮：目标为空时禁用，提示里带上目标标题
  Widget _buildSwitchButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required EpisodeNeighbor? neighbor,
  }) {
    var target = neighbor;
    var tooltip = target == null ? '没有$label' : '$label：${target.label}';
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: Button(
          onPressed: target == null ? null : () => onOpenEpisode(target.id),
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14),
              const SizedBox(width: 4),
              Text(label, style: BTTypography.caption(context)),
            ],
          ),
        ),
      ),
    );
  }

  /// 章节标题、元信息与所属条目
  Widget _buildIdentity(BuildContext context, BangumiEpisodeSubject? subject) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectableText(
                'ep.${EpisodeDetailPage.formatSort(data.sort)} '
                '${_name.isEmpty ? '章节 ${data.id}' : _name}',
                style: BTTypography.title(context),
              ),
            ),
            const SizedBox(width: 8),
            _buildSwitchButton(
              context,
              icon: FluentIcons.chevron_left,
              label: '上一集',
              neighbor: previous,
            ),
            const SizedBox(width: 4),
            _buildSwitchButton(
              context,
              icon: FluentIcons.chevron_right,
              label: '下一集',
              neighbor: next,
            ),
          ],
        ),
        if (_nameCn.isNotEmpty) ...[
          const SizedBox(height: 4),
          SelectableText(
            _nameCn,
            style: BTTypography.body(
              context,
            ).copyWith(color: BTColors.textSecondary(context)),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _MetaChip(
              icon: FluentIcons.calendar,
              text: data.airDate.isEmpty ? '未定' : data.airDate,
            ),
            _MetaChip(
              icon: FluentIcons.clock,
              text: data.duration.isEmpty ? '未知时长' : data.duration,
            ),
            _MetaChip(icon: FluentIcons.video, text: data.type.label),
            // 未登录或接口未返回收藏状态时不占位
            if (_collectionLabel != null)
              _MetaChip(icon: FluentIcons.check_mark, text: _collectionLabel!),
          ],
        ),
        if (subject != null) ...[
          const SizedBox(height: 10),
          _buildSubjectRow(context, subject),
          if (subject.info.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              replaceEscape(subject.info).trim(),
              style: BTTypography.caption(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
        const SizedBox(height: 6),
        Text(
          subject == null
              ? '章节 ID ${data.id}'
              : '章节 ID ${data.id} · 条目 ID ${subject.id}',
          style: BTTypography.caption(
            context,
          ).copyWith(color: BTColors.textTertiary(context)),
        ),
        if (subject != null && subject.metaTags.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '标签：${subject.metaTags.map(replaceEscape).join(' · ')}',
            style: BTTypography.caption(
              context,
            ).copyWith(color: BTColors.textTertiary(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// 所属条目一行：名称按内容取宽，点击进入条目详情
  Widget _buildSubjectRow(BuildContext context, BangumiEpisodeSubject subject) {
    var name = subject.nameCn.trim().isEmpty
        ? subject.name.trim()
        : subject.nameCn.trim();
    var rating = subject.rating;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('所属条目', style: BTTypography.caption(context)),
        const SizedBox(width: 8),
        Flexible(
          child: HyperlinkButton(
            onPressed: () => onOpenSubject(subject),
            child: Text(
              replaceEscape(name),
              style: BTTypography.bodyStrong(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (rating != null) ...[
          const SizedBox(width: 8),
          _MetaChip(
            icon: FluentIcons.favorite_star,
            text: '${rating.score.toStringAsFixed(1)} 分',
            tooltip:
                '${rating.total} 人评分'
                '${rating.rank == null ? '' : ' · 排名 #${rating.rank}'}',
          ),
        ],
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    var desc = data.desc.trim();
    if (desc.isEmpty) {
      return Row(
        children: [
          Icon(
            FluentIcons.error_badge,
            size: 16,
            color: BTColors.textTertiary(context),
          ),
          const SizedBox(width: 8),
          Text('暂无简介', style: BTTypography.body(context)),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SubjectDetailColors.content(context),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: SelectableText(
        replaceEscape(desc),
        style: BTTypography.body(context).copyWith(height: 1.6),
      ),
    );
  }
}

/// 剧集信息卡的条目封面，缺图时回落为占位图标。
Widget _buildSubjectCover(BuildContext context, BangumiImages? images) {
  return Container(
    width: 84,
    height: 120,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: SubjectDetailColors.content(context),
      borderRadius: BTRadius.smallBR,
    ),
    child: BtBangumiCover(
      imageUrl: images?.large,
      fit: BoxFit.contain,
      width: 84,
      height: 120,
      maxRequestEdge: BangumiCoverUrl.gridMaxEdge,
      progressSize: 16,
      errorBuilder: (context, {err}) => Icon(
        FluentIcons.photo_error,
        size: 24,
        color: BTColors.textTertiary(context),
      ),
    ),
  );
}

/// 概览使用的小型信息块。
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text, this.tooltip});

  final IconData icon;
  final String text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    var chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: BTColors.textSecondary(context)),
          const SizedBox(width: 5),
          Text(text, style: BTTypography.caption(context)),
        ],
      ),
    );
    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}
