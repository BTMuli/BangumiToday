import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/app/app_dialog_resp.dart';
import '../../components/bangumi/calendar_day.dart';
import '../../models/bangumi/request_subject.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/nav_store.dart';
import 'bangumi_data.dart';
import 'bangumi_user.dart';

/// 今日放送
class CalendarPage extends ConsumerStatefulWidget {
  /// 构造函数
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

/// 今日放送状态
class _CalendarPageState extends ConsumerState<CalendarPage>
    with AutomaticKeepAliveClientMixin {
  /// 请求客户端
  final _client = BtrBangumiApi();

  /// 正在请求数据
  bool isRequesting = true;

  /// 请求数据
  List<BangumiCalendarRespData> calendarData = [];

  /// tabIndex
  int tabIndex = 0;

  /// 星期列表
  List<String> weekday = ['一', '二', '三', '四', '五', '六', '日'];

  /// 今天
  int get today => DateTime.now().weekday - 1;

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await getData();
    });
  }

  /// dispose 保留状态
  @override
  void dispose() {
    super.dispose();
  }

  /// 获取数据
  Future<void> getData() async {
    isRequesting = true;
    calendarData.clear();
    tabIndex = today;
    setState(() {});
    var calendarGet = await _client.getToday();
    if (calendarGet.code != 0 || calendarGet.data == null) {
      isRequesting = false;
      setState(() {});
      showRespErr(calendarGet, context);
      return;
    }
    assert(calendarGet.data != null);
    calendarData = calendarGet.data as List<BangumiCalendarRespData>;
    isRequesting = false;
    setState(() {});
  }

  /// 获取 Tab 数据
  BangumiCalendarRespData? getTabData(int index) {
    if (index >= calendarData.length) return null;
    return calendarData[index];
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

  /// 构建 Tab 头部
  Widget buildTabHeader() {
    return Row(
      children: [
        Image.asset('assets/images/platforms/bangumi-text.png'),
        SizedBox(width: 8.w),
        Text('星期${weekday[today]}'),
        Tooltip(
          message: '刷新',
          child: IconButton(
            icon: Icon(FluentIcons.refresh),
            onPressed: () async {
              await getData();
            },
          ),
        ),
      ],
    );
  }

  /// 构建用户按钮
  Widget buildUserButton(BuildContext context) {
    return Tooltip(
      message: 'Bangumi 用户界面',
      child: FilledButton(
        child: Icon(FluentIcons.contact),
        onPressed: () {
          var paneItem = PaneItem(
            icon: Icon(FluentIcons.contact),
            title: Text('Bangumi 用户界面'),
            body: BangumiUserPage(),
          );
          ref.read(navStoreProvider).addNavItem(paneItem, 'Bangumi 用户界面');
        },
      ),
    );
  }

  /// 构建数据库按钮
  Widget buildDataBaseButton(BuildContext context) {
    return Tooltip(
      message: 'BangumiData',
      child: FilledButton(
        child: Icon(FluentIcons.database_source),
        onPressed: () {
          var paneItem = PaneItem(
            icon: Icon(FluentIcons.database_source),
            title: Text('BangumiData'),
            body: BangumiDataPage(),
          );
          ref.read(navStoreProvider).addNavItem(paneItem, 'BangumiData');
        },
      ),
    );
  }

  /// 构建 Tab 底部
  Widget buildTabFooter() {
    return Row(children: [
      buildUserButton(context),
      SizedBox(width: 16.w),
      buildDataBaseButton(context),
      SizedBox(width: 16.w),
      Image.asset('assets/images/platforms/bangumi-logo.png'),
      SizedBox(width: 16.w),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabView(
      tabs: [
        for (var i = 0; i < 7; i++)
          Tab(
            text: Text('星期${weekday[i]}'),
            icon: i == today
                ? Icon(FluentIcons.away_status)
                : Icon(FluentIcons.calendar),
            body: CalendarDay(data: getTabData(i), loading: isRequesting),
            semanticLabel: '星期${weekday[i]}',
          ),
      ],
      header: buildTabHeader(),
      footer: buildTabFooter(),
      currentIndex: tabIndex,
      onChanged: (index) {
        tabIndex = index;
        setState(() {});
      },
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
    );
  }
}
