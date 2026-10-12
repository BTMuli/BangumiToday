// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../models/playback/playback_item.dart';

/// Watch parents as well as descendants so removed directories can reappear.
class SubjectFileMonitor {
  SubjectFileMonitor({
    required this.directory,
    required Iterable<String> files,
    required this.onChange,
    required this.onUnavailable,
  }) : files = files.map(PlaybackItem.pathKey).toSet();

  final String? directory;
  final Set<String> files;
  final void Function(FileSystemEvent event) onChange;
  final void Function() onUnavailable;
  final _subscriptions = <StreamSubscription<FileSystemEvent>>[];
  bool _closed = false;

  Future<void> start() async {
    var roots = <String, bool>{
      if (directory != null)
        path.dirname(PlaybackItem.pathKey(directory!)): false,
      for (var file in files) path.dirname(file): false,
      if (directory != null) PlaybackItem.pathKey(directory!): true,
    };
    var watching = <(String, bool)>{};
    for (var root in roots.entries) {
      var parent = Directory(root.key);
      var recursive = root.value;
      while (!await parent.exists()) {
        if (_closed) return;
        var next = parent.parent;
        if (next.path == parent.path) break;
        parent = next;
        recursive = false;
      }
      if (_closed) return;
      if (!watching.add((PlaybackItem.pathKey(parent.path), recursive))) {
        continue;
      }
      var failed = false;
      try {
        _subscriptions.add(
          parent
              .watch(recursive: recursive)
              .listen(
                (event) {
                  if (_closed) return;
                  if (_matches(event.path) ||
                      (event is FileSystemMoveEvent &&
                          event.destination != null &&
                          _matches(event.destination!))) {
                    onChange(event);
                  }
                },
                onError: (Object error) {
                  failed = true;
                  if (!_closed) onUnavailable();
                },
                onDone: () {
                  if (_closed) return;
                  if (failed) {
                    onUnavailable();
                  } else {
                    onChange(FileSystemDeleteEvent(parent.path, true));
                  }
                },
              ),
        );
      } on FileSystemException {
        if (!_closed) onUnavailable();
      }
    }
  }

  bool _matches(String changedPath) {
    var changed = PlaybackItem.pathKey(changedPath);
    var root = directory == null ? null : PlaybackItem.pathKey(directory!);
    if (root != null &&
        (changed == root ||
            path.isWithin(root, changed) ||
            path.isWithin(changed, root))) {
      return true;
    }
    return files.any((file) => changed == file || path.isWithin(changed, file));
  }

  void dispose() {
    _closed = true;
    for (var subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}
