// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// A selectable Fluent log with independent horizontal and vertical scrolling.
class PlaybackBuildLog extends StatefulWidget {
  const PlaybackBuildLog({
    super.key,
    required this.lines,
    this.emptyText = '等待编译器输出…',
  });

  final List<String> lines;
  final String emptyText;

  @override
  State<PlaybackBuildLog> createState() => _PlaybackBuildLogState();
}

class _PlaybackBuildLogState extends State<PlaybackBuildLog> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void initState() {
    super.initState();
    _followTail();
  }

  void _followTail() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _vertical.hasClients) {
        _vertical.jumpTo(_vertical.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlaybackBuildLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(oldWidget.lines, widget.lines)) return;
    // Reading older output keeps its position. Only follow actual new output.
    if (!_vertical.hasClients || _vertical.position.extentAfter < 24) {
      _followTail();
    }
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorSecondary,
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Scrollbar(
        controller: _vertical,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        child: Scrollbar(
          controller: _horizontal,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _vertical,
            primary: false,
            child: SingleChildScrollView(
              controller: _horizontal,
              primary: false,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 20, 18),
                child: SelectionArea(
                  child: Text(
                    widget.lines.isEmpty
                        ? widget.emptyText
                        : widget.lines.join('\n'),
                    softWrap: false,
                    style: theme.typography.caption?.copyWith(
                      fontFamily: 'Consolas',
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
