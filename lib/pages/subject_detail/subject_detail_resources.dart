// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/services/bmf_rss_service.dart';
import '../../core/services/bt_engine/protocol.dart';
import '../../core/services/download_directory.dart';
import '../../core/services/download_service.dart';
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/playback_episode_files.dart';
import '../../core/utils/playback_paths.dart';
import '../../data/repositories/episode_mark_gateway_impl.dart';
import '../../database/app/app_subscription.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/database/app_subscription_model.dart';
import '../../models/playback/playback_item.dart';
import '../../providers/app_providers.dart';
import '../../providers/playback_episode_link_providers.dart';
import '../../providers/subject_playback_providers.dart';
import '../../request/mikan/mikan_api.dart';
import '../../store/bt_dir_download_state.dart';
import '../../store/bt_download_store.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bmf/bmf_resource_item.dart';
import '../../widgets/bmf/bmf_rss_data.dart';
import '../../widgets/rss/rss_group_header.dart';
import '../../widgets/rss/rss_refresh_status.dart';
import '../../widgets/rss/rss_release_data.dart';
import '../../widgets/rss/rss_release_detail_dialog.dart';
import '../playback/playback_actions.dart';
import 'subject_detail_colors.dart';
import 'subject_episode_files_dialog.dart';

part 'subject_detail_resources/actions.dart';
part 'subject_detail_resources/rss.dart';
part 'subject_detail_resources/files.dart';

/// 详情页专用资源工作区：管理栏与列表共享页签的宽度和剩余高度。
/// 仅沿用数据与服务，不使用抽屉的 BMF 面板或折叠组件。
class SubjectDetailResources extends ConsumerStatefulWidget {
  const SubjectDetailResources({
    super.key,
    required this.subjectId,
    required this.title,
    required this.airDate,
    required this.onSearchRss,
  });

  final int subjectId;
  final String title;
  final String? airDate;
  final Future<void> Function() onSearchRss;

  @override
  ConsumerState<SubjectDetailResources> createState() =>
      _SubjectDetailResourcesState();
}

