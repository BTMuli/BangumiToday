// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/services/bt_engine_client.dart';
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/playback/playback_item.dart';
import '../../providers/download_subject_providers.dart';
import '../../store/bt_download_store.dart';
import '../playback/playback_actions.dart';
import 'download_playback_files.dart';

class DownloadTaskPlayButton extends ConsumerStatefulWidget {
  const DownloadTaskPlayButton({
    required this.task,
    required this.busy,
    super.key,
  });

  final BtTaskSnapshot task;
  final bool busy;

  @override
  ConsumerState<DownloadTaskPlayButton> createState() =>
      _DownloadTaskPlayButtonState();
}

class _DownloadTaskPlayButtonState
    extends ConsumerState<DownloadTaskPlayButton> {
  var _opening = false;

  Future<void> _play() async {
    if (_opening || widget.busy) return;
    setState(() => _opening = true);
    try {
      var task = widget.task;
      var subject = ref.read(
        downloadTaskSubjectProvider((
          taskId: task.id,
          savePath: task.savePath,
          manual: task.manual,
        )),
      );
      var downloads = ref.read(btDownloadStoreProvider.notifier);
      var items = await loadDownloadPlaybackFiles(
        task: task,
        readPage: (offset) => downloads.taskFiles(task.id, offset: offset),
        subject: subject,
      );
      if (!mounted) return;
      var selected = items.length == 1
          ? items.single
          : await _chooseVideo(items, task.savePath);
      if (selected == null || !mounted) return;
      await openLocalPlaybackFile(
        ref,
        selected.filePath,
        subject: selected.subject,
      );
    } catch (error) {
      if (mounted) await reportPlaybackError(context, ref, error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<PlaybackItem?> _chooseVideo(
    List<PlaybackItem> items,
    String directory,
  ) {
    var subdirectories = [
      for (var item in items)
        path.dirname(path.relative(item.filePath, from: directory)),
    ];
    var commonDirectory = subdirectories.toSet().length == 1
        ? subdirectories.first
        : null;
    var displayDirectory = commonDirectory == null || commonDirectory == '.'
        ? directory
        : path.join(directory, commonDirectory);
    return showDialog<PlaybackItem>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 760),
        title: const Text('选择要播放的视频'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${items.length} 个已下载完成的视频',
              style: BTTypography.caption(context),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 4),
            Tooltip(
              message: displayDirectory,
              child: Text(
                displayDirectory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: BTTypography.caption(context),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.55).clamp(
                  160,
                  440,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: BTColors.surfaceSecondary(context),
                    borderRadius: BTRadius.mediumBR,
                    border: Border.all(color: BTColors.divider(context)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        height: 1,
                        child: ColoredBox(color: BTColors.divider(context)),
                      ),
                    ),
                    itemBuilder: (context, index) => _DownloadVideoRow(
                      item: items[index],
                      subdirectory:
                          commonDirectory == null &&
                              subdirectories[index] != '.'
                          ? subdirectories[index]
                          : null,
                      onPressed: () => Navigator.of(context).pop(items[index]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var blocked = downloadPlaybackBlockedReason(widget.task);
    return Tooltip(
      message: _opening ? '正在打开视频' : blocked ?? '播放已下载的视频，多个视频可选择文件',
      child: SizedBox.square(
        dimension: 30,
        child: IconButton(
          onPressed: _opening || widget.busy || blocked != null ? null : _play,
          icon: _opening
              ? const SizedBox.square(
                  dimension: 14,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Icon(FluentIcons.play, size: 15),
        ),
      ),
    );
  }
}

class _DownloadVideoRow extends StatelessWidget {
  const _DownloadVideoRow({
    required this.item,
    required this.subdirectory,
    required this.onPressed,
  });

  final PlaybackItem item;
  final String? subdirectory;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Tooltip(
      message: item.filePath,
      child: HoverButton(
        semanticLabel: '播放 ${item.title}',
        onPressed: onPressed,
        builder: (context, states) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: states.isPressed
              ? accent.withValues(alpha: 0.16)
              : states.isHovered || states.isFocused
              ? accent.withValues(alpha: 0.08)
              : Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              children: [
                Icon(FluentIcons.play, size: 14, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: BTTypography.body(context),
                      ),
                      if (subdirectory != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subdirectory!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: BTTypography.caption(context),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: Text(
                    BTFileTool.formatSize(item.sizeBytes!),
                    textAlign: TextAlign.right,
                    style: BTTypography.caption(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
