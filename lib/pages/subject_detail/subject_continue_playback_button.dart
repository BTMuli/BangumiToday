// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../models/playback/playback_item.dart';
import '../../providers/subject_playback_providers.dart';
import '../playback/playback_actions.dart';
import '../playback/playback_label.dart';

/// 续播未看完的历史章节，已看完时选择后续匹配章节。
class SubjectContinuePlaybackButton extends ConsumerStatefulWidget {
  const SubjectContinuePlaybackButton({
    super.key,
    required this.subject,
    required this.watchedEpisodes,
  });

  final int subject;
  final int watchedEpisodes;

  @override
  ConsumerState<SubjectContinuePlaybackButton> createState() =>
      _SubjectContinuePlaybackButtonState();
}

class _SubjectContinuePlaybackButtonState
    extends ConsumerState<SubjectContinuePlaybackButton> {
  bool _opening = false;

  Future<void> _resume(PlaybackItem item) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await resumeLocalPlayback(context, ref, item);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var history = ref.watch(subjectPlaybackHistoryProvider(widget.subject));
    if (!history.hasValue) return const SizedBox.shrink();
    var previous = history.value;
    var fileData = ref.watch(subjectPlaybackFilesProvider(widget.subject));
    if (fileData.hasError) return const SizedBox.shrink();
    var files = fileData.value;
    if (files == null) return const SizedBox.shrink();
    var previousAvailable =
        previous != null && files.any((file) => file.key == previous.key);
    var item = ref
        .watch(
          subjectContinuePlaybackItemProvider((
            subject: widget.subject,
            watchedEpisodes: widget.watchedEpisodes,
          )),
        )
        .value;
    if (item == null || !files.any((file) => file.key == item.key)) {
      return const SizedBox.shrink();
    }
    var canResume = previousAvailable && previous.key == item.key;
    var label = PlaybackLabel.fromName(item.title, filePath: item.filePath);
    var action = previous != null || widget.watchedEpisodes > 0
        ? '继续播放'
        : '开始播放';
    var progress = !canResume
        ? [
            previous == null
                ? '尚无播放记录'
                : previousAvailable
                ? '上次播放的章节已看完'
                : '上次播放文件不可用',
            previousAvailable
                ? '将播放下一个匹配章节'
                : widget.watchedEpisodes > 0
                ? '账号已看到第 ${widget.watchedEpisodes} 话，将播放下一个匹配正片章节'
                : '将播放首个匹配章节',
          ].join('，')
        : [
            '上次播放到 ${_time(item.resumePosition)}',
            if (item.durationMs > 0)
              _time(Duration(milliseconds: item.durationMs)),
          ].join(' / ');
    return Tooltip(
      message: [
        _opening ? '正在打开视频' : action,
        ?label.episode,
        progress,
        item.filePath,
      ].join('\n'),
      child: Semantics(
        label: _opening ? '正在打开视频' : action,
        child: IconButton(
          icon: _opening
              ? const SizedBox.square(
                  dimension: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Icon(FluentIcons.play, size: 16),
          onPressed: _opening ? null : () => _resume(item),
        ),
      ),
    );
  }

  static String _time(Duration value) {
    var hours = value.inHours;
    var minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    var seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
