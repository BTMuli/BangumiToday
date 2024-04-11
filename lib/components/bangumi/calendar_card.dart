import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../database/bangumi/bangumi_data.dart';
import '../../models/bangumi/get_calendar.dart';
import '../../pages/bangumi/bangumi_detail.dart';
import '../../store/nav_store.dart';

/// 今日放送-番剧卡片
class CalendarCard extends ConsumerStatefulWidget {
  /// 数据
  final CalendarItemBangumi data;

  /// 构造函数
  const CalendarCard({super.key, required this.data});

  @override
  ConsumerState<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends ConsumerState<CalendarCard>
    with AutomaticKeepAliveClientMixin {
  /// 数据
  CalendarItemBangumi get data => widget.data;

  /// 放送时间
  String upTime = '';

  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    // todo bug 当页面切换时，会重新获取时间
    Future.delayed(Duration.zero, () async {
      await getTime();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 格式化时间
  String fmtInt(int time) {
    return time.toString().padLeft(2, '0');
  }

  /// 获取放送时间
  Future<void> getTime() async {
    var itemGet = await BtsBangumiData().readItem(data.name);
    if (itemGet == null) return;
    upTime = itemGet.begin;
    var time = DateTime.parse(upTime);
    upTime = '${fmtInt(time.hour)}:${fmtInt(time.minute)}';
    setState(() {});
  }

  /// 构建无封面的卡片
  Widget buildCoverError(BuildContext context, {String? err}) {
    return Container(
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
  Widget buildCover(BuildContext context) {
    if (data.images == null ||
        data.images?.large == null ||
        data.images?.large == '') {
      return buildCoverError(context);
    }
    // bangumi 在线切图
    // see: https://github.com/bangumi/img-proxy
    var pathGet = Uri.parse(data.images!.large).path;
    var link = 'https://lain.bgm.tv/r/0x600$pathGet';
    return CachedNetworkImage(
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
    );
  }

  /// 获取 PaneItem
  PaneItem getPaneItem(BuildContext context) {
    return PaneItem(
      icon: Icon(FluentIcons.info),
      title: Text('番剧详情'),
      body: BangumiDetail(id: data.id.toString()),
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
              var paneItem = getPaneItem(context);
              ref.read(navStoreProvider).addNavItem(paneItem, '番剧详情');
            },
          ),
        ),
      ],
    );
  }

  /// 构建番剧项
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var rateStr = '';
    if (data.rating != null) {
      rateStr = '评分：${data.rating?.score}(${data.rating?.total})';
    }
    // todo，部分数据放到封面下方
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
              upTime == '' ? Container() : Text('放送时间：$upTime'),
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
