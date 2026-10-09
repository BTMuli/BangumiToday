// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';

/// 独立接口页签的加载、空内容和错误状态。
class SubjectDetailModuleStatus extends StatelessWidget {
  const SubjectDetailModuleStatus({
    super.key,
    this.loading = false,
    required this.message,
    this.onRetry,
  });

  final bool loading;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 20,
              child: ProgressRing(strokeWidth: 2),
            )
          else
            Icon(
              onRetry == null ? FluentIcons.info : FluentIcons.error_badge,
              size: 18,
              color: BTColors.textSecondary(context),
            ),
          const SizedBox(width: 10),
          Flexible(child: Text(message, style: BTTypography.body(context))),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: '重新加载',
              child: Semantics(
                label: '重新加载',
                child: IconButton(
                  icon: const Icon(FluentIcons.refresh, size: 14),
                  onPressed: onRetry,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
