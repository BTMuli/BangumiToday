// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/services/download_directory.dart';
import '../../core/services/episode_mark_service.dart';
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/playback_episode_files.dart';
import '../../core/utils/playback_paths.dart';
import '../../data/repositories/episode_mark_gateway_impl.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_item.dart';
import '../../providers/app_providers.dart';
import '../../providers/playback_episode_link_providers.dart';
import '../../providers/subject_playback_providers.dart';
import '../../ui/bt_dialog.dart';
import '../playback/playback_actions.dart';

part 'subject_episode_files_dialog/widgets.dart';

String subjectFileEpisodeLabel(BangumiEpisode episode) {
  var number = episode.sort == episode.sort.truncateToDouble()
      ? episode.sort.toInt().toString()
      : episode.sort.toString();
  var name = episode.nameCn.isEmpty ? episode.name : episode.nameCn;
  return '${episode.type.label} $number${name.isEmpty ? '' : ' · $name'}';
}

Future<void> showSubjectEpisodeFiles(
  BuildContext context, {
  required int subject,
  BangumiEpisode? episode,
  String? filePath,
}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (_) => _SubjectEpisodeFilesDialog(
    subject: subject,
    episode: episode,
    filePath: filePath,
  ),
);

/// Both chapter and local-file entry points edit the same durable links.
class _SubjectEpisodeFilesDialog extends ConsumerStatefulWidget {
  const _SubjectEpisodeFilesDialog({
    required this.subject,
    this.episode,
    this.filePath,
  });

  final int subject;
  final BangumiEpisode? episode;
  final String? filePath;

  @override
  ConsumerState<_SubjectEpisodeFilesDialog> createState() =>
      _SubjectEpisodeFilesDialogState();
}

