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
import '../../ui/bt_select.dart';
import '../playback/playback_actions.dart';

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
  final _fileScrollController = ScrollController();
  (String?, int, int, double, double)? _revealSignature;
  static const _fileRowExtent = 56.0;
  String? _directory;
  String? _selectedFile;
  int? _selectedEpisode;
  bool _loadingFiles = true;
  bool _busy = false;
  String? _error;
  String? _notice;

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
    _fileScrollController.dispose();
    super.dispose();
  }

  void _revealSelectedFile(
    List<String> files,
    String? selected,
    double rowExtent,
    double viewportHeight,
  ) {
    var key = selected == null ? null : PlaybackItem.pathKey(selected);
    var index = files.indexWhere((file) => PlaybackItem.pathKey(file) == key);
    var signature = (key, index, files.length, rowExtent, viewportHeight);
    if (_revealSignature == signature) return;
    _revealSignature = signature;
    if (index < 0) return;
    // Lazy lists have not built distant rows; use their exact fixed extent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _revealSignature != signature ||
          !_fileScrollController.hasClients) {
        return;
      }
      var position = _fileScrollController.position;
      if (!position.hasContentDimensions) return;
      var top = index * rowExtent;
      if (top >= position.pixels &&
          top + rowExtent <= position.pixels + position.viewportDimension) {
        return;
      }
      var offset = top - (position.viewportDimension - rowExtent) / 2;
      _fileScrollController.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
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
          _selectedEpisode = linked!.episode;
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
          (linked?.subject == widget.subject ? linked?.episode : inferred?.id);
      _notice = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
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
    var episode = _selectedEpisode!;
    var storage = ref.read(playbackEpisodeLinksProvider);
    var existing = (await storage.readAll())[PlaybackItem.pathKey(file)];
    if (!mounted) return;
    if (existing != null &&
        (existing.subject != widget.subject || existing.episode != episode)) {
      var confirmed = await showConfirm(
        context,
        title: '修改文件关联',
        content: '该文件已关联其他章节，确定改为当前章节吗？',
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
    if (mounted) setState(() => _notice = '已保存关联');
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
      files: _files.values.where(
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
        (selected == null
            ? null
            : matched[PlaybackItem.pathKey(selected)]?.episode);
    var validEpisode = episodes.any((e) => e.id == selectedEpisode);
    var effective = selected == null
        ? null
        : matched[PlaybackItem.pathKey(selected)];
    var unchanged = effective != null && effective.episode == selectedEpisode;
    var loading = _loadingFiles || chapterData.isLoading || linkData.isLoading;
    var rowExtent = MediaQuery.textScalerOf(
      context,
    ).scale(_fileRowExtent).clamp(_fileRowExtent, double.infinity);
    var canSave =
        !_busy &&
        !loading &&
        !linkData.hasError &&
        selected != null &&
        validEpisode &&
        !unchanged;
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 760),
      title: Text(
        widget.episode == null
            ? '章节文件与自动匹配'
            : '${subjectFileEpisodeLabel(widget.episode!)} · 本地文件',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        height: (MediaQuery.sizeOf(context).height - 260)
            .clamp(180, 430)
            .toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '下载目录中的视频会自动匹配章节，无需逐集保存。'
              '识别失败或有误时再手动修正。',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('已匹配 ${linkedFiles.length} 个文件')),
                Tooltip(
                  message: '重新扫描目录',
                  child: IconButton(
                    icon: const Icon(FluentIcons.refresh, size: 16),
                    onPressed: _busy || loading
                        ? null
                        : () => _run(() async {
                            ref.invalidate(
                              subjectPlaybackFilesProvider(widget.subject),
                            );
                            await _loadFiles();
                          }),
                  ),
                ),
                Button(
                  onPressed: _busy || loading
                      ? null
                      : () => _run(_chooseDirectory),
                  child: const Text('选择目录…'),
                ),
                const SizedBox(width: 8),
                Button(
                  onPressed: _busy || loading
                      ? null
                      : () => _run(() => _pickFile(links, episodes)),
                  child: const Text('选择其他文件…'),
                ),
              ],
            ),
            if (_directory != null) ...[
              const SizedBox(height: 8),
              Text(_directory!, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            if (loading) const ProgressBar(),
            Expanded(
              child: files.isEmpty
                  ? const Center(child: Text('暂无视频文件，请选择本地文件'))
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
                      child: LayoutBuilder(
                        builder: (_, constraints) {
                          _revealSelectedFile(
                            files,
                            selected,
                            rowExtent,
                            constraints.maxHeight,
                          );
                          return ListView.builder(
                            controller: _fileScrollController,
                            padding: EdgeInsets.zero,
                            itemExtent: rowExtent,
                            itemCount: files.length,
                            itemBuilder: (_, index) {
                              var file = files[index];
                              var link = links[PlaybackItem.pathKey(file)];
                              var effective =
                                  matched[PlaybackItem.pathKey(file)];
                              var chapter = episodes
                                  .where((e) => e.id == effective?.episode)
                                  .firstOrNull;
                              var chapterLabel = chapter == null
                                  ? null
                                  : subjectFileEpisodeLabel(chapter);
                              var label = link == null
                                  ? chapter == null
                                        ? '未能自动匹配，可手动选择章节'
                                        : '自动匹配：$chapterLabel'
                                  : link.subject != widget.subject
                                  ? '已关联其他条目'
                                  : chapter == null
                                  ? '关联章节已不存在'
                                  : '手动修正：$chapterLabel';
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Tooltip(
                                  message: file,
                                  child: RadioButton<String>(
                                    value: PlaybackItem.pathKey(file),
                                    enabled: !_busy,
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          path.basename(file),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: FluentTheme.of(
                                            context,
                                          ).typography.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            if (widget.episode == null)
              BtSelect<int>(
                value: validEpisode ? selectedEpisode : null,
                isExpanded: true,
                items: [
                  for (var episode in episodes)
                    ComboBoxItem(
                      value: episode.id,
                      child: Text(
                        subjectFileEpisodeLabel(episode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy || selected == null
                    ? null
                    : (value) => setState(() {
                        _selectedFile = selected;
                        _selectedEpisode = value;
                      }),
              ),
            if (chapterData.hasError || linkData.hasError) ...[
              const SizedBox(height: 8),
              Text(
                '加载关联数据失败：'
                '${chapterData.error ?? linkData.error}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              Button(
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
            ],
            if (_error != null || _notice != null) ...[
              const SizedBox(height: 8),
              Text(
                _error ?? _notice!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (linked?.subject == widget.subject &&
            (widget.episode == null || linked?.episode == widget.episode!.id))
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
                        _notice = '已清除手动修正';
                      });
                    }
                  }),
            child: Text(
              _automaticFiles.contains(linked!.key) ? '恢复自动匹配' : '解除手动关联',
            ),
          ),
        Button(
          onPressed: _busy || selected == null
              ? null
              : () => _run(
                  () => openLocalPlayback(
                    context,
                    ref,
                    selected,
                    subject: widget.subject,
                  ),
                ),
          child: const Text('播放文件'),
        ),
        FilledButton(
          onPressed: canSave
              ? () => _run(() async {
                  _selectedFile = selected;
                  _selectedEpisode = selectedEpisode;
                  await _save();
                })
              : null,
          child: Text(unchanged && linked == null ? '自动匹配已生效' : '保存修正'),
        ),
        Button(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
