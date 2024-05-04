// Flutter imports:
import 'package:flutter/material.dart' as material;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pasteboard/pasteboard.dart';

// Project imports:
import '../../components/app/app_infobar.dart';
import '../../tools/file_tool.dart';

class BtcVideo extends StatefulWidget {
  /// controller
  final VideoController controller;

  /// 构造函数
  const BtcVideo(this.controller, {super.key});

  @override
  State<BtcVideo> createState() => _BtcVideoState();
}

class _BtcVideoState extends State<BtcVideo>
    with material.AutomaticKeepAliveClientMixin {
  /// 控制器
  VideoController get controller => widget.controller;

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// 当前播放速度
  double speed = 1.0;

  /// 速度的flyout
  final FlyoutController speedFlyout = FlyoutController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    speed = controller.player.state.rate;
  }

  @override
  void dispose() {
    speedFlyout.dispose();
    super.dispose();
  }

  /// 根据速度获取对应文本
  String getSpeedLabel(double val) {
    if (val == 2.0) return '2.0倍速';
    if (val == 1.5) return '1.5倍速';
    if (val == 1.25) return '1.25倍速';
    if (val == 1.0) return '1.0倍速';
    return '${val.toStringAsFixed(2)}倍速';
  }

  /// 显示速度flyout
  void showSpeedFlyout() {
    speedFlyout.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: true,
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
      leading: value == speed ? const Icon(material.Icons.check) : null,
      text: Text(getSpeedLabel(value)),
      onPressed: () async {
        speed = value;
        setState(() {});
        await controller.player.setRate(value);
      },
    );
  }

  /// 控制栏的数据构建
  MaterialDesktopVideoControlsThemeData buildControls() {
    var base = FluentTheme.of(context).accentColor;
    return MaterialDesktopVideoControlsThemeData(
      seekBarThumbColor: base.lighter,
      seekBarPositionColor: base.darker,
      bottomButtonBar: [
        const MaterialDesktopSkipPreviousButton(),
        const MaterialDesktopPlayOrPauseButton(),
        const MaterialDesktopSkipNextButton(),
        const MaterialDesktopPositionIndicator(),
        const MaterialDesktopVolumeButton(),
        const Spacer(),
        IconButton(
          onPressed: () async {
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
          },
          icon: const Icon(FluentIcons.camera, size: 24),
        ),
        FlyoutTarget(
          controller: speedFlyout,
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
    super.build(context);
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
