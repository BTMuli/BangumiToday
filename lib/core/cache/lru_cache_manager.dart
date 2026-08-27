// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:hive/hive.dart';

class LRUCacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final String? etag;
  final String? lastModified;
  int accessCount;
  DateTime lastAccessed;

  LRUCacheEntry({
    required this.data,
    required this.timestamp,
    this.etag,
    this.lastModified,
    this.accessCount = 1,
    DateTime? lastAccessed,
  }) : lastAccessed = lastAccessed ?? DateTime.now();

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'etag': etag,
      'lastModified': lastModified,
      'accessCount': accessCount,
      'lastAccessed': lastAccessed.toIso8601String(),
    };
  }

  factory LRUCacheEntry.fromJson(Map<String, dynamic> json) {
    return LRUCacheEntry(
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
      etag: json['etag'],
      lastModified: json['lastModified'],
      accessCount: json['accessCount'] ?? 1,
      lastAccessed: json['lastAccessed'] != null
          ? DateTime.parse(json['lastAccessed'])
          : DateTime.now(),
    );
  }
}

class LRUCacheManager {
  LRUCacheManager._();

  static final LRUCacheManager instance = LRUCacheManager._();

  factory LRUCacheManager() => instance;

  static const String _boxName = 'lru_cache';

  Box<dynamic>? _box;

  Future<void>? _initialization;

  final Map<String, LRUCacheEntry> _memoryCache = {};

  final int _maxMemoryCacheSize = 50;

  final int _maxDiskCacheSize = 500;

  final Duration _defaultMaxAge = const Duration(hours: 6);

  final List<String> _accessOrder = [];

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    var inProgress = _initialization;
    if (inProgress != null) return await inProgress;

