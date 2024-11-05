// Flutter imports:
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart'
    as mdi;

// Package imports:
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../store/app_store.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_icon.dart';
import '../../utils/get_theme_label.dart';
import '../../widgets/config/app_config_bgm.dart';

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

  /// 设备信息
  WindowsDeviceInfo? deviceInfo;

  /// 当前主题
  ThemeMode get curThemeMode => ref.watch(appStoreProvider).themeMode;

  /// 当前主题色
  AccentColor get curAccentColor => ref.watch(appStoreProvider).accentColor;

  /// 保存状态
  @override
  bool get wantKeepAlive => false;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      packageInfo = await PackageInfo.fromPlatform();
      deviceInfo = await DeviceInfoPlugin().windowsInfo;
      setState(() {});
    });
  }

  /// 构建 Windows 设备信息
  Widget buildWinDeviceInfo(WindowsDeviceInfo diw) {
    return Expander(
      leading: Icon(mdi.MdiIcons.laptopAccount),
      header: Text(diw.productName),
      content: Column(
        children: [
          ListTile(
            leading: Icon(mdi.MdiIcons.laptop),
            title: const Text('所在平台'),
            subtitle: Text(
              'Windows ${diw.displayVersion} '
              '${diw.majorVersion}.${diw.minorVersion}.${diw.buildNumber}'
              '(${diw.buildLab})',
            ),
          ),
          ListTile(
            leading: Icon(mdi.MdiIcons.devices),
            title: const Text('设备'),
            subtitle: Text('${diw.computerName} ${diw.productId}'),
          ),
          ListTile(
            leading: Icon(mdi.MdiIcons.identifier),
            title: const Text('标识符'),
            subtitle: Text(
              diw.deviceId.substring(1, diw.deviceId.length - 1),
            ),
          ),
        ],
      ),
    );
  }

  /// 设备信息项
  Widget buildDeviceInfo() {
    if (deviceInfo != null) return buildWinDeviceInfo(deviceInfo!);
    return const ListTile(title: Text('设备信息'), subtitle: Text('未知设备'));
  }

  /// 构建主题项Flyout
  MenuFlyoutItem buildThemeFlyout(ThemeModeConfig theme) {
    return MenuFlyoutItem(
      text: Text(theme.label),
      leading: Icon(theme.icon),
      onPressed: () async {
        await ref.read(appStoreProvider.notifier).setThemeMode(theme.cur);
      },
      selected: curThemeMode == theme.cur,
      trailing:
          curThemeMode == theme.cur ? BtIcon(FluentIcons.check_mark) : null,
    );
  }

  /// 构建主题切换
  Widget buildThemeSwitch() {
    var themes = getThemeModeConfigList();
    var curTheme = getThemeModeConfig(curThemeMode);
    return ListTile(
      leading: Icon(curTheme.icon),
      title: const Text('主题模式'),
      subtitle: Text(curTheme.label),
      trailing: DropDownButton(
        title: Text(curTheme.label),
        items: themes.map(buildThemeFlyout).toList(),
      ),
    );
  }

  /// 构建主题色切换展开
  Widget buildColorFlyout(AccentColor color) {
    return Button(
      autofocus: curAccentColor == color,
      style: ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsets.zero)),
      onPressed: () async {
        await ref.read(appStoreProvider.notifier).setAccentColor(color);
        if (mounted) Navigator.of(context).pop();
      },
      child: SizedBox(
        width: 32.spMax,
        height: 32.spMax,
        child: ColoredBox(color: color),
      ),
    );
  }

  /// 构建主题色切换
  Widget buildColorSwitch() {
    return ListTile(
      leading: const Icon(FluentIcons.color),
      title: const Text('主题色'),
      subtitle: Text(
        curAccentColor.value.toRadixString(16),
        style: TextStyle(color: curAccentColor),
      ),
      trailing: SplitButton(
        flyout: FlyoutContent(
          constraints: BoxConstraints(maxWidth: 200.w),
          child: curThemeMode == ThemeMode.system
              ? const Text('跟随系统设置\r\n无法更改')
              : Wrap(
                  runSpacing: 8.h,
                  spacing: 8.w,
                  children: Colors.accentColors.map(buildColorFlyout).toList(),
                ),
        ),
        child: SizedBox(
          width: 32.spMax,
          height: 32.spMax,
          child: ColoredBox(color: curAccentColor),
        ),
      ),
    );
  }

  /// 构建应用徽章
  Widget buildAppBadge(BuildContext context) {
    var shadow = const Shadow(
      color: Colors.black,
      offset: Offset(1, 1),
      blurRadius: 2,
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: curAccentColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HyperlinkButton(
            child: Image.asset('assets/images/logo.png', width: 100.w),
            onPressed: () {
              launchUrlString('https://github.com/BTMuli/BangumiToday');
            },
          ),
          Text(
            'BangumiToday',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [shadow],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Version: ${packageInfo?.version} '
            'Build: ${packageInfo?.buildNumber}',
            style: TextStyle(color: Colors.white, shadows: [shadow]),
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

  /// 构建应用信息
  Widget buildAppInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        buildAppBadge(context),
        SizedBox(height: 16.h),
        Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tooltip(
              message: 'Github',
              child: Button(
                onPressed: () async {
                  await launchUrlString(
                      'https://github.com/BTMuli/BangumiToday');
                },
                child: BtIcon(mdi.MdiIcons.github),
              ),
            ),
            SizedBox(width: 16.w),
            Tooltip(
              message: '日志',
              child: Button(
                onPressed: BTLogTool().openLogDir,
                child: BtIcon(mdi.MdiIcons.faceAgent),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建应用配置
  Widget buildAppConfig() {
    return Expander(
      leading: const Icon(FluentIcons.settings),
      header: const Text('应用配置'),
      content: Column(children: [buildThemeSwitch(), buildColorSwitch()]),
    );
  }

  /// 构建配置项
  List<Widget> buildConfigList() {
    return [
      buildDeviceInfo(),
      buildAppConfig(),
      AppConfigBgmWidget(),
    ];
  }

  /// 构建设置页面
  @override
  Widget build(BuildContext context) {
    super.build(context);
    var configList = buildConfigList();
    return ScaffoldPage.withPadding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: ListView.separated(
                itemBuilder: (_, int idx) => configList[idx],
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemCount: configList.length),
          ),
          SizedBox(width: 12.w),
          buildAppInfo(),
        ],
      ),
    );
  }
}
