// Flutter imports:
import 'package:flutter/material.dart' as material;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pasteboard/pasteboard.dart';

// Project imports:
import '../../../components/app/app_dialog.dart';
import '../../../components/app/app_infobar.dart';
import '../../../components/base/base_theme_icon.dart';
import '../../../request/source/danmaku_api.dart';
import '../../../store/danmaku_hive.dart';
import '../../../store/play_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/log_tool.dart';
import 'play_controller.dart';

class PlayVideoWidget extends ConsumerStatefulWidget {
  /// 构造函数
  const PlayVideoWidget({super.key});

  @override
  ConsumerState<PlayVideoWidget> createState() => _PlayVideoWidgetState();
}

class _PlayVideoWidgetState extends ConsumerState<PlayVideoWidget> {
  /// Player
  BtPlayer get player => ref.watch(playControllerProvider).player;

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// 当前播放速度
  double get speed => player.state.rate;

  // 当前字幕
  SubtitleTrack? subtitle;

  /// PlayHive
  final PlayHive hivePlay = PlayHive();

  /// 弹幕Hive
  final DanmakuHive hiveDanmaku = DanmakuHive();

  /// 速度的flyout
  final FlyoutController flyout = FlyoutController();

  /// 字幕
  List<SubtitleTrack> get subtitles => player.state.tracks.subtitle;

  /// 弹幕 api
  final BtrDanmakuAPI danmakuApi = BtrDanmakuAPI();

  @override
  void dispose() {
    flyout.dispose();
    super.dispose();
  }

