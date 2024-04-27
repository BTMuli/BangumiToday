// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../components/app/app_infobar.dart';
import '../../components/bangumi/subject_detail/bsd_bmf.dart';
import '../../database/app/app_bmf.dart';

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

  /// Bmf 数据，只包括subject
  List<int> bmfList = [];

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await init();
    });
  }

  /// 销毁
  @override
  void dispose() {
    super.dispose();
  }

  /// 初始化
  Future<void> init() async {
    bmfList = [];
    setState(() {});
    var read = await sqlite.readAll();
    var list = read.map((e) => e.subject).toList();
    bmfList = list;
    setState(() {});
  }

  /// 构建头部
  Widget buildHeader(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 16.w),
        Image.asset('assets/images/logo.png', height: 40),
        SizedBox(width: 16.w),
        Text('BMF配置', style: FluentTheme.of(context).typography.title),
        const Spacer(),
        IconButton(
          icon: const Icon(FluentIcons.refresh),
          onPressed: () async {
            await init();
            if (context.mounted) await BtInfobar.success(context, '刷新成功');
          },
        ),
        SizedBox(width: 16.w),
      ],
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      header: buildHeader(context),
      content: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        children: [
          for (var item in bmfList) ...[
            BsdBmf(item, isConfig: true),
            SizedBox(height: 16.h)
          ]
        ],
      ),
    );
  }
}
