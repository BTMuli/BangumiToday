// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import 'sd_pw_rate_chart.dart';

/// 详情页面的信息卡片 TODO: 调整UI
class SdpOverviewWidget extends StatelessWidget {
  /// 番剧数据
  final BangumiSubject item;

  /// 构造函数
  const SdpOverviewWidget(this.item, {super.key});

  /// 构建无封面的卡片
  Widget buildCoverError(BuildContext context, {String? err}) {
    return SizedBox(
      width: 200.w,
      height: 300.h,
      child: Card(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BtIcon(FluentIcons.photo_error),
              Text(
                err ?? '无封面',
                style: TextStyle(
                  fontSize: err == null ? 28.sp : 18.sp,
                  color: FluentTheme.of(context).accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建封面
  Widget buildCover(BuildContext context, BangumiImages images) {
    if (images.large == '') {
      return buildCoverError(context);
    }
    // bangumi 在线切图
    // see: https://github.com/bangumi/img-proxy
    var pathGet = Uri.parse(images.large).path;
    var link = 'https://lain.bgm.tv/r/0x600$pathGet';
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 400.w, maxHeight: 300.h),
      child: CachedNetworkImage(
        imageUrl: link,
        fit: BoxFit.scaleDown,
        progressIndicatorBuilder: (context, url, dp) => Center(
          child: ProgressRing(
            value: dp.progress == null ? 0 : dp.progress! * 100,
          ),
        ),
        errorWidget: (context, url, error) =>
            buildCoverError(context, err: error.toString()),
      ),
    );
  }

  /// 构建信息文本
  Widget buildText(String text) {
    return Text(text, style: TextStyle(fontSize: 16));
  }

  /// 构建收藏badge
  Widget buildCollectionInfoBadge(
    BuildContext context,
    BangumiCollectionType type,
    int? count,
  ) {
    return Tooltip(
      message: type.label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: FluentTheme.of(context).accentColor.withValues(alpha: 0.2),
          border: Border.all(color: FluentTheme.of(context).accentColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            BtIcon(type.icon, size: 16),
            SizedBox(width: 4),
            Text(count?.toString() ?? '0', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 构建Tag
  Widget buildTag(BuildContext context, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: FluentTheme.of(context).accentColor.withValues(alpha: 0.2),
        border: Border.all(color: FluentTheme.of(context).accentColor),
      ),
      child: Text('#$text#', style: TextStyle(fontSize: 12)),
    );
  }

  /// 构建基本信息
  Widget buildInfo(BuildContext context) {
    var nameW = List<Widget>.empty(growable: true);
    if (item.nameCn == '') {
      nameW.add(buildText('名称: ${item.name}'));
    } else {
      nameW.add(buildText('中文名: ${item.nameCn}'));
      nameW.add(SizedBox(height: 4.h));
      nameW.add(buildText('名称: ${item.name}'));
    }

    /// 只取前10个tag
    var showTags = item.tags.length > 10 ? item.tags.sublist(0, 10) : item.tags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            buildText('ID: ${item.id}'),
            SizedBox(width: 12),
            Tooltip(
              message: '前往Bangumi',
              child: IconButton(
                icon: BtIcon(FluentIcons.edge_logo),
                onPressed: () async {
                  await launchUrlString('https://bgm.tv/subject/${item.id}');
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
        ...nameW,
        SizedBox(height: 4),
        buildText('首播: ${item.date}'),
        SizedBox(height: 4),
        buildText('集数: ${item.eps}/${item.totalEpisodes}'),
        SizedBox(height: 4),
        buildText('平台: ${item.platform}'),
        SizedBox(height: 4),
        buildText('收藏情况：'),
        SizedBox(height: 4),
        Wrap(
          runAlignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            SizedBox(width: 12),
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
        SizedBox(height: 4),
        buildText('标签: '),
        SizedBox(height: 4),
        Wrap(
          runAlignment: WrapAlignment.start,
          spacing: 4,
          runSpacing: 4,
          children: [
            SizedBox(width: 12),
            ...showTags.map((e) => buildTag(context, e.name)),
          ],
        ),
      ],
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
        SizedBox(width: 12.w),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 300.h),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(right: 12.w),
              scrollDirection: Axis.vertical,
              child: buildInfo(context),
            ),
          ),
        ),
        SdpRateChartWidget(item.rating),
        SizedBox(width: 12.w),
      ],
    );
  }
}
