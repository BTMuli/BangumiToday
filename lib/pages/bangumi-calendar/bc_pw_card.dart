// Dart imports:
import 'dart:math' as math;
import 'dart:ui';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../database/app/app_bmf.dart';
import '../../database/app/app_rss.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/database/app_bmf_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/bangumi_utils.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/bangumi/subject_detail/bsd_bmf_drawer.dart';
import '../../widgets/bangumi/subject_detail/bsd_rss_search_dialog.dart';
import '../../widgets/common/bt_drawer.dart';

class BcpCardWidget extends ConsumerStatefulWidget {
  static const _padding = 10.0;
  static const _borderWidth = 1.0;
  static const _actionPadding = 8.0;
  static const _actionIconSize = 18.0;
  static const _titleMaxLines = 4;
  static const _subTitleMaxLines = 2;

  final BangumiLegacySubjectSmall data;

  /// 放送时刻（本地时间 `HH:mm`）
  final String? airTime;

  /// 当天放送的话数
  final int? episode;

  /// 是否已在本地收藏里标记为看过
  final bool watched;

  /// 是否在 BMF 订阅列表里
  final bool inBmf;

  const BcpCardWidget({
    super.key,
    required this.data,
    this.airTime,
    this.episode,
    this.watched = false,
    this.inBmf = false,
  });

