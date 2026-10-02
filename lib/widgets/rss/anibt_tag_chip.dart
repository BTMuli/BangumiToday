// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// A shared tag style for the filter panel and release list.
class AnibtTagChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double maxWidth;

  const AnibtTagChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.highlighted = false,
    this.onPressed,
    this.tooltip,
    this.maxWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    var accent = theme.accentColor;
    var dark = theme.brightness == Brightness.dark;
    var foreground = highlighted
        ? Color.lerp(accent, dark ? Colors.white : Colors.black, 0.2)!
        : (dark ? Colors.grey[30] : Colors.grey[150]);
    var background = selected
        ? accent.withValues(alpha: dark ? 0.35 : 0.22)
        : highlighted
        ? accent.withValues(alpha: dark ? 0.2 : 0.12)
        : (dark ? Colors.white : Colors.black).withValues(alpha: 0.06);
    var border = highlighted
        ? accent.withValues(alpha: 0.5)
        : (dark ? Colors.white : Colors.black).withValues(alpha: 0.12);
    var shape = StadiumBorder(side: BorderSide(color: border));
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    var content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: foreground, size: 12),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
    return Tooltip(
      message: tooltip ?? label,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: onPressed == null
            ? DecoratedBox(
                decoration: ShapeDecoration(color: background, shape: shape),
                child: Padding(padding: padding, child: content),
              )
            : Semantics(
                toggled: selected,
                child: Button(
                  onPressed: onPressed,
                  style: ButtonStyle(
                    shape: WidgetStatePropertyAll(shape),
                    padding: const WidgetStatePropertyAll(padding),
                    foregroundColor: WidgetStatePropertyAll(foreground),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.isHovered || states.isPressed
                          ? Color.lerp(background, foreground, 0.12)
                          : background,
                    ),
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }
}
