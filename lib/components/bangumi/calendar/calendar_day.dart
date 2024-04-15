import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/bangumi/bangumi_model.dart';
import 'calendar_card.dart';

/// 今日放送-单日
class CalendarDay extends StatelessWidget {
  /// 数据
  final List<BangumiLegacySubjectSmall> data;

  /// 是否在加载中
  final bool loading;

  /// 构造函数
  const CalendarDay({
    super.key,
    required this.data,
    required this.loading,
  });

  /// 构建错误
  Widget buildError(BuildContext context) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProgressRing(),
            SizedBox(height: 20.h),
            Text('正在加载数据...'),
          ],
        ),
      );
    }
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.error, color: FluentTheme.of(context).accentColor),
          SizedBox(width: 10.w),
          Text('没有放送数据'),
        ],
      ),
    );
  }

  /// 构建列表
  Widget buildList() {
    return GridView(
      controller: ScrollController(),
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 10 / 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      children: data.map((e) => CalendarCard(data: e)).toList(),
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: data.isEmpty ? buildError(context) : buildList(),
    );
  }
}
