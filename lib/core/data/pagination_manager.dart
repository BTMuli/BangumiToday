import 'dart:async';

import 'package:flutter/foundation.dart';

class PaginationState<T> {
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  PaginationState({
    this.items = const [],
    this.currentPage = 0,
    this.totalPages = 0,
    this.totalItems = 0,
    this.pageSize = 50,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    int? pageSize,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      pageSize: pageSize ?? this.pageSize,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class PaginationResult<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  PaginationResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });
}

class PaginationManager<T> extends ChangeNotifier {
  final Future<PaginationResult<T>> Function(int page, int pageSize) fetchPage;
  final int pageSize;
  final int maxCachedPages;
  final bool keepAllItems;

  PaginationState<T> _state = PaginationState<T>();
  final Map<int, List<T>> _pageCache = {};
  final StreamController<PaginationState<T>> _stateController =
      StreamController<PaginationState<T>>.broadcast();

  PaginationManager({
    required this.fetchPage,
    this.pageSize = 50,
    this.maxCachedPages = 10,
    this.keepAllItems = true,
  });

  PaginationState<T> get state => _state;
  Stream<PaginationState<T>> get stateStream => _stateController.stream;
  List<T> get items => _state.items;
  bool get isLoading => _state.isLoading;
  bool get hasMore => _state.hasMore;

  Future<void> loadFirstPage() async {
    if (_state.isLoading) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();
    _stateController.add(_state);

    try {
      final result = await fetchPage(1, pageSize);

      _pageCache[1] = result.items;
      _cleanupCache();

      _state = PaginationState<T>(
        items: result.items,
        currentPage: 1,
        totalPages: (result.total / pageSize).ceil(),
        totalItems: result.total,
        pageSize: pageSize,
        isLoading: false,
        hasMore: result.hasMore,
      );

      notifyListeners();
      _stateController.add(_state);
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      notifyListeners();
      _stateController.add(_state);
    }
  }

  Future<void> loadNextPage() async {
    if (_state.isLoading || !_state.hasMore) return;

    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    _stateController.add(_state);

    try {
      final nextPage = _state.currentPage + 1;
      final result = await fetchPage(nextPage, pageSize);

      _pageCache[nextPage] = result.items;
      _cleanupCache();

      final newItems = keepAllItems
          ? [..._state.items, ...result.items]
          : _getVisibleItems(nextPage);

      _state = _state.copyWith(
        items: newItems,
        currentPage: nextPage,
        totalPages: (result.total / pageSize).ceil(),
        totalItems: result.total,
        isLoading: false,
        hasMore: result.hasMore,
      );

      notifyListeners();
      _stateController.add(_state);
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      notifyListeners();
      _stateController.add(_state);
    }
  }

  Future<void> refresh() async {
    _pageCache.clear();
    _state = PaginationState<T>(pageSize: pageSize);
    await loadFirstPage();
  }

  Future<void> loadPage(int page) async {
    if (_state.isLoading) return;

    if (_pageCache.containsKey(page)) {
      _state = _state.copyWith(
        items: _getVisibleItems(page),
        currentPage: page,
      );
      notifyListeners();
      _stateController.add(_state);
      return;
    }

    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    _stateController.add(_state);

    try {
      final result = await fetchPage(page, pageSize);

      _pageCache[page] = result.items;
      _cleanupCache();

      _state = _state.copyWith(
        items: _getVisibleItems(page),
        currentPage: page,
        totalPages: (result.total / pageSize).ceil(),
        totalItems: result.total,
        isLoading: false,
        hasMore: page < (result.total / pageSize).ceil(),
      );

      notifyListeners();
      _stateController.add(_state);
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      notifyListeners();
      _stateController.add(_state);
    }
  }

  List<T> _getVisibleItems(int currentPage) {
    if (keepAllItems) {
      final allItems = <T>[];
      for (int i = 1; i <= currentPage; i++) {
        if (_pageCache.containsKey(i)) {
          allItems.addAll(_pageCache[i]!);
        }
      }
      return allItems;
    } else {
      return _pageCache[currentPage] ?? [];
    }
  }

