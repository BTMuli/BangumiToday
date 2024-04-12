import 'package:local_notifier/local_notifier.dart';

/// 应用通知工具，负责调用系统通知服务
class BTNotifierTool {
  BTNotifierTool._();

  static final BTNotifierTool _instance = BTNotifierTool._();

  /// 获取实例
  factory BTNotifierTool() => _instance;

  /// 初始化
  Future<void> init() async {
    await localNotifier.setup(appName: 'BangumiToday');
  }

  /// 创建通知
  /// 必需的是 title 和 body
  /// onShow、onClick、onClose 等回调函数可以为空
  static Future<void> showMini({
    required String title,
    required String body,
    void Function()? onClick,
  }) async {
    var notification = LocalNotification(
      title: title,
      body: body,
    );
    if (onClick != null) notification.onClick = onClick;
    await notification.show();
  }
}
