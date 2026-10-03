import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/theme/bt_theme.dart';
import '../../models/playback/playback_item.dart';
import '../../store/nav_store.dart';
import '../../store/playback_store.dart';
import '../../ui/bt_infobar.dart';
import 'playback_actions.dart';

class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({super.key});

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  late final PlaybackStore _store;
  late final BTNavStore _nav;
  bool _wasActive = true;

  @override
  void initState() {
    super.initState();
    _store = ref.read(playbackStoreProvider);
    _nav = ref.read(navStoreProvider);
    _nav.addListener(_onNavigation);
    unawaited(_run(_store.refreshHistory));
  }

  void _onNavigation() {
    var active = _nav.curIndex == _nav.playbackIndex;
    if (_wasActive && !active) unawaited(_run(_store.pause));
    _wasActive = active;
  }

  @override
  void dispose() {
    _nav.removeListener(_onNavigation);
    unawaited(_store.pause().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    }
  }

  Future<void> _pickFile() async {
    var file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: '视频',
          extensions: [
            'mp4',
            'mkv',
            'avi',
            'mov',
            'webm',
            'm4v',
            'ts',
            'm2ts',
            'wmv',
            'flv',
            'mpg',
            'mpeg',
          ],
        ),
      ],
    );
    if (file != null && mounted) {
      await openLocalPlayback(context, ref, file.path);
    }
  }

  Future<void> _pickSubtitle() async {
    var file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: '字幕',
          extensions: ['ass', 'ssa', 'srt', 'vtt', 'sub'],
        ),
      ],
    );
    if (file != null) {
      await _store.player?.setSubtitleTrack(SubtitleTrack.uri(file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    var store = ref.watch(playbackStoreProvider);
    var current = store.current;
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('播放'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Button(
              onPressed: () => _run(_pickFile),
              child: const Text('打开本地视频'),
            ),
            if (current != null) ...[
              const SizedBox(width: 8),
              Button(
                onPressed: () => _run(store.stop),
                child: const Text('停止播放'),
              ),
            ],
          ],
        ),
      ),
      content: LayoutBuilder(
        builder: (context, constraints) {
          var side = _buildSide(store);
          var main = Column(
            children: [
              if (store.error != null)
                InfoBar(
                  title: const Text('播放失败'),
                  content: Text(store.error!),
                  severity: InfoBarSeverity.error,
                ),
              if (current != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    current.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Expanded(
                child: current == null || store.video == null
                    ? const Center(child: Text('从 BMF、下载详情或最近播放打开视频'))
                    : material.Theme(
                        data: material.ThemeData.dark(),
                        child: material.Material(
                          color: material.Colors.black,
                          child: Video(
                            controller: store.video!,
                            controls: MaterialDesktopVideoControls,
                          ),
                        ),
                      ),
              ),
              if (current != null && store.player != null)
                _buildControls(store.player!),
            ],
          );
          if (constraints.maxWidth < 850) {
            return Column(
              children: [
                Expanded(child: main),
                SizedBox(height: 190, child: side),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: main),
              const SizedBox(width: 12),
              SizedBox(width: 300, child: side),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls(Player player) => StreamBuilder<bool>(
    stream: player.stream.playing,
    initialData: player.state.playing,
    builder: (context, playing) => Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Button(
            key: const ValueKey('playback-toggle'),
            onPressed: () => _run(() async {
              if (player.state.playing)
                await _store.pause();
              else
                await player.play();
            }),
            child: Text(playing.data == true ? '暂停' : '继续播放'),
          ),
          Button(
            onPressed: () => _run(
              () => player.seek(
                player.state.position > const Duration(seconds: 10)
                    ? player.state.position - const Duration(seconds: 10)
                    : Duration.zero,
              ),
            ),
            child: const Text('后退 10 秒'),
          ),
          Button(
            onPressed: () => _run(
              () => player.seek(
                player.state.position + const Duration(seconds: 10) <
                        player.state.duration
                    ? player.state.position + const Duration(seconds: 10)
                    : player.state.duration,
              ),
            ),
            child: const Text('前进 10 秒'),
          ),
          StreamBuilder<double>(
            stream: player.stream.rate,
            initialData: player.state.rate,
            builder: (context, rate) => ComboBox<double>(
              value: rate.data,
              items: [
                for (var value in [0.5, 1.0, 1.25, 1.5, 2.0])
                  ComboBoxItem(value: value, child: Text('${value}x')),
              ],
              onChanged: (value) {
                if (value != null) unawaited(_run(() => player.setRate(value)));
              },
            ),
          ),
          Button(
            onPressed: () => _run(_pickSubtitle),
            child: const Text('加载字幕'),
          ),
          StreamBuilder<Tracks>(
            stream: player.stream.tracks,
            initialData: player.state.tracks,
            builder: (context, tracks) => Wrap(
              spacing: 8,
              children: [
                DropDownButton(
                  title: const Text('音轨'),
                  items: [
                    for (var track in tracks.data?.audio ?? <AudioTrack>[])
                      MenuFlyoutItem(
                        text: Text(track.title ?? track.language ?? track.id),
                        onPressed: () =>
                            _run(() => player.setAudioTrack(track)),
                      ),
                  ],
                ),
                DropDownButton(
                  title: const Text('字幕轨道'),
                  items: [
                    for (var track
                        in tracks.data?.subtitle ?? <SubtitleTrack>[])
                      MenuFlyoutItem(
                        text: Text(
                          track.id == 'no'
                              ? '关闭字幕'
                              : track.title ?? track.language ?? track.id,
                        ),
                        onPressed: () =>
                            _run(() => player.setSubtitleTrack(track)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSide(PlaybackStore store) => ListView(
    padding: const EdgeInsets.only(right: 12),
    children: [
      Text('播放列表', style: BTTypography.subtitle(context)),
      if (store.playlist.isEmpty)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('打开视频后显示同目录已完成文件'),
        ),
      for (var i = 0; i < store.playlist.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Button(
            onPressed: store.loading ? null : () => _run(() => store.jump(i)),
            child: Row(
              children: [
                Icon(
                  i == store.index ? FluentIcons.play : FluentIcons.video,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    store.playlist[i].title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      Text('最近播放', style: BTTypography.subtitle(context)),
      if (store.history.isEmpty)
        const Padding(padding: EdgeInsets.all(8), child: Text('暂无播放记录')),
      for (var item in store.history) _historyCard(item),
    ],
  );

  Widget _historyCard(PlaybackItem item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: item.filePath,
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            item.completed
                ? '已看完'
                : '已观看 ${_time(item.positionMs)} / ${_time(item.durationMs)}',
          ),
          Wrap(
            spacing: 8,
            children: [
              Button(
                onPressed: () => resumeLocalPlayback(context, ref, item),
                child: Text(item.completed ? '重新播放' : '继续观看'),
              ),
              if (item.subject != null)
                IconButton(
                  icon: const Icon(FluentIcons.info),
                  onPressed: () => ref
                      .read(navStoreProvider)
                      .addNavItemB(subject: item.subject!),
                ),
              Tooltip(
                message: '移除记录',
                child: IconButton(
                  icon: const Icon(FluentIcons.delete),
                  onPressed: () =>
                      _run(() => _store.removeHistory(item.filePath)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static String _time(int milliseconds) {
    var seconds = milliseconds ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
