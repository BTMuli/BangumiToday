import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theme/bt_theme.dart';

class BtInfobarType {
  InfoBar infoBar;
  BuildContext context;

  BtInfobarType(this.infoBar, this.context);

  Future<void> show() async {
    if (!context.mounted) return;
    return await displayInfoBar(context, builder: (_, _) => infoBar);
  }
}

class BtInfobarQueue extends ChangeNotifier {
  BtInfobarQueue._();

  static final BtInfobarQueue _instance = BtInfobarQueue._();

  factory BtInfobarQueue() => _instance;

  List<BtInfobarType> queue = [];
  Timer? timer;

  Future<void> fresh() async {
    if (queue.length == 1) {
      await queue.first.show();
      queue.removeAt(0);
      notifyListeners();
    }
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (queue.isEmpty) {
        timer.cancel();
        return;
      }
      await queue.first.show();
      queue.removeAt(0);
      notifyListeners();
    });
  }

  Future<void> add(BtInfobarType infoBar) async {
    queue.add(infoBar);
    if (timer == null || !timer!.isActive) {
      await fresh();
    }
    notifyListeners();
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
      _buildInfoBar(context, text, severity),
      context,
    );
    return await queue.add(btInfobar);
  }

  static InfoBar _buildInfoBar(
    BuildContext context,
    String text,
    InfoBarSeverity severity,
  ) {
    return InfoBar(
      title: Text(
        text,
        style: BTTypography.body(context).copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      severity: severity,
    );
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
        margin: EdgeInsets.all(16.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
            Expanded(
              child: Text(
                message,
                style: BTTypography.body(context),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(width: 12.w),
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
      builder: (context) => _BTToastWidget(
        message: message,
        icon: icon,
      ),
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

  const _BTToastWidget({
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 80.h,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
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
                  size: 18.sp,
                  color: FluentTheme.of(context).accentColor,
                ),
                SizedBox(width: 10.w),
              ],
              Text(
                message,
                style: BTTypography.body(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
