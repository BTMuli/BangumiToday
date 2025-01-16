// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../store/app_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/log_tool.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/get_theme_label.dart';

class AppConfigInfoWidget extends ConsumerStatefulWidget {
  const AppConfigInfoWidget({super.key});

  @override
  ConsumerState<AppConfigInfoWidget> createState() =>
      _AppConfigInfoWidgetState();
}

class _AppConfigInfoWidgetState extends ConsumerState<AppConfigInfoWidget> {
  /// 应用信息
  PackageInfo? packageInfo;

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// logTool
  final BTLogTool logTool = BTLogTool();

  /// 当前主题
  ThemeMode get curThemeMode => ref.watch(appStoreProvider).themeMode;

  /// 当前主题色
  AccentColor get curAccentColor => ref.watch(appStoreProvider).accentColor;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() {});
    });
  }

  /// 构建应用信息
  Widget buildAppInfo() {
    return ListTile(
      leading: Image.asset("assets/images/logo.png", width: 24, height: 24),
      title: Text('BangumiToday'),
      subtitle: Text('版本：${packageInfo?.version}+${packageInfo?.buildNumber}'),
      trailing: IconButton(
        icon: BtIcon(MdiIcons.github),
        onPressed: () async {
          await launchUrlString('https://github.com/BTMuli/BangumiToday');
        },
      ),
    );
  }

  /// 构建主题项
  MenuFlyoutItemBase buildThemeFlyout(ThemeModeConfig theme) {
    return MenuFlyoutItem(
      text: Text(theme.label),
      leading:
          curThemeMode == theme.cur ? BtIcon(theme.icon) : Icon(theme.icon),
      onPressed: () async {
        if (curThemeMode == theme.cur) {
          if (mounted) await BtInfobar.warn(context, '当前主题已经是${theme.label}主题');
          return;
        }
        await ref.read(appStoreProvider.notifier).setThemeMode(theme.cur);
      },
      selected: curThemeMode == theme.cur,
      trailing: curThemeMode == theme.cur ? Icon(MdiIcons.check) : null,
    );
  }

  /// 构建主题信息
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
        curAccentColor.colorValue.toRadixString(16),
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

  /// 构建日志信息
  Widget buildLogInfo() {
    return ListTile(
      leading: const Icon(FluentIcons.folder_search),
      title: const Text('日志信息'),
      subtitle: Text(logTool.logDir),
      trailing: IconButton(
        icon: BtIcon(MdiIcons.folderOpen),
        onPressed: logTool.openLogDir,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expander(
      leading: const Icon(FluentIcons.settings),
      initiallyExpanded: true,
      header: const Text('应用配置'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildAppInfo(),
          buildThemeSwitch(),
          buildColorSwitch(),
          buildLogInfo(),
        ],
      ),
    );
  }
}
