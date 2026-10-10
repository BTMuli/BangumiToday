// Dart imports:
import 'dart:io';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/services/app_cache_service.dart';
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../store/playback_store.dart';
import '../../tools/log_retention.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import 'storage_cleanup_dialog.dart';

class AppSettingStorage extends ConsumerStatefulWidget {
  const AppSettingStorage({super.key});

  @override
  ConsumerState<AppSettingStorage> createState() => _AppSettingStorageState();
}

class _AppSettingStorageState extends ConsumerState<AppSettingStorage> {
  final _cache = const AppCacheService();
  final _sizes = <AppCacheKind, int>{};
  final _cacheErrors = <AppCacheKind, String>{};
  List<LogStorageGroup> _logs = [];
  String? _logError;
  bool _loadingCache = false;
  bool _loadingLogs = false;
  bool _confirming = false;
  String? _cleaning;

  bool get _busy => _confirming || _cleaning != null;
  BTLogRetention get _logStorage => BTLogRetention(
    Directory(BTLogTool.logDir),
    onError: (error) => BTLogTool.warn('日志管理失败：$error'),
  );

  @override
  void initState() {
    super.initState();
    _refreshCache();
    _refreshLogs();
  }

  Future<void> _refreshCache() async {
    if (_loadingCache) return;
    setState(() => _loadingCache = true);
    var sizes = <AppCacheKind, int>{};
    var errors = <AppCacheKind, String>{};
    for (var kind in AppCacheKind.values) {
      try {
        sizes[kind] = await _cache.getSize(kind);
      } catch (error) {
        errors[kind] = '$error';
      }
    }
    if (!mounted) return;
    setState(() {
      _sizes
        ..clear()
        ..addAll(sizes);
      _cacheErrors
        ..clear()
        ..addAll(errors);
      _loadingCache = false;
    });
  }

