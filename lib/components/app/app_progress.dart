import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 应用组件
class AppProgress {
  /// 上下文
  BuildContext context;

  /// 标题
  late String title;

  /// 文本
  late String text;

  /// 进度
  late double? progress;

  /// state
  late StateSetter state;

  /// 宽度
  double get width => 400.w;

  /// 高度
  double get height => 100.h;

  /// 构造
  AppProgress(
    this.context, {
    this.title = '加载中',
    this.text = '请稍后',
    this.progress = 0.0,
  });

  /// 开始
  void start() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (_, setState) {
            state = setState;
            state(() {});
            return ContentDialog(
              title: Text(title),
              content: SizedBox(
                width: width,
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 20.sp),
                    ),
                    SizedBox(height: 10.h),
                    SizedBox(
                      width: double.infinity,
                      child: ProgressBar(value: progress, strokeWidth: 10.h),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 更新
  void update({
    String? title,
    String? text,
    double? progress,
  }) {
    if (title != null) this.title = title;
    if (text != null) this.text = text;
    this.progress = progress;
    // todo bug LateInitializationError: Field 'state' has not been initialized.
    state(() {});
  }

  /// 结束
  void end() {
    Navigator.of(context).pop();
  }
}