class _SubjectDetailResourcesState
    extends ConsumerState<SubjectDetailResources> {
  late AppBmfModel _bmf = _emptyModel();
  late final BmfRssData _rss = BmfRssData(bmf: _bmf);
  final _sourceFlyout = FlyoutController();
  final _fileTool = BTFileTool();
  final _downloading = <(int?, String)>{};
  final _collapsedGroups = <(int?, String)>{};
  List<String> _files = [];
  Map<String, int> _fileSizes = {};
  BtDirDownloadState? _dirState;
  StreamSubscription<BmfChange>? _modelSubscription;
  StreamSubscription<BmfRssUpdateEvent>? _rssSubscription;
  StreamSubscription<BmfRssStatusEvent>? _statusSubscription;
  Timer? _fileTimer;
  Timer? _storeDebounce;
  bool _initialized = false;
  bool _busy = false;
  bool _refreshingRss = false;
  bool _refreshingFiles = false;
  bool _filesQueued = false;
  bool _fileStateUnknown = false;
  bool _showFiles = false;
  bool _active = true;
  String? _loadError;
  String? _fileError;
  int _modelGeneration = 0;
  int _fileGeneration = 0;

  AppBmfModel _emptyModel() => AppBmfModel(
    subject: widget.subjectId,
    title: widget.title,
    airDate: widget.airDate,
  );

  @override
  void initState() {
    super.initState();
    _rss.addListener(_onRssChanged);
    _modelSubscription = ref.read(bmfRepositoryProvider).changes.listen((
      event,
    ) {
      if (event.subject == widget.subjectId) unawaited(_loadModel());
    });
    _rssSubscription = BmfRssService.instance.updateStream.listen(
      _rss.applyUpdate,
    );
    _statusSubscription = BmfRssService.instance.statusStream.listen((event) {
      if (event.subscriptionId == _rss.selectedSubscriptionId) {
        unawaited(_rss.load());
      }
    });
    unawaited(_loadModel());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var active = TickerMode.valuesOf(context).enabled;
    if (active != _active) {
      _active = active;
      _syncFileTimer();
      if (active && _showFiles) unawaited(_refreshFiles());
    }
  }

  @override
  void dispose() {
    _modelGeneration++;
    _fileGeneration++;
    _modelSubscription?.cancel();
    _rssSubscription?.cancel();
    _statusSubscription?.cancel();
    _fileTimer?.cancel();
    _storeDebounce?.cancel();
    _rss.removeListener(_onRssChanged);
    _rss.dispose();
    _sourceFlyout.dispose();
    super.dispose();
  }

  void _onRssChanged() {
    if (mounted) setState(() {});
  }

  void _update(VoidCallback callback) => setState(callback);

  Future<void> _loadModel() async {
    var generation = ++_modelGeneration;
    try {
      var model = await ref.read(bmfRepositoryProvider).read(widget.subjectId);
      if (!mounted || generation != _modelGeneration) return;
      var oldDirectory = _bmf.download;
      setState(() {
        _bmf = model == null
            ? _emptyModel()
            : model.copyWith(
                airDate: model.airDate?.isNotEmpty == true
                    ? model.airDate
                    : widget.airDate,
              );
        _initialized = true;
        _loadError = null;
        // 已删除的来源不应在缓存加载完成前继续显示旧资源。
        if (!_bmf.subscriptions.any(
          (s) => s.id == _rss.selectedSubscriptionId,
        )) {
          _rss.subscription = null;
          _rss.rssItems = [];
          _rss.rssReleases = [];
          _rss.rssGroups = [];
          _rss.pendingItemKeys = {};
        }
      });
      _rss.updateBmf(_bmf);
      if (oldDirectory != _bmf.download) {
        _fileGeneration++;
        _files = [];
        _fileSizes = {};
        _dirState = null;
        _fileError = null;
        _syncFileTimer();
        await _refreshFiles();
      }
    } catch (error) {
      if (!mounted || generation != _modelGeneration) return;
      setState(() {
        _initialized = true;
        _loadError = '加载下载与订阅失败，请重试';
      });
      BTLogTool.warn('加载详情页资源失败：${error.runtimeType}');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectFiles(bool value) {
    setState(() => _showFiles = value);
    _syncFileTimer();
    if (value) unawaited(_refreshFiles());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<(String, String, String)>>(
      btDownloadStoreProvider.select(
        (store) => [
          for (var task in store.tasks) (task.id, task.state, task.savePath),
        ],
      ),
      (previous, next) {
        if (_bmf.download?.isNotEmpty != true || !mounted) return;
        var directory = path.normalize(_bmf.download!).toLowerCase();
        var before =
            previous
                ?.where(
                  (task) => path.normalize(task.$3).toLowerCase() == directory,
                )
                .toList() ??
            [];
        var after = next
            .where((task) => path.normalize(task.$3).toLowerCase() == directory)
            .toList();
        if (before.length == after.length &&
            Iterable<int>.generate(
              after.length,
            ).every((i) => before[i] == after[i])) {
          return;
        }
        _storeDebounce ??= Timer(const Duration(seconds: 1), () {
          _storeDebounce = null;
          if (mounted) unawaited(_refreshFiles());
        });
      },
    );
    if (!_initialized) return const Center(child: ProgressRing());
    if (_loadError != null) {
      return _emptyState(_loadError!, action: _loadModel, label: '重试');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _modeButton(
                '订阅资源 · ${_rss.rssReleases.length} 条',
                MdiIcons.rss,
                false,
              ),
              const SizedBox(width: 8),
              _modeButton('本地文件 · ${_files.length} 个', FluentIcons.video, true),
              const Spacer(),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox.square(
                    dimension: 16,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                ),
              _iconAction(
                '搜索订阅',
                FluentIcons.search,
                _busy ? null : () => _run(_searchRss),
              ),
              _iconAction(
                '粘贴 RSS',
                FluentIcons.paste,
                _busy ? null : () => _run(_addRss),
              ),
              _iconAction(
                '设置下载目录',
                FluentIcons.folder,
                _busy ? null : () => _run(_chooseDirectory),
              ),
              _iconAction(
                '修改标题',
                FluentIcons.edit,
                _busy ? null : () => _run(_editTitle),
              ),
              if (_bmf.id != -1)
                _iconAction(
                  '清除配置',
                  FluentIcons.delete,
                  _busy ? null : () => _run(_removeModel),
                ),
            ],
          ),
        ),
        Container(height: 1, color: BTColors.divider(context)),
        Expanded(child: _showFiles ? _buildFiles() : _buildRss()),
      ],
    );
  }

  Widget _modeButton(String label, IconData icon, bool files) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      selected: _showFiles == files,
      child: ToggleButton(
        checked: _showFiles == files,
        onChanged: (_) => _selectFiles(files),
        child: Icon(icon, size: 18),
      ),
    ),
  );

  Widget _iconAction(String label, IconData icon, VoidCallback? onPressed) =>
      Tooltip(
        message: label,
        child: IconButton(icon: Icon(icon, size: 16), onPressed: onPressed),
      );

  Widget _emptyState(String text, {VoidCallback? action, String? label}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: BTTypography.body(context),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 12),
                Button(onPressed: _busy ? null : action, child: Text(label!)),
              ],
            ],
          ),
        ),
      );

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: FluentTheme.of(context).accentColor.withValues(alpha: 0.2),
      borderRadius: BTRadius.smallBR,
    ),
    child: Text(
      label,
      style: BTTypography.caption(
        context,
      ).copyWith(color: BTColors.textPrimary(context)),
    ),
  );
}
