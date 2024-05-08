// Flutter imports:
import 'package:flutter/material.dart' as material;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pasteboard/pasteboard.dart';

// Project imports:
import '../../components/app/app_infobar.dart';
import '../../components/base/base_theme_icon.dart';
import '../../store/play_store.dart';
import '../../tools/file_tool.dart';
import '../../tools/log_tool.dart';

class BtcVideo extends StatefulWidget {
  /// controller
  final VideoController controller;

  /// 构造函数
  const BtcVideo(this.controller, {super.key});

  @override
  State<BtcVideo> createState() => _BtcVideoState();
}

class _BtcVideoState extends State<BtcVideo> {
  /// 控制器
  VideoController get controller => widget.controller;

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// 当前播放速度
  double speed = 1.0;

  // 当前字幕
  SubtitleTrack? subtitle;

  /// hive
  final PlayHive hive = PlayHive();

  /// 速度的flyout
  final FlyoutController flyout = FlyoutController();

  /// 字幕
  List<SubtitleTrack> get subtitles => controller.player.state.tracks.subtitle;

  @override
  void initState() {
    super.initState();
    speed = controller.player.state.rate;
    if (subtitles.isNotEmpty) {
      subtitle = subtitles.first;
    }
    setState(() {});
  }

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
        await controller.player.setSubtitleTrack(v);
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
        speed = value;
        setState(() {});
        await controller.player.setRate(value);
      },
    );
  }

  /// 构建截图
  Future<void> takeScreenshot() async {
    await controller.player.pause();
    var progress = controller.player.state.position.inSeconds;
    var index = controller.player.state.playlist.index;
    var file = controller.player.state.playlist.medias[index].uri;
    var name = Uri.parse(file).pathSegments.last;
    var res = await controller.player.screenshot();
    if (res == null) {
      if (mounted) await BtInfobar.error(context, '截图失败');
      await controller.player.play();
      return;
    }
    var imagePath = await fileTool.writeTempImage(res, name, progress);
    // 提前写个空白文件，以防粘贴把之前的文本带上
    // todo 详见 https://github.com/MixinNetwork/flutter-plugins/issues/335
    Pasteboard.writeText('');
    var check = await Pasteboard.writeFiles([imagePath]);
    if (!check) {
      if (mounted) await BtInfobar.error(context, '截图失败');
      await controller.player.play();
      return;
    }
    if (mounted) await BtInfobar.success(context, '截图已复制到剪贴板');
    await controller.player.play();
  }

  /// 保存当前进度
  Future<void> saveProgress() async {
    var progress = controller.player.state.position.inMilliseconds;
    var index = controller.player.state.playlist.index;
    await hive.updateProgress(progress, index);
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
            var index = controller.player.state.playlist.index;
            await saveProgress();
            if (index == 0) {
              if (mounted) await BtInfobar.warn(context, '已经是第一个了');
              return;
            }
            await controller.player.previous();
            await controller.player.stream.buffer.first;
            var progress = hive.getProgress(index - 1);
            if (progress != 0) {
              BTLogTool.info('跳转到上次播放进度: $progress');
              await controller.player.seek(Duration(milliseconds: progress));
            }
            setState(() {});
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.play),
          onPressed: () async {
            var isPlaying = controller.player.state.playing;
            if (isPlaying) {
              await controller.player.pause();
              await saveProgress();
            } else {
              await controller.player.play();
            }
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.chevron_right_end6),
          onPressed: () async {
            var total = controller.player.state.playlist.medias.length;
            var index = controller.player.state.playlist.index;
            await saveProgress();
            if (index == total - 1) {
              if (mounted) await BtInfobar.warn(context, '已经是最后一个了');
              return;
            }
            await controller.player.next();
            await controller.player.stream.buffer.first;
            var progress = hive.getProgress(index + 1);
            if (progress != 0) {
              BTLogTool.info('跳转到上次播放进度: $progress');
              await controller.player.seek(Duration(milliseconds: progress));
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
          controller: controller,
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
