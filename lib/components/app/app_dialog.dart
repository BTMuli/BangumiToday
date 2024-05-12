// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 对 Dialog 的封装

/// 输入框对话框
/// [title] 标题，[content] 内容，[onSubmit] 提交回调
/// [value] 默认值
Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  required String content,
  String value = '',
}) async {
  var confirm = false;
  var controller = TextEditingController();
  if (value.isNotEmpty) controller.text = value;
  await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return ContentDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(content),
            const SizedBox(height: 12.0),
            TextBox(controller: controller, autofocus: true),
          ],
        ),
        actions: [
          Button(
            onPressed: () {
              confirm = true;
              Navigator.of(context).pop();
            },
            child: const Text('提交'),
          ),
          Button(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
  if (!confirm) return null;
  return controller.text;
}

/// 确认框对话框
/// [title] 标题，[content] 内容，[onSubmit] 提交回调
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  var confirm = false;
  await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return ContentDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          Button(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          Button(
            onPressed: () {
              confirm = true;
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  return confirm;
}
