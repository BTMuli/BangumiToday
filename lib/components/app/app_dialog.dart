import 'package:fluent_ui/fluent_ui.dart';

/// 对 Dialog 的封装

/// 输入框对话框
/// [title] 标题，[content] 内容，[onSubmit] 提交回调
Future<void> showInputDialog(
  BuildContext context, {
  required String title,
  required String content,
  required Function(String) onSubmit,
}) {
  final controller = TextEditingController();
  return showDialog(
    context: context,
    builder: (context) {
      return ContentDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(content),
            SizedBox(height: 12.0),
            TextBox(controller: controller, autofocus: true),
          ],
        ),
        actions: [
          Button(
            onPressed: () {
              onSubmit(controller.text);
              Navigator.of(context).pop();
            },
            child: Text('提交'),
          ),
          Button(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('取消'),
          ),
        ],
      );
    },
  );
}
