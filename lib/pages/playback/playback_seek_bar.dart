part of 'playback_page.dart';

/// A compact, rounded progress bar shown above the playback control bar.
///
/// The track and filled portions use fully rounded ends on both sides. It
/// supports click-to-seek and horizontal drag, and reports interaction to the
/// owning controls so the chrome stays visible while scrubbing.
class _PlaybackSeekBar extends StatefulWidget {
  const _PlaybackSeekBar({
    super.key,
    required this.player,
    required this.chapters,
    required this.onChapter,
    required this.run,
    required this.onInteraction,
  });

  final Player player;
  final List<PlaybackChapter> chapters;
  final ValueChanged<PlaybackChapter> onChapter;
  final Future<void> Function(Future<void> Function()) run;
  final void Function(bool) onInteraction;

  @override
  State<_PlaybackSeekBar> createState() => _PlaybackSeekBarState();
}

class _PlaybackSeekBarState extends State<_PlaybackSeekBar> {
  static const _trackHeight = 4.0;
  static const _thumbRadius = 6.0;
  static const _hitHeight = 24.0;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _bufferSub;
  bool _dragging = false;
  bool _hovering = false;
  double _hoverFraction = 0;
  double _positionMs = 0;
  double _durationMs = 0;
  double _bufferMs = 0;
  double _dragMs = 0;
  double _trackWidth = 0;

  @override
  void initState() {
    super.initState();
    _positionMs = widget.player.state.position.inMilliseconds.toDouble();
    _durationMs = widget.player.state.duration.inMilliseconds.toDouble();
    _bufferMs = widget.player.state.buffer.inMilliseconds.toDouble();
    _positionSub = widget.player.stream.position.listen((value) {
      if (_dragging || !mounted) return;
      setState(() => _positionMs = value.inMilliseconds.toDouble());
    });
    _durationSub = widget.player.stream.duration.listen((value) {
      if (!mounted) return;
      setState(() => _durationMs = value.inMilliseconds.toDouble());
    });
    _bufferSub = widget.player.stream.buffer.listen((value) {
      if (mounted) setState(() => _bufferMs = value.inMilliseconds.toDouble());
    });
  }

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_bufferSub?.cancel());
    super.dispose();
  }

  double get _fraction {
    if (_durationMs <= 0) return 0;
    var value = _dragging ? _dragMs : _positionMs;
    return (value / _durationMs).clamp(0.0, 1.0);
  }

  void _updateFromX(double dx) {
    if (_trackWidth <= 0) return;
    var fraction = (dx / _trackWidth).clamp(0.0, 1.0);
    setState(() => _dragMs = fraction * _durationMs);
  }

  void _startDrag(DragStartDetails details) {
    if (_durationMs <= 0 || _trackWidth <= 0) return;
    _dragging = true;
    widget.onInteraction(true);
    setState(() => _dragMs = _positionMs);
    _updateFromX(details.localPosition.dx);
  }

  void _drag(DragUpdateDetails details) =>
      _updateFromX(details.localPosition.dx);

  Future<void> _endDrag() async {
    if (!_dragging) return;
    var target = Duration(
      milliseconds: _dragMs.clamp(0.0, _durationMs).round(),
    );
    setState(() {
      _dragging = false;
      _positionMs = target.inMilliseconds.toDouble();
    });
    try {
      await widget.run(() => widget.player.seek(target));
    } finally {
      if (mounted) widget.onInteraction(false);
    }
  }

  void _cancelDrag() {
    if (!_dragging) return;
    _dragging = false;
    if (mounted) setState(() {});
    widget.onInteraction(false);
  }

  PlaybackChapter? _nearChapter(double dx) {
    if (_durationMs <= 0 || _trackWidth <= 0) return null;
    PlaybackChapter? nearest;
    var distance = 8.0;
    for (var chapter in widget.chapters) {
      var milliseconds = chapter.start.inMicroseconds / 1000;
      if (milliseconds >= _durationMs) continue;
      var x = milliseconds / _durationMs * _trackWidth;
      var delta = (x - dx).abs();
      if (delta <= distance) {
        nearest = chapter;
        distance = delta;
      }
    }
    return nearest;
  }

  String get _tooltip {
    var milliseconds = _dragging ? _dragMs : _hoverFraction * _durationMs;
    var time = Duration(milliseconds: milliseconds.round());
    var chapter = _dragging
        ? playbackChapterAt(widget.chapters, time)
        : _nearChapter(_hoverFraction * _trackWidth) ??
              playbackChapterAt(widget.chapters, time);
    if (chapter == null) return _playbackTime(time);
    return '${_playbackTime(time)} · ${chapter.title}'
        '\n章节起点 ${_playbackTime(chapter.start)}（点击刻度跳转）';
  }

  void _tap(TapUpDetails details) {
    if (_trackWidth <= 0 || _durationMs <= 0) return;
    var chapter = _nearChapter(details.localPosition.dx);
    if (chapter != null) {
      widget.onChapter(chapter);
      return;
    }
    var fraction = (details.localPosition.dx / _trackWidth).clamp(0.0, 1.0);
    var target = Duration(milliseconds: (fraction * _durationMs).round());
    setState(() => _positionMs = target.inMilliseconds.toDouble());
    widget.onInteraction(true);
    unawaited(
      widget
          .run(() async {
            await widget.player.seek(target);
          })
          .whenComplete(() {
            if (mounted) widget.onInteraction(false);
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var fraction = _fraction;
    var buffered = _durationMs > 0
        ? (_bufferMs / _durationMs).clamp(0.0, 1.0)
        : 0.0;
    var trackHeight = _hovering || _dragging ? 6.0 : _trackHeight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: MouseRegion(
        cursor: _durationMs > 0
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        onHover: (event) {
          if (_trackWidth > 0) {
            setState(
              () => _hoverFraction = (event.localPosition.dx / _trackWidth)
                  .clamp(0.0, 1.0),
            );
          }
        },
        child: Tooltip(
          message: _tooltip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _tap,
            onHorizontalDragStart: _startDrag,
            onHorizontalDragUpdate: _drag,
            onHorizontalDragEnd: (_) => unawaited(_endDrag()),
            onHorizontalDragCancel: _cancelDrag,
            child: SizedBox(
              height: _hitHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _trackWidth = constraints.maxWidth;
                  var playedWidth = constraints.maxWidth * fraction;
                  return Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: constraints.maxWidth,
                        height: trackHeight,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              width: constraints.maxWidth * buffered,
                              decoration: BoxDecoration(
                                color: material.Colors.white24,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            Container(
                              width: playedWidth,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_durationMs > 0 && constraints.maxWidth >= 4)
                        for (var chapter in widget.chapters)
                          if (chapter.start.inMicroseconds / 1000 < _durationMs)
                            Positioned(
                              left:
                                  (chapter.start.inMicroseconds /
                                              1000 /
                                              _durationMs *
                                              constraints.maxWidth -
                                          2)
                                      .clamp(0.0, constraints.maxWidth - 4),
                              child: IgnorePointer(
                                child: Container(
                                  width: 4,
                                  height: trackHeight + 6,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.black),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                      if (_hovering || _dragging)
                        Align(
                          alignment: Alignment(fraction * 2 - 1, 0),
                          child: Container(
                            width: _thumbRadius * 2,
                            height: _thumbRadius * 2,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: material.Colors.black38,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
