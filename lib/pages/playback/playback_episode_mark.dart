// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/services/episode_mark_service.dart';
import '../../providers/episode_mark_providers.dart';
import '../../store/nav_store.dart';
import '../../store/playback_store.dart';
import '../../ui/bt_infobar.dart';

/// A notice never opens a dialog or requests focus until the user selects it.
class PlaybackEpisodeMarkPrompt extends ConsumerWidget {
  const PlaybackEpisodeMarkPrompt({super.key, this.beforeOpenSubject});

  final Future<void> Function()? beforeOpenSubject;

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    EpisodeMarkPrompt prompt,
  ) async {
    var controller = ref.read(episodeMarkProvider.notifier);
    var candidate = controller.beginConfirmation(prompt);
    if (candidate == null) return;
    var name = ref.read(playbackStoreProvider).nameFor(candidate.subject);
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          var state = dialogRef.watch(episodeMarkProvider);
          var valid =
              state.confirmingId == prompt.id &&
              state.prompts.any((item) => item.id == prompt.id) &&
              controller.currentAccount() == prompt.account;
          if (!valid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!dialogContext.mounted) return;
              var route = ModalRoute.of(dialogContext);
              if (route != null) Navigator.of(dialogContext).removeRoute(route);
            });
          }
          return ContentDialog(
            title: const Text('标记章节看过'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate.completion.item.title),
                const SizedBox(height: 12),
                Text(name ?? '条目 #${candidate.subject}'),
                Text('第 ${candidate.number} 话 · ${candidate.episode.name}'),
                const SizedBox(height: 12),
                const Text('播放已结束。确认后将此章节标记为看过。'),
              ],
            ),
            actions: [
              Button(
                child: const Text('取消'),
                onPressed: () => Navigator.pop(context, false),
              ),
              FilledButton(
                child: const Text('标记看过'),
                onPressed: valid ? () => Navigator.pop(context, true) : null,
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) {
      controller.dismiss(prompt.id);
      return;
    }
    var result = await controller.confirm(prompt);
    if (!context.mounted || result.status == EpisodeMarkWriteStatus.expired)
      return;
    if (result.status == EpisodeMarkWriteStatus.failed) {
      await BtInfobar.error(context, result.message ?? '标记失败，请重试');
    } else if (result.message != null) {
      await BtInfobar.error(context, result.message!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var state = ref.watch(episodeMarkProvider);
    if (state.prompts.isEmpty) return const SizedBox.shrink();
    var prompt = state.prompts.first;
    var busy = state.confirmingId != null;
    var controller = ref.read(episodeMarkProvider.notifier);
    var candidate = prompt.candidate;
    return InfoBar(
      title: Text('播放已结束 · ${prompt.completion.item.title}'),
      content: Text(
        prompt.loading
            ? '正在匹配章节…'
            : prompt.message ??
                  '是否将第 ${candidate!.number} 话「${candidate.episode.name}」标记看过？',
      ),
      severity: prompt.message == null
          ? InfoBarSeverity.info
          : InfoBarSeverity.warning,
      onClose: busy ? null : () => controller.dismiss(prompt.id),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (candidate != null)
            Button(
              onPressed: busy ? null : () => _confirm(context, ref, prompt),
              child: Text(prompt.retryable ? '重试确认' : '标记看过'),
            )
          else if (prompt.retryable)
            Button(
              onPressed: busy ? null : () => controller.retry(prompt),
              child: const Text('重试'),
            ),
          if (!prompt.loading) ...[
            const SizedBox(width: 8),
            Button(
              onPressed: busy
                  ? null
                  : () async {
                      var subject = prompt.completion.item.subject;
                      if (subject == null) return;
                      var navigation = ref.read(navStoreProvider.notifier);
                      controller.dismiss(prompt.id);
                      await beforeOpenSubject?.call();
                      navigation.addNavItemB(subject: subject);
                    },
              child: const Text('打开章节'),
            ),
          ],
        ],
      ),
    );
  }
}
