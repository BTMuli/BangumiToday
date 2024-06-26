// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../components/app/app_dialog_resp.dart';
import '../../components/app/app_infobar.dart';
import '../../components/bangumi/calendar/calendar_day.dart';
import '../../database/bangumi/bangumi_collection.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/bgm_user_hive.dart';
import '../../store/nav_store.dart';
import 'bangumi_collection.dart';
import 'bangumi_data.dart';
import 'bangumi_search.dart';
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

  /// 是否只显示收藏
  bool isShowCollection = false;

  /// 收藏数据库
  final BtsBangumiCollection sqlite = BtsBangumiCollection();

  /// 用户hive
  final BgmUserHive hive = BgmUserHive();

  /// tabIndex
  int tabIndex = 0;

  /// 星期列表
  List<String> weekday = ['一', '二', '三', '四', '五', '六', '日'];

  /// 今天
  int get today => DateTime.now().weekday - 1;

  /// flyout controller
  final FlyoutController controller = FlyoutController();

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    if (hive.user != null) {
      isShowCollection = true;
      setState(() {});
    }
    Future.microtask(() async {
      await getData(freshTab: true);
    });
  }

  /// dispose 保留状态
  @override
  void dispose() {
    super.dispose();
  }

  /// 获取数据
  Future<void> getData({bool freshTab = false}) async {
    isRequesting = true;
    calendarData.clear();
    if (freshTab) {
      tabIndex = today;
    }
    setState(() {});
    var calendarGet = await _client.getToday();
    if (calendarGet.code != 0 || calendarGet.data == null) {
      isRequesting = false;
      setState(() {});
      if (mounted) await showRespErr(calendarGet, context);
      return;
    }
    assert(calendarGet.data != null);
    var data = calendarGet.data as List<BangumiCalendarRespData>;
    if (isShowCollection) {
      for (var d in data) {
        for (var item in d.items.toList()) {
          var check = await sqlite.isCollected(item.id);
          if (!check) d.items.remove(item);
        }
      }
    }
    calendarData = data;
    isRequesting = false;
    setState(() {});
  }

  /// 获取 Tab 数据
  List<BangumiLegacySubjectSmall> getTabData(int index) {
    if (index >= calendarData.length) return [];
    return calendarData[index].items;
  }

  /// 刷新
  Widget buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProgressRing(),
          SizedBox(height: 20.h),
          const Text('正在加载数据...')
        ],
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
            icon: const Icon(FluentIcons.refresh),
            onPressed: () async {
              await getData();
            },
          ),
        ),
      ],
    );
  }

  /// 构建收藏按钮
  MenuFlyoutItem buildFlyoutCollection(BuildContext context) {
    var color = FluentTheme.of(context).accentColor;
    var title = "Bangumi-用户收藏";
    var pane = PaneItem(
      icon: Icon(FluentIcons.favorite_star, color: color),
      title: Text(title),
      body: const BangumiCollectionPage(),
    );
    return MenuFlyoutItem(
      leading: Icon(
        FluentIcons.favorite_star,
        color: hive.user == null ? null : color,
      ),
      text: const Text('查看用户收藏'),
      onPressed: () async {
        if (hive.user == null) {
          await BtInfobar.warn(context, '请前往用户界面登录');
          return;
        }
        ref.read(navStoreProvider).addNavItem(pane, title);
      },
    );
  }

  /// 构建用户按钮
  MenuFlyoutItem buildFlyoutUser(BuildContext context) {
    var color = FluentTheme.of(context).accentColor;
    var title = "Bangumi 用户界面";
    var pane = PaneItem(
      icon: Icon(FluentIcons.contact, color: color),
      title: Text(title),
      body: const BangumiUserPage(),
    );
    return MenuFlyoutItem(
      leading: Icon(
        FluentIcons.contact,
        color: color,
      ),
      text: const Text('查看用户界面'),
      onPressed: () async {
        ref.read(navStoreProvider).addNavItem(pane, title);
      },
    );
  }

  /// 构建数据按钮
  MenuFlyoutItem buildFlyoutData(BuildContext context) {
    var color = FluentTheme.of(context).accentColor;
    var title = "BangumiData";
    var pane = PaneItem(
      icon: Icon(FluentIcons.database_source, color: color),
      title: Text(title),
      body: const BangumiDataPage(),
    );
    return MenuFlyoutItem(
      leading: Icon(
        FluentIcons.database_source,
        color: color,
      ),
      text: const Text('BangumiData 数据库'),
      onPressed: () async {
        ref.read(navStoreProvider).addNavItem(pane, title);
      },
    );
  }

  /// 构建搜索按钮
  MenuFlyoutItem buildFlyoutSearch(BuildContext context) {
    var color = FluentTheme.of(context).accentColor;
    var title = "Bangumi-条目搜索";
    var pane = PaneItem(
      icon: Icon(FluentIcons.search, color: color),
      title: Text(title),
      body: const BangumiSearchPage(),
    );
    return MenuFlyoutItem(
      leading: Icon(
        FluentIcons.search,
        color: color,
      ),
      text: const Text('Bangumi-条目搜索'),
      onPressed: () async {
        ref.read(navStoreProvider).addNavItem(pane, title);
      },
    );
  }

  /// 构建flyout
  void buildFlyout() {
    controller.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => MenuFlyout(
        items: [
          buildFlyoutCollection(context),
          buildFlyoutUser(context),
          buildFlyoutData(context),
          buildFlyoutSearch(context),
        ],
      ),
    );
  }

  /// 构建 flyout 按钮
  Widget buildFlyoutButton(BuildContext context) {
    return FlyoutTarget(
      controller: controller,
      child: Button(
        style: ButtonStyle(
          backgroundColor: ButtonState.all(FluentTheme.of(context).accentColor),
        ),
        onPressed: buildFlyout,
        child: const Tooltip(message: '更多', child: Icon(FluentIcons.more)),
      ),
    );
  }

  /// 构建收藏按钮
  Widget buildCollectSwitch(BuildContext context) {
    return Tooltip(
      message: '只显示收藏',
      child: ToggleButton(
        checked: isShowCollection,
        onChanged: (v) async {
          isShowCollection = v;
          setState(() {});
          await getData();
        },
        child: const Icon(FluentIcons.favorite_star),
      ),
    );
  }

  /// 构建 Tab 底部
  Widget buildTabFooter() {
    return Row(children: [
      buildCollectSwitch(context),
      SizedBox(width: 8.w),
      buildFlyoutButton(context),
      SizedBox(width: 8.w),
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
                ? const Icon(FluentIcons.away_status)
                : const Icon(FluentIcons.calendar),
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
