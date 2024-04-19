import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:local_notifier/local_notifier.dart';

//// 通知队列，changeNotifier
class BTNotifierQueue extends ChangeNotifier {
  BTNotifierQueue._();

  static final BTNotifierQueue _instance = BTNotifierQueue._();

  /// 获取实例
  factory BTNotifierQueue() => _instance;

  /// 通知队列
  final List<LocalNotification> _notifications = [];

  /// 定时器
  Timer? _timer;

  /// 初始化
  Future<void> initTimer() async {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_notifications.isNotEmpty) {
        var notification = _notifications.first;
        await notification.show();
        _notifications.remove(notification);
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  /// 添加通知
  Future<void> add(LocalNotification notification) async {
    _notifications.add(notification);
    if (_timer == null || !_timer!.isActive) {
      await initTimer();
    }
    notifyListeners();
  }

  /// 获取通知
  List<LocalNotification> get notifications => _notifications;
}

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

  /// 通知队列
  static final _notifications = BTNotifierQueue();

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
    await _notifications.add(notification);
  }
}
