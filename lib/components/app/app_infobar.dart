import 'package:fluent_ui/fluent_ui.dart';

/// 对InfoBar的封装
class BtInfobar {
  BtInfobar._();

  /// 实例
  static final BtInfobar _instance = BtInfobar._();

  /// 获取实例
  factory BtInfobar() => _instance;

  /// show
  static Future<void> show(
    BuildContext context,
    String text,
    InfoBarSeverity severity,
  ) async {
    return await displayInfoBar(context, builder: (context, close) {
      return InfoBar(title: Text(text), severity: severity);
    });
  }

  /// success
  static Future<void> success(BuildContext context, String text) async {
    return await show(context, text, InfoBarSeverity.success);
  }

  /// error
  static Future<void> error(BuildContext context, String text) async {
    return await show(context, text, InfoBarSeverity.error);
  }

  /// warning
  static Future<void> warn(BuildContext context, String text) async {
    return await show(context, text, InfoBarSeverity.warning);
  }

  /// info
  static Future<void> info(BuildContext context, String text) async {
    return await show(context, text, InfoBarSeverity.info);
  }
}
