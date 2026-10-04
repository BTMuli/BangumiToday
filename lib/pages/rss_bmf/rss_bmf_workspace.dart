// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/cache/subject_cache.dart';
import '../../core/services/bmf_rss_service.dart';
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/rss_date.dart';
import '../../database/app/app_rss.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/rss/rss.dart';
import '../../providers/app_providers.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../ui/bt_select.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/bmf/bmf_auto_update_button.dart';
import '../../widgets/bmf/bmf_card.dart';
import '../../widgets/bmf/bmf_expander.dart';
import '../../widgets/subject_detail/subject_rss_search_dialog.dart';
import 'bmf_filter_model.dart';
import 'bmf_subject_data.dart';

part 'rss_bmf_workspace/config_dialog.dart';
part 'rss_bmf_workspace/header.dart';
part 'rss_bmf_workspace/workspace.dart';

class RssBmfWorkspace extends ConsumerStatefulWidget {
  const RssBmfWorkspace({super.key});

  @override
  ConsumerState<RssBmfWorkspace> createState() => _RssBmfWorkspaceState();
}

abstract class _RssBmfWorkspaceStateBase extends ConsumerState<RssBmfWorkspace>
    with AutomaticKeepAliveClientMixin {
  final BtsAppRss rss = BtsAppRss();
  final BTFileTool fileTool = BTFileTool();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _bmfListController = ScrollController();
  final ScrollController _rssPaneController = ScrollController();
  final ScrollController _filePaneController = ScrollController();
  final FlyoutController _filterFlyoutController = FlyoutController();
  final BmfFilterModel _filterModel = BmfFilterModel();
  final Map<String, int> _rssSubjectsByKey = {};
  final Map<int, int> _statusRevisions = {};
  final Map<int, int> _updateRevisions = {};
  String _loadedStatusSignature = '';
  String _loadedSubjectSignature = '';
  int _statusLoadGeneration = 0;
  int _subjectLoadGeneration = 0;
  bool _refreshing = false;

  int? selectedSubject;
  int _handledNavigationRequest = 0;
  bool _showCompactDetail = false;
  bool _showLocalFiles = false;
  bool _splitResources = false;
  double? _listPaneWidth;

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
      setState(() {
        _statusRevisions.update(
          event.subject,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        _filterModel.pendingCounts[event.subject] = event.pendingCount;
      });
    });
    _updateSubscription = BmfRssService.instance.updateStream.listen((event) {
      var subject = _rssSubjectsByKey[event.key];
      var latestUpdate = latestRssPublishedAt(event.items);
      if (!mounted || subject == null) return;
      setState(() {
        _updateRevisions.update(
          subject,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        _filterModel.rssItemCounts[subject] = event.items.length;
        if (latestUpdate == null) {
          _filterModel.latestUpdateTimes.remove(subject);
        } else {
          _filterModel.latestUpdateTimes[subject] = latestUpdate;
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _statusSubscription?.cancel();
    _updateSubscription?.cancel();
    _searchController.dispose();
    _bmfListController.dispose();
    _rssPaneController.dispose();
    _filePaneController.dispose();
    _filterFlyoutController.dispose();
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

  void _applyNavigationIntent(BmfNavigationState navigation) {
    if (navigation.requestId == _handledNavigationRequest) return;
    _handledNavigationRequest = navigation.requestId;
    selectedSubject = navigation.targetSubject;
    _showCompactDetail = navigation.targetSubject != null;
    _showLocalFiles = false;
    _filterModel.resetFilters();
    _debounceTimer?.cancel();
    _searchController.clear();
  }

  void onSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _changeListOptions(() => _filterModel.searchQuery = query);
    });
  }

  void _changeListOptions(VoidCallback change) {
    setState(() {
      change();
      _showCompactDetail = false;
    });
    if (_bmfListController.hasClients) _bmfListController.jumpTo(0);
  }

  void _resetFilters() {
    _debounceTimer?.cancel();
    _searchController.clear();
    _changeListOptions(_filterModel.resetFilters);
  }

  void _scheduleDataLoad(List<AppBmfModel> bmfList) {
    var subjectSignature = bmfList.map((item) => item.subject).join('|');
    if (_loadedSubjectSignature != subjectSignature) {
      _loadedSubjectSignature = subjectSignature;
      var generation = ++_subjectLoadGeneration;
      unawaited(_loadSubjectData(bmfList, generation));
    }
    var rssSignature = bmfList
        .map((item) => '${item.subject}:${item.rss}:${item.mkBgmId}')
        .join('|');
    if (_loadedStatusSignature == rssSignature) return;
    _loadedStatusSignature = rssSignature;
    _rssSubjectsByKey
      ..clear()
      ..addEntries(
        bmfList.where(BmfFilterModel.hasRss).map((item) {
          var key = item.mkBgmId?.isNotEmpty == true
              ? item.mkBgmId!
              : item.rss!;
          return MapEntry(key, item.subject);
        }),
      );
    var generation = ++_statusLoadGeneration;
    _filterModel.pendingCounts.clear();
    _filterModel.rssItemCounts.clear();
    _filterModel.latestUpdateTimes.clear();
    unawaited(_loadUpdateStates(bmfList, generation));
  }

  Future<void> _loadSubjectData(
    List<AppBmfModel> bmfList,
    int generation,
  ) async {
    try {
      var collections = await ref
          .read(bangumiRepositoryProvider)
          .getLocalCollections();
      var byId = {for (var item in collections) item.subjectId: item.subject};
      var entries = await Future.wait(
        bmfList.map((item) async {
          var cached = await BgmSubjectCache().read(
            item.subject,
            allowStale: true,
          );
          var collection = byId[item.subject];
          return MapEntry(
            item.subject,
            BmfSubjectData.fromSources(
              covers: [
                cached?.images.common,
                cached?.images.medium,
                cached?.images.large,
                collection?.images.common,
                collection?.images.medium,
                collection?.images.large,
              ],
              dates: [cached?.date, collection?.date],
              names: [
                cached?.nameCn,
                collection?.nameCn,
                cached?.name,
                collection?.name,
              ],
            ),
          );
        }),
      );
      if (!mounted || generation != _subjectLoadGeneration) return;
      setState(() {
        _filterModel.subjectData
          ..clear()
          ..addEntries(entries);
      });
    } catch (error) {
      BTLogTool.warn('Failed to load BMF subject cache: $error');
    }
  }

  Future<void> _loadUpdateStates(
    List<AppBmfModel> bmfList,
    int generation,
  ) async {
    var statusRevisions = Map<int, int>.of(_statusRevisions);
    var updateRevisions = Map<int, int>.of(_updateRevisions);
    try {
      var values = await Future.wait(
        bmfList.where(BmfFilterModel.hasRss).map((item) async {
          var model = item.mkBgmId?.isNotEmpty == true
              ? await rss.readByMkId(item.mkBgmId!)
              : await rss.read(item.rss!);
          var items = <RssItem>[];
          if (model != null) {
            try {
              items = RssFeed.parse(model.data).items;
            } catch (error) {
              BTLogTool.warn(
                'Failed to parse BMF RSS cache (${item.subject}): $error',
              );
            }
          }
          return (
            item.subject,
            model?.pendingItemKeys.length ?? 0,
            latestRssPublishedAt(items),
            items.length,
          );
        }),
      );
      if (!mounted || generation != _statusLoadGeneration) return;
      setState(() {
        for (var value in values) {
          if (_statusRevisions[value.$1] == statusRevisions[value.$1]) {
            _filterModel.pendingCounts[value.$1] = value.$2;
          }
          if (_updateRevisions[value.$1] == updateRevisions[value.$1]) {
            _filterModel.rssItemCounts[value.$1] = value.$4;
            if (value.$3 == null) {
              _filterModel.latestUpdateTimes.remove(value.$1);
            } else {
              _filterModel.latestUpdateTimes[value.$1] = value.$3!;
            }
          }
        }
      });
    } catch (error) {
      BTLogTool.warn('Failed to load BMF RSS status: $error');
    }
  }

  Future<void> _refreshWorkspace() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(bmfListProvider.notifier).refresh();
      if (!mounted) return;
      setState(() {
        _loadedStatusSignature = '';
        _loadedSubjectSignature = '';
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  AppBmfModel? _selectedModel() {
    if (_filterModel.filteredList.isEmpty) {
      return null;
    }
    var selected = _filterModel.filteredList
        .where((item) => item.subject == selectedSubject)
        .firstOrNull;
    if (selected != null) return selected;
    selectedSubject = _filterModel.filteredList.first.subject;
    _showLocalFiles = false;
    return _filterModel.filteredList.first;
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
      barrierDismissible: true,
      dismissWithEsc: true,
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

  /// 打开番剧 RSS 搜索，选中的 RSS 直接写回当前关联。
  Future<void> _searchRss(AppBmfModel bmf) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (_) => SubjectRssSearchDialog(
        subjectId: bmf.subject,
        title: bmf.title ?? '未命名番剧',
        currentRss: bmf.rss,
        selectOnly: true,
        onSubscribe: (dialogContext, rssUrl) async {
          var repo = ref.read(bmfRepositoryProvider);
          var duplicated = await repo.checkRss(
            rssUrl,
            excludeSubject: bmf.subject,
          );
          if (!dialogContext.mounted) return false;
          if (duplicated) {
            await BtInfobar.error(dialogContext, '该 RSS 已经被其他 BMF 使用');
            return false;
          }
          if (bmf.rss != null && bmf.rss!.isNotEmpty && bmf.rss != rssUrl) {
            if (bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty) {
              await rss.deleteByMkId(bmf.mkBgmId!);
            } else {
              await rss.delete(bmf.rss!);
            }
          }
          await repo.updateModel(
            bmf.copyWith(rss: rssUrl, mkBgmId: null, mkGroupId: null),
          );
          if (dialogContext.mounted) {
            await BtInfobar.success(dialogContext, 'RSS 关联已更新');
          }
          return true;
        },
      ),
    );
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
}

class _RssBmfWorkspaceState extends _RssBmfWorkspaceStateBase
    with _RssBmfWorkspaceHeader, _RssBmfWorkspacePane {
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
        _scheduleDataLoad(bmfList);
        _filterModel.applyFilter(bmfList);
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
}
