import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/bangumi/bangumi_model_patch.dart';
import '../../../store/app_store.dart';
import '../../../utils/bangumi_utils.dart';

/// 番剧评分折线图
/// 参考：fl_chart的bar_chart_sample8.dart
/// 文档参考：https://github.com/imaNNeo/fl_chart/blob/main/repo_files/documentations/bar_chart.md
/// 代码：https://github.com/imaNNeo/fl_chart/blob/main/example/lib/presentation/samples/bar/bar_chart_sample8.dart
/// 动画部分参考同类型下的 sample1
/// 代码：https://github.com/imaNNeo/fl_chart/blob/main/example/lib/presentation/samples/bar/bar_chart_sample1.dart
class BsdRateChart extends ConsumerStatefulWidget {
  /// 评分数据
  final BangumiPatchRating? rating;

  /// 构造函数
  const BsdRateChart(this.rating, {super.key});

  @override
  ConsumerState<BsdRateChart> createState() => _BangumiRateBarChartState();
}

class _BangumiRateBarChartState extends ConsumerState<BsdRateChart> {
  /// 数据
  BangumiPatchRating? get rating => widget.rating;

  /// 是否有数据
  bool get empty => rating == null || rating!.total == 0;

  /// 颜色
  AccentColor get color => ref.read(appStoreProvider).accentColor;

  /// 初始化
  @override
  void initState() {
    super.initState();
  }

  /// 获取Tiles
  Widget getTiles(double value, TitleMeta meta) {
    var style = TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp);
    return SideTitleWidget(
      axisSide: AxisSide.left,
      child: Text(value.toInt().toString(), style: style),
    );
  }

  Widget leftTitles(double value, TitleMeta meta) {
    var style = const TextStyle(fontWeight: FontWeight.bold);
    var max = getMaxY();
    var title5 = [0, max * 0.2, max * 0.4, max * 0.6, max * 0.8, max];
    if (title5.contains(value)) {
      return SideTitleWidget(
        space: 0,
        axisSide: meta.axisSide,
        child: Text(value.toInt().toString(), style: style),
      );
    }
    return const SizedBox();
  }

  /// 制造数据-单项
  BarChartGroupData makeDataItem(BuildContext context, int i, int val) {
    var gradient = LinearGradient(
      colors: [color, color.lightest],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
    return BarChartGroupData(
      x: i + 1,
      barRods: [
        BarChartRodData(
          toY: val.toDouble(),
          color: color.light,
          gradient: gradient,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          width: 35.w,
        ),
      ],
      showingTooltipIndicators: [0],
    );
  }

  /// 制造数据
  List<BarChartGroupData> makeData(BuildContext context) {
    var list = List.filled(10, 0);
    var res = <BarChartGroupData>[];
    if (rating == null) {
      for (var i = 0; i < list.length; i++) {
        res.add(makeDataItem(context, i, 0));
      }
    } else {
      for (var i = 0; i < list.length; i++) {
        var score = rating!.count['$i'];
        res.add(makeDataItem(context, i, score ?? 0));
      }
    }
    return res;
  }

  /// 获取触摸数据
  BarTouchData getTouchData(BuildContext context) {
    return BarTouchData(
      enabled: false,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (group) => Colors.transparent,
        tooltipPadding: const EdgeInsets.all(4),
        tooltipMargin: 0,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          var val = rod.toY.toInt();
          var text = val.toString();
          if (rod.toY > 1000) {
            text = '${(val / 1000).toStringAsFixed(1)}k';
          }
          var c = groupIndex % 2 == 0 ? color.dark : color.light;
          return BarTooltipItem(text, TextStyle(color: c));
        },
      ),
    );
  }

  /// 获取最大值
  double getMaxY() {
    var list = [10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
    var countMax = rating!.count.values.reduce(
      (value, element) => value > element ? value : element,
    );
    var countMax5 = list.firstWhere(
      (element) => element >= countMax,
      orElse: () => 20000,
    );
    var countMaxList = [
      countMax5 * 0,
      countMax5 * 0.2,
      countMax5 * 0.4,
      countMax5 * 0.6,
      countMax5 * 0.8,
      countMax5,
    ];
    var countMaxIndex = countMaxList.indexWhere(
      (element) => element >= countMax,
    );
    return countMaxList[countMaxIndex].toDouble();
  }

  /// 获取数据
  BarChartData getData(BuildContext context) {
    var maxY = getMaxY();
    var maxLen = maxY.toInt().toString().length;
    return BarChartData(
      barTouchData: getTouchData(context),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: getTiles,
            reservedSize: 20,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            reservedSize: maxLen * 8.0,
            showTitles: true,
            interval: 1,
            getTitlesWidget: leftTitles,
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      maxY: maxY,
      borderData: FlBorderData(show: false),
      barGroups: makeData(context),
      gridData: const FlGridData(show: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500.w,
      height: 300.h,
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              empty
                  ? '暂无评分'
                  : '${rating!.score} ${getBangumiRateLabel(rating!.score)}'
                      '(${rating!.total}人评分)',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            SizedBox(height: 20.h),
            Expanded(child: BarChart(getData(context))),
          ],
        ),
      ),
    );
  }
}
