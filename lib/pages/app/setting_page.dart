// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import '../../widgets/app/config/app_config_bgm.dart';
import '../../widgets/app/config/app_config_device.dart';
import '../../widgets/app/config/app_config_info.dart';

/// 设置页面
class SettingPage extends ConsumerStatefulWidget {
  /// 构造函数
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

/// 设置页面状态
class _SettingPageState extends ConsumerState<SettingPage>
    with AutomaticKeepAliveClientMixin {
  /// 应用信息
  PackageInfo? packageInfo;

  /// 保存状态
  @override
  bool get wantKeepAlive => false;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      packageInfo = await PackageInfo.fromPlatform();
      setState(() {});
    });
  }

  /// 构建应用徽章
  Widget buildAppBadge(BuildContext context) {
    var shadow = const Shadow(
      color: Colors.black,
      offset: Offset(1, 1),
      blurRadius: 2,
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: FluentTheme.of(context).accentColor,
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.png', width: 100.w),
          Text(
            'BangumiToday '
            '${packageInfo?.version ?? '0.0.0'}'
            '+${packageInfo?.buildNumber ?? ''}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [shadow],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '©2024 BTMuli<bt-muli@outlook.com>',
            style: TextStyle(color: Colors.white, shadows: [shadow]),
          ),
        ],
      ),
    );
  }

  /// 构建配置项
  List<Widget> buildConfigList() {
    return [
      AppConfigInfoWidget(),
      AppConfigDeviceWidget(),
      AppConfigBgmWidget(),
    ];
  }

  /// 构建设置页面
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var configList = buildConfigList();
    return ScaffoldPage.withPadding(
      padding: EdgeInsets.all(8),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: ListView.separated(
              itemBuilder: (_, int idx) => configList[idx],
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemCount: configList.length,
            ),
          ),
          const SizedBox(width: 12),
          buildAppBadge(context),
        ],
      ),
    );
  }
}
