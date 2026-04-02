import 'dart:async';

import '../cache/lru_cache_manager.dart';
import '../memory/memory_manager.dart';

class PerformanceMetrics {
  final MemoryInfo? memoryInfo;
  final CacheStats cacheStats;
  final NavStats navStats;
  final DateTime timestamp;
  final Duration uptime;

  PerformanceMetrics({
    this.memoryInfo,
    required this.cacheStats,
    required this.navStats,
    required this.timestamp,
    required this.uptime,
  });

  Map<String, dynamic> toJson() => {
    'memory': memoryInfo != null
        ? {
            'usedMB': memoryInfo!.usedMemoryMB,
            'usagePercent': memoryInfo!.usagePercent,
          }
        : null,
    'cache': cacheStats.toJson(),
    'nav': navStats.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'uptime': uptime.inSeconds,
  };
}

class CacheStats {
  final int memoryCacheSize;
  final int diskCacheSize;
  final int maxMemoryCacheSize;
  final int maxDiskCacheSize;

  CacheStats({
    required this.memoryCacheSize,
    required this.diskCacheSize,
    required this.maxMemoryCacheSize,
    required this.maxDiskCacheSize,
  });

  double get memoryUsagePercent =>
      maxMemoryCacheSize > 0 ? (memoryCacheSize / maxMemoryCacheSize) * 100 : 0;

  double get diskUsagePercent =>
      maxDiskCacheSize > 0 ? (diskCacheSize / maxDiskCacheSize) * 100 : 0;

  Map<String, dynamic> toJson() => {
    'memoryCacheSize': memoryCacheSize,
    'diskCacheSize': diskCacheSize,
    'maxMemoryCacheSize': maxMemoryCacheSize,
    'maxDiskCacheSize': maxDiskCacheSize,
    'memoryUsagePercent': memoryUsagePercent,
    'diskUsagePercent': diskUsagePercent,
  };
}

class NavStats {
  final int totalNavCount;
  final int loadedIndices;
  final int cachedBodies;
  final int curIndex;

  NavStats({
    required this.totalNavCount,
    required this.loadedIndices,
    required this.cachedBodies,
    required this.curIndex,
  });

  double get loadEfficiency =>
      totalNavCount > 0 ? (loadedIndices / totalNavCount) * 100 : 0;

  Map<String, dynamic> toJson() => {
    'totalNavCount': totalNavCount,
    'loadedIndices': loadedIndices,
    'cachedBodies': cachedBodies,
    'curIndex': curIndex,
    'loadEfficiency': loadEfficiency,
  };
}

class PerformanceMonitor {
  PerformanceMonitor._();

  static final PerformanceMonitor instance = PerformanceMonitor._();

  factory PerformanceMonitor() => instance;

  final MemoryManager _memoryManager = MemoryManager.instance;
  final LRUCacheManager _cacheManager = LRUCacheManager.instance;

  final List<PerformanceMetrics> _metricsHistory = [];
  final int _maxHistorySize = 100;

  Timer? _monitorTimer;
  final StreamController<PerformanceMetrics> _metricsController =
      StreamController<PerformanceMetrics>.broadcast();

  Stream<PerformanceMetrics> get metricsStream => _metricsController.stream;
  List<PerformanceMetrics> get metricsHistory =>
      List.unmodifiable(_metricsHistory);

  DateTime? _startTime;
  Map<String, dynamic> Function()? _getNavStats;

  void setNavStatsProvider(Map<String, dynamic> Function() provider) {
    _getNavStats = provider;
  }

  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _startTime ??= DateTime.now();
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(interval, (_) => _collectMetrics());
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  Future<PerformanceMetrics> _collectMetrics() async {
    final memoryInfo = await _memoryManager.getMemoryInfo();
    final cacheStats = _cacheManager.getCacheStats();

    final navStatsMap = _getNavStats != null
        ? _getNavStats!()
        : <String, dynamic>{};
    final navStats = NavStats(
      totalNavCount: navStatsMap['totalNavCount'] ?? 0,
      loadedIndices: navStatsMap['loadedIndices'] ?? 0,
      cachedBodies: navStatsMap['cachedBodies'] ?? 0,
      curIndex: navStatsMap['curIndex'] ?? 0,
    );

    final metrics = PerformanceMetrics(
      memoryInfo: memoryInfo,
      cacheStats: CacheStats(
        memoryCacheSize: cacheStats['memoryCacheSize'] ?? 0,
        diskCacheSize: cacheStats['diskCacheSize'] ?? 0,
        maxMemoryCacheSize: cacheStats['maxMemoryCacheSize'] ?? 0,
        maxDiskCacheSize: cacheStats['maxDiskCacheSize'] ?? 0,
      ),
      navStats: navStats,
      timestamp: DateTime.now(),
      uptime: _startTime != null
          ? DateTime.now().difference(_startTime!)
          : Duration.zero,
    );

    _metricsHistory.add(metrics);
    if (_metricsHistory.length > _maxHistorySize) {
      _metricsHistory.removeAt(0);
    }

    _metricsController.add(metrics);
    return metrics;
  }

