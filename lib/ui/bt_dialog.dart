// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../models/app/response.dart';
import '../widgets/app/app_resp_err.dart';

/// 输入框对话框
Future<String?> showInput(
  BuildContext context, {
  required String title,
  required String content,
  String value = '',
}) async {
  var controller = TextEditingController();
  if (value.isNotEmpty) controller.text = value;
  return await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (_) => ContentDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(content),
          SizedBox(height: 8.h),
          TextBox(controller: controller, autofocus: true),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('提交'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}

/// 确认框对话框
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  var confirm = await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (_) => ContentDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  if (confirm == null || confirm is! bool) return false;
  return confirm;
}

/// 错误信息回调
Future<void> showRespErr(
  BTResponse resp,
  BuildContext context, {
  String? title,
}) async {
  await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (_) => ContentDialog(
      title: Text(title ?? (resp.code == 0 ? '请求成功' : '请求失败')),
      content: AppRespErrWidget(resp),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
