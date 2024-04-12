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

  /// isShow
  bool isShow = false;

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
  }) {
    if (onTaskbar && defaultTargetPlatform == TargetPlatform.windows) {
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);
      return;
    }
    onTaskbar = false;
  }

  /// 更新
  void update({String? title, String? text, double? progress}) {
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
    if (onTaskbar) {
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
    }
    if (close != null) close!();
    notifyListeners();
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
  }) {
    var controller = ProgressController(
      title: title ?? '加载中',
      text: text ?? '请稍后',
      progress: progress,
      onTaskbar: onTaskbar,
    );
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => ProgressWidget(controller),
    );
    controller.isShow = true;
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
    widget.controller.close = () {
      if (widget.controller.isShow) {
        Navigator.of(context).pop();
        widget.controller.isShow = false;
        return;
      }
    };
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.text,
              style: FluentTheme.of(context).typography.body,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            SizedBox(height: 10.h),
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