  /// 显示字幕flyout
  void showSubtitleFlyout() {
    flyout.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => MenuFlyout(
        items: subtitles.map(buildSubtitleButton).toList(),
      ),
    );
  }

  /// 构建字幕按钮
  MenuFlyoutItem buildSubtitleButton(SubtitleTrack v) {
    return MenuFlyoutItem(
      leading: v == subtitle ? const BaseThemeIcon(material.Icons.check) : null,
      selected: v == subtitle,
      text: Text('${v.id} ${v.language} ${v.title}'),
      onPressed: () async {
        await player.setSubtitleTrack(v);
        subtitle = v;
        setState(() {});
      },
    );
  }

  /// 根据速度获取对应文本
  String getSpeedLabel(double val) {
    if (val == 2.0) return '2.0倍速';
    if (val == 1.5) return '1.5倍速';
    if (val == 1.25) return '1.25倍速';
    if (val == 1.0) return '1.0倍速';
    return '${val.toStringAsFixed(2)}倍速';
  }

  /// 根据速度获取对应图标
  IconData getSpeedIcon(double val) {
    if (val == 2.0) return FluentIcons.fast_forward_two_x;
    if (val == 1.5) return FluentIcons.fast_forward_one_five_x;
    if (val == 1.25) return FluentIcons.fast_forward;
    if (val == 1.0) return FluentIcons.fast_forward_one_x;
    return FluentIcons.fast_forward;
  }

  /// 显示速度flyout
  void showSpeedFlyout() {
    flyout.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) {
        return MenuFlyout(items: [
          buildSpeedButton(2.0),
          buildSpeedButton(1.5),
          buildSpeedButton(1.25),
          buildSpeedButton(1.0),
        ]);
      },
    );
  }

  /// 构建速度按钮
  MenuFlyoutItem buildSpeedButton(double value) {
    return MenuFlyoutItem(
      leading:
          value == speed ? const BaseThemeIcon(material.Icons.check) : null,
      selected: value == speed,
      trailing: BaseThemeIcon(getSpeedIcon(value)),
      text: Text(getSpeedLabel(value)),
      onPressed: () async {
        ref.read(playControllerProvider.notifier).setSpeed(value);
      },
    );
  }

  /// 构建截图
  Future<void> takeScreenshot() async {
    await player.pause();
    var progress = player.state.position.inSeconds;
    var index = player.state.playlist.index;
    var file = player.state.playlist.medias[index].uri;
    var name = Uri.parse(file).pathSegments.last;
    var res = await player.screenshot();
    if (res == null) {
      if (mounted) await BtInfobar.error(context, '截图失败');
      await player.play();
      return;
    }
    var imagePath = await fileTool.writeTempImage(res, name, progress);
    // 提前写个空白文件，以防粘贴把之前的文本带上
    // todo 详见 https://github.com/MixinNetwork/flutter-plugins/issues/335
    Pasteboard.writeText('');
    var check = await Pasteboard.writeFiles([imagePath]);
    if (!check) {
      if (mounted) await BtInfobar.error(context, '截图失败');
      await player.play();
      return;
    }
    if (mounted) await BtInfobar.success(context, '截图已复制到剪贴板');
    await player.play();
  }

  /// 保存当前进度
  Future<void> saveProgress() async {
    var progress = player.state.position.inMilliseconds;
    var index = player.state.playlist.index;
    await hivePlay.updateProgress(progress, index);
  }

  /// 控制栏的数据构建
  /// todo，这边的 widget 似乎不会改变，详见 https://github.com/media-kit/media-kit/issues/808
  MaterialDesktopVideoControlsThemeData buildControls() {
    var base = FluentTheme.of(context).accentColor;
    return MaterialDesktopVideoControlsThemeData(
      seekBarThumbColor: base.lighter,
      seekBarPositionColor: base.darker,
      bottomButtonBar: [
        IconButton(
          icon: const Icon(FluentIcons.chevron_left_end6),
          onPressed: () async {
            var index = player.state.playlist.index;
            await saveProgress();
            if (index == 0) {
              if (mounted) await BtInfobar.warn(context, '已经是第一个了');
              return;
            }
            await player.previous();
            await player.stream.buffer.first;
            var progress = hivePlay.getProgress(index - 1);
            if (progress != 0) {
              BTLogTool.info('跳转到上次播放进度: $progress');
              await player.seek(Duration(milliseconds: progress));
            }
            setState(() {});
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.play),
          onPressed: () async {
            var isPlaying = player.state.playing;
            if (isPlaying) {
              await player.pause();
              await saveProgress();
            } else {
              await player.play();
            }
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.chevron_right_end6),
          onPressed: () async {
            var total = player.state.playlist.medias.length;
            var index = player.state.playlist.index;
            await saveProgress();
            if (index == total - 1) {
              if (mounted) await BtInfobar.warn(context, '已经是最后一个了');
              return;
            }
            await player.next();
            await player.stream.buffer.first;
            var progress = hivePlay.getProgress(index + 1);
            if (progress != 0) {
              BTLogTool.info('跳转到上次播放进度: $progress');
              await player.seek(Duration(milliseconds: progress));
            }
            setState(() {});
          },
        ),
        const MaterialDesktopPositionIndicator(),
        const MaterialDesktopVolumeButton(),
        const Spacer(),
        // todo 字幕获取存在问题，详见 https://github.com/media-kit/media-kit/issues/807
        if (subtitles.isNotEmpty)
          FlyoutTarget(
            controller: flyout,
            child: IconButton(
              icon: const Icon(material.Icons.closed_caption, size: 24),
              onPressed: showSubtitleFlyout,
            ),
          ),
        IconButton(
          onPressed: () async => await takeScreenshot(),
          icon: const Icon(FluentIcons.camera, size: 24),
        ),
        FlyoutTarget(
          controller: flyout,
          child: IconButton(
            icon: const Icon(material.Icons.fast_forward, size: 24),
            onPressed: showSpeedFlyout,
          ),
        ),
        const MaterialDesktopFullscreenButton(),
        IconButton(
          icon: const Icon(FluentIcons.comment),
          onPressed: () async {
            /// 获取当前播放的model
            var cur = hivePlay.all[player.state.playlist.index];
            if (cur.danmakuId == null || cur.danmakuId == -1) {
              /// 查询 animeId
              var animeFind = hiveDanmaku.findBySubject(cur.subjectId);
              if (animeFind == null || animeFind.animeId == null) {
                await BtInfobar.error(context, '未找到对应弹幕');
              }
              if (mounted) {
                var input = await showInputDialog(
                  context,
                  title: '集数',
                  content: '请输入对应集数',
                );
                if (input == null || input.isEmpty) return;
                if (!int.tryParse(input, radix: 10)!.isFinite) {
                  if (mounted) await BtInfobar.error(context, '请输入数字');
                  return;
                }
                var episode = animeFind!.animeId! * 10000 + int.parse(input);
                var comments = await danmakuApi.getDanmaku2(episode);
                if (comments.isEmpty && mounted) {
                  await BtInfobar.error(context, '未找到对应弹幕');
                  return;
                }
                player.addDanmaku(comments);
                ref.read(playControllerProvider.notifier).toggleDanmaku();
              }
              return;
            }
            ref.read(playControllerProvider.notifier).toggleDanmaku();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialDesktopVideoControlsTheme(
      normal: buildControls(),
      fullscreen: buildControls(),
      child: material.Scaffold(
        body: Video(
          controller: ref.watch(playControllerProvider).video,
          // 对于部分字幕无法处理，详见 https://github.com/media-kit/media-kit/issues/805
          subtitleViewConfiguration: SubtitleViewConfiguration(
            style: TextStyle(
              fontFamily: 'SMonoSC',
              fontSize: 28,
              backgroundColor: Colors.black.withOpacity(0.5),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ),
    );
  }
}
