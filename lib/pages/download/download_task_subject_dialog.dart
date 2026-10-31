// Dart imports:
import 'dart:async';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/download_subject_search_controller.dart';
import '../../core/services/bt_engine_client.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/download_subject.dart';
import '../../database/app/download_subjects.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/bangumi_providers.dart';
import '../../providers/download_subject_providers.dart';
import '../../store/bmf_store.dart';
import '../../store/bt_download_store.dart';

Future<void> showDownloadTaskSubjectDialog(
  BuildContext context, {
  required BtTaskSnapshot task,
}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (_) => _DownloadTaskSubjectDialog(task: task),
);

class _DownloadTaskSubjectDialog extends ConsumerStatefulWidget {
  const _DownloadTaskSubjectDialog({required this.task});

  final BtTaskSnapshot task;

  @override
  ConsumerState<_DownloadTaskSubjectDialog> createState() =>
      _DownloadTaskSubjectDialogState();
}

class _DownloadTaskSubjectDialogState
    extends ConsumerState<_DownloadTaskSubjectDialog> {
  final _input = TextEditingController();
  late final DownloadSubjectSearchController _search;
  Timer? _debounce;
  int? _selectedId;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _search = DownloadSubjectSearchController(
      ref.read(bangumiRepositoryProvider),
    );
    _input.text = downloadSubjectSearchKeyword(widget.task.displayName);
    _search.changeQuery(_input.text);
    _search.addListener(_searchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_search.search());
    });
  }

  void _searchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_searchChanged);
    _search.dispose();
    _input.dispose();
    super.dispose();
  }

  void _changeQuery(String value) {
    _debounce?.cancel();
    _selectedId = null;
    _saveError = null;
    _search.changeQuery(value);
    _debounce = Timer(const Duration(milliseconds: 400), _submit);
  }

  void _submit() {
    _debounce?.cancel();
    unawaited(_search.search());
  }

  Future<void> _save() async {
    var subjectId = _selectedId;
    if (_saving || subjectId == null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      var tasks = ref.read(btDownloadStoreProvider).tasksById;
      if (!tasks.containsKey(widget.task.id)) {
        throw StateError('下载任务已移除，无法修改关联条目。');
      }
      await downloadSubjectsStorage.write(widget.task.id, subjectId);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _saveError = '保存关联失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var candidates = prioritizeDownloadSubjectCandidates(
      savePath: widget.task.savePath,
      bmfs: ref.watch(bmfListProvider).value ?? const [],
      results: _search.results,
    );
    var directoryDetails = {
      for (var candidate in candidates)
        if (candidate.directoryMatch != null)
          candidate.id: ref
              .watch(downloadSubjectDetailsProvider(candidate.id))
              .value,
    };
    var currentId = ref.watch(
      downloadTaskSubjectProvider((
        taskId: widget.task.id,
        savePath: widget.task.savePath,
      )),
    );
    var current = currentId == null
        ? null
        : ref.watch(downloadSubjectDetailsProvider(currentId)).value;
    var currentName = current == null
        ? currentId == null
              ? '未关联条目'
              : '条目 #$currentId'
        : current.nameCn.isNotEmpty
        ? current.nameCn
        : current.name;
    var error = _saveError ?? _search.error;
    return PopScope(
      canPop: !_saving,
      child: ContentDialog(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        title: const Text('修改关联条目'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.task.displayName, maxLines: 2),
              const SizedBox(height: 8),
              Text('当前关联：$currentName'),
              const SizedBox(height: 12),
              TextBox(
                controller: _input,
                placeholder: '搜索番剧名称',
                enabled: !_saving,
                onSubmitted: (_) => _submit(),
                onChanged: _changeQuery,
                suffix: Tooltip(
                  message: _search.loading ? '正在搜索番剧' : '搜索番剧',
                  child: IconButton(
                    icon: _search.loading
                        ? const SizedBox.square(
                            dimension: 15,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        : const Icon(
                            FluentIcons.search,
                            size: 15,
                            semanticLabel: '搜索番剧',
                          ),
                    onPressed: _search.loading || _saving ? null : _submit,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (error != null)
                InfoBar(
                  title: Text(error),
                  severity: InfoBarSeverity.error,
                  action: _search.error == null
                      ? null
                      : Button(
                          onPressed: _search.loading || _saving
                              ? null
                              : () => _search.search(
                                  more: _search.results.isNotEmpty,
                                ),
                          child: const Text('重试'),
                        ),
                ),
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.4).clamp(
                  140,
                  320,
                ),
                child: candidates.isEmpty
                    ? Center(
                        child: Text(
                          _search.loading
                              ? '正在搜索…'
                              : _search.searched
                              ? '没有找到相关番剧，试试其他名称'
                              : '输入番剧名称搜索',
                        ),
                      )
                    : ListView.separated(
                        itemCount:
                            candidates.length + (_search.hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          if (index == candidates.length) {
                            return Button(
                              onPressed: _search.loading || _saving
                                  ? null
                                  : () => _search.search(more: true),
                              child: Text(_search.loading ? '正在加载…' : '加载更多'),
                            );
                          }
                          var candidate = candidates[index];
                          return _candidate(
                            candidate,
                            detail: directoryDetails[candidate.id],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              const Text('选择正确季度后保存。下载文件和进度保持不变。'),
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _saving || _selectedId == null ? null : _save,
            child: Text(_saving ? '正在保存…' : '保存关联'),
          ),
        ],
      ),
    );
  }

  Widget _candidate(
    DownloadSubjectCandidate candidate, {
    BangumiSubject? detail,
  }) {
    var selected = _selectedId == candidate.id;
    var bmf = candidate.directoryMatch;
    var result = candidate.searchResult;
    var preferredName = [
      bmf?.title,
      detail?.nameCn,
      result?.nameCn,
      detail?.name,
      result?.name,
    ].whereType<String>().where((name) => name.trim().isNotEmpty).firstOrNull;
    var name = preferredName ?? '条目 #${candidate.id}';
    var originalName = detail?.name ?? result?.name;
    var date = detail?.date ?? result?.date ?? bmf?.airDate;
    var platform = detail?.platform ?? result?.platform;
    var episodes = detail?.eps ?? result?.eps ?? 0;
    var details = [
      if (date?.isNotEmpty == true) date!,
      if (platform?.isNotEmpty == true) platform!,
      if (episodes > 0) '$episodes 话',
    ].join(' · ');
    var accent = FluentTheme.of(context).accentColor;
    var contentHeight = MediaQuery.textScalerOf(context).scale(56);
    var caption = BTTypography.caption(context).copyWith(height: 1.2);
    var metadata = details.isEmpty ? result?.info ?? '' : details;
    return Semantics(
      selected: selected,
      child: HoverButton(
        semanticLabel: '选择 $name，$details${bmf == null ? '' : '，BMF 目录匹配'}',
        onPressed: _saving
            ? null
            : () => setState(() => _selectedId = candidate.id),
        builder: (context, states) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected || states.isHovered || states.isFocused
                ? accent.withValues(alpha: 0.08)
                : BTColors.surfaceSecondary(context),
            borderRadius: BTRadius.smallBR,
            border: Border.all(color: selected ? accent : Colors.transparent),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BTRadius.smallBR,
                child: CachedNetworkImage(
                  imageUrl:
                      detail?.images.common ?? result?.images.common ?? '',
                  width: contentHeight * 40 / 56,
                  height: contentHeight,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const Icon(FluentIcons.video),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: contentHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (bmf != null) ...[
                            Tooltip(
                              message: '下载目录：${bmf.download}',
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BTRadius.smallBR,
                                ),
                                child: Text('BMF 目录匹配', style: caption),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Tooltip(
                              message: name,
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BTTypography.body(
                                  context,
                                ).copyWith(height: 1.2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Tooltip(
                        message: originalName ?? '',
                        child: Text(
                          originalName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: caption,
                        ),
                      ),
                      Tooltip(
                        message: metadata,
                        child: Text(
                          metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(FluentIcons.check_mark, size: 16, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
