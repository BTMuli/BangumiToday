import 'package:flutter/foundation.dart';

class OptimizedDataList<T> {
  final List<T> _items;
  final int _totalCount;
  final DateTime _createdAt;
  final String? _cursor;

  OptimizedDataList({required List<T> items, int? totalCount, String? cursor})
    : _items = List.unmodifiable(items),
      _totalCount = totalCount ?? items.length,
      _createdAt = DateTime.now(),
      _cursor = cursor;

  List<T> get items => _items;
  int get length => _items.length;
  int get totalCount => _totalCount;
  bool get hasMore => _items.length < _totalCount;
  DateTime get createdAt => _createdAt;
  String? get cursor => _cursor;

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  T operator [](int index) => _items[index];

  OptimizedDataList<T> append(OptimizedDataList<T> other) {
    return OptimizedDataList(
      items: [..._items, ...other._items],
      totalCount: other._totalCount,
      cursor: other._cursor,
    );
  }

  OptimizedDataList<T> prepend(OptimizedDataList<T> other) {
    return OptimizedDataList(
      items: [...other._items, ..._items],
      totalCount: _totalCount + other._totalCount,
      cursor: _cursor,
    );
  }

  OptimizedDataList<T> slice(int start, [int? end]) {
    return OptimizedDataList(
      items: _items.sublist(start, end),
      totalCount: _totalCount,
      cursor: _cursor,
    );
  }

  OptimizedDataList<R> map<R>(R Function(T) mapper) {
    return OptimizedDataList(
      items: _items.map(mapper).toList(),
      totalCount: _totalCount,
      cursor: _cursor,
    );
  }

  OptimizedDataList<T> where(bool Function(T) test) {
    return OptimizedDataList(
      items: _items.where(test).toList(),
      cursor: _cursor,
    );
  }

  void forEach(void Function(T) action) {
    _items.forEach(action);
  }

  T? firstWhere(bool Function(T) test, {T Function()? orElse}) {
    return _items.firstWhere(test, orElse: orElse);
  }

  T? lastWhere(bool Function(T) test, {T Function()? orElse}) {
    return _items.lastWhere(test, orElse: orElse);
  }

  int indexWhere(bool Function(T) test, [int start = 0]) {
    return _items.indexWhere(test, start);
  }

  bool any(bool Function(T) test) => _items.any(test);

  bool every(bool Function(T) test) => _items.every(test);

  Iterable<T> get iterable => _items;

  List<R> toList<R>({bool growable = true}) {
    return _items.cast<R>().toList(growable: growable);
  }

  Set<T> toSet() => _items.toSet();

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) itemToJson) {
    return {
      'items': _items.map(itemToJson).toList(),
      'totalCount': _totalCount,
      'createdAt': _createdAt.toIso8601String(),
      'cursor': _cursor,
    };
  }

  factory OptimizedDataList.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    return OptimizedDataList(
      items: (json['items'] as List)
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'],
      cursor: json['cursor'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OptimizedDataList<T>) return false;
    if (_totalCount != other._totalCount) return false;
    if (_cursor != other._cursor) return false;
    if (_items.length != other._items.length) return false;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i] != other._items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(_items, _totalCount, _cursor);
}

class DataDiff<T> {
  final List<T> added;
  final List<T> removed;
  final List<(T oldItem, T newItem)> updated;
  final List<T> unchanged;

  DataDiff({
    required this.added,
    required this.removed,
    required this.updated,
    required this.unchanged,
  });

  bool get hasChanges =>
      added.isNotEmpty || removed.isNotEmpty || updated.isNotEmpty;

  int get totalChanges => added.length + removed.length + updated.length;

  static DataDiff<T> compute<T>(
    List<T> oldList,
    List<T> newList,
    Object Function(T) getId,
    bool Function(T, T) isEqual,
  ) {
    var oldMap = <Object, T>{};
    for (var item in oldList) {
      oldMap[getId(item)] = item;
    }

    var newMap = <Object, T>{};
    for (var item in newList) {
      newMap[getId(item)] = item;
    }

    var added = <T>[];
    var removed = <T>[];
    var updated = <(T, T)>[];
    var unchanged = <T>[];

    for (var entry in newMap.entries) {
      if (!oldMap.containsKey(entry.key)) {
        added.add(entry.value);
      } else {
        var oldItem = oldMap[entry.key] as T;
        if (!isEqual(oldItem, entry.value)) {
          updated.add((oldItem, entry.value));
        } else {
          unchanged.add(entry.value);
        }
      }
    }

    for (var entry in oldMap.entries) {
      if (!newMap.containsKey(entry.key)) {
        removed.add(entry.value);
      }
    }

    return DataDiff(
      added: added,
      removed: removed,
      updated: updated,
      unchanged: unchanged,
    );
  }
}

