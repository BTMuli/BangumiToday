// Flutter imports:
import 'package:flutter/material.dart' as material;

// Package imports:
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../components/app/app_infobar.dart';
import '../../store/app_store.dart';
import '../../tools/log_tool.dart';
import '../../tools/scheme_tool.dart';
import '../../utils/get_theme_label.dart';

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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Expander(
        leading: const Icon(material.Icons.laptop_windows),
        header: Text(diw.productName),
        content: Column(
          children: [
            ListTile(
              leading: const Icon(material.Icons.desktop_windows_outlined),
              title: const Text('所在平台'),
              subtitle: Text(
                'Windows ${diw.displayVersion} '
                '${diw.majorVersion}.${diw.minorVersion}.${diw.buildNumber}'
                '(${diw.buildLab})',
              ),
            ),
            ListTile(
              leading: const Icon(material.Icons.devices_outlined),
              title: const Text('设备'),
              subtitle: Text('${diw.computerName} ${diw.productId}'),
            ),
            ListTile(
              leading: const Icon(material.Icons.device_hub_outlined),
              title: const Text('标识符'),
              subtitle: Text(
                diw.deviceId.substring(1, diw.deviceId.length - 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 设备信息项
  Widget buildDeviceInfo() {
    if (deviceInfo != null) {
      return buildWinDeviceInfo(deviceInfo!);
    }
    return const ListTile(
      title: Text('设备信息'),
      subtitle: Text('未知设备'),
    );
  }

  /// 构建主题切换
  Widget buildThemeSwitch() {
    var themes = getThemeModeConfigList();
    var curTheme = getThemeModeConfig(curThemeMode);
    return ListTile(
      leading: Icon(curTheme.icon),
      title: const Text('主题模式'),
      subtitle: Text(curThemeMode.toString()),
      trailing: DropDownButton(
        title: Text(curTheme.label),
        items: [
          for (var theme in themes)
            MenuFlyoutItem(
              text: Text(theme.label),
              leading: Icon(theme.icon),
              onPressed: () {
                ref.read(appStoreProvider.notifier).setThemeMode(theme.cur);
              },
            )
        ],
      ),
    );
  }

  /// 构建主题色切换展开
  Widget buildColorFlyout() {
    if (curThemeMode == ThemeMode.system) {
      return const Text('跟随系统设置\r\n无法更改');
    }
    return Wrap(
      runSpacing: 8.h,
      spacing: 8.w,
      children: [
        for (var color in Colors.accentColors)
          Button(
            autofocus: curAccentColor == color,
            style: ButtonStyle(
              padding: ButtonState.all(
                EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 4.h,
                ),
              ),
            ),
            onPressed: () {
              ref.read(appStoreProvider.notifier).setAccentColor(color);
              Navigator.of(context).pop();
            },
            child: Container(
              width: 32.w,
              height: 32.h,
              color: color,
            ),
          )
      ],
    );
  }

  /// 构建主题色切换
  Widget buildColorSwitch() {
    return ListTile(
      leading: const Icon(FluentIcons.color),
      title: const Text('主题色'),
      subtitle: Text(curAccentColor.toString()),
      trailing: SplitButton(
        flyout: FlyoutContent(
          constraints: BoxConstraints(maxWidth: 200.w),
          child: buildColorFlyout(),
        ),
        child: Container(
          decoration: BoxDecoration(color: curAccentColor),
          width: 32.w,
          height: 32.h,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        buildAppBadge(context),
        SizedBox(height: 16.h),
        Row(
          children: [
            Button(
              child: Row(
                children: [
                  const Icon(FluentIcons.info),
                  SizedBox(width: 4.w),
                  const Text('Github'),
                ],
              ),
              onPressed: () async {
                await launchUrlString('https://github.com/BTMuli/BangumiToday');
              },
            ),
            SizedBox(width: 8.w),
            Button(
              child: Row(
                children: [
                  const Icon(FluentIcons.mail),
                  SizedBox(width: 4.w),
                  const Text('Email'),
                ],
              ),
              onPressed: () async {
                await launchUrlString('mailto:bt-muli@outlook.com');
              },
            ),
            SizedBox(width: 8.w),
            Button(
              child: Row(
                children: [
                  const Icon(FluentIcons.folder),
                  SizedBox(width: 4.w),
                  const Text('Log'),
                ],
              ),
              onPressed: () async {
                await BTLogTool().openLogDir();
              },
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Button(
              child: const Text('测试 Protocol'),
              onPressed: () async {
                await launchUrlString("BangumiToday://test");
                if (mounted) await BTSchemeTool().test(context);
              },
            ),
            SizedBox(width: 8.w),
            Button(
              child: const Text('添加 Protocol'),
              onPressed: () async {
                await BTSchemeTool().init();
                if (mounted) await BtInfobar.success(context, '添加成功');
              },
            ),
          ],
        )
      ],
    );
  }

  /// 构建配置项
  List<Widget> buildConfigList() {
    return [
      buildDeviceInfo(),
      buildThemeSwitch(),
      buildColorSwitch(),
    ];
  }

  /// 构建设置页面
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(child: ListView(children: buildConfigList())),
          SizedBox(width: 16.w),
          buildAppInfo(),
          SizedBox(width: 16.w),
        ],
      ),
    );
  }
}
