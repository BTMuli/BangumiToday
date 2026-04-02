import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;

class FileScanResult {
  final String path;
  final int size;
  final DateTime modifiedTime;
  final bool isDirectory;

  FileScanResult({
    required this.path,
    required this.size,
    required this.modifiedTime,
    required this.isDirectory,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'size': size,
    'modifiedTime': modifiedTime.toIso8601String(),
    'isDirectory': isDirectory,
  };

  factory FileScanResult.fromJson(Map<String, dynamic> json) {
    return FileScanResult(
      path: json['path'],
      size: json['size'],
      modifiedTime: DateTime.parse(json['modifiedTime']),
      isDirectory: json['isDirectory'],
    );
  }
}

class DirectoryScanProgress {
  final int filesScanned;
  final int directoriesScanned;
  final String? currentPath;
  final bool isComplete;

  DirectoryScanProgress({
    this.filesScanned = 0,
    this.directoriesScanned = 0,
    this.currentPath,
    this.isComplete = false,
  });

  DirectoryScanProgress copyWith({
    int? filesScanned,
    int? directoriesScanned,
    String? currentPath,
    bool? isComplete,
  }) {
    return DirectoryScanProgress(
      filesScanned: filesScanned ?? this.filesScanned,
      directoriesScanned: directoriesScanned ?? this.directoriesScanned,
      currentPath: currentPath ?? this.currentPath,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

class AsyncDirectoryScanner {
  AsyncDirectoryScanner._();

  static final AsyncDirectoryScanner instance = AsyncDirectoryScanner._();

  factory AsyncDirectoryScanner() => instance;

  final Map<String, Isolate> _activeScans = {};
  final Map<String, ReceivePort> _receivePorts = {};
  final Map<String, StreamController<DirectoryScanProgress>>
  _progressControllers = {};

  Future<List<FileScanResult>> scanDirectory(
    String directoryPath, {
    bool recursive = true,
    int maxDepth = 10,
    List<String>? extensions,
    void Function(DirectoryScanProgress)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    var completer = Completer<List<FileScanResult>>();
    var results = <FileScanResult>[];
    var receivePort = ReceivePort();
    var progressController = StreamController<DirectoryScanProgress>();

    _receivePorts[directoryPath] = receivePort;
    _progressControllers[directoryPath] = progressController;

    receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        if (message['type'] == 'progress') {
          var progress = DirectoryScanProgress(
            filesScanned: message['filesScanned'],
            directoriesScanned: message['directoriesScanned'],
            currentPath: message['currentPath'],
            isComplete: message['isComplete'],
          );
          onProgress?.call(progress);
          progressController.add(progress);
        } else if (message['type'] == 'result') {
          results.add(FileScanResult.fromJson(message['data']));
        } else if (message['type'] == 'complete') {
          receivePort.close();
          progressController.close();
          _activeScans.remove(directoryPath);
          _receivePorts.remove(directoryPath);
          _progressControllers.remove(directoryPath);
          if (!completer.isCompleted) {
            completer.complete(results);
          }
        } else if (message['type'] == 'error') {
          receivePort.close();
          progressController.close();
          _activeScans.remove(directoryPath);
          _receivePorts.remove(directoryPath);
          _progressControllers.remove(directoryPath);
          if (!completer.isCompleted) {
            completer.completeError(Exception(message['error']));
          }
        }
      }
    });

    try {
      var isolate = await Isolate.spawn(
        _scanIsolate,
        _ScanConfig(
          sendPort: receivePort.sendPort,
          directoryPath: directoryPath,
          recursive: recursive,
          maxDepth: maxDepth,
          extensions: extensions,
        ),
      );
      _activeScans[directoryPath] = isolate;
    } catch (e) {
      receivePort.close();
      await progressController.close();
      _receivePorts.remove(directoryPath);
      _progressControllers.remove(directoryPath);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  static void _scanIsolate(_ScanConfig config) {
    var sendPort = config.sendPort;
    int filesScanned = 0;
    int directoriesScanned = 0;

    void sendProgress(String? currentPath, {bool isComplete = false}) {
      sendPort.send({
        'type': 'progress',
        'filesScanned': filesScanned,
        'directoriesScanned': directoriesScanned,
        'currentPath': currentPath,
        'isComplete': isComplete,
      });
    }

    void scanDir(String dirPath, int depth) {
      if (depth > config.maxDepth) return;

      try {
        var dir = Directory(dirPath);
        if (!dir.existsSync()) return;

        var entities = dir.listSync(recursive: false);

        for (var entity in entities) {
          try {
            if (entity is File) {
              var stat = entity.statSync();
              var ext = path.extension(entity.path).toLowerCase();

              if (config.extensions == null ||
                  config.extensions!.isEmpty ||
                  config.extensions!.contains(ext)) {
                sendPort.send({
                  'type': 'result',
                  'data': {
                    'path': entity.path,
                    'size': stat.size,
                    'modifiedTime': stat.modified.toIso8601String(),
                    'isDirectory': false,
                  },
                });
                filesScanned++;
              }
            } else if (entity is Directory && config.recursive) {
              directoriesScanned++;
              sendProgress(entity.path);
              scanDir(entity.path, depth + 1);
            }
          } catch (_) {}
        }
      } catch (e) {
        sendPort.send({'type': 'error', 'error': e.toString()});
      }
    }

    try {
      scanDir(config.directoryPath, 0);
      sendProgress(null, isComplete: true);
      sendPort.send({'type': 'complete'});
    } catch (e) {
      sendPort.send({'type': 'error', 'error': e.toString()});
    }
  }

  void cancelScan(String directoryPath) {
    var isolate = _activeScans[directoryPath];
    if (isolate != null) {
      isolate.kill(priority: Isolate.immediate);
      _activeScans.remove(directoryPath);
    }

    var receivePort = _receivePorts[directoryPath];
    if (receivePort != null) {
      receivePort.close();
      _receivePorts.remove(directoryPath);
    }

    var progressController = _progressControllers[directoryPath];
    if (progressController != null) {
      progressController.close();
      _progressControllers.remove(directoryPath);
    }
  }

  void cancelAllScans() {
    for (var entry in _activeScans.entries) {
      entry.value.kill(priority: Isolate.immediate);
    }
    _activeScans.clear();

    for (var port in _receivePorts.values) {
      port.close();
    }
    _receivePorts.clear();

    for (var controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
  }

  Stream<DirectoryScanProgress> getProgressStream(String directoryPath) {
    return _progressControllers[directoryPath]?.stream ?? const Stream.empty();
  }

  bool isScanning(String directoryPath) {
    return _activeScans.containsKey(directoryPath);
  }
}

class _ScanConfig {
  final SendPort sendPort;
  final String directoryPath;
  final bool recursive;
  final int maxDepth;
  final List<String>? extensions;

  _ScanConfig({
    required this.sendPort,
    required this.directoryPath,
    required this.recursive,
    required this.maxDepth,
    this.extensions,
  });
}

class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class DirectoryWatcher {
  final String directoryPath;
  final void Function(FileSystemEvent)? onChanged;
  final Duration debounceTime;

  DirectoryWatcher({
    required this.directoryPath,
    this.onChanged,
    this.debounceTime = const Duration(milliseconds: 500),
  });

  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  FileSystemEvent? _lastEvent;

  Future<void> start() async {
    var dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw Exception('Directory does not exist: $directoryPath');
    }

    _subscription = dir.watch(recursive: true).listen((event) {
      _lastEvent = event;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceTime, () {
        if (_lastEvent != null) {
          onChanged?.call(_lastEvent!);
        }
      });
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  bool get isWatching => _subscription != null;
}

class DirectoryWatcherManager {
  DirectoryWatcherManager._();

  static final DirectoryWatcherManager instance = DirectoryWatcherManager._();

  factory DirectoryWatcherManager() => instance;

  final Map<String, DirectoryWatcher> _watchers = {};

  Future<void> watch(
    String directoryPath, {
    void Function(FileSystemEvent)? onChanged,
    Duration debounceTime = const Duration(milliseconds: 500),
  }) async {
    if (_watchers.containsKey(directoryPath)) {
      return;
    }

    var watcher = DirectoryWatcher(
      directoryPath: directoryPath,
      onChanged: onChanged,
      debounceTime: debounceTime,
    );

    await watcher.start();
    _watchers[directoryPath] = watcher;
  }

  void unwatch(String directoryPath) {
    var watcher = _watchers.remove(directoryPath);
    watcher?.stop();
  }

  void unwatchAll() {
    for (var watcher in _watchers.values) {
      watcher.stop();
    }
    _watchers.clear();
  }

  List<String> get watchedDirectories => _watchers.keys.toList();

  bool isWatching(String directoryPath) {
    return _watchers.containsKey(directoryPath);
  }
}
