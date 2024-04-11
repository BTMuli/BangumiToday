import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/bangumi/request_subject.dart';
import 'calendar_card.dart';

/// 今日放送-单日
class CalendarDay extends StatelessWidget {
  /// 数据
  final BangumiCalendarRespData? data;

  /// 是否在加载中
  final bool loading;

  /// 构造函数
  const CalendarDay({
    super.key,
    required this.data,
    required this.loading,
  });

  /// 构建错误
  Widget buildError() {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(),
            SizedBox(height: 20.h),
            Text('正在加载数据...'),
          ],
        ),
      );
    }
    return Center(
      child: Text('加载失败'),
    );
  }

  /// 构建列表
  Widget buildList() {
    return GridView(
      controller: ScrollController(),
      padding: EdgeInsets.all(12.sp),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 400.w / 280.h,
        mainAxisSpacing: 8.h,
        crossAxisSpacing: 7.w,
      ),
      children: data!.items.map((e) => CalendarCard(data: e)).toList(),
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: data == null ? buildError() : buildList(),
    );
  }
}
