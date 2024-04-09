import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/bangumi/common_model.dart';
import '../../models/bangumi/get_subject.dart';
import 'rate_bar_chart.dart';

/// 详情页面的信息卡片
class BangumiDetailCard extends StatelessWidget {
  /// 番剧数据
  final BangumiSubject item;

  /// 构造函数
  const BangumiDetailCard(this.item, {super.key});

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
  Widget buildCover(BuildContext context, BangumiImage images) {
    if (images.large == '') {
      return buildCoverError(context);
    }
    // bangumi 在线切图
    // see: https://github.com/bangumi/img-proxy
    var pathGet = Uri.parse(images.large).path;
    var link = 'https://lain.bgm.tv/r/0x600$pathGet';
    return SizedBox(
      width: 200.w,
      height: 300.h,
      child: CachedNetworkImage(
        imageUrl: link,
        fit: BoxFit.cover,
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
  Widget buildInfo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      buildText('ID: ${item.id}'),
      SizedBox(height: 12.h),
      buildText('中文名: ${item.nameCn}'),
      SizedBox(height: 12.h),
      buildText('原名: ${item.name}'),
      SizedBox(height: 12.h),
      buildText('首播: ${item.date}'),
      SizedBox(height: 12.h),
      buildText('集数: ${item.eps}/${item.totalEpisodes}'),
      SizedBox(height: 12.h),
      buildText('平台: ${item.platform}'),
      SizedBox(height: 12.h),
      buildText('追番情况：'),
      SizedBox(height: 12.h),
      buildText(
        '想看：${item.collection.wish} '
        '在看：${item.collection.collect} '
        '看过：${item.collection.doing} '
        '抛弃：${item.collection.onHold} '
        '搁置：${item.collection.dropped} ',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCover(context, item.images),
        SizedBox(width: 12.w),
        Expanded(child: buildInfo()),
        BangumiRateBarChart(item.rating),
        SizedBox(width: 12.w),
      ],
    );
  }
}
