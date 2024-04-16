import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../models/app/response.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../app/app_dialog_resp.dart';
import 'bsd_rate_chart.dart';
import 'bsd_sites.dart';

/// 详情页面的信息卡片
class BsdOverview extends StatelessWidget {
  /// 番剧数据
  final BangumiSubject item;

  /// 构造函数
  const BsdOverview(this.item, {super.key});

  /// 构建无封面的卡片
  Widget buildCoverError(BuildContext context, {String? err}) {
    return Container(
      width: 200.w,
      height: 300.h,
      decoration: BoxDecoration(
        color: FluentTheme.of(context).brightness.isDark
            ? Colors.white.withAlpha(900)
            : Colors.black.withAlpha(900),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.photo_error,
              color: FluentTheme.of(context).accentColor,
            ),
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
    return SizedBox(
      width: 200.w,
      child: CachedNetworkImage(
        imageUrl: link,
        fit: BoxFit.fitWidth,
        progressIndicatorBuilder: (context, url, dp) => Center(
          child: ProgressRing(
            value: dp.progress == null ? 0 : dp.progress! * 100,
          ),
        ),
        errorWidget: (context, url, error) => buildCoverError(
          context,
          err: error.toString(),
        ),
      ),
    );
  }

  /// 构建信息文本
  Widget buildText(String text) {
    return Text(text, style: TextStyle(fontSize: 20.sp));
  }

  /// 构建基本信息
  Widget buildInfo(BuildContext context) {
    var nameW = List<Widget>.empty(growable: true);
    if (item.nameCn == '') {
      nameW.add(buildText('名称: ${item.name}'));
    } else {
      nameW.add(buildText('中文名: ${item.nameCn}'));
      nameW.add(SizedBox(height: 12.h));
      nameW.add(buildText('名称: ${item.name}'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        children: [
          buildText('ID: ${item.id}'),
          SizedBox(width: 12.w),
          Tooltip(
            message: '前往Bangumi',
            child: IconButton(
              icon: Icon(
                FluentIcons.edge_logo,
                color: FluentTheme.of(context).accentColor,
              ),
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
      SizedBox(height: 8.h),
      buildText('首播: ${item.date}'),
      SizedBox(height: 8.h),
      buildText('集数: ${item.eps}/${item.totalEpisodes}'),
      SizedBox(height: 8.h),
      buildText('平台: ${item.platform}'),
      SizedBox(height: 8.h),
      buildText('收藏情况：'),
      SizedBox(height: 8.h),
      buildText(
        '想看：${item.collection.wish} '
        '在看：${item.collection.doing} '
        '看过：${item.collection.collect} '
        '抛弃：${item.collection.onHold} '
        '搁置：${item.collection.dropped} ',
      ),
    ]);
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
        Expanded(child: buildInfo(context)),
        SizedBox(width: 12.w),
        BsdSites(item.name),
        SizedBox(width: 12.w),
        BsdRateChart(item.rating),
        SizedBox(width: 12.w),
      ],
    );
  }
}