class DataStore<T> extends ChangeNotifier {
  OptimizedDataList<T> _data;
  final int maxSize;
  final void Function(T)? onEvict;

  DataStore({List<T>? initialData, this.maxSize = 10000, this.onEvict})
    : _data = OptimizedDataList(items: initialData ?? []);

  OptimizedDataList<T> get data => _data;
  List<T> get items => _data.items;
  int get length => _data.length;
  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;

  T operator [](int index) => _data[index];

  void setData(List<T> items, {int? totalCount, String? cursor}) {
    _data = OptimizedDataList(
      items: items,
      totalCount: totalCount,
      cursor: cursor,
    );
    notifyListeners();
  }

  void appendData(List<T> items, {int? totalCount, String? cursor}) {
    var newItems = [..._data.items, ...items];
    if (newItems.length > maxSize) {
      var evictedCount = newItems.length - maxSize;
      var evictedItems = newItems.take(evictedCount);
      for (var item in evictedItems) {
        onEvict?.call(item);
      }
      newItems.removeRange(0, evictedCount);
    }

    _data = OptimizedDataList(
      items: newItems,
      totalCount: totalCount ?? _data.totalCount,
      cursor: cursor,
    );
    notifyListeners();
  }

  void prependData(List<T> items) {
    _data = _data.prepend(OptimizedDataList(items: items));
    notifyListeners();
  }

  void updateItem(int index, T newItem) {
    var newItems = List<T>.from(_data.items);
    newItems[index] = newItem;
    _data = OptimizedDataList(
      items: newItems,
      totalCount: _data.totalCount,
      cursor: _data.cursor,
    );
    notifyListeners();
  }

  void removeItem(int index) {
    var newItems = List<T>.from(_data.items);
    var removedItem = newItems.removeAt(index);
    onEvict?.call(removedItem);
    _data = OptimizedDataList(
      items: newItems,
      totalCount: _data.totalCount - 1,
      cursor: _data.cursor,
    );
    notifyListeners();
  }

  void removeWhere(bool Function(T) test) {
    var newItems = <T>[];
    for (var item in _data.items) {
      if (test(item)) {
        onEvict?.call(item);
      } else {
        newItems.add(item);
      }
    }
    _data = OptimizedDataList(
      items: newItems,
      totalCount: newItems.length,
      cursor: _data.cursor,
    );
    notifyListeners();
  }

  void clear() {
    for (var item in _data.items) {
      onEvict?.call(item);
    }
    _data = OptimizedDataList(items: []);
    notifyListeners();
  }

  void applyDiff(DataDiff<T> diff) {
    var newItems = List<T>.from(_data.items);

    for (var item in diff.removed) {
      newItems.remove(item);
    }

    for (var (oldItem, newItem) in diff.updated) {
      var index = newItems.indexOf(oldItem);
      if (index != -1) {
        newItems[index] = newItem;
      }
    }

    newItems.insertAll(0, diff.added);

    _data = OptimizedDataList(items: newItems);
    notifyListeners();
  }
}

class LazyDataLoader<T> {
  final Future<List<T>> Function(int offset, int limit) fetchFunction;
  final int batchSize;
  final int maxCacheSize;

  final List<T> _cache = [];
  int _totalSize = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  LazyDataLoader({
    required this.fetchFunction,
    this.batchSize = 100,
    this.maxCacheSize = 1000,
  });

  List<T> get cachedItems => List.unmodifiable(_cache);
  int get cachedCount => _cache.length;
  int get totalCount => _totalSize;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;

  Future<List<T>> loadInitial() async {
    if (_isLoading) return [];

    _isLoading = true;
    try {
      var items = await fetchFunction(0, batchSize);
      _cache.clear();
      _cache.addAll(items);
      _hasMore = items.length >= batchSize;
      _totalSize = items.length;
      return items;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<T>> loadMore() async {
    if (_isLoading || !_hasMore) return [];

    _isLoading = true;
    try {
      var items = await fetchFunction(_cache.length, batchSize);
      _cache.addAll(items);
      _hasMore = items.length >= batchSize;

      if (_cache.length > maxCacheSize) {
        var removeCount = _cache.length - maxCacheSize;
        _cache.removeRange(0, removeCount);
      }

      return items;
    } finally {
      _isLoading = false;
    }
  }

  Future<List<T>> getRange(int start, int end) async {
    if (start < 0 || end < start) return [];

    if (end <= _cache.length) {
      return _cache.sublist(start, end);
    }

    while (_hasMore && _cache.length < end) {
      await loadMore();
    }

    var actualEnd = end.clamp(0, _cache.length);
    return _cache.sublist(start, actualEnd);
  }

  void clearCache() {
    _cache.clear();
    _totalSize = 0;
    _hasMore = true;
  }
}
