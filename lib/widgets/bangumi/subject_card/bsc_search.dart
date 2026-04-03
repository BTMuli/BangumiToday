// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../../core/theme/bt_theme.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/request_subject.dart';
import '../../../store/nav_store.dart';
import '../../../ui/bt_icon.dart';
import '../../../utils/bangumi_utils.dart';
import '../../common/bt_card.dart';

/// Bangumi 条目卡片-搜索结果
class BscSearch extends ConsumerStatefulWidget {
  /// 结果
  final BangumiSubjectSearchData data;

  /// 构造
  const BscSearch(this.data, {super.key});

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
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BtIcon(FluentIcons.photo_error, size: 28.sp),
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
      imageUrl: 'https://lain.bgm.tv/r/0x600$pathGet',
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: FluentTheme.of(context).accentColor.withValues(alpha: 0.15),
          borderRadius: BTRadius.smallBR,
          border: Border.all(
            color: FluentTheme.of(context).accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 11.sp,
            color: FluentTheme.of(context).accentColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget buildTags() {
    var maxNum = 5;
    var tags = subject.tags;
    tags.sort((a, b) => b.count.compareTo(a.count));
    if (tags.length > maxNum) {
      tags = tags.sublist(0, maxNum);
    }
    return SizedBox(
      height: 24.h,
      child: Wrap(
        spacing: 4.w,
        runSpacing: 4.h,
        children: tags.map((e) => buildTag(e.name, e.count)).toList(),
      ),
    );
  }

  Widget buildAction(BuildContext context) {
    var paneTitle = subject.nameCn == '' ? subject.name : subject.nameCn;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: _buildScoreWidget()),
        SizedBox(width: 8.w),
        Tooltip(
          message: '查看$label详情',
          child: BTCard(
            useShadow: false,
            useAcrylic: false,
            padding: EdgeInsets.all(8.w),
            borderRadius: BTRadius.medium,
            onTap: () => ref
                .read(navStoreProvider)
                .addNavItemB(
                  type: label,
                  subject: subject.id,
                  paneTitle: paneTitle,
                ),
            child: Icon(
              FluentIcons.open_in_new_tab,
              size: 16.sp,
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.15),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.favorite_star_fill, size: 14.sp, color: scoreColor),
          SizedBox(width: 4.w),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: scoreColor,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            scoreLabel,
            style: TextStyle(
              fontSize: 12.sp,
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
          child: Text(
            label == '条目' ? name : '[$label] $name',
            style: FluentTheme.of(context).typography.subtitle,
            maxLines: 1,
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
        const SizedBox(height: 4),
        _buildMetaInfo(),
        const SizedBox(height: 4),
        Expanded(child: buildTags()),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildCollectionInfo(),
            const Spacer(),
            buildAction(context),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaInfo() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 4.h,
      children: [
        if (subject.date != null && subject.date!.isNotEmpty)
          _buildMetaItem(FluentIcons.calendar, subject.date!),
        if (subject.eps > 0)
          _buildMetaItem(FluentIcons.play, '${subject.eps}集'),
        if (subject.platform != null && subject.platform!.isNotEmpty)
          _buildMetaItem(FluentIcons.devices2, subject.platform!),
      ],
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.sp, color: BTColors.textSecondary(context)),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
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
          Icon(FluentIcons.heart_fill, size: 12.sp, color: Colors.red),
          SizedBox(width: 3.w),
          Text(
            '$collect',
            style: TextStyle(
              fontSize: 11.sp,
              color: BTColors.textSecondary(context),
            ),
          ),
          SizedBox(width: 10.w),
        ],
        if (wish > 0) ...[
          Icon(
            FluentIcons.favorite_star_fill,
            size: 12.sp,
            color: Colors.orange,
          ),
          SizedBox(width: 3.w),
          Text(
            '$wish',
            style: TextStyle(
              fontSize: 11.sp,
              color: BTColors.textSecondary(context),
            ),
          ),
          SizedBox(width: 10.w),
        ],
        if (doing > 0) ...[
          Icon(FluentIcons.play, size: 12.sp, color: Colors.green),
          SizedBox(width: 3.w),
          Text(
            '$doing',
            style: TextStyle(
              fontSize: 11.sp,
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
        height: 150,
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 150,
              child: buildCover(subject.images.common),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: buildInfo(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