  /// 为完整文字行、放送信息（时刻/话数）和操作按钮预留高度。
  static double minimumHeight(
    BuildContext context, {
    required bool hasAirInfo,
  }) {
    var defaultTextStyle = DefaultTextStyle.of(context);
    double textHeight(String text, TextStyle style) {
      var painter = TextPainter(
        text: TextSpan(text: text, style: defaultTextStyle.style.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        textHeightBehavior:
            defaultTextStyle.textHeightBehavior ??
            DefaultTextHeightBehavior.maybeOf(context),
      )..layout();
      var height = painter.height;
      painter.dispose();
      return height;
    }

    var titleHeight = textHeight(
      List.filled(_titleMaxLines, '国').join('\n'),
      BTTypography.subtitle(context),
    );
    var subTitleHeight = textHeight(
      List.filled(_subTitleMaxLines, '国').join('\n'),
      BTTypography.caption(context),
    );
    var airTimeHeight = hasAirInfo
        ? 6 + math.max(12.0, textHeight('00:00', BTTypography.caption(context)))
        : 0.0;
    return 2 * (_padding + _borderWidth) +
        titleHeight +
        4 +
        subTitleHeight +
        airTimeHeight +
        8 +
        _actionIconSize +
        2 * _actionPadding;
  }

  @override
  ConsumerState<BcpCardWidget> createState() => _BcpCardState();
}

class _BcpCardState extends ConsumerState<BcpCardWidget>
    with SingleTickerProviderStateMixin {
  BangumiLegacySubjectSmall get data => widget.data;

  bool _isHovered = false;

  /// 当前是否在 BMF 订阅列表里，抽屉里改动后即时更新
  late bool _inBmf = widget.inBmf;

  /// RSS 操作菜单
  final FlyoutController _rssFlyout = FlyoutController();

  late AnimationController _animationController;
  late Animation<double> _elevationAnimation;

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

  @override
  void dispose() {
    _rssFlyout.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BcpCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父级重新读了订阅状态（例如在别处加了订阅）时同步过来
    if (oldWidget.inBmf != widget.inBmf) _inBmf = widget.inBmf;
  }

  /// 标题：优先中文名
  String get displayTitle => data.nameCn == '' ? data.name : data.nameCn;

  /// 弹出 RSS 操作菜单
  void showRssMenu(BuildContext context) {
    _rssFlyout.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: const Icon(MdiIcons.rss),
            text: const Text('编辑 RSS'),
            onPressed: searchRss,
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.list),
            text: const Text('订阅详情'),
            onPressed: openBmfDrawer,
          ),
        ],
      ),
    );
  }

  /// 重新读取该条目的 BMF 状态，订阅被建出来或删掉后同步卡片上的 RSS 按钮。
  Future<void> syncBmfState() async {
    var bmf = await BtsAppBmf().read(data.id);
    if (!mounted) return;
    if ((bmf != null) != _inBmf) setState(() => _inBmf = bmf != null);
  }

  /// 打开 RSS 搜索弹窗，选中字幕组后写回该条目的 BMF 订阅。
  Future<void> searchRss() async {
    var repo = ref.read(bmfRepositoryProvider);
    var current = await repo.read(data.id);
    if (!mounted) return;
    var title = displayTitle;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (_) => BsdRssSearchDialog(
        subjectId: data.id,
        title: title,
        currentRss: current?.rss,
        onSubscribe: (dialogContext, rss) async {
          var check = await repo.checkRss(rss, excludeSubject: data.id);
          if (!dialogContext.mounted || !mounted) return false;
          if (check) {
            await BtInfobar.error(dialogContext, '该RSS已经被其他BMF使用');
            return false;
          }
          var bmf = await repo.read(data.id);
          if (bmf == null) {
            bmf = AppBmfModel(
              subject: data.id,
              title: title,
              airDate: data.airDate,
              rss: rss,
            );
          } else {
            // 旧 RSS 的缓存数据跟着订阅一起换掉，避免留下过期条目
            if (bmf.rss != null && bmf.rss!.isNotEmpty && bmf.rss != rss) {
              await BtsAppRss().delete(bmf.rss!);
            }
            bmf = bmf.copyWith(rss: rss);
          }
          await repo.write(bmf);
          await repo.refreshRss(bmf);
          if (dialogContext.mounted) {
            await BtInfobar.success(dialogContext, '成功设置 RSS');
          }
          return true;
        },
      ),
    );
    if (!mounted) return;
    await syncBmfState();
  }

  /// 打开订阅详情侧边栏：订阅里的 RSS 与下载目录都在这里改动
  Future<void> openBmfDrawer() async {
    await showBTDrawer(
      context: context,
      width: 420,
      child: BsdBmfDrawer(
        subjectId: data.id,
        title: displayTitle,
        airDate: data.airDate,
      ),
    );
    if (!mounted) return;
    await syncBmfState();
  }

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
              size: 32,
              color: BTColors.textTertiary(context),
            ),
            SizedBox(height: 8),
            Text(
              err ?? '无封面',
              style: BTTypography.body(context).copyWith(
                color: BTColors.textTertiary(context),
                fontSize: err == null ? 14 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCoverImage(BuildContext context) {
    return BtBangumiCover(
      imageUrl: data.images?.large,
      borderRadius: BTRadius.mediumBR,
      errorBuilder: buildCoverError,
    );
  }

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
            padding: EdgeInsets.all(BcpCardWidget._actionPadding),
            decoration: BoxDecoration(
              color: _isHovered
                  ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BTRadius.smallBR,
            ),
            child: Icon(
              icon,
              size: BcpCardWidget._actionIconSize,
              color: FluentTheme.of(context).accentColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAction(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_inBmf)
          FlyoutTarget(
            controller: _rssFlyout,
            child: buildActionButton(
              context: context,
              icon: MdiIcons.rss,
              tooltip: 'RSS 订阅',
              onPressed: () => showRssMenu(context),
            ),
          ),
        if (_inBmf) SizedBox(width: 4),
        buildActionButton(
          context: context,
          icon: FluentIcons.edge_logo,
          tooltip: '在浏览器中打开',
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
        SizedBox(width: 4),
        buildActionButton(
          context: context,
          icon: FluentIcons.info,
          tooltip: '查看详情',
          onPressed: () => ref
              .read(navStoreProvider)
              .addNavItemB(
                type: '动画',
                subject: data.id,
                paneTitle: data.nameCn == '' ? data.name : data.nameCn,
              ),
          onLongPress: () async {
            var name = data.nameCn == '' ? data.name : data.nameCn;
            ref
                .read(navStoreProvider)
                .addNavItemB(
                  type: '动画',
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

  Widget buildCoverInfo(BuildContext context) {
    var rateWidget = <Widget>[];
    var statWidget = <Widget>[];

    if (data.rating != null) {
      var score = data.rating!.score / 2;
      var label = getBangumiRateLabel(data.rating!.score);
      rateWidget.add(
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RatingControl(
            rating: score,
            iconSize: 16,
            starSpacing: 1,
            ratedIconColor: FluentTheme.of(context).accentColor.withAlpha(128),
            unratedIconColor: Colors.white.withAlpha(128),
          ),
        ),
      );
      rateWidget.add(SizedBox(height: 4));
      rateWidget.add(
        Text(
          '${data.rating?.score} $label',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

      statWidget.addAll([
        Icon(
          FluentIcons.favorite_star_fill,
          size: 11,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        SizedBox(width: 3),
        Text(
          '${data.rating!.total}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ]);
    }
    if (data.collection?.doing != null) {
      statWidget.insertAll(0, [
        Icon(
          FluentIcons.play,
          size: 11,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        SizedBox(width: 3),
        Text(
          '${data.collection!.doing}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        if (data.rating != null) SizedBox(width: 10),
      ]);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rateWidget,
        if (statWidget.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: statWidget),
            ),
          ),
      ],
    );
  }

  /// 构建封面上的状态标记
  Widget buildCoverChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BTColors.surfacePrimary(context).withValues(alpha: 0.85),
        borderRadius: BTRadius.smallBR,
      ),
      child: Text(
        text,
        style: BTTypography.caption(context).copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: BTColors.textSecondary(context),
        ),
      ),
    );
  }

  Widget buildCover(BuildContext context) {
    return ClipRRect(
      borderRadius: BTRadius.mediumBR,
      child: Stack(
        children: [
          Positioned.fill(child: buildCoverImage(context)),
          if (widget.watched)
            Positioned(left: 6, top: 6, child: buildCoverChip(context, '看过')),
          if (data.rating != null || data.collection?.doing != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

  Widget buildInfo(BuildContext context) {
    var unescape = HtmlUnescape();
    var title = data.nameCn == '' ? data.name : data.nameCn;
    var subTitle = data.nameCn == '' ? '' : data.name;
    title = unescape.convert(title);
    subTitle = unescape.convert(subTitle);
    var hasAirTime = widget.airTime != null && widget.airTime!.isNotEmpty;
    var hasAirInfo = hasAirTime || widget.episode != null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Tooltip(
            message: title,
            child: Text(
              title,
              style: BTTypography.subtitle(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
              maxLines: BcpCardWidget._titleMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (subTitle.isNotEmpty) ...[
          SizedBox(height: 4),
          Tooltip(
            message: subTitle,
            child: Text(
              subTitle,
              style: BTTypography.caption(context),
              maxLines: BcpCardWidget._subTitleMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (hasAirInfo) ...[
          SizedBox(height: 6),
          Tooltip(
            message: '放送时刻为本地时间，星期与话数按日本放送日推算',
            child: Row(
              children: [
                if (hasAirTime) ...[
                  Icon(
                    FluentIcons.clock,
                    size: 12,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  SizedBox(width: 4),
                  Text(
                    widget.airTime!,
                    style: BTTypography.caption(
                      context,
                    ).copyWith(color: FluentTheme.of(context).accentColor),
                  ),
                ],
                if (widget.episode != null) ...[
                  if (hasAirTime) SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '第${widget.episode}话',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BTTypography.caption(context).copyWith(
                        color: FluentTheme.of(context).accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        SizedBox(height: 8),
        buildAction(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Opacity(
      // 看过的条目弱化，配合排序靠后一起降权
      opacity: widget.watched ? 0.55 : 1,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
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
                      ? FluentTheme.of(
                          context,
                        ).accentColor.withValues(alpha: 0.3)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04)),
                  width: BcpCardWidget._borderWidth,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: FluentTheme.of(
                            context,
                          ).accentColor.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                        ...BTTheme.shadow(context, level: BTShadowLevel.medium),
                      ]
                    : BTTheme.shadow(context, level: BTShadowLevel.subtle),
              ),
              padding: EdgeInsets.all(BcpCardWidget._padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BTRadius.mediumBR,
                      child: buildCover(context),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: buildInfo(context)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
