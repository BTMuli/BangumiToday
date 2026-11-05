// Dart imports:
import 'dart:math' as math;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../widgets/common/empty_state.dart';
import 'bangumi_calendar_card.dart';
import 'bangumi_calendar_data.dart';

/// 今日放送-单日分组
///
/// 提供日期头、空状态与网格参数，由页面拼成
/// `SliverMainAxisGroup`（头 + `SliverGrid.builder`）。
class BangumiCalendarDay {
  /// 星期标签，如 `周六`
  final String weekday;

  /// 分组日期
  final DateTime date;

  /// 是否今天
  final bool isToday;

  /// 数据
  final List<BangumiCalendarItem> data;

  /// 分组是否还在准备中（准备完成前数据是置空的）
  final bool loading;

  /// 收藏筛选开启时的收藏 ID；null 表示显示全部条目。
  final Set<int>? collectedIds;

  /// 是否以凌晨 6 点作为放送日边界。
  final bool nightMode;

  /// 当前是否只展示收藏与 BMF 订阅条目。
  bool get collectionOnly => collectedIds != null;

  /// 空状态最小高度，保证滚动距离稳定
  static const double emptyMinHeight = 180;

  /// 按横向卡片所需宽度排布，避免通用屏幕断点让卡片过宽。
  static const double minimumCardWidth = 280;

  /// 卡片间距
  static const double cardSpacing = 8;

  /// 网格外边距
  static const EdgeInsets gridPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  /// 构造函数
  const BangumiCalendarDay({
    required this.weekday,
    required this.date,
    required this.isToday,
    required this.data,
    required this.loading,
    this.collectedIds,
    this.nightMode = false,
  });

  /// 月份/日期，如 `10/03`
  String get monthDay {
    var month = date.month.toString().padLeft(2, '0');
    var day = date.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  /// 是否有放送时刻或话数信息（影响卡片最小高度）。
  bool get hasAirInfo => data.any(
    (item) => (item.airClock ?? '').isNotEmpty || item.episode != null,
  );

  /// 按可用内容宽度计算列数。
  static int gridColumns(double contentWidth) {
    return math.max(
      1,
      ((contentWidth + cardSpacing) / (minimumCardWidth + cardSpacing)).floor(),
    );
  }

  /// 计算网格行高。
  static double gridMainAxisExtent({
    required BuildContext context,
    required double contentWidth,
    required int columns,
    required bool hasAirInfo,
  }) {
    var cardWidth = (contentWidth - (columns - 1) * cardSpacing) / columns;
    var minimumHeight = BangumiCalendarCard.minimumHeight(
      context,
      hasAirInfo: hasAirInfo,
    );
    return math.max(cardWidth * 7 / 10, minimumHeight);
  }

  /// 根据视口宽度构建网格 delegate。
  SliverGridDelegate buildGridDelegate(BuildContext context, double maxWidth) {
    var contentWidth = maxWidth - gridPadding.horizontal;
    var columns = gridColumns(contentWidth);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisExtent: gridMainAxisExtent(
        context: context,
        contentWidth: contentWidth,
        columns: columns,
        hasAirInfo: hasAirInfo,
      ),
      mainAxisSpacing: cardSpacing,
      crossAxisSpacing: cardSpacing,
    );
  }

  /// 构建空状态
  Widget buildEmptyState(BuildContext context) {
    if (loading) {
      return BTEmptyState.loading(message: '正在加载数据...');
    }
    return BTEmptyState.noData(
      title: collectionOnly ? '暂无收藏或 BMF 番剧放送' : '暂无可显示的放送',
      message: collectionOnly ? '可关闭收藏筛选查看其他放送条目' : '该日期暂无符合显示条件的番剧',
    );
  }

  /// 空状态主体：用最小高度稳住滚动距离。
  Widget buildEmptyBody(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: emptyMinHeight),
      child: buildEmptyState(context),
    );
  }

  /// 构建今天标记
  Widget buildTodayBadge(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BTRadius.smallBR,
      ),
      child: Text(
        '今天',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }

  /// 构建分组头
  Widget buildHeader(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${date.day}',
            style: BTTypography.titleLarge(
              context,
            ).copyWith(color: isToday ? accent : BTColors.textPrimary(context)),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(weekday, style: BTTypography.subtitle(context)),
          ),
          if (isToday) ...[const SizedBox(width: 8), buildTodayBadge(context)],
          const Spacer(),
          // 还在准备时条目是置空的，数量不做数，先不显示
          if (!loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '$monthDay · ${data.length} 部',
                style: BTTypography.caption(context),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建单张日历卡片。
  Widget buildCard(BuildContext context, BangumiCalendarItem item) {
    return RepaintBoundary(
      key: ValueKey(item.subject.id),
      child: BangumiCalendarCard(
        data: item.subject,
        airTime: item.airClock,
        episode: item.episode,
        watched: item.watched,
        inBmf: item.inBmf,
        nightMode: nightMode,
        bmfOnly:
            collectionOnly &&
            item.inBmf &&
            !collectedIds!.contains(item.subject.id),
      ),
    );
  }
}
