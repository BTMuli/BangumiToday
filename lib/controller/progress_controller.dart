// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

/// 进度条 controller
class ProgressController extends ChangeNotifier {
  /// 标题
  late String title;

  /// 文本
  late String text;

  /// 进度，百分比
  late double? progress;

  /// isShow
  bool isShow = false;

  /// 任务支持取消时显示操作按钮，完成后可置空以停止接受取消。
  VoidCallback? onCancel;

  final String cancelText;
  bool _ended = false;

  /// close
  void Function()? close;

  /// 是否在任务栏显示
  late bool onTaskbar;

  /// onTaskbar 的 getter
  bool get taskbar => onTaskbar;

  /// onTaskbar 的 setter
  set taskbar(bool value) {
    if (value && defaultTargetPlatform == TargetPlatform.windows) {
      onTaskbar = value;
      update(title: title, text: text, progress: progress);
      return;
    }
    if (!value && defaultTargetPlatform == TargetPlatform.windows) {
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
    }
    onTaskbar = false;
  }

  /// 构造
  ProgressController({
    this.title = '加载中',
    this.text = '请稍后',
    this.progress,
    this.onTaskbar = false,
    this.onCancel,
    this.cancelText = '取消',
  }) {
    if (onTaskbar && defaultTargetPlatform == TargetPlatform.windows) {
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);
      return;
    }
    onTaskbar = false;
  }

  /// 更新
  void update({String? title, String? text, double? progress}) {
    if (_ended) return;
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

  /// 结束
  void end() {
    if (_ended) return;
    _ended = true;
    isShow = false;
    onCancel = null;
    if (onTaskbar) {
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
    }
    var closeDialog = close;
    close = null;
    closeDialog?.call();
  }

  void cancel() {
    var cancelTask = onCancel;
    if (_ended || cancelTask == null) return;
    onCancel = null;
    try {
      cancelTask();
    } finally {
      end();
    }
  }

  @override
  void dispose() {
    _ended = true;
    isShow = false;
    close = null;
    onCancel = null;
    super.dispose();
  }
}

/// 进度条组件
class ProgressWidget extends StatefulWidget {
  /// 控制器
  final ProgressController controller;

  /// 构造
  const ProgressWidget(this.controller, {super.key});

  /// 显示
  static ProgressController show(
    BuildContext context, {
    String? title,
    String? text,
    double? progress,
    bool onTaskbar = false,
    VoidCallback? onCancel,
    String cancelText = '取消',
  }) {
    var controller = ProgressController(
      title: title ?? '加载中',
      text: text ?? '请稍后',
      progress: progress,
      onTaskbar: onTaskbar,
      onCancel: onCancel,
      cancelText: cancelText,
    );
    controller.isShow = true;
    unawaited(
      showDialog<void>(
        barrierDismissible: false,
        dismissWithEsc: onCancel == null,
        context: context,
        builder: (context) => ProgressWidget(controller),
      ),
    );
    return controller;
  }

  @override
  State<ProgressWidget> createState() => _ProgressWidgetState();
}

/// 进度条组件状态
class _ProgressWidgetState extends State<ProgressWidget> {
  /// 数据
  ProgressController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.close = _closeDialog;
    controller.addListener(_onUpdate);
    // 快速失败或取消可能发生在弹窗第一帧之前。
    if (controller._ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _closeDialog());
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _closeDialog() {
    if (!mounted) return;
    var route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    var navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onUpdate);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(controller.title),
      actions: controller.onCancel == null
          ? null
          : [
              Button(
                onPressed: controller.cancel,
                child: Text(controller.cancelText),
              ),
            ],
      content: SizedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.text,
              style: FluentTheme.of(context).typography.body,
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ProgressBar(
                value: controller.progress,
                backgroundColor: FluentTheme.of(context).accentColor.darkest,
                activeColor: FluentTheme.of(context).accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
