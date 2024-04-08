import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/bangumi/get_calendar.dart';

/// 今日放送-番剧卡片
class CalendarCard extends StatelessWidget {
  /// 数据
  final CalendarItemBangumi data;

  /// 构造函数
  const CalendarCard({super.key, required this.data});

  /// 构建封面
  Widget buildCover(BuildContext context) {
    if (data.images == null ||
        data.images?.large == null ||
        data.images?.large == '') {
      return Container(
        decoration: BoxDecoration(
          color: FluentTheme.of(context).brightness.isDark
              ? Colors.white.withAlpha(900)
              : Colors.black.withAlpha(900),
        ),
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
                '暂无封面',
                style: TextStyle(
                  fontSize: 28.sp,
                  color: FluentTheme.of(context).accentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: data.images!.large,
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, dp) => Center(
        child: ProgressRing(
          value: dp.progress == null ? 0 : dp.progress! * 100,
        ),
      ),
      errorWidget: (context, url, error) => Icon(FluentIcons.error),
    );
  }

  /// 构建交互
  Widget buildAction(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Tooltip(
          message: data.url,
          child: IconButton(
            icon: Icon(
              FluentIcons.edge_logo,
              color: FluentTheme.of(context).accentColor.light,
            ),
            onPressed: () async {
              if (await canLaunchUrlString(data.url)) {
                await launchUrlString(data.url);
              } else {
                throw 'Could not launch ${data.url}';
              }
            },
          ),
        ),
        Tooltip(
          message: '查看详情',
          child: IconButton(
            icon: Icon(
              FluentIcons.info,
              color: FluentTheme.of(context).accentColor.light,
            ),
            onPressed: () {
              GoRouter.of(context).go('/bangumi/${data.id}');
            },
          ),
        ),
      ],
    );
  }

  /// 构建番剧项
  @override
  Widget build(BuildContext context) {
    var rateStr = '';
    if (data.rating != null) {
      rateStr = '评分：${data.rating?.score}(${data.rating?.total})';
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(child: buildCover(context)),
        SizedBox(width: 5.w),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.nameCn == '' ? data.name : data.nameCn,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              data.nameCn == '' || data.name.length > 40
                  ? Container()
                  : Text(
                      data.name,
                      style: TextStyle(
                        color: FluentTheme.of(context).accentColor.lighter,
                      ),
                    ),
              rateStr == ''
                  ? Text(data.airDate)
                  : Text('${data.airDate} $rateStr'),
              data.collection?.doing != null
                  ? Text('${data.collection?.doing}人在看')
                  : Container(),
              buildAction(context),
            ],
          ),
        )
      ],
    );
  }
}
