import 'package:fluent_ui/fluent_ui.dart';

/// 一级封装
Future<void> showInfoBar(
  BuildContext context, {
  InfoBarSeverity severity = InfoBarSeverity.success,
  required String text,
}) async {
  return await displayInfoBar(context, builder: (context, close) {
    return InfoBar(title: Text(text), severity: severity);
  });
}

/// 二级封装
class BTInfoBar {
  BTInfoBar._();

  /// 实例
  static final BTInfoBar _instance = BTInfoBar._();

  /// 获取实例
  factory BTInfoBar() => _instance;

  /// success
  static Future<void> success(BuildContext context, String text) async {
    return await showInfoBar(
      context,
      text: text,
      severity: InfoBarSeverity.success,
    );
  }

  /// error
  static Future<void> error(BuildContext context, String text) async {
    return await showInfoBar(
      context,
      text: text,
      severity: InfoBarSeverity.error,
    );
  }

  /// warning
  static Future<void> warn(BuildContext context, String text) async {
    return await showInfoBar(
      context,
      text: text,
      severity: InfoBarSeverity.warning,
    );
  }

  /// info
  static Future<void> info(BuildContext context, String text) async {
    return await showInfoBar(
      context,
      text: text,
      severity: InfoBarSeverity.info,
    );
  }
}
