part of '../download_task_details.dart';

class _TrackerGraph extends StatefulWidget {
  const _TrackerGraph({
    required this.trackers,
    required this.onShowPeers,
    this.showDetails = false,
    super.key,
  });

  final List<BtTaskTrackerDetail> trackers;
  final ValueChanged<String> onShowPeers;
  final bool showDetails;

  @override
  State<_TrackerGraph> createState() => _TrackerGraphState();
}

class _TrackerGraphState extends State<_TrackerGraph>
    with SingleTickerProviderStateMixin {
  String? _selectedId;
  int? _selectedTier;
  bool _taskSelected = false;
  late final AnimationController _flow;
  final TransformationController _transform = TransformationController();
  Size _viewport = Size.zero;
  final Set<int> _pointers = {};
  int? _pressedPointer;
  Offset? _pressOrigin;
  bool _pointerGesture = false;

  void _finishPointerGesture() {
    if (!mounted || _pointers.isNotEmpty) return;
    scheduleMicrotask(() {
      if (mounted && _pointers.isEmpty) _pointerGesture = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _taskSelected = widget.showDetails;
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_flow.isAnimating) _flow.repeat();
    } else {
      _flow.stop();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _select({String? trackerId, int? tier, bool task = false}) {
    if (!mounted) return;
    if (_selectedId == trackerId &&
        _selectedTier == tier &&
        _taskSelected == task) {
      return;
    }
    var wasOpen = _selectedId != null || _selectedTier != null || _taskSelected;
    var willOpen = trackerId != null || tier != null || task;
    if (wasOpen != willOpen) _transform.value = Matrix4.identity();
    setState(() {
      _selectedId = trackerId;
      _selectedTier = tier;
      _taskSelected = task;
    });
  }

  void _zoom(double factor) {
    var center = _viewport.center(Offset.zero);
    var sceneCenter = _transform.toScene(center);
    var scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      12.0,
    );
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, center.dx - sceneCenter.dx * scale)
      ..setEntry(1, 3, center.dy - sceneCenter.dy * scale);
  }

  @override
  Widget build(BuildContext context) {
    var byTier = <int, Map<String, List<BtTaskTrackerDetail>>>{};
    for (var row in widget.trackers) {
      byTier
          .putIfAbsent(row.tier, () => {})
          .putIfAbsent(row.url, () => [])
          .add(row);
    }
    var tiers = byTier.keys.toList()..sort();
    var groups = <_TrackerGraphGroup>[
      for (var tier in tiers)
        for (var url in (byTier[tier]!.keys.toList()..sort()))
          _TrackerGraphGroup(tier, url, byTier[tier]![url]!),
    ];
    _TrackerGraphGroup? selected;
    for (var group in groups) {
      if (group.id == _selectedId) selected = group;
    }
    var selection = selected;
    var detailGroups = selection != null
        ? [selection]
        : _taskSelected
        ? groups
        : groups.where((group) => group.tier == _selectedTier).toList();
    var detailTitle =
        selection?.url ??
        (_taskSelected
            ? '当前任务 · ${groups.length} 个 Tracker'
            : '层级 $_selectedTier');
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _canvas(
                  context,
                  groups,
                  tiers,
                  selection,
                  vertical: detailGroups.isNotEmpty,
                ),
              ),
              if (detailGroups.isNotEmpty)
                Expanded(
                  child: _TrackerGraphDetails(
                    title: detailTitle,
                    groups: detailGroups,
                    onClose: _select,
                    onShowPeers: widget.onShowPeers,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (var state in [
                      'working',
                      'error',
                      'mixed',
                      'updating',
                      'waiting',
                    ])
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _graphStateColor(context, state),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          _TrackerStatus(state: state),
                        ],
                      ),
                  ],
                ),
              ),
              Tooltip(
                message: '缩小节点图',
                child: IconButton(
                  icon: const Icon(FluentIcons.remove, size: 14),
                  onPressed: () => _zoom(1 / 1.25),
                ),
              ),
              Tooltip(
                message: '放大节点图',
                child: IconButton(
                  icon: const Icon(FluentIcons.add, size: 14),
                  onPressed: () => _zoom(1.25),
                ),
              ),
              Tooltip(
                message: '适配整个节点图',
                child: IconButton(
                  icon: const Icon(FluentIcons.fit_page, size: 14),
                  onPressed: () => _transform.value = Matrix4.identity(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _canvas(
    BuildContext context,
    List<_TrackerGraphGroup> groups,
    List<int> tiers,
    _TrackerGraphGroup? selected, {
    required bool vertical,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      _viewport = constraints.biggest;
      var width = max(
        vertical ? 360.0 : 480.0,
        vertical ? constraints.maxHeight : constraints.maxWidth,
      );
      var crossViewport = vertical
          ? constraints.maxWidth
          : constraints.maxHeight;
      var crossStart = vertical ? 100.0 : 52.0;
      var crossPadding = crossStart + 24;
      var targetRows = max(4, ((crossViewport - crossPadding) / 36).floor());
      var tierColumns = min(
        max(1, (width * .19 / 36).floor() + 1),
        (tiers.length / targetRows).ceil(),
      );
      var trackerColumns = min(
        max(1, (width * .36 / 36).floor() + 1),
        (groups.length / targetRows).ceil(),
      );
      var tierRows = (tiers.length / tierColumns).ceil();
      var trackerRows = (groups.length / trackerColumns).ceil();
      var height = max(
        crossViewport,
        crossPadding + (max(tierRows, trackerRows) - 1) * 36,
      );
      var sceneSize = vertical ? Size(height, width) : Size(width, height);
      Offset orient(Offset point) =>
          vertical ? Offset(point.dy, point.dx) : point;
      var trackerPoints = <String, Offset>{};
      var tierPoints = <int, Offset>{};
      Offset point(
        int index,
        int count,
        int columns,
        double left,
        double right,
      ) {
        var rows = (count / columns).ceil();
        var column = index ~/ rows;
        var columnRows = min(rows, count - column * rows);
        return orient(
          Offset(
            columns == 1
                ? (left + right) / 2
                : left + column * (right - left) / (columns - 1),
            (crossStart + height - 24) / 2 +
                (index % rows - (columnRows - 1) / 2) * 36,
          ),
        );
      }

      for (var index = 0; index < tiers.length; index++) {
        tierPoints[tiers[index]] = point(
          index,
          tiers.length,
          tierColumns,
          width * .24,
          width * .43,
        );
      }
      for (var index = 0; index < groups.length; index++) {
        trackerPoints[groups[index].id] = point(
          index,
          groups.length,
          trackerColumns,
          width * .58,
          width * .94,
        );
      }
      var root = orient(Offset(width * .08, (crossStart + height - 24) / 2));
      var accent = FluentTheme.of(context).accentColor;
      var links = <_TrackerGraphLink>[
        for (var tier in tiers)
          _TrackerGraphLink(
            root,
            tierPoints[tier]!,
            _taskSelected || (selected?.tier ?? _selectedTier) == tier
                ? accent
                : BTColors.textTertiary(context),
            _taskSelected || (selected?.tier ?? _selectedTier) == tier,
            vertical: vertical,
          ),
        for (var group in groups)
          _TrackerGraphLink(
            tierPoints[group.tier]!,
            trackerPoints[group.id]!,
            _graphStateColor(context, group.state),
            _taskSelected ||
                group.id == selected?.id ||
                group.tier == _selectedTier,
            vertical: vertical,
          ),
      ];
      var targets = <(Offset, VoidCallback)>[
        (root, () => _select(task: true)),
        for (var tier in tiers) (tierPoints[tier]!, () => _select(tier: tier)),
        for (var group in groups)
          (trackerPoints[group.id]!, () => _select(trackerId: group.id)),
      ];
      void selectAt(Offset viewportPoint) {
        var fitScale = min(
          _viewport.width / sceneSize.width,
          _viewport.height / sceneSize.height,
        );
        var fitOffset = Offset(
          (_viewport.width - sceneSize.width * fitScale) / 2,
          (_viewport.height - sceneSize.height * fitScale) / 2,
        );
        var scenePoint =
            (_transform.toScene(viewportPoint) - fitOffset) / fitScale;
        var distance = max(
          18.0,
          12 / (fitScale * _transform.value.getMaxScaleOnAxis()),
        );
        VoidCallback? nearest;
        for (var target in targets) {
          var candidate = (target.$1 - scenePoint).distance;
          if (candidate <= distance) {
            distance = candidate;
            nearest = target.$2;
          }
        }
        nearest?.call();
      }

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          _pointerGesture = true;
          _pointers.add(event.pointer);
          if (_pointers.length == 1 && event.buttons == kPrimaryMouseButton) {
            _pressedPointer = event.pointer;
            _pressOrigin = event.position;
          } else {
            _pressedPointer = null;
          }
        },
        onPointerMove: (event) {
          if (_pressedPointer == event.pointer &&
              _pressOrigin != null &&
              (event.position - _pressOrigin!).distance > kTouchSlop / 2) {
            _pressedPointer = null;
          }
        },
        onPointerUp: (event) {
          var activate = _pressedPointer == event.pointer;
          _pointers.remove(event.pointer);
          _pressedPointer = null;
          if (activate) selectAt(event.localPosition);
          _finishPointerGesture();
        },
        onPointerCancel: (event) {
          _pointers.remove(event.pointer);
          _pressedPointer = null;
          _finishPointerGesture();
        },
        onPointerSignal: (_) => _pressedPointer = null,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 12,
          trackpadScrollCausesScale: true,
          boundaryMargin: const EdgeInsets.all(24),
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: sceneSize.width,
                height: sceneSize.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _TrackerGraphPainter(links, _flow),
                          ),
                        ),
                      ),
                    ),
                    for (var header in [
                      (width * .08, '任务'),
                      (width * .335, '层级'),
                      (width * .76, 'Tracker ${groups.length}'),
                    ])
                      Positioned(
                        left: vertical ? 8 : header.$1 - 36,
                        top: vertical ? header.$1 - 8 : 12,
                        width: 72,
                        child: Text(
                          header.$2,
                          textAlign: vertical
                              ? TextAlign.left
                              : TextAlign.center,
                          style: BTTypography.caption(context),
                        ),
                      ),
                    _node(
                      root,
                      color: accent,
                      tooltip: '当前页 · ${groups.length} 个 Tracker',
                      selected:
                          _taskSelected ||
                          selected != null ||
                          tiers.contains(_selectedTier),
                      onPressed: () => _select(task: true),
                      child: const Icon(FluentIcons.download, size: 15),
                    ),
                    for (var tier in tiers)
                      _node(
                        tierPoints[tier]!,
                        color: accent,
                        tooltip: '层级 $tier',
                        child: Text('$tier'),
                        selected:
                            _taskSelected ||
                            (selected?.tier ?? _selectedTier) == tier,
                        onPressed: () => _select(tier: tier),
                      ),
                    for (var index = 0; index < groups.length; index++)
                      _node(
                        trackerPoints[groups[index].id]!,
                        id: groups[index].id,
                        color: _graphStateColor(context, groups[index].state),
                        tooltip:
                            '${groups[index].url}\n'
                            '${_trackerStateLabel(groups[index].state)}',
                        selected:
                            _taskSelected ||
                            groups[index].id == selected?.id ||
                            groups[index].tier == _selectedTier,
                        onPressed: () => _select(trackerId: groups[index].id),
                        child: Text('${index + 1}'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _node(
    Offset point, {
    required Color color,
    required String tooltip,
    required Widget child,
    String? id,
    bool selected = false,
    VoidCallback? onPressed,
  }) => Positioned(
    key: ValueKey(id ?? tooltip),
    left: point.dx - 16,
    top: point.dy - 16,
    width: 32,
    height: 32,
    child: Tooltip(
      message: tooltip,
      child: HoverButton(
        hitTestBehavior: HitTestBehavior.opaque,
        cursor: SystemMouseCursors.click,
        semanticLabel: tooltip,
        onPressed: onPressed == null
            ? null
            : () {
                // 指针统一由画布命中处理；键盘激活仍使用节点按钮。
                if (!_pointerGesture) onPressed();
              },
        builder: (context, states) => Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BTColors.surfacePrimary(context),
              border: Border.all(
                color: color.withValues(
                  alpha: selected || states.isHovered || states.isFocused
                      ? 1
                      : .6,
                ),
                width: selected || states.isFocused ? 2 : 1.2,
              ),
              boxShadow: selected || states.isHovered
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: .22),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: IconTheme(
              data: IconThemeData(color: color),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TrackerGraphGroup {
  const _TrackerGraphGroup(this.tier, this.url, this.rows);

  final int tier;
  final String url;
  final List<BtTaskTrackerDetail> rows;

  String get id => '$tier\n$url';

  String get state {
    var states = rows.map((row) => row.state).toSet();
    if (states.contains('error') && states.length > 1) return 'mixed';
    for (var state in [
      'working',
      'updating',
      'error',
      'waiting',
      'paused',
      'disabled',
    ]) {
      if (states.contains(state)) return state;
    }
    return 'waiting';
  }
}

Color _graphStateColor(BuildContext context, String state) => switch (state) {
  'working' => BTColors.successLight(context),
  'error' => BTColors.errorLight(context),
  'mixed' => BTColors.warningLight(context),
  'updating' => FluentTheme.of(context).accentColor,
  _ => BTColors.textTertiary(context),
};

class _TrackerGraphDetails extends StatelessWidget {
  const _TrackerGraphDetails({
    required this.title,
    required this.groups,
    required this.onClose,
    required this.onShowPeers,
  });

  final String title;
  final List<_TrackerGraphGroup> groups;
  final VoidCallback onClose;
  final ValueChanged<String> onShowPeers;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: BTColors.divider(context))),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SelectableText(
                title,
                style: BTTypography.body(context).copyWith(fontSize: 12),
                maxLines: 2,
              ),
            ),
            Tooltip(
              message: '关闭节点详情',
              child: IconButton(
                icon: const Icon(FluentIcons.clear, size: 14),
                onPressed: onClose,
              ),
            ),
          ],
        ),
        Expanded(
          child: _KeyboardScrollable(
            builder: (context, controller) => ListView.builder(
              controller: controller,
              itemCount: groups.length,
              itemBuilder: (context, index) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: groups.length > 1
                            ? SelectableText(
                                groups[index].url,
                                style: BTTypography.caption(context),
                              )
                            : Text(
                                'Tracker',
                                style: BTTypography.caption(context),
                              ),
                      ),
                      Tooltip(
                        message: '查看此 Tracker 关联的 Peer',
                        child: IconButton(
                          icon: const Icon(FluentIcons.people, size: 14),
                          onPressed: () => onShowPeers(groups[index].url),
                        ),
                      ),
                    ],
                  ),
                  for (var row in groups[index].rows)
                    _TrackerEndpoint(tracker: row),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TrackerGraphLink {
  const _TrackerGraphLink(
    this.from,
    this.to,
    this.color,
    this.active, {
    required this.vertical,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final bool active;
  final bool vertical;
}

class _TrackerGraphStroke {
  _TrackerGraphStroke(this.link) {
    path = Path()..moveTo(link.from.dx, link.from.dy);
    if (link.vertical) {
      var bend = (link.to.dy - link.from.dy) * .48;
      path.cubicTo(
        link.from.dx,
        link.from.dy + bend,
        link.to.dx,
        link.to.dy - bend,
        link.to.dx,
        link.to.dy,
      );
    } else {
      var bend = (link.to.dx - link.from.dx) * .48;
      path.cubicTo(
        link.from.dx + bend,
        link.from.dy,
        link.to.dx - bend,
        link.to.dy,
        link.to.dx,
        link.to.dy,
      );
    }
    metric = path.computeMetrics().first;
  }

  final _TrackerGraphLink link;
  late final Path path;
  late final PathMetric metric;
}

class _TrackerGraphPainter extends CustomPainter {
  _TrackerGraphPainter(this.links, this.flow) : super(repaint: flow);

  final List<_TrackerGraphLink> links;
  final AnimationController flow;
  late final List<_TrackerGraphStroke> _strokes = [
    for (var link in links.where((link) => !link.active))
      _TrackerGraphStroke(link),
    for (var link in links.where((link) => link.active))
      _TrackerGraphStroke(link),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < _strokes.length; index++) {
      var stroke = _strokes[index];
      var link = stroke.link;
      canvas.drawPath(
        stroke.path,
        Paint()
          ..color = link.color.withValues(alpha: link.active ? .8 : .2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = link.active ? 2 : 1,
      );
      if (!flow.isAnimating) continue;
      var distance = ((flow.value + index * .073) % 1) * stroke.metric.length;
      var point = stroke.metric.getTangentForOffset(distance)?.position;
      if (point == null) continue;
      canvas.drawPath(
        stroke.metric.extractPath(max(0.0, distance - 18), distance),
        Paint()
          ..color = link.color.withValues(alpha: link.active ? .7 : .3)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = link.active ? 2.8 : 1.6,
      );
      canvas.drawCircle(
        point,
        link.active ? 4 : 2.5,
        Paint()
          ..color = link.color.withValues(alpha: link.active ? .5 : .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        point,
        link.active ? 1.8 : 1.1,
        Paint()..color = link.color.withValues(alpha: link.active ? 1 : .65),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrackerGraphPainter oldDelegate) =>
      !identical(links, oldDelegate.links);
}
