// Dart imports:
import 'dart:ui';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../database/bangumi/bangumi_data.dart';
import '../../../models/app/response.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../store/nav_store.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/bangumi_utils.dart';

/// 今日放送-番剧卡片
class CalendarCard extends ConsumerStatefulWidget {
  /// 数据
  final BangumiLegacySubjectSmall data;

  /// 构造函数
  const CalendarCard({super.key, required this.data});

  @override
  ConsumerState<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends ConsumerState<CalendarCard>
    with AutomaticKeepAliveClientMixin {
  /// 数据
  BangumiLegacySubjectSmall get data => widget.data;

  /// 放送时间
  String upTime = '';

  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async => await getTime());
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
    var color = FluentTheme.of(context).accentColor.darkest;
    return Card(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(FluentIcons.photo_error, color: color),
            Text(
              err ?? '无封面',
              style: TextStyle(
                fontSize: err == null ? 28.sp : 18.sp,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建封面
  Widget buildCoverImage(BuildContext context) {
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

  /// 构建交互
  Widget buildAction(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
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
              if (kDebugMode) {
                await showRespErr(
                  BTResponse.success(data: data),
                  context,
                  title: '动画详情',
                );
                return;
              }
              if (await canLaunchUrlString(data.url)) {
                await launchUrlString(data.url);
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
            onPressed: () => ref.read(navStoreProvider).addNavItemB(
                type: '动画',
                subject: data.id,
                paneTitle: data.nameCn == '' ? data.name : data.nameCn),
            onLongPress: () async {
              var name = data.nameCn == '' ? data.name : data.nameCn;
              ref.read(navStoreProvider).addNavItemB(
                  type: '动画', subject: data.id, paneTitle: name, jump: false);
              await BtInfobar.success(context, '$name 添加成功');
            },
          ),
        ),
      ],
    );
  }

  /// 构建封面信息，包括评分、放送时间
  Widget buildCoverInfo(BuildContext context) {
    var rateWidget = <Widget>[];
    Widget viewWidget = Container();
    if (data.rating != null) {
      var score = data.rating!.score / 2;
      var label = getBangumiRateLabel(data.rating!.score);
      rateWidget.add(RatingBar(
          rating: score,
          iconSize: 20.sp,
          starSpacing: 1.sp,
          unratedIconColor:
              FluentTheme.of(context).accentColor.withAlpha(128)));
      rateWidget.add(SizedBox(height: 5.h));
      rateWidget.add(Text(
        '${data.rating?.score} $label (${data.rating?.total}人评分)',
        style: TextStyle(
          color: FluentTheme.of(context).accentColor.lighter,
          fontSize: 14,
        ),
      ));
    }
    if (data.collection?.doing != null) {
      viewWidget = Row(
        children: [
          Expanded(child: Container()),
          Text('${data.collection?.doing}人在看'),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rateWidget,
        viewWidget,
      ],
    );
  }

  /// 构建封面
  Widget buildCover(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: buildCoverImage(context)),
        if (data.rating != null || data.collection?.doing != null)
          Positioned(
            right: -1.w,
            left: 0,
            bottom: -1.h,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: buildCoverInfo(context),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 构建右侧内容
  Widget buildInfo(BuildContext context) {
    var unescape = HtmlUnescape();
    var title = data.nameCn == '' ? data.name : data.nameCn;
    var subTitle = data.nameCn == '' ? '' : data.name;
    title = unescape.convert(title);
    subTitle = unescape.convert(subTitle);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: title,
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subTitle.isNotEmpty)
          Tooltip(
            message: subTitle,
            child: Text(
              subTitle,
              style: TextStyle(
                color: FluentTheme.of(context).accentColor.lighter,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (upTime.isNotEmpty) Text('放送时间：$upTime'),
        buildAction(context),
      ],
    );
  }

  /// 构建番剧项
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(child: buildCover(context)),
        SizedBox(width: 5.w),
        Expanded(child: buildInfo(context))
      ],
    );
  }
}