  Future<PerformanceMetrics> getCurrentMetrics() async {
    return await _collectMetrics();
  }

  Map<String, dynamic> getSummary() {
    if (_metricsHistory.isEmpty) {
      return {
        'samples': 0,
        'uptime': _startTime != null
            ? DateTime.now().difference(_startTime!).inSeconds
            : 0,
      };
    }

    final memoryUsages = _metricsHistory
        .where((m) => m.memoryInfo != null)
        .map((m) => m.memoryInfo!.usedMemoryMB)
        .toList();

    final avgMemory = memoryUsages.isNotEmpty
        ? memoryUsages.reduce((a, b) => a + b) / memoryUsages.length
        : 0;

    final maxMemory = memoryUsages.isNotEmpty
        ? memoryUsages.reduce((a, b) => a > b ? a : b)
        : 0;

    final minMemory = memoryUsages.isNotEmpty
        ? memoryUsages.reduce((a, b) => a < b ? a : b)
        : 0;

    return {
      'samples': _metricsHistory.length,
      'uptime': _startTime != null
          ? DateTime.now().difference(_startTime!).inSeconds
          : 0,
      'avgMemoryMB': avgMemory.round(),
      'maxMemoryMB': maxMemory,
      'minMemoryMB': minMemory,
      'currentMemoryMB': memoryUsages.isNotEmpty ? memoryUsages.last : 0,
    };
  }

  void clearHistory() {
    _metricsHistory.clear();
  }

  void dispose() {
    stopMonitoring();
    _metricsController.close();
  }
}

class PerformanceOptimizer {
  PerformanceOptimizer._();

  static final PerformanceOptimizer instance = PerformanceOptimizer._();

  factory PerformanceOptimizer() => instance;

  final MemoryManager _memoryManager = MemoryManager.instance;
  final LRUCacheManager _cacheManager = LRUCacheManager.instance;

  Future<void> optimizeMemory() async {
    await _memoryManager.forceCleanup();
    await _cacheManager.evictLeastRecentlyUsed();
  }

  Future<void> clearAllCaches() async {
    await _cacheManager.clear();
  }

  Future<void> performMaintenance() async {
    await _cacheManager.clearExpired();
    await _memoryManager.forceCleanup();
  }

  Future<Map<String, dynamic>> getOptimizationReport() async {
    final memoryInfo = await _memoryManager.getMemoryInfo();
    final cacheStats = _cacheManager.getCacheStats();

    return {
      'memory': {
        'usedMB': memoryInfo.usedMemoryMB,
        'usagePercent': memoryInfo.usagePercent,
        'isHighUsage': memoryInfo.isHighMemoryUsage,
        'isCritical': memoryInfo.isCriticalMemoryUsage,
      },
      'cache': cacheStats,
      'recommendations': _generateRecommendations(memoryInfo, cacheStats),
    };
  }

  List<String> _generateRecommendations(
    MemoryInfo memoryInfo,
    Map<String, dynamic> cacheStats,
  ) {
    final recommendations = <String>[];

    if (memoryInfo.isCriticalMemoryUsage) {
      recommendations.add('内存使用率过高，建议立即清理缓存');
    } else if (memoryInfo.isHighMemoryUsage) {
      recommendations.add('内存使用率较高，建议进行内存优化');
    }

    final memoryCacheSize = cacheStats['memoryCacheSize'] as int? ?? 0;
    final maxMemoryCacheSize = cacheStats['maxMemoryCacheSize'] as int? ?? 1;
    if (memoryCacheSize > maxMemoryCacheSize * 0.8) {
      recommendations.add('内存缓存接近上限，建议清理');
    }

    return recommendations;
  }
}