  void _cleanupCache() {
    while (_pageCache.length > maxCachedPages) {
      final oldestPage = _pageCache.keys.reduce((a, b) => a < b ? a : b);
      _pageCache.remove(oldestPage);
    }
  }

  void clearCache() {
    _pageCache.clear();
  }

  @override
  void dispose() {
    _pageCache.clear();
    _stateController.close();
    super.dispose();
  }
}

class LazyListManager<T> {
  final Future<List<T>> Function(int offset, int limit) fetchData;
  final int initialLimit;
  final int loadMoreLimit;
  final int maxCachedItems;

  List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  String? _error;

  final StreamController<LazyListState<T>> _stateController =
      StreamController<LazyListState<T>>.broadcast();

  LazyListManager({
    required this.fetchData,
    this.initialLimit = 50,
    this.loadMoreLimit = 50,
    this.maxCachedItems = 1000,
  });

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int get count => _items.length;
  String? get error => _error;
  Stream<LazyListState<T>> get stateStream => _stateController.stream;

  Future<void> loadInitial() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _emitState();

    try {
      final newItems = await fetchData(0, initialLimit);

      _items = newItems;
      _currentOffset = newItems.length;
      _hasMore = newItems.length >= initialLimit;

      _emitState();
    } catch (e) {
      _error = e.toString();
      _emitState();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _emitState();

    try {
      final newItems = await fetchData(_currentOffset, loadMoreLimit);

      if (newItems.length < loadMoreLimit) {
        _hasMore = false;
      }

      _items.addAll(newItems);
      _currentOffset += newItems.length;

      if (_items.length > maxCachedItems) {
        final removeCount = _items.length - maxCachedItems;
        _items.removeRange(0, removeCount);
      }

      _emitState();
    } catch (e) {
      _error = e.toString();
      _emitState();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() async {
    _items.clear();
    _currentOffset = 0;
    _hasMore = true;
    _error = null;
    await loadInitial();
  }

  void clear() {
    _items.clear();
    _currentOffset = 0;
    _hasMore = true;
    _error = null;
    _emitState();
  }

  void _emitState() {
    _stateController.add(LazyListState<T>(
      items: List.unmodifiable(_items),
      isLoading: _isLoading,
      hasMore: _hasMore,
      error: _error,
    ));
  }

  void dispose() {
    _stateController.close();
  }
}

class LazyListState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  LazyListState({
    required this.items,
    required this.isLoading,
    required this.hasMore,
    this.error,
  });
}

class DataBatchProcessor<T> {
  final int batchSize;
  final Duration batchDelay;
  final void Function(List<T> batch) processBatch;

  final List<T> _pendingItems = [];
  Timer? _batchTimer;
  bool _isProcessing = false;

  DataBatchProcessor({
    required this.processBatch,
    this.batchSize = 100,
    this.batchDelay = const Duration(milliseconds: 100),
  });

  void add(T item) {
    _pendingItems.add(item);
    _scheduleProcessing();
  }

  void addAll(List<T> items) {
    _pendingItems.addAll(items);
    _scheduleProcessing();
  }

  void _scheduleProcessing() {
    if (_pendingItems.length >= batchSize) {
      _processNow();
    } else {
      _batchTimer ??= Timer(batchDelay, _processNow);
    }
  }

  void _processNow() {
    _batchTimer?.cancel();
    _batchTimer = null;

    if (_pendingItems.isEmpty || _isProcessing) return;

    _isProcessing = true;
    final batch = _pendingItems.toList();
    _pendingItems.clear();

    try {
      processBatch(batch);
    } finally {
      _isProcessing = false;

      if (_pendingItems.isNotEmpty) {
        _scheduleProcessing();
      }
    }
  }

  Future<void> flush() async {
    while (_pendingItems.isNotEmpty || _isProcessing) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
  }
}