class _SubjectEpisodeFilesDialogState
    extends ConsumerState<_SubjectEpisodeFilesDialog> {
  final _files = <String, String>{};
  final _automaticFiles = <String>{};
  final _listScrollController = ScrollController();
  final _episodeScrollController = ScrollController();
  final _revealSignatures =
      <ScrollController, (String?, int, int, double, double, double)>{};
  static const _fileRowExtent = 64.0;
  String? _directory;
  String? _selectedFile;
  int? _selectedEpisode;
  bool _loadingFiles = true;
  bool _busy = false;
  String? _error;

  bool get _editingFile => widget.episode == null && widget.filePath != null;

  @override
  void initState() {
    super.initState();
    _selectedEpisode = widget.episode?.id;
    _selectedFile = widget.filePath;
    if (widget.filePath != null) _addFile(widget.filePath!);
    unawaited(_loadFiles());
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _episodeScrollController.dispose();
    super.dispose();
  }

  void _revealSelectedRow(
    String? key,
    int index,
    int count,
    double rowExtent,
    double viewportHeight, {
    double topPadding = 0,
    ScrollController? controller,
  }) {
    var scrollController = controller ?? _listScrollController;
    var signature = (key, index, count, rowExtent, viewportHeight, topPadding);
    if (_revealSignatures[scrollController] == signature) return;
    _revealSignatures[scrollController] = signature;
    if (index < 0) return;
    // Lazy lists have not built distant rows; use their exact fixed extent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _revealSignatures[scrollController] != signature ||
          !scrollController.hasClients) {
        return;
      }
      var position = scrollController.position;
      if (!position.hasContentDimensions) return;
      var top = topPadding + index * rowExtent;
      if (top >= position.pixels &&
          top + rowExtent <= position.pixels + position.viewportDimension) {
        return;
      }
      var offset = top - (position.viewportDimension - rowExtent) / 2;
      scrollController.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  void _selectEpisode(int? episode) {
    if (_busy || episode == null) return;
    setState(() {
      _selectedEpisode = episode;
    });
  }

  void _addFile(String file) {
    if (PlaybackPaths.isVideo(file)) {
      _files[PlaybackItem.pathKey(file)] = file;
    }
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loadingFiles = true;
      _error = null;
    });
    try {
      if (_editingFile) {
        // The fixed file only needs its saved link; do not scan other files.
        var links = await ref.read(playbackEpisodeLinksProvider).readAll();
        if (!mounted) return;
        var linked = links[PlaybackItem.pathKey(widget.filePath!)];
        setState(() {
          _selectedEpisode = linked?.subject == widget.subject
              ? linked!.episode ?? 0
              : null;
        });
        return;
      }
      var repository = ref.read(bmfRepositoryProvider);
      var storage = ref.read(playbackEpisodeLinksProvider);
      var model = await repository.read(widget.subject);
      var directory = model?.download;
      var files = <String>[];
      if (directory != null && directory.isNotEmpty) {
        try {
          files = [
            for (var file in await BTFileTool().getFileNames(
              directory,
              recursive: true,
            ))
              if (PlaybackPaths.isVideo(file))
                PlaybackPaths.resolveTaskPath(directory, file),
          ];
        } catch (_) {
          if (mounted) _error = '读取下载目录失败，可手动选择视频文件';
        }
      }
      var links = await storage.readAll();
      if (!mounted) return;
      setState(() {
        _directory = directory;
        _files.clear();
        _automaticFiles.clear();
        if (widget.filePath != null) _addFile(widget.filePath!);
        if (_selectedFile != null) _addFile(_selectedFile!);
        for (var file in files) {
          _addFile(file);
          _automaticFiles.add(PlaybackItem.pathKey(file));
        }
        for (var link in links.values) {
          if (link.subject == widget.subject) _addFile(link.filePath);
        }
        if (_selectedFile == null && widget.episode != null) {
          _selectedFile = links.values
              .where(
                (link) =>
                    link.subject == widget.subject &&
                    link.episode == widget.episode!.id,
              )
              .firstOrNull
              ?.filePath;
        }
        var linked = _selectedFile == null
            ? null
            : links[PlaybackItem.pathKey(_selectedFile!)];
        if (widget.episode == null && linked?.subject == widget.subject) {
          _selectedEpisode = linked!.episode ?? 0;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = '加载文件关联失败：$error');
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  void _selectFile(
    String file,
    Map<String, PlaybackEpisodeLink> links,
    List<BangumiEpisode> episodes,
  ) {
    var linked = links[PlaybackItem.pathKey(file)];
    var inferred = EpisodeMarkService.matchingEpisode(
      PlaybackItem(
        filePath: file,
        title: path.basename(file),
        subject: widget.subject,
      ),
      episodes.map(episodeMarkChapter),
    );
    setState(() {
      _selectedFile = file;
      _selectedEpisode =
          widget.episode?.id ??
          (linked?.subject == widget.subject
              ? linked?.episode ?? 0
              : inferred?.id);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile(
    Map<String, PlaybackEpisodeLink> links,
    List<BangumiEpisode> episodes,
  ) async {
    var file = await pickPlaybackFile();
    if (file == null || !mounted) return;
    _addFile(file.path);
    _selectFile(file.path, links, episodes);
  }

  Future<void> _save() async {
    var file = _selectedFile!;
    var episode = _selectedEpisode == 0 ? null : _selectedEpisode!;
    var storage = ref.read(playbackEpisodeLinksProvider);
    var links = await storage.readAll();
    if (!mounted) return;
    var key = PlaybackItem.pathKey(file);
    var existing = links[key];
    var removing = widget.episode != null && episode == null;
    if (removing) {
      var chapters = ref
          .read(subjectFileEpisodesProvider(widget.subject))
          .value;
      var current = resolvePlaybackEpisodeFiles(
        subject: widget.subject,
        files:
            _automaticFiles.contains(key) || existing?.subject == widget.subject
            ? [file]
            : const [],
        episodes: (chapters ?? const <BangumiEpisode>[]).map(
          episodeMarkChapter,
        ),
        manualLinks: links,
      )[key];
      if (current?.episode != widget.episode!.id) {
        setState(() {
          _selectedEpisode = widget.episode!.id;
          _error = '文件关联已变化，未移除；请重新选择。';
        });
        return;
      }
    }
    if (existing != null &&
        (existing.subject != widget.subject ||
            (episode != null &&
                existing.episode != null &&
                existing.episode != episode))) {
      var confirmed = await showConfirm(
        context,
        title: '修改文件关联',
        content:
            '该文件已关联${existing.subject != widget.subject ? '其他条目' : '其他剧集'}，'
            '确定改为${episode == null ? '不匹配' : '当前剧集'}吗？',
      );
      if (!confirmed || !mounted) return;
    }
    await storage.write(
      PlaybackEpisodeLink(
        filePath: file,
        subject: widget.subject,
        episode: episode,
      ),
    );
    if (mounted && removing) {
      setState(() {
        _selectedFile = null;
        _selectedEpisode = widget.episode!.id;
      });
    }
  }

  void _removeEpisodeFile(String file) {
    if (_busy) return;
    setState(() {
      _selectedFile = file;
      _selectedEpisode = 0;
    });
  }

  Future<void> _chooseDirectory() async {
    var directory = await pickDownloadDirectory(currentPath: _directory);
    if (directory == null || !mounted) return;
    var repository = ref.read(bmfRepositoryProvider);
    if (await repository.checkDir(directory, excludeSubject: widget.subject)) {
      throw StateError('该目录已被其他条目使用');
    }
    var model =
        await repository.read(widget.subject) ??
        AppBmfModel(subject: widget.subject);
    await repository.write(model.copyWith(download: directory));
    if (mounted) await _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    var chapterData = ref.watch(subjectFileEpisodesProvider(widget.subject));
    var episodes = chapterData.value ?? const <BangumiEpisode>[];
    var linkData = ref.watch(playbackEpisodeLinkSnapshotProvider);
    var links = linkData.value ?? const <String, PlaybackEpisodeLink>{};
    var matched = resolvePlaybackEpisodeFiles(
      subject: widget.subject,
      files: _editingFile
          ? [widget.filePath!]
          : _files.values.where(
              (file) =>
                  _automaticFiles.contains(PlaybackItem.pathKey(file)) ||
                  links[PlaybackItem.pathKey(file)]?.subject == widget.subject,
            ),
      episodes: episodes.map(episodeMarkChapter),
      manualLinks: links,
    );
    var linkedFiles = matched.values.where(
      (link) => widget.episode == null || link.episode == widget.episode!.id,
    );
    var files =
        <String, String>{
          ..._files,
          for (var link in linkedFiles) link.key: link.filePath,
        }.values.toList()..sort((a, b) {
          if (widget.episode != null) {
            bool belongs(String file) {
              return matched[PlaybackItem.pathKey(file)]?.episode ==
                  widget.episode!.id;
            }

            var order = (belongs(a) ? 0 : 1).compareTo(belongs(b) ? 0 : 1);
            if (order != 0) return order;
          }
          return PlaybackPaths.naturalCompare(a, b);
        });
    // A chapter opened for playback immediately selects its inferred file.
    var selected =
        _selectedFile ??
        (widget.episode == null ? null : linkedFiles.firstOrNull?.filePath);
    var linked = selected == null
        ? null
        : links[PlaybackItem.pathKey(selected)];
    var selectedEpisode =
        _selectedEpisode ??
        (linked?.subject == widget.subject && linked!.excluded
            ? 0
            : selected == null
            ? null
            : matched[PlaybackItem.pathKey(selected)]?.episode);
    var validEpisode =
        selectedEpisode == 0 || episodes.any((e) => e.id == selectedEpisode);
    var effective = selected == null
        ? null
        : matched[PlaybackItem.pathKey(selected)];
    var unchanged = selectedEpisode == 0
        ? linked?.subject == widget.subject && linked!.excluded
        : effective != null && effective.episode == selectedEpisode;
    var loading = _loadingFiles || chapterData.isLoading || linkData.isLoading;
    var rowExtent = MediaQuery.textScalerOf(
      context,
    ).scale(_fileRowExtent).clamp(_fileRowExtent, double.infinity);
    var canSave =
        !_busy &&
        !loading &&
        !chapterData.hasError &&
        !linkData.hasError &&
        selected != null &&
        validEpisode &&
        !unchanged;
    var excludedCount = files.where((file) {
      var link = links[PlaybackItem.pathKey(file)];
      return link?.subject == widget.subject && link!.excluded;
    }).length;
    var unmatchedCount = files.length - matched.length - excludedCount;
    var canChoose = !_busy && !loading;
    var canSelectEpisode =
        canChoose && !chapterData.hasError && !linkData.hasError;
    var pendingRemoval =
        widget.episode != null && selected != null && selectedEpisode == 0;
    var canRemove =
        canSelectEpisode &&
        widget.episode != null &&
        (pendingRemoval || effective?.episode == widget.episode!.id);
    // Only the list scrolls; surrounding controls retain their positions.
    var body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_editingFile) ...[
          Text(
            '选择该文件对应的剧集；附加内容可选择“不匹配”。',
            style: BTTypography.caption(context),
          ),
          const SizedBox(height: 16),
          _buildEpisodeToolbar(
            episodes.length,
            selectedEpisode,
            enabled: canSelectEpisode,
          ),
          const SizedBox(height: 8),
          if (loading) ...[const ProgressBar(), const SizedBox(height: 8)],
        ] else ...[
          Text(
            widget.episode == null
                ? '视频会自动匹配章节；需要调整时，选择文件后修正关联。'
                : '选择文件关联到本集；一集可关联多个文件。',
            style: BTTypography.caption(context),
          ),
          const SizedBox(height: 16),
          _buildDirectoryBar(canChoose),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('视频文件', style: BTTypography.bodyStrong(context)),
              if (files.isNotEmpty) ...[
                _fileBadge('已匹配 ${linkedFiles.length}', highlighted: true),
                if (unmatchedCount > 0) _fileBadge('未匹配 $unmatchedCount'),
                if (excludedCount > 0) _fileBadge('不匹配 $excludedCount'),
                if (widget.episode != null)
                  Tooltip(
                    message: pendingRemoval ? '撤销本次移除' : '移除选中文件与本集的关联，保存修正后生效',
                    child: Button(
                      onPressed: canRemove
                          ? () => pendingRemoval
                                ? _selectEpisode(widget.episode!.id)
                                : _removeEpisodeFile(selected!)
                          : null,
                      child: _fileActionLabel(
                        pendingRemoval ? FluentIcons.undo : FluentIcons.remove,
                        pendingRemoval ? '撤销移除' : '移除关联',
                      ),
                    ),
                  ),
                Button(
                  onPressed: canChoose
                      ? () => _run(() => _pickFile(links, episodes))
                      : null,
                  child: _fileActionLabel(FluentIcons.add, '添加文件'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (loading) ...[const ProgressBar(), const SizedBox(height: 8)],
        ],
        Flexible(
          flex: _editingFile ? 1 : 3,
          child: _editingFile
              ? _buildEpisodeGrid(
                  episodes,
                  validEpisode ? selectedEpisode : null,
                  effective?.episode,
                  linked,
                  rowExtent,
                  enabled: canSelectEpisode,
                )
              : files.isEmpty
              ? _buildEmptyFiles(loading, canChoose, links, episodes)
              : _buildFileList(
                  files,
                  selected,
                  links,
                  matched,
                  episodes,
                  rowExtent,
                ),
        ),
        if (!_editingFile && selected != null && widget.episode == null) ...[
          const SizedBox(height: 12),
          _buildEpisodeToolbar(
            episodes.length,
            selectedEpisode,
            enabled: canSelectEpisode,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _buildEpisodeGrid(
              episodes,
              validEpisode ? selectedEpisode : null,
              effective?.episode,
              linked,
              rowExtent,
              enabled: canSelectEpisode,
              maxRows: 3,
            ),
          ),
        ],
        if (widget.episode == null && selected != null) ...[
          const SizedBox(height: 8),
          Text(
            selectedEpisode == 0 && !unchanged
                ? '已选择不匹配，保存修正后生效。'
                : unchanged
                ? linked == null
                      ? '自动匹配已生效，无需保存。'
                      : '当前关联已保存。'
                : '选择剧集后保存关联。',
            style: BTTypography.caption(context),
          ),
        ],
        if (chapterData.hasError || linkData.hasError) ...[
          const SizedBox(height: 12),
          _buildFileError(
            '加载关联数据失败：'
            '${chapterData.error ?? linkData.error}',
            action: Button(
              onPressed: _busy
                  ? null
                  : () {
                      ref.invalidate(
                        subjectFileEpisodesProvider(widget.subject),
                      );
                      ref.invalidate(playbackEpisodeLinkSnapshotProvider);
                      unawaited(_loadFiles());
                    },
              child: const Text('重试'),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _buildFileError(_error!),
        ],
      ],
    );
    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: _editingFile ? 560 : 720,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      title: _buildFilesHeader(),
      content: _editingFile
          ? body
          : RadioGroup<String>(
              groupValue: selected == null
                  ? null
                  : PlaybackItem.pathKey(selected),
              onChanged: (key) {
                if (_busy || key == null) return;
                var file = files.firstWhere(
                  (file) => PlaybackItem.pathKey(file) == key,
                );
                _selectFile(file, links, episodes);
              },
              child: body,
            ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (linked?.subject == widget.subject &&
                (widget.episode == null ||
                    linked!.excluded ||
                    linked.episode == widget.episode!.id))
              Button(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await ref
                            .read(playbackEpisodeLinksProvider)
                            .remove(linked!);
                        if (mounted) {
                          setState(() {
                            _selectedEpisode = widget.episode?.id;
                          });
                        }
                      }),
                child: Text(
                  _editingFile || _automaticFiles.contains(linked!.key)
                      ? '恢复自动匹配'
                      : '解除手动关联',
                ),
              ),
            if (selected != null) ...[
              Button(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => openLocalPlayback(
                          context,
                          ref,
                          selected,
                          subject: widget.subject,
                        ),
                      ),
                child: _fileActionLabel(FluentIcons.play, '播放文件'),
              ),
              FilledButton(
                onPressed: canSave
                    ? () => _run(() async {
                        _selectedFile = selected;
                        _selectedEpisode = selectedEpisode;
                        await _save();
                      })
                    : null,
                child: const Text('保存修正'),
              ),
            ],
            Button(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ],
    );
  }
}
