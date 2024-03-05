import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/bangumi/get_calendar.dart';

/// 侧边栏-今日放送-单日
class NavCalendarDay extends StatelessWidget {
  /// 数据
  final CalendarItem data;

  /// 构造函数
  const NavCalendarDay({Key? key, required this.data}) : super(key: key);

  /// 构建番剧标题
  Widget buildItemTitle(BuildContext context, CalendarItemBangumi item) {
    return Padding(
      padding: EdgeInsets.all(4.sp),
      child: Text(
        item.nameCn == '' ? item.name : item.nameCn,
        style: FluentTheme.of(context).typography.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建番剧信息
  Widget buildItemInfo(BuildContext context, CalendarItemBangumi item) {
    return Padding(
      padding: EdgeInsets.all(12.sp),
      child: Text(
        item.name,
        style: FluentTheme.of(context).typography.caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建操作按钮
  Widget buildActionButtons(BuildContext context, CalendarItemBangumi item) {
    return Padding(
      padding: EdgeInsets.all(12.sp),
      child: Row(
        children: [
          Expanded(
            child: IconButton(
              icon: Icon(FluentIcons.play),
              onPressed: () {},
            ),
          ),
          Expanded(
            child: IconButton(
              icon: Icon(FluentIcons.add),
              onPressed: () {
                debugPrint(item.toJson().toString());
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建番剧条目
  Widget buildBangumiItem(BuildContext context, CalendarItemBangumi item) {
    var decoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4.sp),
      boxShadow: kElevationToShadow[1],
    );
    if (item.images?.large != null) {
      decoration = decoration.copyWith(
        image: DecorationImage(
          image: NetworkImage(item.images!.large),
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      padding: EdgeInsets.zero,
      decoration: decoration,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(4.sp),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            buildItemTitle(context, item),
            buildItemInfo(context, item),
            buildActionButtons(context, item),
          ],
        ),
      ),
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: GridView(
        controller: ScrollController(),
        padding: EdgeInsets.all(12.sp),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12.sp,
          mainAxisSpacing: 12.sp,
          childAspectRatio: 4 / 3,
        ),
        children: data.items.map((e) => buildBangumiItem(context, e)).toList(),
      ),
    );
  }
}
