// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../models/playback/playback_item.dart';
import '../../providers/subject_playback_providers.dart';
import '../playback/playback_actions.dart';
import '../playback/playback_label.dart';

/// 收藏与观看进度旁的本地续播入口，无记录时隐藏。
class SubjectContinuePlaybackButton extends ConsumerStatefulWidget {
  const SubjectContinuePlaybackButton({super.key, required this.subject});

  final int subject;

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
    var item = ref.watch(subjectPlaybackHistoryProvider(widget.subject)).value;
    if (item == null) return const SizedBox.shrink();
    var label = PlaybackLabel.fromName(item.title, filePath: item.filePath);
    var action = item.completed ? '重新播放' : '继续播放';
    var progress = item.completed
        ? '上次已播完，将从头播放'
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
