// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

// Project imports:
import '../../core/utils/download_paths.dart';
import 'manual_download_dialog.dart';

/// 下载页内容区局部拖放高亮，与全局 [PlaybackDropTarget] 互补。
///
/// 仅在悬停于本区域时强调「松手添加种子」；种子落点仍走手动添加对话框。
class DownloadDropTarget extends ConsumerStatefulWidget {
  const DownloadDropTarget({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DownloadDropTarget> createState() => _DownloadDropTargetState();
}

class _DownloadDropTargetState extends ConsumerState<DownloadDropTarget> {
  bool _dragging = false;
  bool _opening = false;

  bool get _canDrop => mounted && !_opening;

  void _setDragging(bool value) {
    if (!mounted || _dragging == value) return;
    setState(() => _dragging = value);
  }

  DropOperation _onDropOver(DropOverEvent event) {
    var accepted =
        _canDrop &&
        event.session.allowedOperations.contains(DropOperation.copy) &&
        event.session.items.any((item) => item.canProvide(Formats.fileUri));
    _setDragging(accepted);
    return accepted ? DropOperation.copy : DropOperation.none;
  }

  Future<Uri?> _readUri(DropItem item) {
    var reader = item.dataReader;
    if (reader == null || !reader.canProvide(Formats.fileUri)) {
      return Future.value();
    }
    var result = Completer<Uri?>();
    try {
      var progress = reader.getValue<Uri>(
        Formats.fileUri,
        result.complete,
        onError: (error) => result.completeError(error),
      );
      if (progress == null && !result.isCompleted) result.complete();
    } catch (error, stackTrace) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
    }
    return result.future;
  }

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    _setDragging(false);
    if (!_canDrop) return;
    setState(() => _opening = true);
    unawaited(_openDrop(Future.wait(event.session.items.map(_readUri))));
  }

  Future<void> _openDrop(Future<List<Uri?>> pending) async {
    try {
      var uris = await pending;
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      var torrents = DownloadPaths.droppedTorrents(uris);
      if (torrents.isEmpty) return;
      await showManualDownloadDialog(context, ref, torrentPaths: torrents);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return DropRegion(
      formats: const [Formats.fileUri],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: _onDropOver,
      onPerformDrop: _onPerformDrop,
      onDropLeave: (_) => _setDragging(false),
      onDropEnded: (_) => _setDragging(false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: FluentTheme.of(context).micaBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accent),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.download, size: 24),
                          SizedBox(width: 12),
                          Text('松开以添加种子下载'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
