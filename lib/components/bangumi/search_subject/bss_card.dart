import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../models/app/nav_model.dart';
import '../../../models/app/response.dart';
import '../../../models/bangumi/bangumi_enum_extension.dart';
import '../../../models/bangumi/request_subject.dart';
import '../../../pages/bangumi/bangumi_detail.dart';
import '../../../store/nav_store.dart';
import '../../../utils/bangumi_utils.dart';
import '../../app/app_dialog_resp.dart';
import '../../app/app_infobar.dart';

/// 搜索卡片
class BssCard extends ConsumerStatefulWidget {
  /// 结果
  final BangumiSubjectSearchData data;

  /// 构造
  BssCard(this.data, {super.key});

  @override
  ConsumerState<BssCard> createState() => _BssCardState();
}

/// 搜索卡片状态
/// todo 根据返回内容来看，比起Gridview的卡片，更适合用于Listview
class _BssCardState extends ConsumerState<BssCard> {
  /// 数据
  BangumiSubjectSearchData get subject => widget.data;

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
    if (subject.image.isEmpty) return buildCoverError(context);
    return CachedNetworkImage(
      imageUrl: subject.image,
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

  /// 构建封面信息，包括评分、排名等
  Widget buildCoverInfo(BuildContext context) {
    var score = subject.score / 2;
    var label = getBangumiRateLabel(subject.score);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RatingBar(
          rating: score,
          iconSize: 20.sp,
          starSpacing: 1.sp,
          unratedIconColor:
              FluentTheme.of(context).accentColor.withOpacity(0.5),
        ),
        SizedBox(height: 5.h),
        Text('${subject.score} $label'),
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
        if (subject.type != null) Text('[${subject.type!.label}]'),
        Tooltip(
          message: '查看源网站',
          child: IconButton(
            icon: Icon(
              FluentIcons.edge_logo,
              color: FluentTheme.of(context).accentColor.light,
            ),
            onPressed: () async {
              if (kDebugMode) {
                var resp = BTResponse.success(data: subject);
                showRespErr(resp, context);
                return;
              }
              var link = "https://bgm.tv/subject/${subject.id}";
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
            onPressed: () {
              if (subject.type == null) {
                BtInfobar.error(context, '未知类型');
                return;
              }
              var title = '${subject.type!.label}详情 ${subject.id}';
              var pane = PaneItem(
                icon: Icon(FluentIcons.info),
                title: Text(title),
                body: BangumiDetail(id: subject.id.toString()),
              );
              ref.read(navStoreProvider).addNavItem(
                    pane,
                    title,
                    type: BtmAppNavItemType.bangumiSubject,
                    param: 'subjectDetail_${subject.id}',
                  );
            },
          ),
        ),
      ],
    );
  }

  /// 构建右侧内容
  Widget buildInfo(BuildContext context) {
    var title = subject.nameCn == '' ? subject.name : subject.nameCn;
    var subTitle = subject.nameCn == '' ? '' : subject.name;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: title,
          child: Text(
            title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        SizedBox(height: 5.h),
        if (subject.rank != 0) Text('排名: ${subject.rank}'),
        SizedBox(height: 5.h),
        buildAction(context),
      ],
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
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
