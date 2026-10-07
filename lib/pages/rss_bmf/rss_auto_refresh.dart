// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/utils/rss_date.dart';
import '../../tools/log_tool.dart';

/// Refreshes the visible feed without letting kept-alive tabs keep polling.
class RssAutoRefresh extends StatefulWidget {
  const RssAutoRefresh({
    super.key,
    required this.refreshing,
    required this.lastUpdated,
    required this.lastAttempt,
    required this.onRefresh,
    required this.child,
    this.enabled = true,
  });

  final bool refreshing;
  final DateTime? lastUpdated;
  final DateTime? lastAttempt;
  final Future<void> Function() onRefresh;
  final Widget child;
  final bool enabled;

  @override
  State<RssAutoRefresh> createState() => _RssAutoRefreshState();
}

class _RssAutoRefreshState extends State<RssAutoRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _visible = false;
  bool _checking = false;
  bool _checkScheduled = false;

  bool get _active =>
      _visible &&
      widget.enabled &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _syncTimer();
  }

  @override
  void didUpdateWidget(RssAutoRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncTimer();

  void _syncTimer() {
    if (!_active) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_check()),
    );
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      unawaited(_check());
    });
  }

  Future<void> _check() async {
    if (!mounted ||
        !_active ||
        _checking ||
        widget.refreshing ||
        !rssRefreshDue(
          now: DateTime.now(),
          lastUpdated: widget.lastUpdated,
          lastAttempt: widget.lastAttempt,
        )) {
      return;
    }
    _checking = true;
    try {
      await widget.onRefresh();
    } catch (error) {
      BTLogTool.warn('RSS 列表自动刷新失败：${error.runtimeType}');
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
