// Dart imports:
import 'dart:ui';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../models/app/response.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../store/nav_store.dart';
import '../../../ui/bt_dialog.dart';
import '../../../utils/bangumi_utils.dart';

/// 收藏卡片
class BucCard extends ConsumerStatefulWidget {
  /// 数据
  final BangumiUserSubjectCollection data;

  /// 构造函数
  const BucCard({super.key, required this.data});

  @override
  ConsumerState<BucCard> createState() => _BucCardState();
}

/// 收藏卡片状态
class _BucCardState extends ConsumerState<BucCard>
    with AutomaticKeepAliveClientMixin {
  /// 数据
  BangumiSlimSubject get data => widget.data.subject;

  /// 保存状态
  @override
  bool get wantKeepAlive => false;

  /// 初始化
  @override
  void initState() {
    super.initState();
  }

  /// dispose
  @override
  void dispose() {
    super.dispose();
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
    if (data.images.large == '') {
      return buildCoverError(context);
    }
    // bangumi 在线切图
    // see: https://github.com/bangumi/img-proxy
    var pathGet = Uri.parse(data.images.large).path;
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

  /// 构建封面信息，包括评分、放送时间
  Widget buildCoverInfo(BuildContext context) {
    var rateWidget = <Widget>[];
    Widget viewWidget = Container();
    var score = data.score / 2;
    var label = getBangumiRateLabel(data.score);
    rateWidget.add(RatingBar(
      rating: score,
      iconSize: 20.sp,
      starSpacing: 1.sp,
      unratedIconColor: FluentTheme.of(context).accentColor.withAlpha(128),
    ));
    rateWidget.add(SizedBox(height: 5.h));
    rateWidget.add(Text('${data.score} $label'));
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
        Positioned(
          right: -1.w,
          left: 0,
          bottom: -1.h,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Card(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                child: buildCoverInfo(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建交互
  Widget buildAction(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Tooltip(
          message: '查看源网站',
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
              var link = "https://bgm.tv/subject/${data.id}";
              await launchUrlString(link);
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
                  type: data.type.label,
                  subject: data.id,
                  paneTitle: data.nameCn == '' ? data.name : data.nameCn,
                ),
          ),
        ),
      ],
    );
  }

  /// 构建右侧内容
  Widget buildInfo(BuildContext context) {
    var title = data.nameCn == '' ? data.name : data.nameCn;
    var subTitle = data.nameCn == '' ? '' : data.name;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: title,
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 3,
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
        buildAction(context),
      ],
    );
  }

  /// 构建函数
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
