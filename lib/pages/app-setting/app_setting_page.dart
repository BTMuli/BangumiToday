// Dart imports:
import 'dart:io';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import 'as_pw_bangumi.dart';
import 'as_pw_device.dart';
import 'as_pw_download.dart';
import 'as_pw_info.dart';

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
      if (mounted) setState(() {});
    });
  }

  /// 构建页面头部
  Widget buildPageHeader(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Row(
      children: [
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accent.darker],
            ),
            borderRadius: BTRadius.largeBR,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            FluentIcons.settings,
            color: Colors.white,
            size: 22,
          ),
        ),
        SizedBox(width: 14.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '应用设置',
              style: BTTypography.title(context).copyWith(fontSize: 20.sp),
            ),
            SizedBox(height: 2.h),
            Text('配置应用、下载引擎与 Bangumi 账号', style: BTTypography.caption(context)),
          ],
        ),
      ],
    );
  }

  /// 构建应用徽章
  Widget buildAppBadge(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return SizedBox(
      width: 280.w,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, accent.darker],
          ),
          borderRadius: BTRadius.largeBR,
          boxShadow: BTTheme.shadow(context, level: BTShadowLevel.medium),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BTRadius.mediumBR,
                  ),
                  child: Image.asset('assets/images/logo.png'),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BangumiToday',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'v${packageInfo?.version ?? '0.0.0'}'
                        '+${packageInfo?.buildNumber ?? ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              '番剧时间表、RSS 订阅与下载管理',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Button(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(
                  Colors.white.withValues(alpha: 0.12),
                ),
                foregroundColor: WidgetStatePropertyAll(Colors.white),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BTRadius.mediumBR),
                ),
              ),
              onPressed: () async {
                await launchUrlString('https://github.com/BTMuli/BangumiToday');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.link, size: 14),
                  SizedBox(width: 6.w),
                  const Text('GitHub 仓库'),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              '©2024 BTMuli <bt-muli@outlook.com>',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建配置项
  List<Widget> buildConfigList() {
    return [
      AspInfoWidget(),
      if (Platform.isWindows) AppConfigDownloadWidget(),
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
      padding: EdgeInsets.all(16.w),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildPageHeader(context),
          SizedBox(height: 16.h),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                var list = ListView.separated(
                  itemBuilder: (_, int idx) => configList[idx],
                  separatorBuilder: (_, _) => SizedBox(height: 12.h),
                  itemCount: configList.length,
                );
                // 窗口较窄时隐藏右侧应用徽章，避免挤压设置列表
                if (constraints.maxWidth < 1000) return list;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: list),
                    SizedBox(width: 16.w),
                    buildAppBadge(context),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
