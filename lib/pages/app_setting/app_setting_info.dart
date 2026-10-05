// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/progress_controller.dart';
import '../../core/cache/cache_manager.dart';
import '../../core/services/download_service.dart';
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/get_theme_label.dart';
import '../../models/app/rss_selection_behavior.dart';
import '../../store/app_store.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/bt_buttons.dart';
import '../../widgets/common/bt_setting_section.dart';

class AppConfigInfoWidget extends ConsumerStatefulWidget {
  const AppConfigInfoWidget({super.key});

  @override
  ConsumerState<AppConfigInfoWidget> createState() =>
      _AppConfigInfoWidgetState();
}

class _AppConfigInfoWidgetState extends ConsumerState<AppConfigInfoWidget> {
  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// logTool
  final BTLogTool logTool = BTLogTool();

  late ProgressController progress = ProgressController();

  /// 当前主题
  ThemeMode get curThemeMode => ref.watch(appStoreProvider).themeMode;

  /// 当前主题色
  AccentColor get curAccentColor =>
      ref.watch(appStoreProvider).effectiveAccentColor;

  /// 关闭主窗口后是否隐藏到托盘
  bool get minimizeToTray => ref.watch(appStoreProvider).minimizeToTray;

  /// 缓存大小
  int _cacheSize = 0;

  /// 图片缓存大小
  int _imageCacheSize = 0;

  /// 是否正在计算缓存
  bool _calculatingCache = false;

  /// 是否正在确认或清除缓存
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  /// 计算缓存大小
  Future<void> _calculateCacheSize() async {
    if (_calculatingCache || !mounted) return;
    setState(() => _calculatingCache = true);
    try {
      var downloadSize = await fileTool.getDirSize(BTDownloadTool.downloadDir);
      var cacheSize = await BTCacheManager.instance.getDiskCacheBytes();
      var imageSize = await _getImageCacheSize();

      if (mounted) {
        setState(() {
          _cacheSize = downloadSize + cacheSize + imageSize;
          _imageCacheSize = imageSize;
        });
      }
    } catch (e) {
      BTLogTool.warn('计算缓存大小失败：$e');
    } finally {
      if (mounted) setState(() => _calculatingCache = false);
    }
  }

