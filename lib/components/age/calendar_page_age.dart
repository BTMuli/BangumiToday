import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/age/get_home_list.dart';
import '../../request/age/age_api.dart';
// import '../../store/app_store.dart';

/// 今日放送-age数据源
class CalendarPageAge extends ConsumerStatefulWidget {
  /// 构造函数
  const CalendarPageAge({super.key});

  @override
  ConsumerState<CalendarPageAge> createState() => _CalendarPageAgeState();
}

/// 今日放送-age数据源状态
class _CalendarPageAgeState extends ConsumerState<CalendarPageAge> {
  /// 请求客户端
  final _client = AgeAPI();

  /// 顶部tab
  late int _tabIndex = -1;

  /// 今日星期
  int get _today => DateTime.now().weekday - 1;

  /// 请求数据
  Map<String, List<HomeItem>>? calendarData;

  /// 获取星期x的数据
  String getDay(int index) {
    var dayList = ['一', '二', '三', '四', '五', '六', '日'];
    return '星期${dayList[index]}';
  }

  /// load
  void load() {
    _client.getHomeList().then((value) {
      calendarData = value.weekList;
      _tabIndex = _today;
      setState(() {});
    });
  }

  /// 初始化
  @override
  void initState() {
    super.initState();
    load();
  }

  /// 构建操作按钮
  Widget buildAction() {
    return Row(
      children: [
        Tooltip(
          message: '切换数据源',
          child: DropDownButton(
            title: const Icon(FluentIcons.dataverse),
            items: [
              MenuFlyoutItem(
                text: const Text('bangumi'),
                onPressed: () {
                  // ref.read(appStoreProvider.notifier).setSource('bangumi');
                },
              ),
              MenuFlyoutItem(
                text: const Text('AGE'),
                onPressed: () {
                  // ref.read(appStoreProvider.notifier).setSource('agefans');
                },
              ),
            ],
          ),
        ),
        SizedBox(width: 8.sp),
        Tooltip(
          message: '刷新',
          child: IconButton(
            icon: const Icon(FluentIcons.refresh),
            onPressed: load,
          ),
        ),
        SizedBox(width: 8.sp),
      ],
    );
  }

  /// 构建日历
  Widget buildCalendar() {
    return TabView(
      tabs: [
        for (var i = 0; i < 7; i++)
          Tab(
            text: Text(getDay(i)),
            icon: i == _today
                ? const Icon(FluentIcons.away_status)
                : const Icon(FluentIcons.calendar),
            body: CalendarDayAge(data: calendarData?['${(i + 1) % 7}'] ?? []),
            semanticLabel: getDay(i),
          ),
      ],
      header: Row(
        children: [
          const Tooltip(
            message: '数据来源于 age',
            child: Icon(FluentIcons.info),
          ),
          Text('今日放送-${getDay(_today)}'),
        ],
      ),
      footer: buildAction(),
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

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    if (calendarData == null) {
      return const Center(child: ProgressRing());
    }
    return buildCalendar();
  }
}

/// 今日放送-单日-age数据源
class CalendarDayAge extends StatelessWidget {
  /// 数据
  final List<HomeItem> data;

  /// 构造函数
  const CalendarDayAge({required this.data, super.key});

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
        children: data.map((e) => CalendarCardAge(data: e)).toList(),
      ),
    );
  }
}

/// 今日放送-卡片-age数据源
class CalendarCardAge extends StatelessWidget {
  /// 数据
  final HomeItem data;

  /// 构造函数
  const CalendarCardAge({required this.data, super.key});

  /// 构建加载中卡片
  Widget buildLoadingCard() {
    return const Card(child: Center(child: ProgressRing()));
  }

  /// 构建封面
  Widget buildCover(BuildContext context) {
    var link = agePicUrl.replaceAll('{aid}', data.id.toString());
    return CachedNetworkImage(
      imageUrl: link,
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, dp) => Center(
        child: ProgressRing(
          value: dp.progress == null ? 0 : dp.progress! * 100,
        ),
      ),
      errorWidget: (context, url, error) => const Icon(FluentIcons.error),
    );
  }

  /// 构建渐变层
  Widget buildGradient(BuildContext context) {
    final brightness = FluentTheme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [
            brightness == Brightness.light
                ? Colors.white.withOpacity(0)
                : Colors.black.withOpacity(0),
            brightness == Brightness.light
                ? Colors.white.withOpacity(0.75)
                : Colors.black.withOpacity(0.75),
          ],
        ),
      ),
    );
  }

  /// 构建番剧信息
  Widget buildItemInfo(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: data.name,
            child: Text(
              data.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: data.nameForNew,
            child: Text(data.nameForNew),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200.sp,
      height: 300.sp,
      child: Stack(
        children: [
          Positioned.fill(child: buildCover(context)),
          Positioned.fill(child: buildGradient(context)),
          Positioned(
              bottom: 0, left: 0, right: 0, child: buildItemInfo(context)),
        ],
      ),
    );
  }
}