  Future<void> _refreshLogs() async {
    if (_loadingLogs) return;
    setState(() => _loadingLogs = true);
    try {
      var logs = await _logStorage.listGroups();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _logError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _logError = '读取日志失败：$error');
    } finally {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  Future<void> _clearCache() async {
    if (_busy || _loadingCache) return;
    setState(() => _confirming = true);
    try {
      var selected = await showStorageCleanupDialog<AppCacheKind>(
        context,
        title: '清理缓存',
        description: '请选择要清理的缓存。清理后会在使用时按需重新生成。',
        options: [
          for (var kind in AppCacheKind.values)
            StorageCleanupOption(
              value: kind,
              title: kind.label,
              description: _cacheErrors[kind] ?? kind.description,
              bytes: _sizes[kind],
              enabled: _canClearCache(kind),
            ),
        ],
        selected: {
          AppCacheKind.images,
          AppCacheKind.shaders,
          AppCacheKind.torrents,
        },
      );
      if (selected == null || selected.isEmpty || !mounted) return;
      var failures = <String>[];
      for (var kind in selected) {
        setState(() => _cleaning = 'cache:${kind.name}');
        try {
          var failed = await _cache.clear(kind);
          if (failed > 0) failures.add('${kind.label}：$failed 个文件暂时无法清理');
          if (kind == AppCacheKind.engines) {
            ref
                .read(playbackStoreProvider)
                .tensorRtResources
                .invalidateEngineCache();
          }
        } catch (error) {
          failures.add('${kind.label}：$error');
        }
        if (!mounted) return;
      }
      await _refreshCache();
      if (!mounted) return;
      if (failures.isEmpty) {
        await BtInfobar.success(context, '已清理 ${selected.length} 项缓存');
      } else {
        await BtInfobar.info(
          context,
          '清理完成，以下项目需要稍后重试：\n'
          '${failures.join('\n')}',
        );
      }
    } catch (error) {
      if (mounted) await BtInfobar.error(context, '清理缓存失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
          _cleaning = null;
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    if (_busy || _loadingLogs) return;
    setState(() => _confirming = true);
    try {
      var records = {for (var group in _logs) group.key: group};
      String typeFor(String key) => records[key]!.crashes ? '崩溃记录' : '运行日志';
      var selected = await showStorageCleanupDialog<String>(
        context,
        title: '清理日志与崩溃记录',
        description: '可按组或逐项选择要清理的记录，正在使用的日志会保留。',
        options: [
          for (var group in _logs)
            StorageCleanupOption(
              value: group.key,
              title: '${group.day} · ${group.crashes ? '崩溃记录' : '日志'}',
              description: _logDescription(group),
              bytes: group.bytes,
              enabled: group.canClear,
            ),
        ],
        selected: records.keys.toSet(),
        groupings: [
          StorageCleanupGrouping(
            label: '按日期',
            groupBy: (key) => records[key]!.day,
            itemTitle: typeFor,
            compareGroups: (a, b) => b.compareTo(a),
            compareItems: (a, b) => (records[a]!.crashes ? 1 : 0).compareTo(
              records[b]!.crashes ? 1 : 0,
            ),
            groupAction: (day, keys) => _logDirectoryAction(
              '$day 的日志与崩溃记录',
              keys.map((key) => records[key]!),
            ),
          ),
          StorageCleanupGrouping(
            label: '按类型',
            pinHeaders: true,
            groupBy: typeFor,
            itemTitle: (key) => records[key]!.day,
            compareGroups: (a, b) =>
                (a == '运行日志' ? 0 : 1).compareTo(b == '运行日志' ? 0 : 1),
            compareItems: (a, b) => records[b]!.day.compareTo(records[a]!.day),
            groupAction: (type, keys) => type == '崩溃记录'
                ? _logDirectoryAction(type, keys.map((key) => records[key]!))
                : null,
            itemAction: (key) => records[key]!.crashes
                ? null
                : _logDirectoryAction('${records[key]!.day} 的运行日志', [
                    records[key]!,
                  ]),
          ),
        ],
      );
      if (selected == null || selected.isEmpty || !mounted) return;
      setState(() => _cleaning = 'logs');
      var result = await _logStorage.clearGroups(selected);
      await _refreshLogs();
      if (!mounted) return;
      var message = '已清理 ${result.deleted} 个日志或崩溃记录文件';
      if (result.skipped > 0) message += '，保留 ${result.skipped} 个正在使用的文件';
      if (result.failed > 0) {
        await BtInfobar.info(context, '$message，${result.failed} 个文件暂时无法清理');
      } else {
        await BtInfobar.success(context, message);
      }
    } catch (error) {
      if (mounted) await BtInfobar.error(context, '清理日志失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
          _cleaning = null;
        });
      }
    }
  }

  String _logDescription(LogStorageGroup group) {
    var description = '${group.files} 个文件';
    if (group.protectedFiles > 0) {
      description += ' · ${group.protectedFiles} 个正在使用，保留';
    }
    return description;
  }

  Future<void> _openLogDirectory(String directory) async {
    try {
      var opened = await BTFileTool().openDir(directory);
      if (!opened && mounted) {
        await BtInfobar.info(context, '日志目录已不存在，请刷新日志列表');
      }
    } catch (error) {
      if (mounted) await BtInfobar.error(context, '打开日志目录失败：$error');
    }
  }

  Widget _logDirectoryAction(String title, Iterable<LogStorageGroup> groups) {
    var directories = groups.map((group) => group.directory).toSet();
    var directory = directories.length == 1
        ? directories.single
        : BTLogTool.logDir;
    return _action(
      icon: FluentIcons.open_folder_horizontal,
      label: '打开$title目录\n$directory',
      onPressed: () => _openLogDirectory(directory),
    );
  }

  bool _canClearCache(AppCacheKind kind) =>
      kind == AppCacheKind.data ||
      kind == AppCacheKind.images ||
      _sizes[kind] != 0;

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      button: true,
      child: IconButton(
        onPressed: onPressed,
        style: const ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
        icon: SizedBox.square(
          dimension: 18,
          child: loading
              ? const ProgressRing(strokeWidth: 2)
              : Icon(icon, size: 18),
        ),
      ),
    ),
  );

  Widget _summary(String title, String description, {String? info}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(child: Text(title, style: BTTypography.bodyStrong(context))),
          if (info != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: info,
              child: Icon(
                FluentIcons.info,
                size: 14,
                color: BTColors.textSecondary(context),
                semanticLabel: info,
              ),
            ),
          ],
        ],
      ),
      Text(description, style: BTTypography.caption(context)),
    ],
  );

  Widget _managementRow({
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> actions,
    String? info,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        BtIcon(icon),
        const SizedBox(width: 12),
        Expanded(child: _summary(title, description, info: info)),
        const SizedBox(width: 12),
        ...actions,
      ],
    ),
  );

  Widget _cacheInfo() {
    var total = _sizes.values.fold(0, (a, b) => a + b);
    return _managementRow(
      icon: FluentIcons.broom,
      title: '缓存管理',
      description: _loadingCache
          ? '正在计算缓存大小…'
          : '缓存大小：${BTFileTool.formatSize(total)}'
                '${_cacheErrors.isEmpty ? '' : ' · 部分大小未知'}',
      actions: [
        _action(
          icon: FluentIcons.refresh,
          label: '重新计算缓存大小',
          loading: _loadingCache,
          onPressed: _busy || _loadingCache ? null : _refreshCache,
        ),
        _action(
          icon: FluentIcons.delete,
          label: _cleaning?.startsWith('cache:') == true
              ? '正在清理缓存…'
              : '选择并清理缓存',
          loading: _cleaning?.startsWith('cache:') == true,
          onPressed: _busy || _loadingCache ? null : _clearCache,
        ),
      ],
    );
  }

  Widget _logInfo() {
    var total = _logs.fold(0, (sum, group) => sum + group.bytes);
    var files = _logs.fold(0, (sum, group) => sum + group.files);
    return _managementRow(
      icon: FluentIcons.folder_search,
      title: '日志管理',
      description: _loadingLogs
          ? '正在读取日志…'
          : _logError != null
          ? '读取失败，请刷新'
          : '日志大小：${BTFileTool.formatSize(total)} · $files 个文件',
      info:
          '日志目录：${BTLogTool.logDir}'
          '${_logError == null ? '' : '\n$_logError'}',
      actions: [
        _action(
          icon: FluentIcons.refresh,
          label: '刷新日志列表',
          loading: _loadingLogs,
          onPressed: _busy || _loadingLogs ? null : _refreshLogs,
        ),
        _action(
          icon: FluentIcons.delete,
          label: '选择并清理日志与崩溃记录',
          loading: _cleaning == 'logs',
          onPressed: _busy || _loadingLogs || _logError != null || _logs.isEmpty
              ? null
              : _clearLogs,
        ),
        _action(
          icon: FluentIcons.open_folder_horizontal,
          label: '打开日志目录',
          onPressed: BTLogTool.instance.openLogDir,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_cacheInfo(), const SizedBox(height: 8), _logInfo()],
  );
}
