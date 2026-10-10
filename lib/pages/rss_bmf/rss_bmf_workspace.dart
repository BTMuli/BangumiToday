// Dart imports:
import 'dart:async';
import 'dart:convert';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/cache/subject_cache.dart';
import '../../core/services/bmf_rss_service.dart';
import '../../core/services/download_directory.dart';
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/rss_date.dart';
import '../../database/app/app_bmf.dart';
import '../../database/app/app_subscription.dart';
import '../../database/drift/bt_database.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/database/app_subscription_model.dart';
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
part 'rss_bmf_workspace/recovery_dialog.dart';
part 'rss_bmf_workspace/header.dart';
part 'rss_bmf_workspace/period_filter.dart';
part 'rss_bmf_workspace/workspace.dart';

class RssBmfWorkspace extends ConsumerStatefulWidget {
  const RssBmfWorkspace({super.key});

  @override
  ConsumerState<RssBmfWorkspace> createState() => _RssBmfWorkspaceState();
}

abstract class _RssBmfWorkspaceStateBase extends ConsumerState<RssBmfWorkspace>
    with AutomaticKeepAliveClientMixin {
  final BTFileTool fileTool = BTFileTool();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _bmfListController = ScrollController();
  final ScrollController _rssPaneController = ScrollController();
  final ScrollController _filePaneController = ScrollController();
  final FlyoutController _filterFlyoutController = FlyoutController();
  final BmfFilterModel _filterModel = BmfFilterModel();
  final Map<int, int> _statusRevisions = {};
  final Map<int, int> _updateRevisions = {};
  late final Stream<bool> _hasUnresolvedRecovery = appSubscriptionStorage
      .watchHasUnresolvedRecovery();
  late final Stream<int> _recoveryCount = appSubscriptionStorage
      .watchRecoveryCount();
  String _loadedStatusSignature = '';
  String _loadedSubjectSignature = '';
  int _statusLoadGeneration = 0;
  int _subjectLoadGeneration = 0;
  bool _refreshing = false;
  bool _clearingRecovery = false;

  int? selectedSubject;
  int _handledNavigationRequest = 0;
  bool _showCompactDetail = false;
  bool _showLocalFiles = false;
  bool _splitResources = false;
  double? _listPaneWidth;

  Timer? _debounceTimer;
  StreamSubscription<BmfRssStatusEvent>? _statusSubscription;
  StreamSubscription<BmfRssUpdateEvent>? _updateSubscription;

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
      if (!mounted) return;
      var subject = event.subject;
      setState(() {
        _updateRevisions.update(
          subject,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      });
      unawaited(
        _loadUpdateStates(_filterModel.filteredList, _statusLoadGeneration),
      );
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

  void _applyNavigationIntent(BmfNavigationState navigation) {
    if (navigation.requestId == _handledNavigationRequest) return;
    _handledNavigationRequest = navigation.requestId;
    selectedSubject = navigation.targetSubject;
    _showCompactDetail = navigation.targetSubject != null;
    _showLocalFiles = false;
    _filterModel.resetFilters();
    if (navigation.pendingUpdatesOnly) {
      _filterModel.configurationFilter = BmfConfigurationFilter.updates;
    }
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
        .map((item) {
          var subscriptions = item.subscriptions
              .map((s) => '${s.id}:${s.feedKey}:${s.status}:${s.autoUpdate}')
              .join(',');
          return '${item.subject}:$subscriptions';
        })
        .join('|');
    if (_loadedStatusSignature == rssSignature) return;
    _loadedStatusSignature = rssSignature;
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
      var subscriptions = await appSubscriptionStorage.readAll();
      var caches = await appSubscriptionStorage.readCaches();
      var parsed = <String, List<RssItem>>{};
      var values = bmfList.map((item) {
        var owned = subscriptions.where((s) => s.bmfId == item.id);
        var items = <RssItem>[];
        var pending = 0;
        for (var subscription in owned) {
          pending += subscription.pendingItemKeys.length;
          var feedItems = parsed.putIfAbsent(subscription.feedKey, () {
            try {
              var xml = caches[subscription.feedKey]?.data;
              return xml == null ? <RssItem>[] : RssFeed.parse(xml).items;
            } catch (_) {
              return <RssItem>[];
            }
          });
          items.addAll(feedItems);
        }
        return (
          item.subject,
          pending,
          latestRssPublishedAt(items),
          items.length,
        );
      }).toList();
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

  Future<void> _refreshWorkspace({
    bool refreshRss = false,
    bool includeManual = false,
  }) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      if (refreshRss) {
        await BmfRssService.instance.refreshNow(includeManual: includeManual);
      }
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

    var downloadValue = draft.download.trim();
    var repo = ref.read(bmfRepositoryProvider);

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

    var titleValue = draft.title.trim();
    var updated = bmf.copyWith(
      title: titleValue.isEmpty ? null : titleValue,
      subscriptions: draft.subscriptions,
      download: downloadValue.isEmpty ? null : downloadValue,
    );
    try {
      await repo.updateModel(updated);
    } on StateError catch (error) {
      if (mounted) await BtInfobar.error(context, error.message);
      return;
    }
    if (mounted) await BtInfobar.success(context, 'BMF 配置已保存');
  }

  /// 打开番剧 RSS 搜索，选中的 RSS 直接写回当前关联。
  Future<void> _searchRss(AppBmfModel bmf) async {
    var behavior = ref.read(appStoreProvider).rssSelectionBehavior;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (_) => SubjectRssSearchDialog(
        subjectId: bmf.subject,
        title: bmf.title ?? '未命名番剧',
        currentRss: bmf.rss,
        selectionBehavior: behavior,
        selectOnly: true,
        onSubscribe: (dialogContext, rssUrl) async {
          var repo = ref.read(bmfRepositoryProvider);
          if (!dialogContext.mounted) return false;
          try {
            var current = await repo.read(bmf.subject) ?? bmf;
            var updated = current.withSelectedRss(rssUrl, behavior: behavior);
            var scheduled = await repo.updateModel(updated);
            if (!scheduled) await repo.refreshRss(updated);
          } on StateError catch (error) {
            if (dialogContext.mounted) {
              await BtInfobar.error(dialogContext, error.message);
            }
            return false;
          }
          if (dialogContext.mounted) {
            await BtInfobar.success(dialogContext, 'RSS 订阅已${behavior.label}');
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
        content: '确定删除 ${bmf.title ?? bmf.subject} 的关联配置及仅属于它的旧状态记录吗？',
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

  Future<void> _removeRss(AppBmfModel bmf, int subscriptionId) async {
    var updated = bmf.copyWith(
      subscriptions: bmf.subscriptions
          .where((s) => s.id != subscriptionId)
          .toList(),
    );
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
    return 'rss-${bmf.subject}-$navigationRequest';
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
