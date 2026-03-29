import 'dart:convert';

import 'package:hive/hive.dart';

class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final String? etag;

  CacheEntry({
    required this.data,
    required this.timestamp,
    this.etag,
  });

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }

  Map<String, dynamic> toJson(T Function(T) serializer) {
    return {
      'data': serializer(data),
      'timestamp': timestamp.toIso8601String(),
      'etag': etag,
    };
  }

  factory CacheEntry.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) deserializer,
  ) {
    return CacheEntry(
      data: deserializer(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      etag: json['etag'],
    );
  }
}

class BTCacheManager {
  BTCacheManager._();

  static final BTCacheManager instance = BTCacheManager._();

  factory BTCacheManager() => instance;

  static const String _boxName = 'app_cache';

  Box<dynamic>? _box;

  final Map<String, dynamic> _memoryCache = {};

  final int _maxMemoryCacheSize = 100;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<T?> get<T>(
    String key, {
    Duration? maxAge,
    bool checkMemory = true,
    bool checkDisk = true,
  }) async {
    if (checkMemory) {
      var memData = _memoryCache[key];
      if (memData != null && memData is CacheEntry<T>) {
        if (maxAge == null || !memData.isExpired(maxAge)) {
          return memData.data;
        }
      }
    }

    if (checkDisk && _box != null) {
      var diskData = _box!.get(key);
      if (diskData != null) {
        try {
          var entry = CacheEntry.fromJson(
            jsonDecode(diskData) as Map<String, dynamic>,
            (d) => d as T,
          );
          if (maxAge == null || !entry.isExpired(maxAge)) {
            _setMemoryCache(key, entry);
            return entry.data;
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
    bool saveToMemory = true,
    bool saveToDisk = true,
  }) async {
    var entry = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      etag: etag,
    );

    if (saveToMemory) {
      _setMemoryCache(key, entry);
    }

    if (saveToDisk && _box != null) {
      await _box!.put(
        key,
        jsonEncode(entry.toJson((d) => d)),
      );
    }
  }

  Future<void> setJson<T>(
    String key,
    T data, {
    required Map<String, dynamic> Function(T) toJson,
    required T Function(Map<String, dynamic>) fromJson,
    String? etag,
    bool saveToMemory = true,
    bool saveToDisk = true,
  }) async {
    var entry = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      etag: etag,
    );

    if (saveToMemory) {
      _setMemoryCache(key, entry);
    }

    if (saveToDisk && _box != null) {
      var jsonData = {
        'data': toJson(data),
        'timestamp': entry.timestamp.toIso8601String(),
        'etag': etag,
      };
      await _box!.put(key, jsonEncode(jsonData));
    }
  }

  Future<T?> getJson<T>(
    String key, {
    required T Function(Map<String, dynamic>) fromJson,
    Duration? maxAge,
    bool checkMemory = true,
    bool checkDisk = true,
  }) async {
    if (checkMemory) {
      var memData = _memoryCache[key];
      if (memData != null && memData is CacheEntry<T>) {
        if (maxAge == null || !memData.isExpired(maxAge)) {
          return memData.data;
        }
      }
    }

    if (checkDisk && _box != null) {
      var diskData = _box!.get(key);
      if (diskData != null) {
        try {
          var json = jsonDecode(diskData) as Map<String, dynamic>;
          var data = fromJson(json['data'] as Map<String, dynamic>);
          var entry = CacheEntry(
            data: data,
            timestamp: DateTime.parse(json['timestamp']),
            etag: json['etag'],
          );
          if (maxAge == null || !entry.isExpired(maxAge)) {
            _setMemoryCache(key, entry);
            return entry.data;
          }
        } catch (_) {
          await delete(key);
        }
      }
    }

    return null;
  }

  Future<void> setList<T>(
    String key,
    List<T> data, {
    bool saveToMemory = true,
    bool saveToDisk = true,
  }) async {
    var entry = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
    );

    if (saveToMemory) {
      _setMemoryCache(key, entry);
    }

    if (saveToDisk && _box != null) {
      await _box!.put(key, jsonEncode({
        'data': data,
        'timestamp': entry.timestamp.toIso8601String(),
      }));
    }
  }

  Future<List<T>?> getList<T>(
    String key, {
    Duration? maxAge,
    bool checkMemory = true,
    bool checkDisk = true,
  }) async {
    if (checkMemory) {
      var memData = _memoryCache[key];
      if (memData != null && memData is CacheEntry<List<T>>) {
        if (maxAge == null || !memData.isExpired(maxAge)) {
          return memData.data;
        }
      }
    }

    if (checkDisk && _box != null) {
      var diskData = _box!.get(key);
      if (diskData != null) {
        try {
          var json = jsonDecode(diskData) as Map<String, dynamic>;
          var data = (json['data'] as List).cast<T>();
          var entry = CacheEntry(
            data: data,
            timestamp: DateTime.parse(json['timestamp']),
          );
          if (maxAge == null || !entry.isExpired(maxAge)) {
            _setMemoryCache(key, entry);
            return entry.data;
          }
        } catch (_) {
          await delete(key);
        }
      }
    }

    return null;
  }

  Future<void> delete(String key) async {
    _memoryCache.remove(key);
    if (_box != null) {
      await _box!.delete(key);
    }
  }

  Future<void> clear() async {
    _memoryCache.clear();
    if (_box != null) {
      await _box!.clear();
    }
  }

  Future<void> clearExpired(Duration maxAge) async {
    var now = DateTime.now();

    _memoryCache.removeWhere((key, value) {
      if (value is CacheEntry) {
        return now.difference(value.timestamp) > maxAge;
      }
      return false;
    });

    if (_box != null) {
      var keysToDelete = <dynamic>[];
      for (var key in _box!.keys) {
        var data = _box!.get(key);
        if (data != null) {
          try {
            var json = jsonDecode(data) as Map<String, dynamic>;
            var timestamp = DateTime.parse(json['timestamp']);
            if (now.difference(timestamp) > maxAge) {
              keysToDelete.add(key);
            }
          } catch (_) {
            keysToDelete.add(key);
          }
        }
      }
      for (var key in keysToDelete) {
        await _box!.delete(key);
      }
    }
  }

  void _setMemoryCache(String key, CacheEntry entry) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = entry;
  }

  bool exists(String key) {
    return _memoryCache.containsKey(key) || (_box?.containsKey(key) ?? false);
  }

  int get memoryCacheSize => _memoryCache.length;

  int get diskCacheSize => _box?.length ?? 0;
}

class CacheKeys {
  static const String bangumiCalendar = 'bangumi_calendar';
  static const String bangumiSubject = 'bangumi_subject';
  static const String bangumiEpisodes = 'bangumi_episodes';
  static const String userCollection = 'user_collection';
  static const String userCollections = 'user_collections';
  static const String searchResult = 'search_result';
  static const String rssData = 'rss_data';

  static String subject(int id) => '${bangumiSubject}_$id';
  static String episodes(int id) => '${bangumiEpisodes}_$id';
  static String collection(String username, int subjectId) =>
      '${userCollection}_${username}_$subjectId';
  static String collections(String username) =>
      '${userCollections}_$username';
  static String search(String keyword, int offset) =>
      '${searchResult}_${keyword}_$offset';
  static String rss(String source) => '${rssData}_$source';
}

class CacheDuration {
  static const Duration short = Duration(minutes: 15);
  static const Duration medium = Duration(hours: 6);
  static const Duration long = Duration(days: 1);
  static const Duration veryLong = Duration(days: 7);
}
