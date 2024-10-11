// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../components/app/app_dialog.dart';
import '../../components/app/app_dialog_resp.dart';
import '../../components/app/app_infobar.dart';
import '../../components/bangumi/calendar/calendar_day.dart';
import '../../components/base/base_theme_icon.dart';
import '../../controller/app/progress_controller.dart';
import '../../database/app/app_config.dart';
import '../../database/bangumi/bangumi_collection.dart';
import '../../database/bangumi/bangumi_data.dart';
import '../../models/bangumi/bangumi_data_model.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/request_subject.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../request/bangumi/bangumi_data.dart';
import '../../store/bgm_user_hive.dart';
import '../../store/nav_store.dart';
import '../../tools/notifier_tool.dart';
import 'bangumi_collection.dart';
import 'bangumi_search.dart';

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
  /// bangumiAPI
  final BtrBangumiApi apiBgm = BtrBangumiApi();

  /// bangumiDataAPI
  final BtrBangumiDataApi apiBgd = BtrBangumiDataApi();

  /// 正在请求数据
  bool isRequesting = true;

  /// 请求数据
  List<BangumiCalendarRespData> calendarData = [];

  /// 是否只显示收藏
  bool isShowCollection = false;

  /// 收藏数据库
  final BtsBangumiCollection sqliteBc = BtsBangumiCollection();

  /// 数据库-AppConfig
  final BtsAppConfig sqliteAc = BtsAppConfig();

  /// bangumiData数据库
  final BtsBangumiData sqliteBd = BtsBangumiData();

  /// 用户hive
  final BgmUserHive hive = BgmUserHive();

  /// bangumiData版本号
  late String version = 'unknown';

  /// progress
  late ProgressController progress = ProgressController();

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
      version = await sqliteAc.read('bangumiDataVersion') ?? 'unknown';
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
    if (freshTab) tabIndex = today;
    setState(() {});
    var calendarGet = await apiBgm.getToday();
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
          var check = await sqliteBc.isCollected(item.id);
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

  /// 刷新BangumiData
  Future<void> refreshBgmData(BuildContext context) async {
    progress = ProgressWidget.show(
      context,
      title: '开始获取数据',
      text: '正在获取远程版本',
      progress: null,
    );
    var remoteGet = await apiBgd.getVersion();
    if (remoteGet.code != 0 || remoteGet.data == null) {
      progress.update(text: '获取远程版本失败');
      await Future.delayed(const Duration(seconds: 1));
      progress.end();
      if (context.mounted) await showRespErr(remoteGet, context);
      return;
    }
    var remote = remoteGet.data as String;
    progress.update(title: '成功获取远程版本', text: remote);
    await Future.delayed(const Duration(milliseconds: 500));
    progress.end();
    if (!context.mounted) return;
    var confirm = await showConfirmDialog(
      context,
      title: '确认更新？',
      content: '远程版本：$remote，本地版本：$version',
    );
    if (confirm && context.mounted) {
      progress = ProgressWidget.show(
        context,
        title: '开始更新数据',
        text: '正在更新数据',
        progress: null,
      );
      progress.update(title: '开始获取数据', text: '正在获取JSON数据', progress: null);
      progress.onTaskbar = true;
      var dataGet = await apiBgd.getData();
      if (dataGet.code != 0) {
        progress.update(text: '获取数据失败');
        await Future.delayed(const Duration(seconds: 1));
        progress.end();
        if (context.mounted) await showRespErr(dataGet, context);
        return;
      }
      var rawData = dataGet.data as BangumiDataJson;
      progress.update(title: '成功获取数据', text: '正在写入数据');
      int cnt, total;
      var sites = [];
      for (var entry in rawData.siteMeta.entries) {
        sites.add(BangumiDataSiteFull.fromSite(entry.key, entry.value));
      }
      total = sites.length;
      cnt = 1;
      for (var site in sites) {
        progress.update(
          title: '写入站点数据 $cnt/$total',
          text: site.title,
          progress: (cnt / total) * 100,
        );
        await sqliteBd.writeSite(site);
        cnt++;
        await Future.delayed(const Duration(milliseconds: 200));
      }
      var items = rawData.items;
      total = items.length;
      cnt = 1;
      for (var item in items) {
        progress.update(
          title: '写入条目数据 $cnt/$total',
          text: item.title,
          progress: (cnt / total) * 100,
        );
        await sqliteBd.writeItem(item);
        cnt++;
      }
      await BTNotifierTool.showMini(title: 'BangumiData', body: '数据更新完成');
      await sqliteAc.write('bangumiDataVersion', remote);
      progress.update(text: '已更新到最新版本');
      version = remote;
      setState(() {});
      await Future.delayed(const Duration(seconds: 1));
      progress.end();
    }
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
            onPressed: () async => await getData(),
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

  /// 构建数据按钮
  MenuFlyoutItem buildFlyoutData(BuildContext context) {
    return MenuFlyoutItem(
      leading: BaseThemeIcon(FluentIcons.database_source),
      text: const Text('BangumiData 数据库'),
      trailing: Text(
        version,
        style: TextStyle(
          color: FluentTheme.of(context).accentColor.withOpacity(0.5),
        ),
      ),
      onPressed: () async => await refreshBgmData(context),
    );
  }

  /// 构建搜索按钮
  MenuFlyoutItem buildFlyoutSearch(BuildContext context) {
    var title = "Bangumi-条目搜索";
    var pane = PaneItem(
      icon: BaseThemeIcon(FluentIcons.search),
      title: Text(title),
      body: const BangumiSearchPage(),
    );
    return MenuFlyoutItem(
      leading: BaseThemeIcon(FluentIcons.search),
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
          backgroundColor: WidgetStatePropertyAll(
            FluentTheme.of(context).accentColor,
          ),
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
