// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

// Project imports:
import '../../core/errors/playback_unavailable.dart';
import '../../core/services/playback_subtitle_files.dart';
import '../../core/utils/download_paths.dart';
import '../../core/utils/playback_paths.dart';
import '../../pages/playback/playback_actions.dart';
import '../../store/playback_store.dart';

/// Receives external files over the whole window, including fullscreen routes.
class PlaybackDropTarget extends ConsumerStatefulWidget {
  const PlaybackDropTarget({
    super.key,
    required this.child,
    this.enabled = true,
    this.onTorrentDrop,
    this.playbackPageKey,
  });

  final Widget child;
  final bool enabled;
  final Future<void> Function(List<String> paths)? onTorrentDrop;
  final GlobalKey? playbackPageKey;

  @override
  ConsumerState<PlaybackDropTarget> createState() => _PlaybackDropTargetState();
}

class _PlaybackDropTargetState extends ConsumerState<PlaybackDropTarget> {
  bool _dragging = false;
  bool _opening = false;
  String? _error;
  Timer? _errorTimer;

  bool get _dropEnabled =>
      mounted && widget.enabled && !ref.read(playbackStoreProvider).isClosed;

  bool get _canDrop => _dropEnabled && !_opening;

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
    // Request every URI while the drop session is valid. The native callback
    // returns immediately; reading and opening media must not block its thread.
    unawaited(_openDrop(Future.wait(event.session.items.map(_readUri))));
  }

  Future<void> _openDrop(Future<List<Uri?>> pending) async {
    var store = ref.read(playbackStoreProvider);
    var currentKey = store.current?.key;
    var playlist = store.playlist;
    try {
      var uris = await pending;
      // Let the native drag loop finish before invoking window/player plugins.
      await Future<void>.delayed(Duration.zero);
      if (!_dropEnabled) return;
      var torrents = DownloadPaths.droppedTorrents(uris);
      var onTorrentDrop = widget.onTorrentDrop;
      if (torrents.isNotEmpty && onTorrentDrop != null) {
        _clearError();
        await onTorrentDrop(torrents);
        return;
      }
      var playbackPageKey = widget.playbackPageKey;
      var subtitleFiles = <String>[];
      var directories = <String>[];
      for (var filePath in PlaybackPaths.droppedLocalPaths(uris)) {
        var isDirectory =
            playbackPageKey != null && await Directory(filePath).exists();
        if (!_dropEnabled) return;
        if (isDirectory) {
          directories.add(filePath);
        } else if (PlaybackPaths.isVideo(filePath)) {
          _clearError();
          await openLocalPlaybackFile(ref, filePath);
          return;
        } else if (playbackPageKey != null &&
            PlaybackSubtitleFiles.isSubtitle(filePath)) {
          subtitleFiles.add(filePath);
        }
      }
      if (subtitleFiles.isNotEmpty || directories.isNotEmpty) {
        if (currentKey == null || store.current == null) {
          throw const PlaybackUnavailable('请先打开视频，再加载字幕');
        }
        _clearError();
        if (directories.isNotEmpty) {
          if (!identical(store.playlist, playlist)) {
            throw const PlaybackUnavailable('播放列表已切换，请重新导入字幕目录');
          }
          var context = playbackPageKey?.currentContext;
          if (context != null && context.mounted) {
            await importPlaybackSubtitleDirectories(
              context,
              store,
              directories,
            );
          }
        }
        if (!_dropEnabled) return;
        if (subtitleFiles.isNotEmpty) {
          if (store.current?.key != currentKey) {
            throw const PlaybackUnavailable('视频已切换，请重新加载字幕');
          }
          await store.loadSubtitleFiles(subtitleFiles);
        }
        return;
      }
      throw PlaybackUnavailable(
        onTorrentDrop != null
            ? '未识别到 .torrent 种子或支持的视频文件'
            : playbackPageKey != null
            ? '未识别到支持的视频、字幕文件或字幕目录'
            : '未识别到支持的视频文件',
      );
    } catch (error) {
      if (!_dropEnabled) return;
      var message = consumePlaybackError(ref, error);
      _errorTimer?.cancel();
      setState(() => _error = message);
      _errorTimer = Timer(const Duration(seconds: 6), _clearError);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _clearError() {
    _errorTimer?.cancel();
    if (mounted && _error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var closed = ref.watch(
      playbackStoreProvider.select((store) => store.isClosed),
    );
    var enabled = widget.enabled && !closed;
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
          if (_dragging && enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.onTorrentDrop == null
                                ? FluentIcons.video
                                : FluentIcons.download,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.onTorrentDrop != null
                                ? '松开以添加种子下载或播放视频'
                                : widget.playbackPageKey != null
                                ? '松开以播放视频或加载字幕'
                                : '松开以播放视频',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_error != null && enabled)
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: InfoBar(
                title: Text(_error!),
                severity: InfoBarSeverity.error,
                onClose: _clearError,
              ),
            ),
        ],
      ),
    );
  }
}
