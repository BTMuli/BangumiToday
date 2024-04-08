import 'package:fluent_ui/fluent_ui.dart';

/// info bar 的封装

/// 简单的内容
Future<void> showInfoBar(
  BuildContext context, {
  InfoBarSeverity severity = InfoBarSeverity.success,
  required String text,
}) async {
  return await displayInfoBar(context, builder: (context, close) {
    return InfoBar(title: Text(text), severity: severity);
  });
}
