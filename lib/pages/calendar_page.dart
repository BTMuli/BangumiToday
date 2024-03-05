import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/nav_calendar/calendar_day.dart';
import '../models/bangumi/get_calendar.dart';
import '../request/bangumi/bangumi_api.dart';

/// 今日放送
class CalendarPage extends ConsumerStatefulWidget {
  /// 构造函数
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

/// 今日放送状态
class _CalendarPageState extends ConsumerState<CalendarPage> {
  /// 请求客户端
  final _client = BangumiAPI();

  /// 顶部tab
  late int _tabIndex = -1;

  /// 今日星期
  int get _today => DateTime.now().weekday - 1;

  /// 请求数据
  List<CalendarItem> calendarData = [];

  @override
  void initState() {
    super.initState();
    _client.getToday().then((value) {
      calendarData = value;
      _tabIndex = _today;
      setState(() {});
    });
  }

  /// 构建日历
  Widget _buildCalendar() {
    return TabView(
      tabs: [
        for (var item in calendarData)
          Tab(
            text: Text(item.weekday.cn),
            icon: item.weekday.id == _today
                ? Icon(FluentIcons.away_status)
                : Icon(FluentIcons.calendar),
            body: NavCalendarDay(data: item),
            semanticLabel: item.weekday.cn,
          ),
      ],
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

  @override
  Widget build(BuildContext context) {
    if (calendarData.isNotEmpty) {
      return _buildCalendar();
    }
    return Center(child: ProgressRing());
  }
}
