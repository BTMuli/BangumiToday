import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/bangumi/get_subject.dart';
import '../../store/app_store.dart';

/// 番剧评分折线图
/// 参考：fl_chart的bar_chart_sample8.dart
/// 文档参考：https://github.com/imaNNeo/fl_chart/blob/main/repo_files/documentations/bar_chart.md
/// 代码：https://github.com/imaNNeo/fl_chart/blob/main/example/lib/presentation/samples/bar/bar_chart_sample8.dart
/// 动画部分参考同类型下的 sample1
/// 代码：https://github.com/imaNNeo/fl_chart/blob/main/example/lib/presentation/samples/bar/bar_chart_sample1.dart
class BangumiRateBarChart extends ConsumerStatefulWidget {
  /// 评分数据
  final BangumiSubjectRating? rating;

  /// 构造函数
  const BangumiRateBarChart(this.rating, {super.key});

  @override
  ConsumerState<BangumiRateBarChart> createState() =>
      _BangumiRateBarChartState();
}

class _BangumiRateBarChartState extends ConsumerState<BangumiRateBarChart> {
  /// 数据
  BangumiSubjectRating? get rating => widget.rating;

  /// 是否有数据
  bool get empty => rating == null;

  /// 颜色
  AccentColor get color => ref.read(appStoreProvider).accentColor;

  /// 获取Tiles
  Widget getTiles(double value, TitleMeta meta) {
    var style = TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp);
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text((value.toInt() + 1).toString(), style: style),
    );
  }

  /// 制造数据-单项
  BarChartGroupData makeDataItem(BuildContext context, int i, int val) {
    var gradient = LinearGradient(
      colors: [color, color.lightest],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
    return BarChartGroupData(
      x: i,
      barRods: [
        BarChartRodData(
          toY: val.toDouble(),
          color: color.light,
          gradient: gradient,
          borderRadius: BorderRadius.all(Radius.circular(4.sp)),
          width: 25.w,
          borderSide: BorderSide(color: Colors.white, width: 2.w),
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
        tooltipPadding: EdgeInsets.zero,
        tooltipMargin: 0,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return BarTooltipItem(
            rod.toY.toInt().toString(),
            TextStyle(
              color: color.lighter,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          );
        },
      ),
    );
  }

  /// 获取数据
  BarChartData getData(BuildContext context) {
    return BarChartData(
      barTouchData: getTouchData(context),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: getTiles,
            reservedSize: 30,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(reservedSize: 40, showTitles: true),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      barGroups: makeData(context),
      gridData: FlGridData(show: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450.w,
      height: 300.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).brightness.isLight
            ? Colors.white.withAlpha(900)
            : Colors.black.withAlpha(900),
        borderRadius: BorderRadius.circular(8.sp),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            empty ? '暂无评分' : '${rating!.score}(${rating!.total}人评分)',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          SizedBox(height: 20.h),
          Expanded(child: BarChart(getData(context))),
        ],
      ),
    );
  }
}
