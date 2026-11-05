// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../core/theme/bt_theme.dart';

class BtInfobarType {
  InfoBarSeverity severity;
  String text;
  BuildContext context;
  int count;

  BtInfobarType({
    required this.severity,
    required this.text,
    required this.context,
    this.count = 1,
  });

  bool get isSuccessLike =>
      severity == InfoBarSeverity.success || severity == InfoBarSeverity.info;

  bool get isErrorLike =>
      severity == InfoBarSeverity.error || severity == InfoBarSeverity.warning;

  Duration get displayDuration => isErrorLike
      ? const Duration(seconds: 3)
      : const Duration(milliseconds: 1600);

  InfoBar buildInfoBar() {
    var label = count > 1 ? '$text（×$count）' : text;
    return InfoBar(
      title: Text(
        label,
        style: BTTypography.body(context).copyWith(fontWeight: FontWeight.w500),
      ),
      severity: severity,
    );
  }

  Future<void> show() async {
    if (!context.mounted) return;
    return await displayInfoBar(
      context,
      alignment: Alignment.bottomCenter,
      duration: displayDuration,
      builder: (_, _) => buildInfoBar(),
    );
  }
}

class BtInfobarQueue extends ChangeNotifier {
  BtInfobarQueue._();

  static final BtInfobarQueue _instance = BtInfobarQueue._();

  factory BtInfobarQueue() => _instance;

  final List<BtInfobarType> queue = [];
  var _draining = false;

  /// 成功类相邻间隔；错误类等当前条完全结束后再出下一条。
  static const Duration _successGap = Duration(milliseconds: 120);

  bool _tryMerge(BtInfobarType infoBar) {
    if (!infoBar.isSuccessLike || queue.isEmpty) return false;
    var last = queue.last;
    if (!last.isSuccessLike ||
        last.severity != infoBar.severity ||
        last.text != infoBar.text ||
        last.context != infoBar.context) {
      return false;
    }
    last.count += infoBar.count;
    return true;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (queue.isNotEmpty) {
        var item = queue.removeAt(0);
        notifyListeners();
        await item.show();
        if (queue.isEmpty) break;
        // 成功类缩短排队间隔；错误/警告仍串行，等本条结束后再播下一条。
        if (item.isSuccessLike && queue.first.isSuccessLike) {
          await Future<void>.delayed(_successGap);
        }
      }
    } finally {
      _draining = false;
      if (queue.isNotEmpty) {
        unawaited(_drain());
      }
    }
  }

  Future<void> add(BtInfobarType infoBar) async {
    if (_tryMerge(infoBar)) {
      notifyListeners();
      return;
    }
    queue.add(infoBar);
    notifyListeners();
    await _drain();
  }
}

class BtInfobar {
  BtInfobar._();

  static final BtInfobar _instance = BtInfobar._();

  factory BtInfobar() => _instance;

  static final BtInfobarQueue queue = BtInfobarQueue();

  static Future<void> show(
    BuildContext context,
    String text,
    InfoBarSeverity severity,
  ) async {
    var btInfobar = BtInfobarType(
      severity: severity,
      text: text,
      context: context,
    );
    return await queue.add(btInfobar);
  }

  static Future<void> success(BuildContext context, String text) async {
    return await show(context, text, InfoBarSeverity.success);
  }

  static Future<void> error(BuildContext context, String text) async {
    return await show(context, text, InfoBarSeverity.error);
  }

  static Future<void> warn(BuildContext context, String text) async {
    return await show(context, text, InfoBarSeverity.warning);
  }

  static Future<void> info(BuildContext context, String text) async {
    return await show(context, text, InfoBarSeverity.info);
  }
}

class BTSnackBar {
  static Future<void> show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) async {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    await displayInfoBar(
      context,
      duration: duration,
      builder: (context, close) => Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2D2D2D).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BTRadius.mediumBR,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: BTTheme.shadow(context, level: BTShadowLevel.medium),
        ),
        child: Row(
          children: [
            Expanded(child: Text(message, style: BTTypography.body(context))),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  close();
                  onAction();
                },
                child: Text(
                  actionLabel,
                  style: BTTypography.body(context).copyWith(
                    color: FluentTheme.of(context).accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BTToast {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    _overlayEntry?.remove();
    _timer?.cancel();

    var overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _BTToastWidget(message: message, icon: icon),
    );

    overlay.insert(_overlayEntry!);

    _timer = Timer(duration, () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _timer?.cancel();
    _timer = null;
  }
}

class _BTToastWidget extends StatelessWidget {
  final String message;
  final IconData? icon;

  const _BTToastWidget({required this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2D2D2D).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BTRadius.largeBR,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: BTTheme.shadow(context, level: BTShadowLevel.strong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: FluentTheme.of(context).accentColor,
                ),
                SizedBox(width: 10),
              ],
              Text(message, style: BTTypography.body(context)),
            ],
          ),
        ),
      ),
    );
  }
}
