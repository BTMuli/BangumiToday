import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/playback_window_service.dart';
import '../../store/playback_store.dart';
import '../../ui/bt_infobar.dart';
import 'playback_actions.dart';

/// The main window shows durable history and launch actions, never a Video.
class PlaybackEntrancePage extends ConsumerStatefulWidget {
  const PlaybackEntrancePage({super.key});
  @override
  ConsumerState<PlaybackEntrancePage> createState() =>
      _PlaybackEntrancePageState();
}

class _PlaybackEntrancePageState extends ConsumerState<PlaybackEntrancePage> {
  @override
  void initState() {
    super.initState();
    unawaited(_run(ref.read(playbackStoreProvider).refreshHistory));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    }
  }

  Future<void> _pickFile() async {
    var file = await pickPlaybackFile();
    if (file != null && mounted)
      await openLocalPlayback(context, ref, file.path);
  }

  @override
  Widget build(BuildContext context) {
    var store = ref.watch(playbackStoreProvider);
    var windows = ref.watch(playbackWindowServiceProvider);
    return ScaffoldPage(
      header: const PageHeader(title: Text('播放')),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: windows.isClosing
                    ? null
                    : () => _run(() => windows.open()),
                child: Text(windows.hasWindow ? '显示播放器' : '打开播放器'),
              ),
              Button(
                onPressed: windows.isClosing ? null : () => _run(_pickFile),
                child: const Text('打开本地视频'),
              ),
              Button(
                onPressed: () => _run(store.refreshHistory),
                child: const Text('刷新记录'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('视频在独立窗口播放，浏览主窗口时会继续播放。'),
          if (windows.error != null) ...[
            const SizedBox(height: 12),
            InfoBar(
              title: Text(windows.error!),
              severity: InfoBarSeverity.warning,
            ),
          ],
          const SizedBox(height: 24),
          const Text('最近播放'),
          const SizedBox(height: 12),
          Expanded(
            child: store.history.isEmpty
                ? const Center(child: Text('还没有播放记录'))
                : ListView.builder(
                    itemCount: store.history.length,
                    itemBuilder: (context, index) {
                      var item = store.history[index];
                      var minutes = Duration(
                        milliseconds: item.positionMs,
                      ).inMinutes;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Button(
                                onPressed: windows.isClosing
                                    ? null
                                    : () => resumeLocalPlayback(
                                        context,
                                        ref,
                                        item,
                                      ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        item.completed
                                            ? '已播完'
                                            : '上次播放到 $minutes 分钟',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: '删除播放记录',
                              child: IconButton(
                                icon: const Icon(FluentIcons.delete),
                                onPressed: windows.isClosing
                                    ? null
                                    : () => _run(
                                        () => windows.removeHistory(
                                          item.filePath,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
