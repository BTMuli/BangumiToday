import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/bangumi/get_calendar.dart';
import 'calendar_day.dart';

/// 日历页面
class CalendarTab extends StatefulWidget {
  /// 番剧数据
  final List<CalendarItem> data;

  /// 刷新回调
  final void Function() onRefresh;

  /// 构造函数
  const CalendarTab({super.key, required this.data, required this.onRefresh});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

/// 日历页面状态
class _CalendarTabState extends State<CalendarTab> {
  /// 顶部 tab
  late int _tabIndex = today;

  /// 今日星期
  int get today => DateTime.now().weekday - 1;

  /// 构建刷新按钮
  Widget buildRefresh() {
    return Tooltip(
      message: '刷新',
      child: IconButton(
        icon: Icon(FluentIcons.refresh),
        onPressed: widget.onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TabView(
      tabs: [
        for (var item in widget.data)
          Tab(
            text: Text(item.weekday.cn),
            icon: item.weekday.id == today + 1
                ? Icon(FluentIcons.away_status)
                : Icon(FluentIcons.calendar),
            body: CalendarDay(data: item),
            semanticLabel: item.weekday.cn,
          ),
      ],
      header: Row(children: [
        Image.asset('assets/images/platforms/bangumi-text.png'),
        SizedBox(width: 8.w),
        Text(widget.data[today].weekday.cn),
        buildRefresh(),
      ]),
      footer: Row(children: [
        Image.asset('assets/images/platforms/bangumi-logo.png'),
        SizedBox(width: 16.w),
      ]),
      currentIndex: _tabIndex,
      onChanged: (index) {
        setState(() {
          _tabIndex = index;
        });
      },
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
    );
  }
}
