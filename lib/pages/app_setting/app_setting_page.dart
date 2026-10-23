// Dart imports:
import 'dart:io';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../core/theme/bt_theme.dart';
import '../../request/app_update_api.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/bt_content_frame.dart';
import 'app_setting_bangumi.dart';
import 'app_setting_device.dart';
import 'app_setting_download.dart';
import 'app_setting_info.dart';
import 'app_setting_network.dart';
import 'app_setting_playback.dart';

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

  bool _checkingUpdate = false;

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

  Future<void> _openBadgeLink(String url) async {
    try {
      if (!await launchUrlString(url) && mounted) {
        await BtInfobar.error(context, '无法打开链接，请检查默认浏览器设置');
      }
    } catch (error) {
      BTLogTool.warn('打开应用信息链接失败：$error');
      if (mounted) await BtInfobar.error(context, '打开链接失败，请稍后重试');
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      var current = packageInfo ?? await PackageInfo.fromPlatform();
      var response = await BtrAppUpdateApi.getLatestRelease();
      if (!mounted) return;
      packageInfo = current;
      var release = response.data;
      if (response.code != 0 || release == null) {
        await BtInfobar.error(context, response.message);
        return;
      }
      if (!release.isNewerThan(current.version)) {
        await BtInfobar.success(context, '当前 v${current.version} 已是最新版本');
        return;
      }
      var openRelease = await showConfirmAction(
        context,
        title: '发现新版本 ${release.tag}',
        content:
            '当前版本：v${current.version}\n'
            '最新版本：${release.tag}\n\n'
            '前往发布页查看更新内容并下载新版。',
        confirmText: '前往下载',
        cancelText: '稍后再说',
      );
      if (openRelease && mounted) await _openBadgeLink(release.url);
    } catch (error) {
      BTLogTool.warn('检测应用更新失败：$error');
      if (mounted) await BtInfobar.error(context, '检测更新失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
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
              '基于 Bangumi 的桌面追番应用，'
              '集放送日历、收藏与进度管理、RSS 订阅、资源下载和本地播放于一体。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildBadgeAction(
                  // ignore: deprecated_member_use
                  icon: MdiIcons.github,
                  label: 'GitHub 仓库',
                  onPressed: () => _openBadgeLink(BTAppConstants.appLink),
                ),
                buildBadgeAction(
                  // ignore: deprecated_member_use
                  icon: MdiIcons.qqchat,
                  label: 'QQ 群',
                  onPressed: () => _openBadgeLink(BTAppConstants.appQqGroup),
                ),
                buildBadgeAction(
                  icon: FluentIcons.globe,
                  label: '官方网站',
                  onPressed: () => _openBadgeLink(BTAppConstants.appWebsite),
                ),
                buildBadgeAction(
                  icon: FluentIcons.sync,
                  label: _checkingUpdate ? '正在检测更新…' : '检测更新',
                  onPressed: _checkingUpdate ? null : _checkForUpdates,
                  loading: _checkingUpdate,
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
  Widget buildBadgeAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: 32,
        child: IconButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.isPressed) {
                return Colors.white.withValues(alpha: 0.26);
              }
              if (states.isHovered) {
                return Colors.white.withValues(alpha: 0.2);
              }
              return Colors.white.withValues(alpha: 0.12);
            }),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BTRadius.mediumBR),
            ),
          ),
          onPressed: onPressed,
          icon: loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: ProgressRing(
                    strokeWidth: 2,
                    activeColor: Colors.white,
                  ),
                )
              : Icon(icon, size: 16),
        ),
      ),
    );
  }

  /// 构建配置项
  List<Widget> buildConfigList() {
    return [
      AppConfigInfoWidget(),
      if (Platform.isWindows) AppConfigNetworkWidget(),
      if (Platform.isWindows) AppConfigDownloadWidget(),
      if (Platform.isWindows) AppConfigPlaybackWidget(),
      AppConfigDeviceWidget(),
      AppConfigBgmWidget(),
    ];
  }

  /// 构建设置页面
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var configList = buildConfigList();
    return ScaffoldPage(
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
                    // 右侧留出滚动条槽位，避免滚动条压在设置卡片边缘
                    padding: EdgeInsets.only(right: 12),
                    itemBuilder: (_, int idx) => configList[idx],
                    separatorBuilder: (_, _) => SizedBox(height: 12),
                    itemCount: configList.length,
                  );
                  // 窗口较窄时隐藏右侧应用徽章，避免挤压设置列表
                  if (constraints.maxWidth < 800) return list;
                  // 列表右侧已留出滚动条槽位，无需再与徽章留间距
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: list),
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
