import 'dart:convert';

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

  final Map<String, LRUCacheEntry> _memoryCache = {};

  final int _maxMemoryCacheSize = 50;

  final int _maxDiskCacheSize = 500;

  final Duration _defaultMaxAge = const Duration(hours: 6);

  final List<String> _accessOrder = [];

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _box = await Hive.openBox(_boxName);
    _isInitialized = true;
    await _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    if (_box == null) return;

    final keys = _box!.keys.toList();
    keys.sort((a, b) {
      final entryA = _box!.get(a);
      final entryB = _box!.get(b);
      if (entryA == null || entryB == null) return 0;

      try {
        final jsonA = jsonDecode(entryA) as Map<String, dynamic>;
        final jsonB = jsonDecode(entryB) as Map<String, dynamic>;
        final timeA = DateTime.parse(
          jsonA['lastAccessed'] ?? jsonA['timestamp'],
        );
        final timeB = DateTime.parse(
          jsonB['lastAccessed'] ?? jsonB['timestamp'],
        );
        return timeA.compareTo(timeB);
      } catch (_) {
        return 0;
      }
    });

    for (final key in keys) {
      if (_memoryCache.length >= _maxMemoryCacheSize) break;
      final data = _box!.get(key);
      if (data != null) {
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          _memoryCache[key.toString()] = LRUCacheEntry.fromJson(json);
          _accessOrder.add(key.toString());
        } catch (_) {}
      }
    }
  }

  Future<T?> get<T>(String key, {Duration? maxAge}) async {
    final effectiveMaxAge = maxAge ?? _defaultMaxAge;

    final memEntry = _memoryCache[key];
    if (memEntry != null && !memEntry.isExpired(effectiveMaxAge)) {
      memEntry.accessCount++;
      memEntry.lastAccessed = DateTime.now();
      _updateAccessOrder(key);
      return memEntry.data as T;
    }

    if (_box != null) {
      final diskData = _box!.get(key);
      if (diskData != null) {
        try {
          final json = jsonDecode(diskData) as Map<String, dynamic>;
          final entry = LRUCacheEntry.fromJson(json);
          if (!entry.isExpired(effectiveMaxAge)) {
            _setMemoryCache(key, entry);
            return entry.data as T;
          }
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
    final entry = LRUCacheEntry(
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
    final entry = LRUCacheEntry(
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
    }
  }

  Future<T?> getJson<T>(
    String key, {
    required T Function(Map<String, dynamic>) fromJson,
    Duration? maxAge,
  }) async {
    final effectiveMaxAge = maxAge ?? _defaultMaxAge;

    final memEntry = _memoryCache[key];
    if (memEntry != null && !memEntry.isExpired(effectiveMaxAge)) {
      memEntry.accessCount++;
      memEntry.lastAccessed = DateTime.now();
      _updateAccessOrder(key);
      try {
        return fromJson(memEntry.data as Map<String, dynamic>);
      } catch (_) {
        await delete(key);
        return null;
      }
    }

    if (_box != null) {
      final diskData = _box!.get(key);
      if (diskData != null) {
        try {
          final json = jsonDecode(diskData) as Map<String, dynamic>;
          final entry = LRUCacheEntry.fromJson(json);
          if (!entry.isExpired(effectiveMaxAge)) {
            _setMemoryCache(key, entry);
            return fromJson(entry.data as Map<String, dynamic>);
          }
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
      final oldestKey = _accessOrder.isNotEmpty
          ? _accessOrder.removeAt(0)
          : null;
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
    final effectiveMaxAge = maxAge ?? _defaultMaxAge;
    final now = DateTime.now();

    final keysToRemove = <String>[];

    _memoryCache.removeWhere((key, entry) {
      final shouldRemove = now.difference(entry.timestamp) > effectiveMaxAge;
      if (shouldRemove) {
        keysToRemove.add(key);
        _accessOrder.remove(key);
      }
      return shouldRemove;
    });

    if (_box != null) {
      for (final key in _box!.keys) {
        final data = _box!.get(key);
        if (data != null) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final timestamp = DateTime.parse(json['timestamp']);
            if (now.difference(timestamp) > effectiveMaxAge) {
              keysToRemove.add(key.toString());
            }
          } catch (_) {
            keysToRemove.add(key.toString());
          }
        }
      }

      for (final key in keysToRemove) {
        await _box!.delete(key);
      }
    }
  }

  Future<void> evictLeastRecentlyUsed() async {
    while (_memoryCache.length > _maxMemoryCacheSize) {
      final oldestKey = _accessOrder.isNotEmpty
          ? _accessOrder.removeAt(0)
          : null;
      if (oldestKey != null) {
        _memoryCache.remove(oldestKey);
      } else {
        break;
      }
    }

    if (_box != null && _box!.length > _maxDiskCacheSize) {
      final allEntries = <MapEntry<dynamic, DateTime>>[];

      for (final key in _box!.keys) {
        final data = _box!.get(key);
        if (data != null) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final lastAccessed = json['lastAccessed'] != null
                ? DateTime.parse(json['lastAccessed'])
                : DateTime.parse(json['timestamp']);
            allEntries.add(MapEntry(key, lastAccessed));
          } catch (_) {}
        }
      }

      allEntries.sort((a, b) => a.value.compareTo(b.value));

      final toRemove = allEntries.take(_box!.length - _maxDiskCacheSize);
      for (final entry in toRemove) {
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

class IncrementalUpdateResult<T> {
  final List<T> newItems;
  final List<T> updatedItems;
  final List<T> deletedItems;
  final DateTime lastUpdate;

  IncrementalUpdateResult({
    required this.newItems,
    required this.updatedItems,
    required this.deletedItems,
    required this.lastUpdate,
  });

  bool get hasChanges =>
      newItems.isNotEmpty || updatedItems.isNotEmpty || deletedItems.isNotEmpty;
}

class IncrementalCacheManager<T> {
  final LRUCacheManager _cacheManager;
  final String Function(T) getId;
  final DateTime Function(T)? getUpdatedAt;
  final int Function(T, T)? compareUpdate;

  IncrementalCacheManager({
    required this.getId,
    this.getUpdatedAt,
    this.compareUpdate,
    LRUCacheManager? cacheManager,
  }) : _cacheManager = cacheManager ?? LRUCacheManager.instance;

  Future<void> saveItems(String cacheKey, List<T> items) async {
    final now = DateTime.now();
    final data = {
      'items': items.map((e) => e).toList(),
      'lastUpdate': now.toIso8601String(),
      'count': items.length,
    };
    await _cacheManager.set(cacheKey, data);
  }

  Future<IncrementalUpdateResult<T>?> computeIncrementalUpdate({
    required String cacheKey,
    required List<T> newItems,
  }) async {
    final cachedData = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
    if (cachedData == null) {
      return null;
    }

    final cachedItems = (cachedData['items'] as List).cast<T>();
    final lastUpdate = DateTime.parse(cachedData['lastUpdate']);

    final cachedMap = <String, T>{};
    for (final item in cachedItems) {
      cachedMap[getId(item)] = item;
    }

    final newMap = <String, T>{};
    for (final item in newItems) {
      newMap[getId(item)] = item;
    }

    final newItemsList = <T>[];
    final updatedItems = <T>[];
    final deletedItems = <T>[];

    for (final entry in newMap.entries) {
      if (!cachedMap.containsKey(entry.key)) {
        newItemsList.add(entry.value);
      } else if (getUpdatedAt != null || compareUpdate != null) {
        final cachedItem = cachedMap[entry.key]!;
        final newItem = entry.value;

        bool isUpdated = false;
        if (compareUpdate != null) {
          isUpdated = compareUpdate!(cachedItem, newItem) != 0;
        } else if (getUpdatedAt != null) {
          final cachedTime = getUpdatedAt!(cachedItem);
          final newTime = getUpdatedAt!(newItem);
          isUpdated = newTime.isAfter(cachedTime);
        }

        if (isUpdated) {
          updatedItems.add(newItem);
        }
      }
    }

    for (final entry in cachedMap.entries) {
      if (!newMap.containsKey(entry.key)) {
        deletedItems.add(entry.value);
      }
    }

    return IncrementalUpdateResult(
      newItems: newItemsList,
      updatedItems: updatedItems,
      deletedItems: deletedItems,
      lastUpdate: lastUpdate,
    );
  }

  Future<List<T>> getItems(String cacheKey) async {
    final cachedData = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
    if (cachedData == null) return [];

    return (cachedData['items'] as List).cast<T>();
  }

  Future<DateTime?> getLastUpdate(String cacheKey) async {
    final cachedData = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
    if (cachedData == null) return null;

    return DateTime.parse(cachedData['lastUpdate']);
  }
}
