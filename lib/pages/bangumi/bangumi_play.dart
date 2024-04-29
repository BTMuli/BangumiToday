// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart' as material;

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_control_panel/video_player_control_panel.dart';
import 'package:video_player_win/video_player_win_plugin.dart';

// Project imports:
import '../../store/nav_store.dart';

/// 播放器页面
class BangumiPlayPage extends ConsumerStatefulWidget {
  /// 文件
  final String file;

  /// 目录，可选
  final String? dir;

  /// 构造函数
  const BangumiPlayPage(this.file, {super.key, this.dir});

  @override
  ConsumerState<BangumiPlayPage> createState() => _BangumiPlayPageState();
}

/// BangumiPlayPageState
class _BangumiPlayPageState extends ConsumerState<BangumiPlayPage>
    with AutomaticKeepAliveClientMixin {
  /// 播放器
  late VideoPlayerController controller;

  /// 文件列表
  List<String> files = [];

  /// 是否有数据
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    WindowsVideoPlayer.registerWith();
    controller = VideoPlayerController.file(File(widget.file));
    controller.initialize().then((_) {
      if (controller.value.isInitialized) {
        controller.play();
        setState(() {});
      }
    }).catchError((e) {
      debugPrint("controller.initialize() error occurs: $e");
    });
  }

  /// 构建顶部栏操作
  List<Widget> buildHeaderActions() {
    return [];
  }

  /// 构建顶部栏
  Widget buildHeader() {
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItem('内置播放');
        },
      ),
      title: Tooltip(
        message: widget.file,
        child: const Text('内置播放'),
      ),
      commandBar: Row(
        children: buildHeaderActions(),
      ),
    );
  }

  /// 构建内容
  Widget buildContent() {
    if (!controller.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ProgressRing(),
            SizedBox(height: 12.h),
            const Text('Loading...'),
          ],
        ),
      );
    }
    return material.Scaffold(
      body: Card(
        padding: const EdgeInsets.all(0),
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: JkVideoControlPanel(
              controller,
              showClosedCaptionButton: true,
              showFullscreenButton: false,
              showVolumeButton: true,
            ),
          ),
        ),
      ),
    );
  }

  /// dispose
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(header: buildHeader(), content: buildContent());
  }
}
