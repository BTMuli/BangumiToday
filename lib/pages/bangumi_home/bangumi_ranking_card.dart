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
            width: 36,
            child: Text(
              position.toString().padLeft(2, '0'),
              style: BTTypography.subtitle(context).copyWith(
                color: position <= 3 ? accent : BTColors.textTertiary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          BtBangumiCover(
            imageUrl: subject.images.large,
            width: 84,
            height: 126,
            borderRadius: BTRadius.smallBR,
            errorBuilder: (context, {err}) => Container(
              width: 84,
              height: 126,
              color: BTColors.surfaceSecondary(context),
              child: const Center(child: Icon(FluentIcons.photo, size: 24)),
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
