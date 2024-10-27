// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 对InfoBar的封装
class BtInfobarType {
  /// info
  InfoBar infoBar;

  /// build context
  BuildContext context;

  /// 构造函数
  BtInfobarType(this.infoBar, this.context);

  /// show
  Future<void> show() async {
    return await displayInfoBar(context, builder: (_, __) => infoBar);
  }
}

/// InfoBar队列
class BtInfobarQueue extends ChangeNotifier {
  BtInfobarQueue._();

  static final BtInfobarQueue _instance = BtInfobarQueue._();

  factory BtInfobarQueue() => _instance;

  /// 队列
  List<BtInfobarType> queue = [];

  /// 定时器
  Timer? timer;

  /// 刷新
  Future<void> fresh() async {
    if (queue.length == 1) {
      await queue.first.show();
      queue.removeAt(0);
      notifyListeners();
    }
    timer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (queue.isEmpty) {
        timer.cancel();
        return;
      }
      await queue.first.show();
      queue.removeAt(0);
      notifyListeners();
    });
  }

  /// 添加
  Future<void> add(BtInfobarType infoBar) async {
    queue.add(infoBar);
    if (timer == null || !timer!.isActive) {
      await fresh();
    }
    notifyListeners();
  }
}

/// 对InfoBar的封装
class BtInfobar {
  BtInfobar._();

  /// 实例
  static final BtInfobar _instance = BtInfobar._();

  /// 获取实例
  factory BtInfobar() => _instance;

  /// 队列
  static final BtInfobarQueue queue = BtInfobarQueue();

  /// show
  static Future<void> show(
    BuildContext context,
    String text,
    InfoBarSeverity severity,
  ) async {
    var btInfobar = BtInfobarType(
      InfoBar(title: Text(text), severity: severity),
      context,
    );
    return await queue.add(btInfobar);
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