  /// 获取图片缓存大小
  Future<int> _getImageCacheSize() async {
    return DefaultCacheManager().store.getCacheSize();
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

  /// 构建主题模式切换按钮组
  Widget buildThemeToggle() {
    var themes = getThemeModeConfigList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('主题模式', style: BTTypography.bodyStrong(context)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var theme in themes)
              ToggleButton(
                checked: curThemeMode == theme.cur,
                onChanged: (v) async {
                  if (!v) return;
                  await ref
                      .read(appStoreProvider.notifier)
                      .setThemeMode(theme.cur);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(theme.icon, size: 14),
                      SizedBox(width: 6),
                      Text(theme.label),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 构建主题色切换按钮组
  Widget buildColorToggle() {
    var currentColorValue = curAccentColor.colorValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('主题色', style: BTTypography.bodyStrong(context)),
        SizedBox(height: 8),
        if (curThemeMode == ThemeMode.system)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('跟随系统设置，无法更改主题色', style: BTTypography.caption(context)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var color in Colors.accentColors)
                ToggleButton(
                  checked: currentColorValue == color.colorValue,
                  onChanged: (v) async {
                    if (!v) return;
                    await ref
                        .read(appStoreProvider.notifier)
                        .setAccentColor(color);
                  },
                  style: ToggleButtonThemeData(
                    checkedButtonStyle: ButtonStyle(
                      padding: WidgetStatePropertyAll(EdgeInsets.zero),
                    ),
                    uncheckedButtonStyle: ButtonStyle(
                      padding: WidgetStatePropertyAll(EdgeInsets.zero),
                    ),
                  ),
                  child: Tooltip(
                    message:
                        '#${color.colorValue.toRadixString(16).toUpperCase()}',
                    child: SizedBox.square(
                      dimension: 32,
                      child: ColoredBox(
                        color: currentColorValue == color.colorValue
                            ? color
                            : color.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// 构建主题配置行（主题模式与主题色同一行）
  Widget buildThemeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: buildThemeToggle()),
        SizedBox(width: 24),
        Expanded(child: buildColorToggle()),
      ],
    );
  }

  /// 构建关闭后最小化到托盘配置
  Widget buildMinimizeToTrayInfo() {
    return ListTile(
      leading: const BtIcon(FluentIcons.system),
      title: const Text('关闭后最小化到托盘'),
      subtitle: const Text('关闭主窗口时继续在后台运行，可从托盘菜单退出应用'),
      trailing: ToggleSwitch(
        checked: minimizeToTray,
        onChanged: (value) async {
          await ref.read(appStoreProvider.notifier).setMinimizeToTray(value);
        },
      ),
    );
  }

  Widget buildRssSelectionBehaviorInfo() {
    var behavior = ref.watch(appStoreProvider).rssSelectionBehavior;
    return ListTile(
      leading: const BtIcon(MdiIcons.rss),
      title: const Text('搜索 RSS 默认行为'),
      subtitle: const Text('替换：只保留选中的源；新增：保留已有源并添加'),
      trailing: BTSegmentedControl(
        selectedIndex: behavior.index,
        options: [for (var value in RssSelectionBehavior.values) value.label],
        onChanged: (index) async {
          await ref
              .read(appStoreProvider.notifier)
              .setRssSelectionBehavior(RssSelectionBehavior.values[index]);
        },
      ),
    );
  }

  /// 构建日志信息
  Widget buildLogInfo() {
    return ListTile(
      leading: const BtIcon(FluentIcons.folder_search),
      title: const Text('日志信息'),
      subtitle: Text(BTLogTool.logDir),
      trailing: BTIconButton(
        icon: MdiIcons.folderOpen,
        tooltip: '打开日志目录',
        onPressed: logTool.openLogDir,
      ),
    );
  }

  /// 构建bt下载目录
  Widget buildDownloadInfo() {
    return ListTile(
      leading: const BtIcon(FluentIcons.download),
      title: const Text('下载目录'),
      subtitle: Text(BTDownloadTool.downloadDir),
      trailing: Row(
        children: [
          BTIconButton(
            icon: FluentIcons.delete,
            tooltip: '清理下载目录',
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
          BTIconButton(
            icon: MdiIcons.folderOpen,
            tooltip: '打开下载目录',
            onPressed: BTDownloadTool.openDownloadDir,
          ),
        ],
      ),
    );
  }

  /// 构建缓存信息
  Widget buildCacheInfo() {
    return ListTile(
      leading: const BtIcon(FluentIcons.broom),
      title: const Text('缓存管理'),
      subtitle: Text(
        _calculatingCache
            ? '正在计算缓存大小...'
            : '缓存大小：${BTFileTool.formatSize(_cacheSize)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BTIconButton(
            icon: FluentIcons.refresh,
            tooltip: '重新计算缓存大小',
            onPressed: _calculatingCache || _clearingCache
                ? null
                : _calculateCacheSize,
          ),
          BTIconButton(
            icon: FluentIcons.delete,
            tooltip: '清除全部缓存',
            onPressed: _cacheSize == 0 || _calculatingCache || _clearingCache
                ? null
                : _clearCache,
          ),
        ],
      ),
    );
  }

  /// 构建图片缓存信息
  Widget buildImageCacheInfo() {
    return ListTile(
      leading: BtIcon(MdiIcons.imageOutline),
      title: const Text('图片缓存'),
      subtitle: Text(
        _calculatingCache
            ? '正在计算图片缓存大小...'
            : '缓存大小：${BTFileTool.formatSize(_imageCacheSize)}',
      ),
      trailing: BTIconButton(
        icon: FluentIcons.delete,
        tooltip: '清除图片缓存',
        onPressed: _imageCacheSize == 0 || _calculatingCache || _clearingCache
            ? null
            : () => _clearCache(imagesOnly: true),
      ),
    );
  }

  /// 清除缓存
  Future<void> _clearCache({bool imagesOnly = false}) async {
    if (_clearingCache || _calculatingCache) return;
    setState(() => _clearingCache = true);
    var title = imagesOnly ? '清除图片缓存' : '清除全部缓存';
    try {
      var check = await showConfirm(
        context,
        title: title,
        content: imagesOnly
            ? '确定要清除图片缓存吗？\n封面和头像将在下次使用时重新加载。'
            : '确定要清除全部缓存吗？\n这将清除：\n• 应用数据缓存\n• 图片缓存\n• 下载文件',
      );
      if (!check || !mounted) return;

      progress = ProgressWidget.show(context, title: title, text: '正在清除缓存...');

      if (!imagesOnly) {
        await BTCacheManager.instance.clear();
        progress.update(text: '已清除应用缓存');
      }

      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      progress.update(text: '已清除图片缓存');

      if (!imagesOnly) {
        await fileTool.clearDir(BTDownloadTool.downloadDir);
        progress.update(text: '已清除下载文件');
      }

      progress.end();
      await _calculateCacheSize();
      if (mounted) {
        await BtInfobar.success(context, imagesOnly ? '图片缓存已清除' : '缓存已清除');
      }
    } catch (e) {
      if (progress.isShow) progress.end();
      if (mounted) await BtInfobar.error(context, '清除缓存失败：$e');
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BTSettingSection(
      icon: FluentIcons.settings,
      title: '应用配置',
      subtitle: '主题、RSS、缓存、日志与路径设置',
      initiallyExpanded: true,
      children: [
        buildThemeRow(),
        const BTSettingDivider(),
        buildMinimizeToTrayInfo(),
        buildRssSelectionBehaviorInfo(),
        const BTSettingDivider(),
        buildCacheInfo(),
        buildImageCacheInfo(),
        buildLogInfo(),
        const BTSettingDivider(),
        buildDownloadInfo(),
      ],
    );
  }
}
