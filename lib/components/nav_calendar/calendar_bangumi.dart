import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/bangumi/get_calendar.dart';

/// 侧边栏-今日放送-番剧项
class CalendarBangumi extends StatelessWidget {
  /// 传入的数据
  final CalendarItemBangumi data;

  /// 构造函数
  const CalendarBangumi({super.key, required this.data});

  /// 构建封面
  Widget buildCover(BuildContext context) {
    if (data.images == null ||
        data.images?.large == null ||
        data.images?.large == '') {
      return Icon(FluentIcons.photo_error);
    }
    return CachedNetworkImage(
      imageUrl: data.images!.large,
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, progress) => Center(
        child: ProgressRing(
          value: progress.progress == null ? 0 : progress.progress! * 100,
        ),
      ),
      errorWidget: (context, url, error) => Icon(FluentIcons.error),
    );
  }

  /// 构建渐变层
  Widget buildGradient(BuildContext context) {
    final brightness = FluentTheme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [
            brightness == Brightness.light
                ? Colors.white.withOpacity(0)
                : Colors.black.withOpacity(0),
            brightness == Brightness.light
                ? Colors.white.withOpacity(0.75)
                : Colors.black.withOpacity(0.75),
          ],
        ),
      ),
    );
  }

  /// 构建番剧信息
  Widget buildItemInfo(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: data.nameCn == '' ? data.name : data.nameCn,
            child: Text(
              data.nameCn == '' ? data.name : data.nameCn,
              maxLines: 1,
              style: FluentTheme.of(context).typography.subtitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: data.url,
            child: IconButton(
              icon: Icon(FluentIcons.edge_logo),
              onPressed: () async {
                if (await canLaunchUrlString(data.url)) {
                  await launchUrlString(data.url);
                } else {
                  throw 'Could not launch ${data.url}';
                }
              },
            ),
          ),
          // todo 详情页面
        ],
      ),
    );
  }

  /// 构建番剧项
  @override
  Widget build(BuildContext context) {
    // stack 布局，由底到上分别是封面、渐变层、番剧信息及操作按钮
    return Stack(
      children: [
        Positioned.fill(child: buildCover(context)),
        Positioned.fill(child: buildGradient(context)),
        Positioned(bottom: 0, left: 0, right: 0, child: buildItemInfo(context)),
      ],
    );
  }
}
