import 'package:fluent_ui/fluent_ui.dart';

class LazyLoadWrapper extends StatefulWidget {
  final Widget Function(BuildContext) builder;
  final bool keepAlive;
  final Duration preloadOffset;
  final VoidCallback? onVisible;
  final VoidCallback? onInvisible;
  final Widget? placeholder;

  const LazyLoadWrapper({
    super.key,
    required this.builder,
    this.keepAlive = false,
    this.preloadOffset = const Duration(milliseconds: 100),
    this.onVisible,
    this.onInvisible,
    this.placeholder,
  });

  @override
  State<LazyLoadWrapper> createState() => _LazyLoadWrapperState();
}

class _LazyLoadWrapperState extends State<LazyLoadWrapper>
    with AutomaticKeepAliveClientMixin {
  bool _isVisible = false;
  bool _isLoaded = false;
  Widget? _cachedWidget;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  void _onVisibilityChanged(bool isVisible) {
    if (_isVisible != isVisible) {
      _isVisible = isVisible;
      if (isVisible) {
        widget.onVisible?.call();
        if (!_isLoaded) {
          setState(() {
            _isLoaded = true;
          });
        }
      } else {
        widget.onInvisible?.call();
        if (!widget.keepAlive && _isLoaded) {
          _cachedWidget = null;
          setState(() {
            _isLoaded = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null && mounted) {
            final scrollableState = Scrollable.of(context);
            final position = scrollableState.position;
            final viewport = position.viewportDimension;

            final widgetTop = renderBox.localToGlobal(Offset.zero).dy;
            final widgetBottom = widgetTop + renderBox.size.height;

            final isVisible = widgetBottom > 0 && widgetTop < viewport;

            _onVisibilityChanged(isVisible);
          }
        }
        return false;
      },
      child: _isLoaded
          ? (_cachedWidget ??= widget.builder(context))
          : (widget.placeholder ?? const SizedBox.shrink()),
    );
  }
}

class LazyTabPage extends StatefulWidget {
  final List<Tab> tabs;
  final int currentIndex;
  final void Function(int)? onChanged;
  final Widget? header;
  final Widget? footer;
  final double? cacheExtent;
  final bool lazyLoad;

  const LazyTabPage({
    super.key,
    required this.tabs,
    this.currentIndex = 0,
    this.onChanged,
    this.header,
    this.footer,
    this.cacheExtent,
    this.lazyLoad = true,
  });

  @override
  State<LazyTabPage> createState() => _LazyTabPageState();
}

class _LazyTabPageState extends State<LazyTabPage> {
  late int _currentIndex;
  final Set<int> _loadedIndices = {};
  final Map<int, Widget> _cachedBodies = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _loadedIndices.add(_currentIndex);
  }

  @override
  void didUpdateWidget(LazyTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _currentIndex = widget.currentIndex;
      _loadedIndices.add(_currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.header != null) widget.header!,
        Expanded(
          child: IndexedStack(
            index: _currentIndex,
            children: widget.tabs.asMap().entries.map((entry) {
              final index = entry.key;

              if (!widget.lazyLoad || _loadedIndices.contains(index)) {
                return _cachedBodies.putIfAbsent(
                  index,
                  () => entry.value.body,
                );
              }
              return const SizedBox.shrink();
            }).toList(),
          ),
        ),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }
}

class LazyNavigationView extends StatefulWidget {
  final List<PaneItem> items;
  final List<PaneItem>? footerItems;
  final int selectedIndex;
  final void Function(int)? onChanged;
  final bool lazyLoad;
  final int preloadCount;

  const LazyNavigationView({
    super.key,
    required this.items,
    this.footerItems,
    this.selectedIndex = 0,
    this.onChanged,
    this.lazyLoad = true,
    this.preloadCount = 1,
  });

  @override
  State<LazyNavigationView> createState() => _LazyNavigationViewState();
}

class _LazyNavigationViewState extends State<LazyNavigationView> {
  late int _selectedIndex;
  final Set<int> _loadedIndices = {};
  final Map<int, Widget> _cachedBodies = {};

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _loadedIndices.add(_selectedIndex);
    _preloadAdjacent();
  }

  @override
  void didUpdateWidget(LazyNavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _selectedIndex = widget.selectedIndex;
      _loadedIndices.add(_selectedIndex);
      _cachedBodies.removeWhere(
          (key, _) => (key - _selectedIndex).abs() > widget.preloadCount + 2);
      _preloadAdjacent();
    }
  }

  void _preloadAdjacent() {
    for (int i = 1; i <= widget.preloadCount; i++) {
      final prevIndex = _selectedIndex - i;
      final nextIndex = _selectedIndex + i;
      if (prevIndex >= 0) _loadedIndices.add(prevIndex);
      if (nextIndex < widget.items.length) _loadedIndices.add(nextIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _selectedIndex,
      children: widget.items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        if (!widget.lazyLoad || _loadedIndices.contains(index)) {
          return _cachedBodies.putIfAbsent(
            index,
            () => item.body,
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}
