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
import 'bmf_filter_model.dart';

part 'rb_pw_bmf/config_dialog.dart';
part 'rb_pw_bmf/header.dart';
part 'rb_pw_bmf/workspace.dart';

class RbpBmfWidget extends ConsumerStatefulWidget {
  const RbpBmfWidget({super.key});

  @override
  ConsumerState<RbpBmfWidget> createState() => _RbpBmfState();
}

abstract class _RbpBmfStateBase extends ConsumerState<RbpBmfWidget>
    with AutomaticKeepAliveClientMixin {
  final BtsAppRss rss = BtsAppRss();
  final BTFileTool fileTool = BTFileTool();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _rssPaneController = ScrollController();
  final ScrollController _filePaneController = ScrollController();
  late final BmfFilterModel _filterModel = BmfFilterModel(rss: rss);

  int? selectedSubject;
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
      setState(() {
        _filterModel.pendingCounts[event.subject] = event.pendingCount;
      });
    });
    _updateSubscription = BmfRssService.instance.updateStream.listen((event) {
      var subject = _filterModel.rssSubjectsByKey[event.key];
      var latestUpdate = latestRssPublishedAt(event.items);
      if (!mounted || subject == null || latestUpdate == null) return;
      setState(() {
        _filterModel.latestUpdateTimes[subject] = latestUpdate;
      });
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

  void _applyNavigationIntent(BmfNavigationStore navigation) {
    if (navigation.requestId == _handledNavigationRequest) return;
    _handledNavigationRequest = navigation.requestId;
    selectedSubject = navigation.targetSubject;
    _showCompactDetail = navigation.targetSubject != null;
    _filterModel.configurationFilter = BmfConfigurationFilter.all;
    _filterModel.selectedQuarter = BmfQuarter.all;
    _filterModel.searchQuery = '';
    _debounceTimer?.cancel();
    _searchController.clear();
  }

  void onSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _filterModel.searchQuery = query);
    });
  }

  AppBmfModel? _selectedModel() {
    if (_filterModel.filteredList.isEmpty || selectedSubject == null) {
      return null;
    }
    return _filterModel.filteredList
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
}

class _RbpBmfState extends _RbpBmfStateBase
    with _RbpBmfHeader, _RbpBmfWorkspace {
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
        if (_filterModel.scheduleStatusLoad(bmfList)) {
          Future.microtask(() async {
            await _filterModel.loadUpdateStates(bmfList);
            if (mounted) setState(() {});
          });
        }
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
