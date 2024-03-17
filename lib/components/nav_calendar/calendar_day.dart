import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/bangumi/get_calendar.dart';
import 'calendar_card.dart';

/// 今日放送-单日
class CalendarDay extends StatelessWidget {
  /// 数据
  final CalendarItem data;

  /// 构造函数
  const CalendarDay({super.key, required this.data});

  /// 构建
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: GridView(
        controller: ScrollController(),
        padding: EdgeInsets.all(12.sp),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 12.sp,
          mainAxisSpacing: 12.sp,
          childAspectRatio: 2 / 3,
        ),
        children: data.items.map((e) => CalendarCard(data: e)).toList(),
      ),
    );
  }
}
