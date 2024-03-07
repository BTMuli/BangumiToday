import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/bangumi/get_calendar.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/app_store.dart';

/// 今日放送-bangumi数据源
class CalendarPageBangumi extends ConsumerStatefulWidget {
  /// 构造函数
  const CalendarPageBangumi({super.key});

  @override
  ConsumerState<CalendarPageBangumi> createState() =>
      _CalendarPageBangumiState();
}

/// 今日放送-bangumi数据源状态
class _CalendarPageBangumiState extends ConsumerState<CalendarPageBangumi> {
  /// 请求客户端
  final _client = BangumiAPI();

  /// 顶部tab
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

  /// 构建操作按钮
  Widget buildAction() {
    return Row(
      children: [
        Tooltip(
          message: '切换数据源',
          child: DropDownButton(
            title: Icon(FluentIcons.dataverse),
            items: [
              MenuFlyoutItem(
                text: Text('bangumi'),
                onPressed: () {
                  ref.read(appStoreProvider.notifier).setSource('bangumi');
                },
              ),
              MenuFlyoutItem(
                text: Text('AGE'),
                onPressed: () {
                  ref.read(appStoreProvider.notifier).setSource('agefans');
                },
              ),
            ],
          ),
        ),
        SizedBox(width: 8.sp),
        Tooltip(
          message: '刷新',
          child: IconButton(
            icon: Icon(FluentIcons.refresh),
            onPressed: () {
              _client.getToday().then((value) {
                calendarData = value;
                _tabIndex = _today;
                setState(() {});
              });
            },
          ),
        ),
        SizedBox(width: 8.sp),
      ],
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
            body: CalendarDayBangumi(data: item),
            semanticLabel: item.weekday.cn,
          ),
      ],
      header: Row(
        children: [
          Tooltip(
            message: '数据来源于 bangumi.tv',
            child: Icon(FluentIcons.info),
          ),
          Text(calendarData[_today].weekday.cn),
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

  @override
  Widget build(BuildContext context) {
    if (calendarData.isNotEmpty) {
      return _buildCalendar();
    }
    return Center(child: ProgressRing());
  }
}

/// 今日放送-单日-bangumi数据源
class CalendarDayBangumi extends StatelessWidget {
  /// 数据
  final CalendarItem data;

  /// 构造函数
  const CalendarDayBangumi({super.key, required this.data});

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
        children: data.items
            .map(
              (e) => CalendarCardBangumi(data: e),
            )
            .toList(),
      ),
    );
  }
}

/// 今日放送-单番剧-bangumi数据源
class CalendarCardBangumi extends StatelessWidget {
  /// 数据
  final CalendarItemBangumi data;

  /// 构造函数
  const CalendarCardBangumi({super.key, required this.data});

  /// 构建封面
  Widget buildCover(BuildContext context) {
    if (data.images == null ||
        data.images?.large == null ||
        data.images?.large == '') {
      return Icon(FluentIcons.photo_error);
    }
    return CachedNetworkImage(
      imageUrl: data.images!.large,
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, dp) => Center(
        child: ProgressRing(
          value: dp.progress == null ? 0 : dp.progress! * 100,
        ),
      ),
      errorWidget: (context, url, error) => Icon(FluentIcons.error),
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

  /// 构建交互
  Widget buildAction(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Tooltip(
          message: data.url,
          child: IconButton(
            icon: Icon(FluentIcons.edge_logo),
            onPressed: () async {
              if (await canLaunchUrlString(data.url)) {
                await launchUrlString(data.url);
              } else {
                throw 'Could not launch ${data.url}';
              }
            },
          ),
        ),
      ],
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
            message: data.nameCn == '' ? data.name : data.nameCn,
            child: Text(
              data.nameCn == '' ? data.name : data.nameCn,
              maxLines: 1,
              style: FluentTheme.of(context).typography.subtitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          buildAction(context),
        ],
      ),
    );
  }

  /// 构建番剧项
  @override
  Widget build(BuildContext context) {
    // stack 布局，由底到上分别是封面、渐变层、番剧信息及操作按钮
    return Stack(
      children: [
        Positioned.fill(child: buildCover(context)),
        Positioned.fill(child: buildGradient(context)),
        Positioned(bottom: 0, left: 0, right: 0, child: buildItemInfo(context)),
      ],
    );
  }
}