    var initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
    }
  }

  Future<void> _initialize() async {
    _box = await Hive.openBox(_boxName);
    await clearExpired();
    await _loadFromDisk();
    await evictLeastRecentlyUsed();
    _isInitialized = true;
  }

  Future<void> _loadFromDisk() async {
    if (_box == null) return;

    var keys = _box!.keys.toList();
    keys.sort((a, b) {
      var entryA = _box!.get(a);
      var entryB = _box!.get(b);
      if (entryA == null || entryB == null) return 0;

      try {
        var jsonA = jsonDecode(entryA) as Map<String, dynamic>;
        var jsonB = jsonDecode(entryB) as Map<String, dynamic>;
        var timeA = DateTime.parse(jsonA['lastAccessed'] ?? jsonA['timestamp']);
        var timeB = DateTime.parse(jsonB['lastAccessed'] ?? jsonB['timestamp']);
        return timeA.compareTo(timeB);
      } catch (_) {
        return 0;
      }
    });

    var firstKeyIndex = keys.length > _maxMemoryCacheSize
        ? keys.length - _maxMemoryCacheSize
        : 0;
    for (var key in keys.skip(firstKeyIndex)) {
      var data = _box!.get(key);
      if (data != null) {
        try {
          var json = jsonDecode(data) as Map<String, dynamic>;
          _memoryCache[key.toString()] = LRUCacheEntry.fromJson(json);
          _accessOrder.add(key.toString());
        } catch (_) {}
      }
    }
  }

  Future<T?> get<T>(String key, {Duration? maxAge}) async {
    var effectiveMaxAge = maxAge ?? _defaultMaxAge;

    var memEntry = _memoryCache[key];
    if (memEntry != null) {
      if (memEntry.isExpired(effectiveMaxAge)) {
        await delete(key);
        return null;
      }
      try {
        memEntry.accessCount++;
        memEntry.lastAccessed = DateTime.now();
        _updateAccessOrder(key);
        return memEntry.data as T;
      } catch (_) {
        await delete(key);
        return null;
      }
    }

    if (_box != null) {
      var diskData = _box!.get(key);
      if (diskData != null) {
        try {
          var json = jsonDecode(diskData) as Map<String, dynamic>;
          var entry = LRUCacheEntry.fromJson(json);
          if (!entry.isExpired(effectiveMaxAge)) {
            entry.accessCount++;
            entry.lastAccessed = DateTime.now();
            _setMemoryCache(key, entry);
            await _box!.put(key, jsonEncode(entry.toJson()));
            return entry.data as T;
          }
          await delete(key);
        } catch (_) {
          await delete(key);
        }
      }
    }

    return null;
  }

  Future<void> set<T>(
    String key,
    T data, {
    String? etag,
    String? lastModified,
    bool saveToMemory = true,
    bool saveToDisk = true,
  }) async {
    var entry = LRUCacheEntry(
      data: data,
      timestamp: DateTime.now(),
      etag: etag,
      lastModified: lastModified,
    );

    if (saveToMemory) {
      _setMemoryCache(key, entry);
    }

    if (saveToDisk && _box != null) {
      await _box!.put(key, jsonEncode(entry.toJson()));
      await evictLeastRecentlyUsed();
    }
  }

  Future<void> setJson<T>(
    String key,
    T data, {
    required Map<String, dynamic> Function(T) toJson,
    String? etag,
    String? lastModified,
    bool saveToMemory = true,
    bool saveToDisk = true,
  }) async {
    var entry = LRUCacheEntry(
      data: toJson(data),
      timestamp: DateTime.now(),
      etag: etag,
      lastModified: lastModified,
    );

    if (saveToMemory) {
      _setMemoryCache(key, entry);
    }

    if (saveToDisk && _box != null) {
      await _box!.put(key, jsonEncode(entry.toJson()));
      await evictLeastRecentlyUsed();
    }
  }

  Future<T?> getJson<T>(
    String key, {
    required T Function(Map<String, dynamic>) fromJson,
    Duration? maxAge,
  }) async {
    var effectiveMaxAge = maxAge ?? _defaultMaxAge;

    var memEntry = _memoryCache[key];
    if (memEntry != null) {
      if (memEntry.isExpired(effectiveMaxAge)) {
        await delete(key);
        return null;
      }
      try {
        memEntry.accessCount++;
        memEntry.lastAccessed = DateTime.now();
        _updateAccessOrder(key);
        return fromJson(memEntry.data as Map<String, dynamic>);
      } catch (_) {
        await delete(key);
        return null;
      }
    }

    if (_box != null) {
      var diskData = _box!.get(key);
      if (diskData != null) {
        try {
          var json = jsonDecode(diskData) as Map<String, dynamic>;
          var entry = LRUCacheEntry.fromJson(json);
          if (!entry.isExpired(effectiveMaxAge)) {
            entry.accessCount++;
            entry.lastAccessed = DateTime.now();
            _setMemoryCache(key, entry);
            await _box!.put(key, jsonEncode(entry.toJson()));
            return fromJson(entry.data as Map<String, dynamic>);
          }
          await delete(key);
        } catch (_) {
          await delete(key);
        }
      }
    }

    return null;
  }

  void _setMemoryCache(String key, LRUCacheEntry entry) {
    if (_memoryCache.containsKey(key)) {
      _accessOrder.remove(key);
    } else if (_memoryCache.length >= _maxMemoryCacheSize) {
      var oldestKey = _accessOrder.isNotEmpty ? _accessOrder.removeAt(0) : null;
      if (oldestKey != null) {
        _memoryCache.remove(oldestKey);
      }
    }

    _memoryCache[key] = entry;
    _accessOrder.add(key);
  }

  void _updateAccessOrder(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  Future<void> delete(String key) async {
    _memoryCache.remove(key);
    _accessOrder.remove(key);
    if (_box != null) {
      await _box!.delete(key);
    }
  }

  Future<void> clear() async {
    _memoryCache.clear();
    _accessOrder.clear();
    if (_box != null) {
      await _box!.clear();
    }
  }

  Future<void> clearExpired([Duration? maxAge]) async {
    var effectiveMaxAge = maxAge ?? _defaultMaxAge;
    var now = DateTime.now();

    var keysToRemove = <String>[];

    _memoryCache.removeWhere((key, entry) {
      var shouldRemove = now.difference(entry.timestamp) > effectiveMaxAge;
      if (shouldRemove) {
        keysToRemove.add(key);
        _accessOrder.remove(key);
      }
      return shouldRemove;
    });

    if (_box != null) {
      for (var key in _box!.keys) {
        var data = _box!.get(key);
        if (data != null) {
          try {
            var json = jsonDecode(data) as Map<String, dynamic>;
            var timestamp = DateTime.parse(json['timestamp']);
            if (now.difference(timestamp) > effectiveMaxAge) {
              keysToRemove.add(key.toString());
            }
          } catch (_) {
            keysToRemove.add(key.toString());
          }
        }
      }

      for (var key in keysToRemove) {
        await _box!.delete(key);
      }
    }
  }

  Future<void> evictLeastRecentlyUsed() async {
    while (_memoryCache.length > _maxMemoryCacheSize) {
      var oldestKey = _accessOrder.isNotEmpty ? _accessOrder.removeAt(0) : null;
      if (oldestKey != null) {
        _memoryCache.remove(oldestKey);
      } else {
        break;
      }
    }

    if (_box != null && _box!.length > _maxDiskCacheSize) {
      var allEntries = <MapEntry<dynamic, DateTime>>[];

      for (var key in _box!.keys) {
        var data = _box!.get(key);
        if (data != null) {
          try {
            var json = jsonDecode(data) as Map<String, dynamic>;
            var lastAccessed = json['lastAccessed'] != null
                ? DateTime.parse(json['lastAccessed'])
                : DateTime.parse(json['timestamp']);
            allEntries.add(MapEntry(key, lastAccessed));
          } catch (_) {
            allEntries.add(
              MapEntry(key, DateTime.fromMillisecondsSinceEpoch(0)),
            );
          }
        }
      }

      allEntries.sort((a, b) => a.value.compareTo(b.value));

      var toRemove = allEntries.take(_box!.length - _maxDiskCacheSize);
      for (var entry in toRemove) {
        await _box!.delete(entry.key);
      }
    }
  }

  bool exists(String key) {
    return _memoryCache.containsKey(key) || (_box?.containsKey(key) ?? false);
  }

  int get memoryCacheSize => _memoryCache.length;

  int get diskCacheSize => _box?.length ?? 0;

  LRUCacheEntry? getCacheEntry(String key) {
    return _memoryCache[key];
  }

  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCacheSize': memoryCacheSize,
      'diskCacheSize': diskCacheSize,
      'maxMemoryCacheSize': _maxMemoryCacheSize,
      'maxDiskCacheSize': _maxDiskCacheSize,
      'accessOrderLength': _accessOrder.length,
    };
  }
}
