import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../components/nav_calendar/calendar_tab.dart';
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
class _CalendarPageState extends State<CalendarPage>
    with AutomaticKeepAliveClientMixin {
  /// 请求客户端
  final _client = BangumiAPI();

  /// 正在请求数据
  bool isRequesting = false;

  /// 请求数据
  List<CalendarItem> calendarData = [];

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
  }

  /// dispose 保留状态
  @override
  void dispose() {
    super.dispose();
  }

  /// 构建日历
  Future<bool> calendarBuilder() async {
    if (calendarData.isEmpty && !isRequesting) {
      isRequesting = true;
      var value = await _client.getToday();
      calendarData = value;
      isRequesting = false;
      setState(() {});
    } else if (isRequesting) {
      return false;
    }
    return true;
  }

  /// 页面刷新
  Future<void> onRefresh() async {
    calendarData = [];
    setState(() {});
  }

  /// 刷新
  Widget buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [ProgressRing(), SizedBox(height: 20.h), Text('正在加载数据...')],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder(
      future: calendarBuilder(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          var data = snapshot.data;
          if (data == false) {
            return buildLoading();
          }
          return CalendarTab(
            data: calendarData,
            onRefresh: onRefresh,
          );
        }
        return buildLoading();
      },
    );
  }
}
