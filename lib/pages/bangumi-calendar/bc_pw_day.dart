// Dart imports:
import 'dart:math' as math;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/layout/responsive.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../widgets/common/empty_state.dart';
import 'bc_pw_card.dart';

/// 今日放送-单日
class BcpDayWidget extends StatelessWidget {
  /// 数据
  final List<BangumiLegacySubjectSmall> data;

  /// 开播时间，按条目原名索引
  final Map<String, String> airTimes;

  /// 是否在加载中
  final bool loading;

  /// 构造函数
  const BcpDayWidget({
    super.key,
    required this.data,
    this.airTimes = const {},
    required this.loading,
  });

  /// 构建空状态
  Widget buildEmptyState(BuildContext context) {
    if (loading) {
      return BTEmptyState.loading(message: '正在加载数据...');
    }
    return BTEmptyState.noData(title: '暂无放送数据', message: '该日期没有番剧放送');
  }

  /// 构建列表
  Widget buildList(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = BTBreakpoints.getGridColumns(constraints.maxWidth);
        var cardWidth =
            (constraints.maxWidth - 16 - (columns - 1) * 8) / columns;
        var minimumHeight = BcpCardWidget.minimumHeight(
          context,
          hasAirTime: data.any(
            (item) => airTimes[item.name]?.isNotEmpty ?? false,
          ),
        );
        return GridView.builder(
          padding: EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: math.max(cardWidth * 7 / 10, minimumHeight),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: data.length,
          scrollCacheExtent: const ScrollCacheExtent.pixels(500),
          itemBuilder: (context, index) {
            var item = data[index];
            return RepaintBoundary(
              key: ValueKey(item.id),
              child: BcpCardWidget(data: item, airTime: airTimes[item.name]),
            );
          },
        );
      },
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: data.isEmpty ? buildEmptyState(context) : buildList(context),
    );
  }
}
