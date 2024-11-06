// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../database/app/app_bmf.dart';
import '../../database/app/app_rss.dart';
import '../../models/database/app_bmf_model.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/subject_detail/bsd_bmf.dart';

/// BMF 配置页面
class BmfPage extends StatefulWidget {
  /// 构造函数
  const BmfPage({super.key});

  @override
  State<BmfPage> createState() => _BmfPageState();
}

/// BMF 配置页面状态
class _BmfPageState extends State<BmfPage> with AutomaticKeepAliveClientMixin {
  /// Bmf 数据库
  final BtsAppBmf sqlite = BtsAppBmf();

  /// rss 数据库
  final BtsAppRss rss = BtsAppRss();

  /// Bmf 数据，只包括subject
  List<AppBmfModel> bmfList = [];

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await preCheck();
      await init();
    });
  }

  /// 销毁
  @override
  void dispose() {
    super.dispose();
  }

  /// 前置检查，删除未使用的rss
  Future<void> preCheck() async {
    var read = await sqlite.readAll();
    var rssList = await rss.readAllRss();
    for (var item in read) {
      if (item.rss != null && item.rss!.isNotEmpty) {
        rssList.remove(item.rss);
      }
    }
    var cnt = rssList.length;
    for (var item in rssList) {
      await rss.delete(item);
    }
    if (cnt > 0 && mounted) {
      await BtInfobar.warn(context, '删除了 $cnt 条未使用的RSS');
    }
  }

  /// 初始化
  Future<void> init() async {
    bmfList.clear();
    setState(() {});
    bmfList = await sqlite.readAll();
    setState(() {});
  }

  /// 构建头部
  Widget buildHeader(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/images/logo.png', height: 28, width: 28),
        SizedBox(width: 4),
        Text('BMF配置', style: FluentTheme.of(context).typography.title),
        const Spacer(),
        IconButton(
          icon: const Icon(FluentIcons.refresh),
          onPressed: () async {
            await init();
            if (context.mounted) await BtInfobar.success(context, '刷新成功');
          },
        ),
      ],
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      header: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        child: buildHeader(context),
      ),
      content: ListView.separated(
        itemBuilder: (_, i) => BsdBmfWidget(
          bmfList[i].subject,
          bmfList[i].title ?? '',
          isConfig: true,
        ),
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemCount: bmfList.length,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      ),
    );
  }
}
