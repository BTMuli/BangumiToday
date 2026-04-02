import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class VirtualListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final double itemHeight;
  final double? itemWidth;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final Widget? emptyPlaceholder;
  final Widget? loadingPlaceholder;
  final bool isLoading;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double cacheExtent;
  final bool shrinkWrap;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final double loadMoreThreshold;

  const VirtualListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemHeight,
    this.itemWidth,
    this.padding,
    this.controller,
    this.emptyPlaceholder,
    this.loadingPlaceholder,
    this.isLoading = false,
    this.crossAxisCount = 1,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.cacheExtent = 500,
    this.shrinkWrap = false,
    this.onLoadMore,
    this.hasMore = false,
    this.loadMoreThreshold = 200,
  });

  @override
  State<VirtualListView<T>> createState() => _VirtualListViewState<T>();
}

class _VirtualListViewState<T> extends State<VirtualListView<T>> {
  late ScrollController _scrollController;
  int _firstVisibleIndex = 0;
  int _lastVisibleIndex = 0;
  final Map<int, Widget> _widgetCache = {};
  static const int _cachePadding = 5;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    _widgetCache.clear();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onLoadMore != null &&
        widget.hasMore &&
        !_scrollController.position.atEdge) {
      var maxScroll = _scrollController.position.maxScrollExtent;
      var currentScroll = _scrollController.position.pixels;

      if (maxScroll - currentScroll <= widget.loadMoreThreshold) {
        widget.onLoadMore!();
      }
    }
  }

  void _updateVisibleRange(double viewportHeight, double scrollOffset) {
    var itemFullHeight = widget.itemHeight + widget.mainAxisSpacing;
    _firstVisibleIndex =
        (scrollOffset / itemFullHeight).floor() - _cachePadding;
    _firstVisibleIndex = _firstVisibleIndex.clamp(0, widget.items.length - 1);

    var visibleCount =
        (viewportHeight / itemFullHeight).ceil() + _cachePadding * 2;
    _lastVisibleIndex = _firstVisibleIndex + visibleCount;
    _lastVisibleIndex = _lastVisibleIndex.clamp(0, widget.items.length);

    _cleanupCache();
  }

  void _cleanupCache() {
    var keysToRemove = <int>[];
    for (var key in _widgetCache.keys) {
      if (key < _firstVisibleIndex - _cachePadding * 2 ||
          key > _lastVisibleIndex + _cachePadding * 2) {
        keysToRemove.add(key);
      }
    }
    for (var key in keysToRemove) {
      _widgetCache.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.items.isEmpty) {
      return widget.loadingPlaceholder ??
          const Center(child: CircularProgressIndicator());
    }

    if (widget.items.isEmpty) {
      return widget.emptyPlaceholder ?? const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        var viewportHeight = constraints.maxHeight;
        var scrollOffset = _scrollController.hasClients
            ? _scrollController.position.pixels
            : 0.0;

        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _updateVisibleRange(viewportHeight, scrollOffset);
            });
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: widget.padding,
          cacheExtent: widget.cacheExtent,
          shrinkWrap: widget.shrinkWrap,
          itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= widget.items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (index < _firstVisibleIndex || index > _lastVisibleIndex) {
              return SizedBox(height: widget.itemHeight, child: null);
            }

            return _widgetCache.putIfAbsent(
              index,
              () => RepaintBoundary(
                key: ValueKey('item_$index'),
                child: SizedBox(
                  height: widget.itemHeight,
                  child: widget.itemBuilder(
                    context,
                    widget.items[index],
                    index,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class VirtualGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final double itemHeight;
  final double itemWidth;
  final int crossAxisCount;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final Widget? emptyPlaceholder;
  final Widget? loadingPlaceholder;
  final bool isLoading;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double cacheExtent;
  final bool shrinkWrap;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final double loadMoreThreshold;
  final double childAspectRatio;

  const VirtualGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemHeight,
    this.itemWidth = 200,
    this.crossAxisCount = 4,
    this.padding,
    this.controller,
    this.emptyPlaceholder,
    this.loadingPlaceholder,
    this.isLoading = false,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.cacheExtent = 500,
    this.shrinkWrap = false,
    this.onLoadMore,
    this.hasMore = false,
    this.loadMoreThreshold = 200,
    this.childAspectRatio = 10 / 7,
  });

  @override
  State<VirtualGridView<T>> createState() => _VirtualGridViewState<T>();
}

class _VirtualGridViewState<T> extends State<VirtualGridView<T>> {
  late ScrollController _scrollController;
  final Map<int, Widget> _widgetCache = {};

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    _widgetCache.clear();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onLoadMore != null &&
        widget.hasMore &&
        !_scrollController.position.atEdge) {
      var maxScroll = _scrollController.position.maxScrollExtent;
      var currentScroll = _scrollController.position.pixels;

      if (maxScroll - currentScroll <= widget.loadMoreThreshold) {
        widget.onLoadMore!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.items.isEmpty) {
      return widget.loadingPlaceholder ??
          const Center(child: CircularProgressIndicator());
    }

    if (widget.items.isEmpty) {
      return widget.emptyPlaceholder ?? const SizedBox.shrink();
    }

    return GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      cacheExtent: widget.cacheExtent,
      shrinkWrap: widget.shrinkWrap,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.childAspectRatio,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
      ),
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const Center(child: CircularProgressIndicator());
        }

        return _widgetCache.putIfAbsent(
          index,
          () => RepaintBoundary(
            key: ValueKey('grid_item_$index'),
            child: widget.itemBuilder(context, widget.items[index], index),
          ),
        );
      },
    );
  }
}

class LazyLoadScrollView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Future<List<T>> Function(int offset, int limit) loadMore;
  final int initialLimit;
  final int loadMoreLimit;
  final Widget? loadingIndicator;
  final Widget? emptyPlaceholder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Axis scrollDirection;

  const LazyLoadScrollView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.loadMore,
    this.initialLimit = 50,
    this.loadMoreLimit = 50,
    this.loadingIndicator,
    this.emptyPlaceholder,
    this.controller,
    this.padding,
    this.physics,
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<LazyLoadScrollView<T>> createState() => _LazyLoadScrollViewState<T>();
}

class _LazyLoadScrollViewState<T> extends State<LazyLoadScrollView<T>> {
  late ScrollController _scrollController;
  List<T> _loadedItems = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadedItems = List.from(widget.items);
    _currentOffset = _loadedItems.length;
  }

  @override
  void didUpdateWidget(LazyLoadScrollView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _loadedItems = List.from(widget.items);
      _currentOffset = _loadedItems.length;
      _hasMore = true;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore) return;

    var maxScroll = _scrollController.position.maxScrollExtent;
    var currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      var newItems = await widget.loadMore(
        _currentOffset,
        widget.loadMoreLimit,
      );

      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        setState(() {
          _loadedItems.addAll(newItems);
          _currentOffset += newItems.length;
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadedItems.isEmpty && !_isLoading) {
      return widget.emptyPlaceholder ?? const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      scrollDirection: widget.scrollDirection,
      itemCount: _loadedItems.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _loadedItems.length) {
          return widget.loadingIndicator ??
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
        }

        return RepaintBoundary(
          key: ValueKey('lazy_item_$index'),
          child: widget.itemBuilder(context, _loadedItems[index], index),
        );
      },
    );
  }
}
