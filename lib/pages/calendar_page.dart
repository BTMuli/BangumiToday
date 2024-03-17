import 'package:fluent_ui/fluent_ui.dart';

import '../components/nav_calendar/calendar_day.dart';
import '../models/bangumi/get_calendar.dart';
import '../request/bangumi/bangumi_api.dart';

/// 今日放送
class CalendarPage extends StatefulWidget {
  /// 构造函数
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

/// 今日放送状态
class _CalendarPageState extends State<CalendarPage> {
  /// 请求客户端
  final _client = BangumiAPI();

  /// 顶部 tab
  late int _tabIndex = -1;

  /// 今日星期
  int get _today => DateTime.now().weekday - 1;

  /// 请求数据
  List<CalendarItem> calendarData = [];

  /// 初始化
  @override
  void initState() {
    super.initState();
    _client.getToday().then((value) {
      calendarData = value;
      _tabIndex = _today;
      setState(() {});
    });
  }

  /// 构建刷新按钮
  Widget buildRefresh() {
    return Tooltip(
      message: '刷新',
      child: IconButton(
        icon: Icon(FluentIcons.refresh),
        onPressed: () async {
          // todo load悬浮窗
          var value = await _client.getToday();
          calendarData = value;
          _tabIndex = _today;
          setState(() {});
        },
      ),
    );
  }

  /// 构建日历
  Widget _buildCalendar() {
    return TabView(
      tabs: [
        for (var item in calendarData)
          Tab(
            text: Text(item.weekday.cn),
            icon: item.weekday.id == _today + 1
                ? Icon(FluentIcons.away_status)
                : Icon(FluentIcons.calendar),
            body: CalendarDay(data: item),
            semanticLabel: item.weekday.cn,
          ),
      ],
      header: Row(children: [
        Text(calendarData[_today].weekday.cn),
        buildRefresh(),
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

  @override
  Widget build(BuildContext context) {
    if (calendarData.isNotEmpty) {
      return _buildCalendar();
    }
    return Center(child: ProgressRing());
  }
}
