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
import '../../core/theme/bt_theme.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../store/nav_store.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/bangumi_utils.dart';

/// 收藏卡片
class UcpCardWidget extends ConsumerStatefulWidget {
  /// 数据
  final BangumiUserSubjectCollection data;

  /// 构造函数
  const UcpCardWidget({super.key, required this.data});

  @override
  ConsumerState<UcpCardWidget> createState() => _UcpCardState();
}

/// 收藏卡片状态
class _UcpCardState extends ConsumerState<UcpCardWidget>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  /// 数据
  BangumiSlimSubject get data => widget.data.subject;

  /// 悬停状态
  bool _isHovered = false;

  /// 动画控制器
  late AnimationController _animationController;
  late Animation<double> _elevationAnimation;

  /// 保存状态
  @override
  bool get wantKeepAlive => false;

  /// 初始化
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: BTTheme.animationDurationNormal,
      vsync: this,
    );
    _elevationAnimation = Tween<double>(begin: 0, end: 4).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  /// dispose
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 构建无封面的卡片
  Widget buildCoverError(BuildContext context, {String? err}) {
    return Container(
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.photo_error,
              size: 32.sp,
              color: BTColors.textTertiary(context),
            ),
            SizedBox(height: 8.h),
            Text(
              err ?? '无封面',
              style: BTTypography.body(context).copyWith(
                color: BTColors.textTertiary(context),
                fontSize: err == null ? 14.sp : 12.sp,
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
    return ClipRRect(
      borderRadius: BTRadius.mediumBR,
      child: CachedNetworkImage(
        imageUrl: link,
        fit: BoxFit.cover,
        progressIndicatorBuilder: (context, url, dp) => Center(
          child: SizedBox(
            width: 24.w,
            height: 24.w,
            child: ProgressRing(
              value: dp.progress == null ? 0 : dp.progress! * 100,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            buildCoverError(context, err: error.toString()),
      ),
    );
  }

  /// 构建封面信息，包括评分、放送时间
  Widget buildCoverInfo(BuildContext context) {
    var rateWidget = <Widget>[];
    Widget viewWidget = Container();
    var score = data.score / 2;
    var label = getBangumiRateLabel(data.score);
    rateWidget.add(
      RatingBar(
        rating: score,
        iconSize: 16.sp,
        starSpacing: 1.sp,
        unratedIconColor: FluentTheme.of(context).accentColor.withAlpha(128),
      ),
    );
    rateWidget.add(SizedBox(height: 4.h));
    rateWidget.add(
      Text(
        '${data.score} $label',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...rateWidget, viewWidget],
    );
  }

  /// 构建封面
  Widget buildCover(BuildContext context) {
    return ClipRRect(
      borderRadius: BTRadius.mediumBR,
      child: Stack(
        children: [
          Positioned.fill(child: buildCoverImage(context)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: buildCoverInfo(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: _isHovered
                  ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BTRadius.smallBR,
            ),
            child: Icon(
              icon,
              size: 18.sp,
              color: FluentTheme.of(context).accentColor,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建交互
  Widget buildAction(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        buildActionButton(
          context: context,
          icon: FluentIcons.edge_logo,
          tooltip: '查看源网站',
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
        SizedBox(width: 4.w),
        buildActionButton(
          context: context,
          icon: FluentIcons.info,
          tooltip: '查看详情',
          onPressed: () => ref.read(navStoreProvider).addNavItemB(
                type: data.type.label,
                subject: data.id,
                paneTitle: data.nameCn == '' ? data.name : data.nameCn,
              ),
          onLongPress: () async {
            var name = data.nameCn == '' ? data.name : data.nameCn;
            ref.read(navStoreProvider).addNavItemB(
                  type: data.type.label,
                  subject: data.id,
                  paneTitle: name,
                  jump: false,
                );
            await BtInfobar.success(context, '$name 添加成功');
          },
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
            style: BTTypography.subtitle(context).copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subTitle.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Tooltip(
            message: subTitle,
            child: Text(
              subTitle,
              style: BTTypography.caption(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        SizedBox(height: 8.h),
        buildAction(context),
      ],
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _animationController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _elevationAnimation,
        builder: (context, child) {
          return AnimatedContainer(
            duration: BTTheme.animationDurationNormal,
            curve: BTTheme.animationCurve,
            decoration: BoxDecoration(
              color: BTColors.surfacePrimary(context),
              borderRadius: BTRadius.largeBR,
              border: Border.all(
                color: _isHovered
                    ? FluentTheme.of(context).accentColor.withValues(alpha: 0.3)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                width: 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: FluentTheme.of(context)
                            .accentColor
                            .withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      ...BTTheme.shadow(context, level: BTShadowLevel.medium),
                    ]
                  : BTTheme.shadow(context, level: BTShadowLevel.subtle),
            ),
            padding: EdgeInsets.all(10.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(child: buildCover(context)),
                SizedBox(width: 12.w),
                Expanded(child: buildInfo(context)),
              ],
            ),
          );
        },
      ),
    );
  }
}
