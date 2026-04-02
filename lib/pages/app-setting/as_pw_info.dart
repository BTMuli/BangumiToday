// Package imports:
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../controller/app/progress_controller.dart';
import '../../core/cache/cache_manager.dart';
import '../../core/cache/lru_cache_manager.dart';
import '../../store/app_store.dart';
import '../../tools/download_tool.dart';
import '../../tools/file_tool.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/get_theme_label.dart';

class AspInfoWidget extends ConsumerStatefulWidget {
  const AspInfoWidget({super.key});

  @override
  ConsumerState<AspInfoWidget> createState() => _AspInfoWidgetState();
}

class _AspInfoWidgetState extends ConsumerState<AspInfoWidget> {
  /// 应用信息
  PackageInfo? packageInfo;

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// logTool
  final BTLogTool logTool = BTLogTool();

  late ProgressController progress = ProgressController();

  /// 当前主题
  ThemeMode get curThemeMode => ref.watch(appStoreProvider).themeMode;

  /// 当前主题色
  AccentColor get curAccentColor => ref.watch(appStoreProvider).accentColor;

  /// 缓存大小
  int _cacheSize = 0;

  /// 是否正在计算缓存
  bool _calculatingCache = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() {});
    });
    _calculateCacheSize();
  }

  /// 计算缓存大小
  Future<void> _calculateCacheSize() async {
    if (_calculatingCache) return;
    _calculatingCache = true;
    var downloadDir = BTDownloadTool.downloadDir;

    var downloadSize = await fileTool.getDirSize(downloadDir);
    var cacheSize = BTCacheManager.instance.diskCacheSize;
    var lruSize = LRUCacheManager.instance.diskCacheSize;
    var imageSize = await _getImageCacheSize();

    if (mounted) {
      setState(() {
        _cacheSize = downloadSize + cacheSize + lruSize + imageSize;
        _calculatingCache = false;
      });
    }
  }

  /// 获取图片缓存大小
  Future<int> _getImageCacheSize() async {
    try {
      var tempDir = await getTemporaryDirectory();
      var cacheDir = Directory('${tempDir.path}/libCachedImageData');
      if (await cacheDir.exists()) {
        return await fileTool.getDirSize(cacheDir.path);
      }
    } catch (_) {}
    return 0;
  }

  /// 删除文件
  Future<void> deleteFiles(
    String dir,
    List<String> files,
    BuildContext context,
  ) async {
    var total = files.length;
    var cnt = 0;
    if (progress.isShow) {
      progress.update(title: '正在删除文件', text: '已删除 $cnt / $total 个文件');
    } else {
      progress = ProgressWidget.show(
        context,
        title: '正在删除文件',
        text: '已删除 $cnt / $total 个文件',
      );
    }
    for (var file in files) {
      await fileTool.deleteFile('$dir/$file');
      cnt++;
      progress.update(text: '已删除 $cnt / $total 个文件');
    }
    progress.end();
    if (context.mounted) await BtInfobar.success(context, '已成功删除 $total 个文件');
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
      leading: curThemeMode == theme.cur
          ? BtIcon(theme.icon)
          : Icon(theme.icon),
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
      subtitle: Text(BTLogTool.logDir),
      trailing: IconButton(
        icon: BtIcon(MdiIcons.folderOpen),
        onPressed: logTool.openLogDir,
      ),
    );
  }

  /// 构建bt下载目录
  Widget buildDownloadInfo() {
    return ListTile(
      leading: const Icon(FluentIcons.download),
      title: const Text('下载目录'),
      subtitle: Text(BTDownloadTool.downloadDir),
      trailing: Row(
        children: [
          IconButton(
            icon: BtIcon(FluentIcons.delete),
            onPressed: () async {
              var files = await fileTool.getFileNames(
                BTDownloadTool.downloadDir,
              );
              if (files.isEmpty) {
                if (mounted) await BtInfobar.info(context, '下载目录为空，无需清理');
                return;
              }
              var len = files.length;
              if (mounted) {
                var check = await showConfirm(
                  context,
                  title: '清理下载目录',
                  content: '下载目录下共有 $len 个文件，是否确认清理？',
                );
                if (!check || !mounted) return;
                await deleteFiles(BTDownloadTool.downloadDir, files, context);
              }
            },
          ),
          IconButton(
            icon: BtIcon(MdiIcons.folderOpen),
            onPressed: BTDownloadTool.openDownloadDir,
          ),
        ],
      ),
    );
  }

  /// 构建缓存信息
  Widget buildCacheInfo() {
    return ListTile(
      leading: const Icon(FluentIcons.broom),
      title: const Text('缓存管理'),
      subtitle: Text(
        _calculatingCache
            ? '正在计算缓存大小...'
            : '缓存大小：${BTFileTool.formatSize(_cacheSize)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: BtIcon(FluentIcons.refresh),
            onPressed: _calculatingCache ? null : _calculateCacheSize,
          ),
          IconButton(
            icon: BtIcon(FluentIcons.delete),
            onPressed: _cacheSize == 0 ? null : _clearCache,
          ),
        ],
      ),
    );
  }

  /// 清除缓存
  Future<void> _clearCache() async {
    var check = await showConfirm(
      context,
      title: '清除缓存',
      content: '确定要清除缓存吗？\n这将清除：\n• 应用数据缓存\n• 图片缓存\n• 下载文件',
    );
    if (!check || !mounted) return;

    if (progress.isShow) {
      progress.update(title: '正在清除缓存', text: '正在清除缓存...');
    } else {
      progress = ProgressWidget.show(
        context,
        title: '正在清除缓存',
        text: '正在清除缓存...',
      );
    }

    try {
      await BTCacheManager.instance.clear();
      progress.update(text: '已清除应用缓存');

      await LRUCacheManager.instance.clear();
      progress.update(text: '已清除 LRU 缓存');

      await DefaultCacheManager().emptyCache();
      progress.update(text: '已清除图片缓存');

      await fileTool.clearDir(BTDownloadTool.downloadDir);
      progress.update(text: '已清除下载文件');

      progress.end();
      await _calculateCacheSize();
      if (mounted) await BtInfobar.success(context, '缓存已清除');
    } catch (e) {
      progress.end();
      if (mounted) await BtInfobar.error(context, '清除缓存失败：$e');
    }
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
          buildCacheInfo(),
          buildLogInfo(),
          buildDownloadInfo(),
        ],
      ),
    );
  }
}
