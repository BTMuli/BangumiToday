import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';

import '../../core/services/bmf_rss_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/rss_date.dart';
import '../../database/app/app_rss.dart';
import '../../models/database/app_bmf_model.dart';
import '../../providers/app_providers.dart';
import '../../tools/file_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/subject_detail/bmf_card.dart';
import '../../widgets/bangumi/subject_detail/bmf_expander.dart';

enum _BmfConfigurationFilter {
  all,
  updates,
  hasRss,
  autoUpdate,
  manualUpdate,
  incomplete,
}

class BmfFilterStats {
  final int total;
  final int updates;
  final int hasRss;
  final int autoUpdate;
  final int manualUpdate;
  final int incomplete;

  const BmfFilterStats({
    required this.total,
    required this.updates,
    required this.hasRss,
    required this.autoUpdate,
    required this.manualUpdate,
    required this.incomplete,
  });

  static const empty = BmfFilterStats(
    total: 0,
    updates: 0,
    hasRss: 0,
    autoUpdate: 0,
    manualUpdate: 0,
    incomplete: 0,
  );
}

class BmfQuarter {
  final int year;
  final int quarter;

  const BmfQuarter(this.year, this.quarter);

  static const all = BmfQuarter(0, 0);

  factory BmfQuarter.fromDate(DateTime date) {
    return BmfQuarter(date.year, ((date.month - 1) ~/ 3) + 1);
  }

  factory BmfQuarter.current() => BmfQuarter.fromDate(DateTime.now());

  String get label => this == all ? '全部季度' : '$year Q$quarter';

  @override
  bool operator ==(Object other) =>
      other is BmfQuarter && other.year == year && other.quarter == quarter;

  @override
  int get hashCode => Object.hash(year, quarter);
}

class _BmfConfigDraft {
  final String title;
  final String rss;
  final String download;
  final bool autoUpdate;

  const _BmfConfigDraft({
    required this.title,
    required this.rss,
    required this.download,
    required this.autoUpdate,
  });
}

class RbpBmfWidget extends ConsumerStatefulWidget {
  const RbpBmfWidget({super.key});

  @override
  ConsumerState<RbpBmfWidget> createState() => _RbpBmfState();
}

