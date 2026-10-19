// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_subject_browse.dart';
import '../../store/nav_store.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/common/bt_card.dart';

class BangumiRankingCard extends ConsumerWidget {
  const BangumiRankingCard({
    super.key,
    required this.item,
    required this.position,
  });

  final BangumiSubjectBrowseItem item;
  final int position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var subject = item.subject;
    var title = subject.nameCn.isEmpty ? subject.name : subject.nameCn;
    var accent = FluentTheme.of(context).accentColor;
    var rank = subject.rating.rank;

    void openDetail({bool jump = true}) {
      ref
          .read(navStoreProvider.notifier)
          .addNavItemB(subject: subject.id, paneTitle: title, jump: jump);
    }

    return BTCard(
      useAcrylic: false,
      useShadow: false,
      padding: const EdgeInsets.all(12),
      onTap: openDetail,
      onLongPress: () => openDetail(jump: false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            height: 126,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BTRadius.smallBR,
                  child: BtBangumiCover(
                    imageUrl: subject.images.large,
                    width: 84,
                    height: 126,
                    errorBuilder: (context, {err}) => Container(
                      width: 84,
                      height: 126,
                      color: BTColors.surfaceSecondary(context),
                      child: const Center(
                        child: Icon(FluentIcons.photo, size: 24),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -1,
                  left: -1,
                  child: _RankingPositionBadge(position: position),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: title,
                  child: Text(
                    title,
                    style: BTTypography.subtitle(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subject.nameCn.isNotEmpty && subject.name != title) ...[
                  const SizedBox(height: 2),
                  Text(
                    subject.name,
                    style: BTTypography.caption(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.info.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Tooltip(
                    message: item.info,
                    child: Text(
                      item.info,
                      style: BTTypography.caption(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (subject.metaTags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subject.metaTags.take(5).join(' · '),
                    style: BTTypography.caption(
                      context,
                    ).copyWith(color: accent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            subject.rating.total > 0
                                ? subject.rating.score.toStringAsFixed(1)
                                : '暂无评分',
                            style: BTTypography.body(context).copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${subject.rating.total} 人评分',
                            style: BTTypography.caption(context),
                          ),
                          if (rank != null && rank > 0)
                            Text(
                              '综合排名 #$rank',
                              style: BTTypography.caption(context),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '查看详情，长按后台添加',
                      child: GestureDetector(
                        onLongPress: () => openDetail(jump: false),
                        child: IconButton(
                          onPressed: openDetail,
                          icon: const Icon(
                            FluentIcons.info,
                            size: 16,
                            semanticLabel: '查看条目详情',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 封面左上角的名次角标：底色沿用卡片表面色，数字按名次档位着色。
class _RankingPositionBadge extends StatelessWidget {
  const _RankingPositionBadge({required this.position});

  /// 右下角使用更大的圆角，形成标签感。
  static const _tailRadius = Radius.circular(10);

  final int position;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(4)),
      child: Container(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BTColors.surfacePrimary(context).withValues(alpha: 0.9),
          border: Border.all(color: BTColors.divider(context)),
          borderRadius: const BorderRadius.only(bottomRight: _tailRadius),
        ),
        child: Text(
          position.toString().padLeft(2, '0'),
          style: TextStyle(
            color: _textColor(context),
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Color _textColor(BuildContext context) {
    var theme = FluentTheme.of(context);
    var brightness = theme.brightness;
    if (position <= 3) {
      return switch (position) {
        1 =>
          brightness == Brightness.dark
              ? const Color(0xFFFFD75E)
              : const Color(0xFFB8860B),
        2 =>
          brightness == Brightness.dark
              ? const Color(0xFFE6E6E6)
              : const Color(0xFF8A8A8A),
        _ =>
          brightness == Brightness.dark
              ? const Color(0xFFE29A5B)
              : const Color(0xFFA0522D),
      };
    }
    var accent = theme.accentColor.defaultBrushFor(brightness);
    var secondary = BTColors.textSecondary(context);
    if (position <= 10) return accent;
    if (position <= 30) return Color.lerp(accent, secondary, 0.35) ?? accent;
    if (position <= 50) return Color.lerp(accent, secondary, 0.65) ?? accent;
    if (position <= 100) return secondary;
    return BTColors.textTertiary(context);
  }
}
