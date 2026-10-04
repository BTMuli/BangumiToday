// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/services/episode_mark_service.dart';
import '../../models/playback/playback_item.dart';
import '../../providers/episode_mark_providers.dart';
import '../../ui/bt_infobar.dart';

/// A row action always captures its own file, even while auto-advance changes
/// the currently playing video. Remote watched status is separate from EOF.
class PlaybackEpisodeMarkButton extends ConsumerStatefulWidget {
  const PlaybackEpisodeMarkButton({
    super.key,
    required this.item,
    this.compact = false,
    this.reveal = true,
  });

  final PlaybackItem item;
  final bool compact;
  final bool reveal;

  @override
  ConsumerState<PlaybackEpisodeMarkButton> createState() =>
      _PlaybackEpisodeMarkButtonState();
}

class _PlaybackEpisodeMarkButtonState
    extends ConsumerState<PlaybackEpisodeMarkButton> {
  bool _busy = false;

  Future<void> _markWatched() async {
    if (_busy) return;
    var item = widget.item;
    var controller = ref.read(episodeMarkProvider.notifier);
    setState(() => _busy = true);
    try {
      var result = await controller.markItem(item);
      if (!mounted) return;
      switch (result.status) {
        case EpisodeMarkWriteStatus.failed:
          await BtInfobar.error(context, result.message ?? '标记失败，请重试');
        case EpisodeMarkWriteStatus.expired:
          await BtInfobar.warn(context, '账户或播放器状态已变化，请重试');
        case EpisodeMarkWriteStatus.marked:
        case EpisodeMarkWriteStatus.alreadyDone:
          if (result.message != null) {
            await BtInfobar.warn(context, result.message!);
          } else {
            await BtInfobar.success(
              context,
              result.status == EpisodeMarkWriteStatus.alreadyDone
                  ? '该章节已经标记看过'
                  : '已标记看过',
            );
          }
      }
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var associated = (widget.item.subject ?? 0) > 0;
    var progress = ref.watch(episodeMarkProvider);
    var key = EpisodeMarkState.itemKey(widget.item);
    var marked = progress.marked.contains(key);
    var checked = progress.checked.contains(key);
    var loading = progress.loading.contains(key);
    var visible = !widget.compact || widget.reveal || _busy || marked;
    return IgnorePointer(
      ignoring: !visible,
      child: Opacity(
        opacity: visible ? 1 : 0,
        child: Tooltip(
          message: !associated
              ? '未关联番剧，无法标记章节看过'
              : _busy
              ? '正在标记看过…'
              : marked
              ? '已标记看过'
              : loading
              ? '正在读取条目观看进度…'
              : !checked
              ? '观看进度尚未确认，点击时读取并标记看过'
              : '标记看过',
          child: IconButton(
            style: widget.compact
                ? ButtonStyle(
                    padding: WidgetStateProperty.all(const EdgeInsets.all(2)),
                  )
                : null,
            icon: _busy || (loading && !checked)
                ? const SizedBox(width: 14, height: 14, child: ProgressRing())
                : Icon(
                    marked
                        ? FluentIcons.completed_solid
                        : FluentIcons.completed,
                    size: 14,
                    color: marked ? FluentTheme.of(context).accentColor : null,
                  ),
            onPressed: associated && !_busy ? _markWatched : null,
          ),
        ),
      ),
    );
  }
}
