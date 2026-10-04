part of 'playback_page.dart';

/// Lives inside Video.controls, including its separate fullscreen route. The
/// chrome can disappear without losing layout or device-pixel-ratio reporting.
class _PlaybackViewportReporter extends StatefulWidget {
  const _PlaybackViewportReporter({required this.store, required this.child});
  final PlaybackStore store;
  final Widget child;

  @override
  State<_PlaybackViewportReporter> createState() =>
      _PlaybackViewportReporterState();
}

class _PlaybackViewportReporterState extends State<_PlaybackViewportReporter>
    with WidgetsBindingObserver {
  final Object _owner = Object();
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    // Moving between monitors can change DPR without changing logical layout.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    // Dispose may occur during layout. Publish changes after this frame so the
    // Store cannot notify another controls instance in the middle of build.
    var store = widget.store;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.releaseViewport(_owner);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var current = ModalRoute.of(context)?.isCurrent ?? true;
      var enabled = TickerMode.valuesOf(context).enabled;
      var fullscreen = isFullscreen(context);
      var viewport = (
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        dpr: View.of(context).devicePixelRatio,
      );
      var revision = ++_revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _revision) return;
        if (!current ||
            !enabled ||
            [
              viewport.width,
              viewport.height,
              viewport.dpr,
            ].any((value) => !value.isFinite || value <= 0)) {
          widget.store.releaseViewport(_owner);
          return;
        }
        widget.store.reportViewport(_owner, viewport, fullscreen: fullscreen);
      });
      return widget.child;
    },
  );
}
