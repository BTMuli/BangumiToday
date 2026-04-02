import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class MemoryInfo {
  final int usedMemoryMB;
  final int totalMemoryMB;
  final double usagePercent;
  final DateTime timestamp;

  MemoryInfo({
    required this.usedMemoryMB,
    required this.totalMemoryMB,
    required this.usagePercent,
    required this.timestamp,
  });

  bool get isHighMemoryUsage => usagePercent > 80;
  bool get isCriticalMemoryUsage => usagePercent > 90;
}

class MemoryManager {
  MemoryManager._();

  static final MemoryManager instance = MemoryManager._();

  factory MemoryManager() => instance;

  final Map<String, WeakReference<Disposable>> _disposables = {};
  final List<MemoryInfo> _memoryHistory = [];
  final int _maxHistoryLength = 100;
  Timer? _monitorTimer;
  final StreamController<MemoryInfo> _memoryStreamController =
      StreamController<MemoryInfo>.broadcast();

  Stream<MemoryInfo> get memoryStream => _memoryStreamController.stream;

  List<MemoryInfo> get memoryHistory => List.unmodifiable(_memoryHistory);

  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(interval, (_) => _checkMemory());
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  Future<MemoryInfo> _checkMemory() async {
    final info = await getMemoryInfo();
    _addToHistory(info);
    _memoryStreamController.add(info);

    if (info.isHighMemoryUsage) {
      await _performCleanup();
    }

    return info;
  }

  void _addToHistory(MemoryInfo info) {
    _memoryHistory.add(info);
    if (_memoryHistory.length > _maxHistoryLength) {
      _memoryHistory.removeAt(0);
    }
  }

  Future<MemoryInfo> getMemoryInfo() async {
    try {
      final memoryUsage = ProcessInfo.currentRss;
      final usedMemoryMB = memoryUsage ~/ (1024 * 1024);

      const estimatedTotalMB = 2048;
      final usagePercent = (usedMemoryMB / estimatedTotalMB) * 100;

      return MemoryInfo(
        usedMemoryMB: usedMemoryMB,
        totalMemoryMB: estimatedTotalMB,
        usagePercent: usagePercent,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return MemoryInfo(
        usedMemoryMB: 0,
        totalMemoryMB: 0,
        usagePercent: 0,
        timestamp: DateTime.now(),
      );
    }
  }

  Future<void> _performCleanup() async {
    final keysToRemove = <String>[];

    for (final entry in _disposables.entries) {
      final ref = entry.value;
      if (ref.target == null) {
        keysToRemove.add(entry.key);
      } else {
        final disposable = ref.target!;
        if (!disposable.isInUse) {
          disposable.dispose();
          keysToRemove.add(entry.key);
        }
      }
    }

    for (final key in keysToRemove) {
      _disposables.remove(key);
    }

    await _forceGarbageCollection();
  }

  Future<void> _forceGarbageCollection() async {
    if (kDebugMode) {
      debugPrint('Memory cleanup triggered');
    }
  }

  void registerDisposable(String key, Disposable disposable) {
    _disposables[key] = WeakReference(disposable);
  }

  void unregisterDisposable(String key) {
    _disposables.remove(key);
  }

  Future<void> forceCleanup() async {
    await _performCleanup();
  }

  void dispose() {
    stopMonitoring();
    _memoryStreamController.close();
    _disposables.clear();
    _memoryHistory.clear();
  }
}

abstract class Disposable {
  bool _isInUse = true;
  bool _isDisposed = false;

  bool get isInUse => _isInUse;
  bool get isDisposed => _isDisposed;

  void markAsNotInUse() {
    _isInUse = false;
  }

  void markAsInUse() {
    _isInUse = true;
  }

  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      onDispose();
    }
  }

  void onDispose();
}

class CacheableData<T> extends Disposable {
  T? _data;
  final DateTime createdAt;
  final Duration? maxAge;
  final void Function(T?)? onDisposeCallback;

  CacheableData({
    T? data,
    this.maxAge,
    this.onDisposeCallback,
  })  : _data = data,
        createdAt = DateTime.now();

  T? get data => _data;
  set data(T? value) => _data = value;

  bool get isExpired {
    if (maxAge == null) return false;
    return DateTime.now().difference(createdAt) > maxAge!;
  }

  @override
  void onDispose() {
    if (onDisposeCallback != null) {
      onDisposeCallback!(_data);
    }
    _data = null;
  }
}
