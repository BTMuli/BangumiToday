// Dart imports:
import 'dart:math' as math;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/layout/responsive.dart';
import '../../core/theme/bt_theme.dart';
import '../../widgets/common/empty_state.dart';
import 'bangumi_calendar_card.dart';
import 'bangumi_calendar_data.dart';

/// 今日放送-单日分组
///
/// 滚动列表里的一天：日期头 + 卡片网格。空状态用固定高度，
/// 免得空分组把滚动距离拉得忽长忽短。
class BangumiCalendarDay extends StatelessWidget {
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

  /// 当前是否只展示收藏条目。
  final bool collectionOnly;

  /// 空状态最小高度，保证滚动距离稳定
  static const double _emptyHeight = 180;

  /// 构造函数
  const BangumiCalendarDay({
    super.key,
    required this.weekday,
    required this.date,
    required this.isToday,
    required this.data,
    required this.loading,
    this.collectionOnly = false,
  });

  /// 月份/日期，如 `10/03`
  String get monthDay {
    var month = date.month.toString().padLeft(2, '0');
    var day = date.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  /// 构建空状态
  Widget buildEmptyState(BuildContext context) {
    if (loading) {
      return BTEmptyState.loading(message: '正在加载数据...');
    }
    return BTEmptyState.noData(
      title: collectionOnly ? '暂无收藏番剧放送' : '暂无可显示的放送',
      message: collectionOnly ? '可关闭「只显示收藏」查看其他放送条目' : '该日期暂无符合显示条件的番剧',
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
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
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

  /// 构建列表
  Widget buildList(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = BTBreakpoints.getGridColumns(constraints.maxWidth);
        var cardWidth =
            (constraints.maxWidth - 16 - (columns - 1) * 8) / columns;
        var minimumHeight = BangumiCalendarCard.minimumHeight(
          context,
          hasAirInfo: data.any(
            (item) => (item.airClock ?? '').isNotEmpty || item.episode != null,
          ),
        );
        return GridView.builder(
          padding: EdgeInsets.all(8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: math.max(cardWidth * 7 / 10, minimumHeight),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: data.length,
          itemBuilder: (context, index) {
            var item = data[index];
            return RepaintBoundary(
              key: ValueKey(item.subject.id),
              child: BangumiCalendarCard(
                data: item.subject,
                airTime: item.airClock,
                episode: item.episode,
                watched: item.watched,
                inBmf: item.inBmf,
              ),
            );
          },
        );
      },
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildHeader(context),
        if (data.isEmpty)
          // 用最小高度而不是固定高度：加载态比空态高，固定高度会溢出
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _emptyHeight),
            child: buildEmptyState(context),
          )
        else
          buildList(context),
      ],
    );
  }
}
