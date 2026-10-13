// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

class SubjectReviewAction extends StatelessWidget {
  const SubjectReviewAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.size = 14,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      child: IconButton(
        icon: loading
            ? SizedBox.square(
                dimension: size,
                child: const ProgressRing(strokeWidth: 2),
              )
            : Icon(icon, size: size),
        onPressed: onPressed,
      ),
    ),
  );
}
