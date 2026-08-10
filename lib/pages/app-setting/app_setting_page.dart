// Dart imports:
import 'dart:io';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../widgets/common/bt_content_frame.dart';
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
          width: 44,
          height: 44,
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
        SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '应用设置',
              style: BTTypography.title(context).copyWith(fontSize: 20),
            ),
            SizedBox(height: 2),
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
      width: 280,
      child: Container(
        padding: EdgeInsets.all(20),
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
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Image.asset('assets/images/logo.png'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BangumiToday',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'v${packageInfo?.version ?? '0.0.0'}'
                        '+${packageInfo?.buildNumber ?? ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              '基于 Bangumi.tv 与蜜柑计划的番剧应用，'
              '结合本地目录提供番剧更新提醒、RSS 订阅与下载、进度记录等功能。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                buildBadgeAction(
                  context,
                  // ignore: deprecated_member_use
                  icon: MdiIcons.github,
                  label: 'GitHub 仓库',
                  url: 'https://github.com/BTMuli/BangumiToday',
                ),
                SizedBox(width: 8),
                buildBadgeAction(
                  context,
                  // ignore: deprecated_member_use
                  icon: MdiIcons.qqchat,
                  label: 'QQ 群',
                  url: 'https://qm.qq.com/q/hUxIfSWluo',
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              '©2024 BTMuli <bt-muli@outlook.com>',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建应用徽章操作按钮
  Widget buildBadgeAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String url,
  }) {
    return Expanded(
      child: Button(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.12),
          ),
          foregroundColor: WidgetStatePropertyAll(Colors.white),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BTRadius.mediumBR),
          ),
        ),
        onPressed: () async {
          await launchUrlString(url);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
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
      padding: EdgeInsets.all(16),
      content: BTContentFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildPageHeader(context),
            SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  var list = ListView.separated(
                    itemBuilder: (_, int idx) => configList[idx],
                    separatorBuilder: (_, _) => SizedBox(height: 12),
                    itemCount: configList.length,
                  );
                  // 窗口较窄时隐藏右侧应用徽章，避免挤压设置列表
                  if (constraints.maxWidth < 800) return list;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: list),
                      SizedBox(width: 16),
                      buildAppBadge(context),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
