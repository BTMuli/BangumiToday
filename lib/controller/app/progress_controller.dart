import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

/// 进度条 controller
class ProgressController extends ChangeNotifier {
  /// 标题
  late String title;

  /// 文本
  late String text;

  /// 进度，百分比
  late double? progress;

  /// 是否在任务栏显示
  late bool onTaskbar;

  /// 构造
  ProgressController({
    this.title = '加载中',
    this.text = '请稍后',
    this.progress,
    this.onTaskbar = false,
  });

  /// 更新
  void update(String? title, String? text, double? progress) {
    if (title != null) this.title = title;
    if (text != null) this.text = text;
    this.progress = progress;
    if (onTaskbar) {
      if (progress == null) {
        WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);
      } else {
        WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
        WindowsTaskbar.setProgress(progress.toInt(), 100);
      }
    }
    notifyListeners();
  }
}

/// 进度条组件
class ProgressWidget extends StatefulWidget {
  /// 控制器
  final ProgressController controller;

  /// 构造
  const ProgressWidget(this.controller, {super.key});

  @override
  State<ProgressWidget> createState() => _ProgressWidgetState();
}

/// 进度条组件状态
class _ProgressWidgetState extends State<ProgressWidget> {
  /// 宽度
  double get width => 400.w;

  /// 高度
  double get height => 100.h;

  /// 数据
  ProgressController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(controller.title),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              controller.text,
              style: FluentTheme.of(context).typography.body,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ProgressBar(value: controller.progress),
            ),
          ],
        ),
      ),
    );
  }
}

/// 进度条调用
class AppProgress {
  /// controller
  late ProgressController controller = ProgressController();

  /// context
  late BuildContext context;

  /// 构造
  AppProgress(
    this.context, {
    required String title,
    String text = '',
    double? progress,
    bool onTaskbar = false,
  }) {
    if (!onTaskbar || defaultTargetPlatform != TargetPlatform.windows) {
      controller = ProgressController(
        title: title,
        text: text,
        progress: progress,
      );
    } else {
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);
      controller = ProgressController(
        title: title,
        text: text,
        progress: progress,
        onTaskbar: true,
      );
    }
  }

  /// 开始
  void start() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => ProgressWidget(controller),
    );
  }

  /// taskbar 的 getter
  bool get onTaskbar => controller.onTaskbar;

  /// taskbar 的 setter
  set onTaskbar(bool value) {
    if (value && defaultTargetPlatform == TargetPlatform.windows) {
      controller.onTaskbar = value;
      update(progress: controller.progress);
      return;
    }
    if (!value && defaultTargetPlatform == TargetPlatform.windows) {
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
    }
    controller.onTaskbar = false;
  }

  /// 更新
  void update({
    String? title,
    String? text,
    double? progress,
  }) {
    controller.update(title, text, progress);
  }

  /// 结束
  void end() {
    if (controller.onTaskbar) {
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
    }
    Navigator.of(context).pop();
  }
}