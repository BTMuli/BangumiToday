import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../database/bangumi/bangumi_data.dart';
import '../../models/bangumi/data_meta.dart';
import '../../models/bangumi/get_calendar.dart';
import '../../request/core/bangumi_data.dart';
import '../app/app_dialog.dart';
import '../app/app_progress.dart';
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

  /// 刷新BangumiData
  Future<void> refreshBangumiData(BuildContext context) async {
    var sqlite = BtsBangumiData();
    var client = BTBangumiData();
    var progress = AppProgress(
      context,
      title: '开始获取数据',
      text: '正在请求BangumiData',
      progress: null,
    );
    progress.start();
    var rawData = await client.getBangumiData();
    progress.update(title: '成功获取数据', text: '正在写入数据');
    var cnt, total;
    var sites = [];
    for (var entry in rawData.siteMeta.entries) {
      sites.add(BangumiDataSiteFull.fromSite(entry.key, entry.value));
    }
    total = sites.length;
    cnt = 0;
    for (var site in sites) {
      progress.update(
        title: '写入站点数据 $cnt/$total',
        text: site.title,
        progress: (cnt / total) * 100,
      );
      await sqlite.writeSite(site);
      cnt++;
      await Future.delayed(Duration(milliseconds: 200));
    }
    var items = rawData.items;
    total = items.length;
    cnt = 0;
    for (var item in items) {
      progress.update(
        title: '写入条目数据 $cnt/$total',
        text: item.title,
        progress: (cnt / total) * 100,
      );
      await sqlite.writeItem(item);
      cnt++;
    }
    progress.update(text: '写入完成');
    await Future.delayed(Duration(seconds: 1));
    progress.end();
  }

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

  /// 构建数据库按钮
  Widget buildDataBaseButton(BuildContext context) {
    return Tooltip(
      message: '数据库',
      child: IconButton(
        icon: Icon(FluentIcons.database_source),
        onPressed: () async {
          var confirm = false;
          await showConfirmDialog(
            context,
            title: 'BangumiData',
            content: '是否更新BangumiData？',
            onSubmit: () {
              confirm = true;
            },
          );
          if (confirm) await refreshBangumiData(context);
        },
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
        buildDataBaseButton(context),
        SizedBox(width: 16.w),
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
