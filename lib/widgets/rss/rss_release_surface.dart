// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';

/// RSS 来源共用的条目底色、间距和悬停反馈。
class RssReleaseSurface extends StatefulWidget {
  final Widget child;

  const RssReleaseSurface({super.key, required this.child});

  @override
  State<RssReleaseSurface> createState() => _RssReleaseSurfaceState();
}

class _RssReleaseSurfaceState extends State<RssReleaseSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: BTDurations.fadeTransition,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _hovered
              ? BTColors.surfaceTertiary(context)
              : BTColors.surfacePrimary(context),
          borderRadius: BTRadius.mediumBR,
          border: Border.all(color: BTColors.divider(context)),
        ),
        child: widget.child,
      ),
    );
  }
}