class _RbpBmfState extends ConsumerState<RbpBmfWidget>
    with AutomaticKeepAliveClientMixin {
  final BtsAppRss rss = BtsAppRss();
  final BTFileTool fileTool = BTFileTool();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _rssPaneController = ScrollController();
  final ScrollController _filePaneController = ScrollController();

  List<AppBmfModel> filteredList = [];
  BmfFilterStats filterStats = BmfFilterStats.empty;
  _BmfConfigurationFilter configurationFilter = _BmfConfigurationFilter.all;
  BmfQuarter selectedQuarter = BmfQuarter.all;
  List<BmfQuarter> quarterOptions = [];
  String searchQuery = '';
  int? selectedSubject;
  final Map<int, int> _pendingCounts = {};
  final Map<int, DateTime> _latestUpdateTimes = {};
  final Map<String, int> _rssSubjectsByKey = {};
  String _loadedStatusSignature = '';
  int _handledNavigationRequest = 0;
  bool _showCompactDetail = false;

  Timer? _debounceTimer;
  StreamSubscription<BmfRssStatusEvent>? _statusSubscription;
  StreamSubscription<BmfRssUpdateEvent>? _updateSubscription;
  bool _preCheckDone = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _statusSubscription = BmfRssService.instance.statusStream.listen((event) {
      if (!mounted) return;
      setState(() => _pendingCounts[event.subject] = event.pendingCount);
    });
    _updateSubscription = BmfRssService.instance.updateStream.listen((event) {
      var subject = _rssSubjectsByKey[event.key];
      var latestUpdate = latestRssPublishedAt(event.items);
      if (!mounted || subject == null || latestUpdate == null) return;
      setState(() => _latestUpdateTimes[subject] = latestUpdate);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _statusSubscription?.cancel();
    _updateSubscription?.cancel();
    _searchController.dispose();
    _rssPaneController.dispose();
    _filePaneController.dispose();
    super.dispose();
  }

  Future<void> _preCheck(List<AppBmfModel> bmfList) async {
    if (_preCheckDone || bmfList.isEmpty) return;
    _preCheckDone = true;

    var rssList = await rss.readAll();
    var usedMkIds = bmfList
        .where((item) => item.mkBgmId != null && item.mkBgmId!.isNotEmpty)
        .map((item) => item.mkBgmId)
        .toSet();
    var unusedRss = rssList.where((rssItem) {
      if (rssItem.mkBgmId == null || rssItem.mkBgmId!.isEmpty) return false;
      return !usedMkIds.contains(rssItem.mkBgmId);
    }).toList();

    for (var item in unusedRss) {
      await rss.deleteByMkId(item.mkBgmId!);
    }
    if (unusedRss.isNotEmpty && mounted) {
      await BtInfobar.warn(context, '清理了 ${unusedRss.length} 条未使用的 RSS 缓存');
    }
  }

  void _computeStats(List<AppBmfModel> bmfList) {
    var hasRss = 0;
    var autoUpdate = 0;
    var manualUpdate = 0;
    var incomplete = 0;
    var updates = 0;
    for (var item in bmfList) {
      var rssConfigured = item.rss != null && item.rss!.isNotEmpty;
      var directoryConfigured =
          item.download != null && item.download!.isNotEmpty;
      if (rssConfigured) hasRss++;
      if (item.autoUpdate) {
        autoUpdate++;
      } else {
        manualUpdate++;
      }
      if (!rssConfigured || !directoryConfigured) incomplete++;
      if ((_pendingCounts[item.subject] ?? 0) > 0) updates++;
    }
    filterStats = BmfFilterStats(
      total: bmfList.length,
      updates: updates,
      hasRss: hasRss,
      autoUpdate: autoUpdate,
      manualUpdate: manualUpdate,
      incomplete: incomplete,
    );
  }

  void applyFilter(List<AppBmfModel> bmfList) {
    var quarters = bmfList
        .map((bmf) => DateTime.tryParse(bmf.airDate ?? ''))
        .whereType<DateTime>()
        .map(BmfQuarter.fromDate)
        .toSet();
    quarters.add(BmfQuarter.current());
    quarterOptions = quarters.toList()
      ..sort((a, b) {
        var yearCompare = b.year.compareTo(a.year);
        return yearCompare != 0 ? yearCompare : b.quarter.compareTo(a.quarter);
      });

    var quarterFilteredList = bmfList.where((bmf) {
      if (selectedQuarter == BmfQuarter.all) return true;
      var airDate = DateTime.tryParse(bmf.airDate ?? '');
      return airDate != null && BmfQuarter.fromDate(airDate) == selectedQuarter;
    }).toList();
    _computeStats(quarterFilteredList);

    var query = searchQuery.trim().toLowerCase();
    filteredList =
        quarterFilteredList.where((bmf) {
          var matchesSearch =
              query.isEmpty ||
              (bmf.title?.toLowerCase().contains(query) ?? false) ||
              bmf.subject.toString().contains(query);
          if (!matchesSearch) return false;

          var hasRss = bmf.rss != null && bmf.rss!.isNotEmpty;
          var hasDirectory = bmf.download != null && bmf.download!.isNotEmpty;
          return switch (configurationFilter) {
            _BmfConfigurationFilter.all => true,
            _BmfConfigurationFilter.updates =>
              (_pendingCounts[bmf.subject] ?? 0) > 0,
            _BmfConfigurationFilter.hasRss => hasRss,
            _BmfConfigurationFilter.autoUpdate => bmf.autoUpdate,
            _BmfConfigurationFilter.manualUpdate => !bmf.autoUpdate,
            _BmfConfigurationFilter.incomplete => !hasRss || !hasDirectory,
          };
        }).toList()..sort((a, b) {
          var aDate =
              _latestUpdateTimes[a.subject] ??
              DateTime.tryParse(a.airDate ?? '');
          var bDate =
              _latestUpdateTimes[b.subject] ??
              DateTime.tryParse(b.airDate ?? '');
          if (aDate != null && bDate != null) {
            var dateCompare = bDate.compareTo(aDate);
            if (dateCompare != 0) return dateCompare;
          } else if (aDate != null) {
            return -1;
          } else if (bDate != null) {
            return 1;
          }
          return b.subject.compareTo(a.subject);
        });
  }

  void _scheduleStatusLoad(List<AppBmfModel> bmfList) {
    _rssSubjectsByKey
      ..clear()
      ..addEntries(
        bmfList
            .where((item) => item.rss != null && item.rss!.isNotEmpty)
            .map(
              (item) => MapEntry(
                item.mkBgmId != null && item.mkBgmId!.isNotEmpty
                    ? item.mkBgmId!
                    : item.rss!,
                item.subject,
              ),
            ),
      );
    var signature = bmfList
        .map((item) => '${item.subject}:${item.rss}:${item.mkBgmId}')
        .join('|');
    if (_loadedStatusSignature == signature) return;
    _loadedStatusSignature = signature;
    Future.microtask(() => _loadUpdateStates(bmfList));
  }

  Future<void> _loadUpdateStates(List<AppBmfModel> bmfList) async {
    var sources = bmfList
        .where((item) => item.rss != null && item.rss!.isNotEmpty)
        .toList();
    var values = await Future.wait(
      sources.map((item) async {
        var model = item.mkBgmId != null && item.mkBgmId!.isNotEmpty
            ? await rss.readByMkId(item.mkBgmId!)
            : await rss.read(item.rss!);
        return (
          item.subject,
          model?.pendingItemKeys.length ?? 0,
          model == null ? null : latestRssPublishedAtFromXml(model.data),
        );
      }),
    );
    if (!mounted) return;
    setState(() {
      _pendingCounts
        ..clear()
        ..addEntries(values.map((value) => MapEntry(value.$1, value.$2)));
      _latestUpdateTimes
        ..clear()
        ..addEntries(
          values
              .where((value) => value.$3 != null)
              .map((value) => MapEntry(value.$1, value.$3!)),
        );
    });
  }

  void _applyNavigationIntent(BmfNavigationStore navigation) {
    if (navigation.requestId == _handledNavigationRequest) return;
    _handledNavigationRequest = navigation.requestId;
    selectedSubject = navigation.targetSubject;
    _showCompactDetail = navigation.targetSubject != null;
    configurationFilter = _BmfConfigurationFilter.all;
    selectedQuarter = BmfQuarter.all;
    searchQuery = '';
    _debounceTimer?.cancel();
    _searchController.clear();
  }

  void onSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => searchQuery = query);
    });
  }

  AppBmfModel? _selectedModel() {
    if (filteredList.isEmpty || selectedSubject == null) return null;
    return filteredList
        .where((item) => item.subject == selectedSubject)
        .firstOrNull;
  }

  void _navigateToDetail(AppBmfModel bmf) {
    ref
        .read(navStoreProvider.notifier)
        .addNavItemB(subject: bmf.subject, paneTitle: bmf.title, type: '动画');
  }

  Future<void> _addToNavOnly(AppBmfModel bmf) async {
    ref
        .read(navStoreProvider.notifier)
        .addNavItemB(
          subject: bmf.subject,
          paneTitle: bmf.title,
          type: '动画',
          jump: false,
        );
    if (mounted) {
      await BtInfobar.success(context, '${bmf.title ?? bmf.subject} 添加成功');
    }
  }

  Future<void> _setAutoUpdate(AppBmfModel bmf, bool enabled) async {
    if (bmf.autoUpdate == enabled) return;
    await ref
        .read(bmfRepositoryProvider)
        .updateModel(bmf.copyWith(autoUpdate: enabled));
    if (mounted) {
      await BtInfobar.success(
        context,
        enabled ? '已开启 RSS 自动更新' : '已关闭 RSS 自动更新',
      );
    }
  }

  Future<void> _copyTitle(AppBmfModel bmf) async {
    var title = bmf.title?.trim();
    if (title == null || title.isEmpty) {
      await BtInfobar.error(context, '标题为空');
      return;
    }

    await Clipboard.setData(ClipboardData(text: title));
    if (mounted) await BtInfobar.success(context, '已复制标题: $title');
  }

  Future<void> _editConfiguration(AppBmfModel bmf) async {
    var draft = await showDialog<_BmfConfigDraft>(
      context: context,
      builder: (context) => _BmfConfigDialog(bmf: bmf),
    );
    if (draft == null || !mounted) return;

    var rssValue = draft.rss.trim();
    var downloadValue = draft.download.trim();
    var repo = ref.read(bmfRepositoryProvider);

    if (rssValue.isNotEmpty) {
      var duplicated = await repo.checkRss(
        rssValue,
        excludeSubject: bmf.subject,
      );
      if (duplicated && mounted) {
        await BtInfobar.error(context, '该 RSS 已经被其他 BMF 使用');
        return;
      }
    }
    if (downloadValue.isNotEmpty) {
      var duplicated = await repo.checkDir(
        downloadValue,
        excludeSubject: bmf.subject,
      );
      if (duplicated && mounted) {
        await BtInfobar.error(context, '该目录已经被其他 BMF 使用');
        return;
      }
    }

    if (bmf.rss != null && bmf.rss!.isNotEmpty && bmf.rss != rssValue) {
      if (bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty) {
        await rss.deleteByMkId(bmf.mkBgmId!);
      } else {
        await rss.delete(bmf.rss!);
      }
    }
    var titleValue = draft.title.trim();
    var updated = bmf.copyWith(
      title: titleValue.isEmpty ? null : titleValue,
      rss: rssValue.isEmpty ? null : rssValue,
      download: downloadValue.isEmpty ? null : downloadValue,
      autoUpdate: draft.autoUpdate,
      mkBgmId: null,
      mkGroupId: null,
    );
    await repo.updateModel(updated);
    if (mounted) await BtInfobar.success(context, 'BMF 配置已保存');
  }

  Future<void> _deleteBmf(
    AppBmfModel bmf, {
    bool requireConfirmation = true,
  }) async {
    if (requireConfirmation) {
      var confirm = await showConfirm(
        context,
        title: '删除 BMF',
        content: '确定删除 ${bmf.title ?? bmf.subject} 的关联配置吗？',
      );
      if (!confirm || !mounted) return;
    }

    var isDelDir = false;
    if (bmf.download != null && bmf.download!.isNotEmpty) {
      isDelDir = await showConfirm(
        context,
        title: '删除下载目录',
        content: '是否删除下载目录？',
      );
    }

    await ref.read(bmfRepositoryProvider).delete(bmf.subject);
    if (isDelDir) await fileTool.deleteDir(bmf.download!);
    if (!mounted) return;
    setState(() => selectedSubject = null);
    await BtInfobar.success(context, 'BMF 配置已删除');
  }

  Future<void> _removeRss(AppBmfModel bmf) async {
    if (bmf.rss != null && bmf.rss!.isNotEmpty) {
      if (bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty) {
        await rss.deleteByMkId(bmf.mkBgmId!);
      } else {
        await rss.delete(bmf.rss!);
      }
    }
    var updated = bmf.copyWith(rss: null, mkBgmId: null, mkGroupId: null);
    await ref.read(bmfRepositoryProvider).updateModel(updated);
    if (mounted) await BtInfobar.success(context, 'RSS 关联已移除');
  }

  Future<void> _removeDirectory(AppBmfModel bmf) async {
    var updated = bmf.copyWith(download: null);
    await ref.read(bmfRepositoryProvider).updateModel(updated);
    if (mounted) await BtInfobar.success(context, '本地目录关联已移除');
  }

  String _rssViewKey(AppBmfModel bmf, int pendingCount) {
    var navigationRequest = selectedSubject == bmf.subject
        ? _handledNavigationRequest
        : 0;
    return 'rss-${bmf.subject}-${bmf.rss}-'
        '${pendingCount > 0}-$navigationRequest';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var bmfListAsync = ref.watch(bmfListProvider);
    var navigation = ref.watch(bmfNavigationProvider);
    _applyNavigationIntent(navigation);

    ref.listen<AsyncValue<List<AppBmfModel>>>(bmfListProvider, (prev, next) {
      next.whenData((bmfList) {
        if (!_preCheckDone) _preCheck(bmfList);
      });
    });

    return bmfListAsync.when(
      data: (bmfList) {
        _scheduleStatusLoad(bmfList);
        applyFilter(bmfList);
        return ScaffoldPage(
          padding: EdgeInsets.zero,
          content: Column(
            children: [
              _buildHeader(context),
              _buildToolbar(context),
              Container(height: 1, color: BTColors.divider(context)),
              Expanded(child: _buildWorkspace(context)),
            ],
          ),
        );
      },
      loading: () => const ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Center(child: ProgressRing()),
      ),
      error: (error, stack) => ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            padding: EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: FluentTheme.of(
                context,
              ).accentColor.withValues(alpha: 0.14),
              borderRadius: BTRadius.mediumBR,
            ),
            child: Image.asset('assets/images/logo.png'),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BMF 工作台', style: BTTypography.title(context)),
                Text(
                  '集中管理番剧、RSS 订阅与本地目录的关联',
                  style: BTTypography.caption(context),
                ),
              ],
            ),
          ),
          Text(
            '${filterStats.total} 个关联',
            style: BTTypography.caption(context),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: '刷新 BMF 配置',
            child: IconButton(
              icon: BtIcon(FluentIcons.refresh, size: 15),
              onPressed: () async {
                await ref.read(bmfListProvider.notifier).refresh();
                if (context.mounted) {
                  await BtInfobar.success(context, 'BMF 配置刷新完成');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          var filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                context,
                label: '全部',
                count: filterStats.total,
                value: _BmfConfigurationFilter.all,
              ),
              _buildFilterChip(
                context,
                label: '有更新',
                count: filterStats.updates,
                value: _BmfConfigurationFilter.updates,
              ),
              _buildFilterChip(
                context,
                label: '已关联 RSS',
                count: filterStats.hasRss,
                value: _BmfConfigurationFilter.hasRss,
              ),
              _buildFilterChip(
                context,
                label: '自动更新',
                count: filterStats.autoUpdate,
                value: _BmfConfigurationFilter.autoUpdate,
              ),
              _buildFilterChip(
                context,
                label: '手动更新',
                count: filterStats.manualUpdate,
                value: _BmfConfigurationFilter.manualUpdate,
              ),
              _buildFilterChip(
                context,
                label: '待补全',
                count: filterStats.incomplete,
                value: _BmfConfigurationFilter.incomplete,
              ),
            ],
          );
          var controls = Row(
            children: [
              SizedBox(width: 140, child: _buildQuarterFilter()),
              SizedBox(width: 8),
              Expanded(
                child: TextBox(
                  controller: _searchController,
                  placeholder: '搜索番剧标题或 ID…',
                  prefix: BtIcon(FluentIcons.search, size: 14),
                  suffix: searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: BtIcon(FluentIcons.clear, size: 12),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => searchQuery = '');
                          },
                        ),
                  onChanged: onSearch,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 860) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [filters, SizedBox(height: 8), controls],
            );
          }
          return Row(
            children: [
              Expanded(child: filters),
              SizedBox(width: 12),
              SizedBox(width: 430, child: controls),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required int count,
    required _BmfConfigurationFilter value,
  }) {
    var selected = configurationFilter == value;
    var accent = FluentTheme.of(context).accentColor;
    return Button(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          selected
              ? accent.withValues(alpha: 0.15)
              : BTColors.surfaceSecondary(context),
        ),
      ),
      onPressed: () => setState(() => configurationFilter = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? accent : BTColors.textPrimary(context),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          SizedBox(width: 6),
          Text(
            '$count',
            style: BTTypography.caption(context).copyWith(
              color: selected ? accent : BTColors.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterFilter() {
    return ComboBox<BmfQuarter>(
      value: selectedQuarter,
      isExpanded: true,
      items: [
        const ComboBoxItem<BmfQuarter>(
          value: BmfQuarter.all,
          child: Text('全部季度'),
        ),
        ...quarterOptions.map(
          (quarter) => ComboBoxItem<BmfQuarter>(
            value: quarter,
            child: Text(quarter.label),
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => selectedQuarter = value);
      },
    );
  }

  Widget _buildWorkspace(BuildContext context) {
    if (filteredList.isEmpty) return _buildEmptyState(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        var compact = constraints.maxWidth < 900;
        var selected = _selectedModel();
        if (compact) {
          if (_showCompactDetail && selected != null) {
            return _buildDetailPane(context, selected, showBackButton: true);
          }
          return _buildBmfList(context, compact: true);
        }

        var listWidth = (constraints.maxWidth * 0.30).clamp(320.0, 420.0);
        return Row(
          children: [
            SizedBox(
              width: listWidth,
              child: _buildBmfList(context, compact: false),
            ),
            Container(width: 1, color: BTColors.divider(context)),
            Expanded(
              child: selected == null
                  ? _buildSelectPrompt(context)
                  : _buildDetailPane(context, selected),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBmfList(BuildContext context, {required bool compact}) {
    var selected = _selectedModel();
    return ColoredBox(
      color: BTColors.surfaceSecondary(context),
      child: ListView.separated(
        padding: EdgeInsets.all(10),
        itemCount: filteredList.length,
        separatorBuilder: (_, _) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          var bmf = filteredList[index];
          return BmfCard(
            key: ValueKey(bmf.subject),
            bmf: bmf,
            pendingCount: _pendingCounts[bmf.subject] ?? 0,
            selected: !compact && selected?.subject == bmf.subject,
            dense: true,
            onAutoUpdateChanged: (enabled) => _setAutoUpdate(bmf, enabled),
            onOpen: () => setState(() {
              selectedSubject = bmf.subject;
              _showCompactDetail = compact;
            }),
            onDelete: () => _deleteBmf(bmf, requireConfirmation: false),
          );
        },
      ),
    );
  }

  Widget _buildDetailPane(
    BuildContext context,
    AppBmfModel bmf, {
    bool showBackButton = false,
  }) {
    var hasRss = bmf.rss != null && bmf.rss!.isNotEmpty;
    var hasDirectory = bmf.download != null && bmf.download!.isNotEmpty;
    var pendingCount = _pendingCounts[bmf.subject] ?? 0;

    return ColoredBox(
      color: BTColors.surfacePrimary(context),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBackButton) ...[
                  IconButton(
                    icon: BtIcon(FluentIcons.back, size: 15),
                    onPressed: () => setState(() => _showCompactDetail = false),
                  ),
                  SizedBox(width: 6),
                ],
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FluentTheme.of(
                      context,
                    ).accentColor.withValues(alpha: 0.14),
                    borderRadius: BTRadius.mediumBR,
                  ),
                  child: Icon(
                    FluentIcons.media,
                    size: 18,
                    color: FluentTheme.of(context).accentColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bmf.title ?? '未命名番剧',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.title(context),
                      ),
                      SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Bangumi #${bmf.subject}',
                            style: BTTypography.caption(context),
                          ),
                          if (bmf.airDate != null && bmf.airDate!.isNotEmpty)
                            Text(
                              '首播 ${bmf.airDate}',
                              style: BTTypography.caption(context),
                            ),
                          if (pendingCount > 0)
                            _buildStatusBadge(
                              context,
                              label: '$pendingCount 条更新',
                              active: true,
                            ),
                          _buildStatusBadge(
                            context,
                            label: bmf.autoUpdate ? 'RSS 自动更新' : 'RSS 手动更新',
                            active: bmf.autoUpdate,
                          ),
                          _buildStatusBadge(
                            context,
                            label: hasRss ? 'RSS 已关联' : '缺少 RSS',
                            active: hasRss,
                          ),
                          _buildStatusBadge(
                            context,
                            label: hasDirectory ? '目录已关联' : '缺少目录',
                            active: hasDirectory,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                FilledButton(
                  onPressed: () => _editConfiguration(bmf),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.edit, size: 13),
                      SizedBox(width: 6),
                      const Text('编辑关联'),
                    ],
                  ),
                ),
                SizedBox(width: 6),
                Tooltip(
                  message: '复制标题',
                  child: IconButton(
                    icon: BtIcon(FluentIcons.copy, size: 14),
                    onPressed: () => _copyTitle(bmf),
                  ),
                ),
                Tooltip(
                  message: '打开番剧详情',
                  child: IconButton(
                    icon: BtIcon(FluentIcons.open_in_new_tab, size: 14),
                    onPressed: () => _navigateToDetail(bmf),
                    onLongPress: () => _addToNavOnly(bmf),
                  ),
                ),
                Tooltip(
                  message: '删除 BMF 关联',
                  child: IconButton(
                    icon: Icon(
                      FluentIcons.delete,
                      size: 14,
                      color: BTColors.errorLight(context),
                    ),
                    onPressed: () => _deleteBmf(bmf),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: BTColors.divider(context)),
          Expanded(
            child: _buildResourcePanes(
              context,
              bmf,
              hasRss: hasRss,
              hasDirectory: hasDirectory,
              pendingCount: pendingCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourcePanes(
    BuildContext context,
    AppBmfModel bmf, {
    required bool hasRss,
    required bool hasDirectory,
    required int pendingCount,
  }) {
    if (!hasRss && !hasDirectory) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: _buildUnconfiguredCard(context, bmf),
      );
    }

    Widget rssPane() => _buildScrollableResourcePane(
      child: BmfRssExpander(
        key: ValueKey(_rssViewKey(bmf, pendingCount)),
        bmf: bmf,
        isConfig: true,
        maxHeight: 320,
        contentScrollable: false,
        expandable: false,
        contentScrollController: _rssPaneController,
        onDelete: () => _removeRss(bmf),
      ),
    );
    Widget filePane() => _buildScrollableResourcePane(
      child: BmfFileExpander(
        key: ValueKey('file-${bmf.subject}-${bmf.download}'),
        downloadDir: bmf.download!,
        subject: bmf.subject,
        maxHeight: 320,
        contentScrollable: false,
        expandable: false,
        contentScrollController: _filePaneController,
        onDelete: () => _removeDirectory(bmf),
      ),
    );

    if (!hasRss) return filePane();
    if (!hasDirectory) return rssPane();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              Expanded(child: rssPane()),
              Container(height: 1, color: BTColors.divider(context)),
              Expanded(child: filePane()),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: rssPane()),
            Container(width: 1, color: BTColors.divider(context)),
            Expanded(child: filePane()),
          ],
        );
      },
    );
  }

  Widget _buildScrollableResourcePane({required Widget child}) {
    return Padding(padding: EdgeInsets.all(12), child: child);
  }

  Widget _buildStatusBadge(
    BuildContext context, {
    required String label,
    required bool active,
  }) {
    var color = active
        ? FluentTheme.of(context).accentColor
        : BTColors.warningLight(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BTRadius.roundBR,
      ),
      child: Text(
        label,
        style: BTTypography.caption(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildUnconfiguredCard(BuildContext context, AppBmfModel bmf) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.largeBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Column(
        children: [
          Icon(
            FluentIcons.link,
            size: 36,
            color: BTColors.textTertiary(context),
          ),
          SizedBox(height: 10),
          Text('尚未建立资源关联', style: BTTypography.subtitle(context)),
          SizedBox(height: 5),
          Text(
            '添加 RSS 用于接收发布更新，添加本地目录用于查看已落地文件。',
            textAlign: TextAlign.center,
            style: BTTypography.caption(context),
          ),
          SizedBox(height: 12),
          Button(
            onPressed: () => _editConfiguration(bmf),
            child: const Text('开始配置'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.bulleted_list,
            size: 42,
            color: BTColors.textTertiary(context),
          ),
          SizedBox(height: 12),
          Text('选择一个番剧关联', style: BTTypography.subtitle(context)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            configurationFilter == _BmfConfigurationFilter.incomplete
                ? FluentIcons.completed
                : MdiIcons.linkOff,
            size: 46,
            color: BTColors.textTertiary(context),
          ),
          SizedBox(height: 12),
          Text(
            searchQuery.isNotEmpty
                ? '没有找到匹配的番剧'
                : configurationFilter == _BmfConfigurationFilter.updates
                ? '没有待处理更新'
                : configurationFilter == _BmfConfigurationFilter.autoUpdate
                ? '没有开启自动更新的 BMF'
                : configurationFilter == _BmfConfigurationFilter.manualUpdate
                ? '没有关闭自动更新的 BMF'
                : configurationFilter == _BmfConfigurationFilter.incomplete
                ? '当前关联均已补全'
                : '暂无 BMF 关联',
            style: BTTypography.subtitle(context),
          ),
          SizedBox(height: 5),
          Text(
            searchQuery.isNotEmpty ? '尝试其他标题或 Bangumi ID' : '可以在番剧详情页创建 BMF 关联',
            style: BTTypography.caption(context),
          ),
        ],
      ),
    );
  }
}

class _BmfConfigDialog extends StatefulWidget {
  final AppBmfModel bmf;

  const _BmfConfigDialog({required this.bmf});

  @override
  State<_BmfConfigDialog> createState() => _BmfConfigDialogState();
}

class _BmfConfigDialogState extends State<_BmfConfigDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _rssController;
  late final TextEditingController _downloadController;
  late bool _autoUpdate;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bmf.title ?? '');
    _rssController = TextEditingController(text: widget.bmf.rss ?? '');
    _downloadController = TextEditingController(
      text: widget.bmf.download ?? '',
    );
    _autoUpdate = widget.bmf.autoUpdate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rssController.dispose();
    _downloadController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _BmfConfigDraft(
        title: _titleController.text,
        rss: _rssController.text,
        download: _downloadController.text,
        autoUpdate: _autoUpdate,
      ),
    );
  }

  Future<void> _refreshNow() async {
    if (_refreshing) return;
    if (widget.bmf.rss == null || widget.bmf.rss!.isEmpty) {
      await BtInfobar.error(context, '请先配置 RSS');
      return;
    }

    setState(() => _refreshing = true);
    var result = await BmfRssService.instance.refreshBmf(widget.bmf);
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (result) {
      await BtInfobar.success(context, 'RSS 刷新成功');
    } else {
      await BtInfobar.error(context, 'RSS 刷新失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: BoxConstraints(maxWidth: 620),
      title: Row(
        children: [
          Icon(FluentIcons.link, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '编辑 ${widget.bmf.title ?? widget.bmf.subject}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(context, '显示标题'),
            TextBox(controller: _titleController, placeholder: '番剧标题'),
            SizedBox(height: 14),
            _buildLabel(context, 'RSS 订阅'),
            TextBox(
              controller: _rssController,
              placeholder: 'Mikan RSS 或其他兼容订阅地址',
            ),
            SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('RSS 自动更新'),
              subtitle: Text(
                _autoUpdate ? '应用运行时会按计划自动刷新 RSS' : '已关闭自动刷新，可使用刷新按钮手动更新',
              ),
              trailing: ToggleSwitch(
                checked: _autoUpdate,
                onChanged: (value) => setState(() => _autoUpdate = value),
              ),
            ),
            SizedBox(height: 6),
            _buildLabel(context, '本地目录'),
            TextBox(
              controller: _downloadController,
              placeholder: '内置下载引擎保存文件的目标目录',
              suffix: Tooltip(
                message: '选择目录',
                child: IconButton(
                  icon: BtIcon(FluentIcons.folder_open, size: 14),
                  onPressed: () async {
                    var directory = await getDirectoryPath();
                    if (directory == null || !mounted) return;
                    setState(() => _downloadController.text = directory);
                  },
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              '应用会把 torrent 与该目录交给内置下载引擎；任务可在下载管理页查看。',
              style: BTTypography.caption(context),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        Button(
          onPressed: _refreshing ? null : _refreshNow,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.refresh, size: 13),
              SizedBox(width: 6),
              Text(_refreshing ? '刷新中…' : '刷新 RSS'),
            ],
          ),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存关联')),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Text(label, style: BTTypography.bodyStrong(context)),
    );
  }
}
