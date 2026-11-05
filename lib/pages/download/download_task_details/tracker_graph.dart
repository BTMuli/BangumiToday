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
    with TickerProviderStateMixin {
  String? _selectedId;
  int? _selectedTier;
  bool _taskSelected = false;
  late final AnimationController _flow;
  late final AnimationController _arrange;
  _GraphScene? _from;
  _GraphScene? _to;
  _GraphScene? _display;
  var _retargetScheduled = false;
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
    _arrange = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    )..addListener(_onArrange);
  }

  void _onArrange() {
    if (mounted && _arrange.isAnimating) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_flow.isAnimating) _flow.repeat();
    } else {
      _flow.stop();
      _arrange.stop();
    }
  }

  @override
  void dispose() {
    _arrange.removeListener(_onArrange);
    _arrange.dispose();
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
      var goal = _buildTrackerScene(
        vertical: vertical,
        viewport: _viewport,
        groups: groups,
        tiers: tiers,
      );
      var motion =
          TickerMode.valuesOf(context).enabled &&
          !MediaQuery.disableAnimationsOf(context);
      if (_to == null || !motion) {
        _from = goal;
        _to = goal;
        _display = goal;
      } else if (!_sameScene(_to!, goal) && !_retargetScheduled) {
        _retargetScheduled = true;
        var next = goal;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _retargetScheduled = false;
          if (!mounted) return;
          _from = _display ?? next;
          _to = next;
          _arrange.forward(from: 0);
        });
      }
      var shown = _sampleScene(goal);
      var accent = FluentTheme.of(context).accentColor;
      var links = <_TrackerGraphLink>[
        for (var tier in tiers)
          if (shown.tiers[tier] != null)
            _TrackerGraphLink(
              shown.root,
              shown.tiers[tier]!,
              _taskSelected || (selected?.tier ?? _selectedTier) == tier
                  ? accent
                  : BTColors.textTertiary(context),
              _taskSelected || (selected?.tier ?? _selectedTier) == tier,
            ),
        for (var group in groups)
          if (shown.tiers[group.tier] != null &&
              shown.trackers[group.id] != null)
            _TrackerGraphLink(
              shown.tiers[group.tier]!,
              shown.trackers[group.id]!,
              _graphStateColor(context, group.state),
              _taskSelected ||
                  group.id == selected?.id ||
                  group.tier == _selectedTier,
            ),
      ];
      var targets = <(Offset, VoidCallback)>[
        (shown.root, () => _select(task: true)),
        for (var tier in tiers)
          if (shown.tiers[tier] != null)
            (shown.tiers[tier]!, () => _select(tier: tier)),
        for (var group in groups)
          if (shown.trackers[group.id] != null)
            (shown.trackers[group.id]!, () => _select(trackerId: group.id)),
      ];
      void selectAt(Offset viewportPoint) {
        var sceneSize = shown.size;
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
                width: shown.size.width,
                height: shown.size.height,
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
                    _node(
                      shown.root,
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
                      if (shown.tiers[tier] != null)
                        _node(
                          shown.tiers[tier]!,
                          color: accent,
                          tooltip: '层级 $tier',
                          child: Text('$tier'),
                          selected:
                              _taskSelected ||
                              (selected?.tier ?? _selectedTier) == tier,
                          onPressed: () => _select(tier: tier),
                        ),
                    for (var index = 0; index < groups.length; index++)
                      if (shown.trackers[groups[index].id] != null)
                        _node(
                          shown.trackers[groups[index].id]!,
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

  bool _sameScene(_GraphScene a, _GraphScene b) {
    if ((a.size.width - b.size.width).abs() > .5) return false;
    if ((a.size.height - b.size.height).abs() > .5) return false;
    if (a.tiers.length != b.tiers.length) return false;
    if (a.trackers.length != b.trackers.length) return false;
    for (var entry in a.tiers.entries) {
      var other = b.tiers[entry.key];
      if (other == null || (other - entry.value).distance > .5) return false;
    }
    for (var entry in a.trackers.entries) {
      var other = b.trackers[entry.key];
      if (other == null || (other - entry.value).distance > .5) return false;
    }
    return true;
  }

  _GraphScene _sampleScene(_GraphScene goal) {
    if (_from == null || _to == null || !_arrange.isAnimating) {
      _display = _to ?? goal;
      return _display!;
    }
    var t = Curves.easeInOutCubic.transform(_arrange.value);
    _display = _GraphScene.lerp(_from!, _to!, t);
    return _display!;
  }

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

class _GraphScene {
  const _GraphScene({
    required this.size,
    required this.root,
    required this.tiers,
    required this.trackers,
  });

  final Size size;
  final Offset root;
  final Map<int, Offset> tiers;
  final Map<String, Offset> trackers;

  static _GraphScene lerp(_GraphScene a, _GraphScene b, double t) {
    Offset mix(Offset? from, Offset to) =>
        from == null ? to : Offset.lerp(from, to, t)!;
    var tiers = <int, Offset>{
      for (var key in {...a.tiers.keys, ...b.tiers.keys})
        key: mix(a.tiers[key], b.tiers[key] ?? a.tiers[key]!),
    };
    var trackers = <String, Offset>{
      for (var key in {...a.trackers.keys, ...b.trackers.keys})
        key: mix(a.trackers[key], b.trackers[key] ?? a.trackers[key]!),
    };
    return _GraphScene(
      size: Size(
        a.size.width + (b.size.width - a.size.width) * t,
        a.size.height + (b.size.height - a.size.height) * t,
      ),
      root: mix(a.root, b.root),
      tiers: tiers,
      trackers: trackers,
    );
  }
}

const _kTierPitch = 32.0;
const _kTrackerPitch = 36.0;
const _kTierToTracker = 80.0;
const _kCenterGap = 72.0;
const _kGutter = 28.0;

double _bandHeight(int count, int columns, double pitch) {
  if (count <= 1) return 0;
  var rows = (count / columns).ceil();
  var step = pitch * 1.08;
  if (rows <= 1) return step * .42;
  return (rows - 1) * step + step * .42;
}

int _columnsFor(int count, double pitch, double maxCross) {
  if (count <= 1) return 1;
  var columns = min(2, count);
  while (columns < count && _bandHeight(count, columns, pitch) > maxCross) {
    columns++;
  }
  return columns;
}

List<Offset> _scatterWing({
  required int count,
  required int side,
  required double inner,
  required double pitch,
  required double maxCross,
}) {
  if (count <= 0) return const [];
  var columns = _columnsFor(count, pitch, maxCross);
  var rows = (count / columns).ceil();
  var outer = inner + max(0, columns - 1) * pitch;
  var step = pitch * 1.08;
  var points = <Offset>[];
  for (var index = 0; index < count; index++) {
    var column = index % columns;
    var row = index ~/ columns;
    var gap = columns <= 1 ? 0.0 : (outer - inner) / (columns - 1);
    var magnitude = inner + column * gap;
    var cross = (row - (rows - 1) / 2) * step;
    if (column.isOdd) cross += step * .42;
    cross += side * ((index % 3) - 1) * 5;
    points.add(Offset(side * magnitude, cross));
  }
  return points;
}

_GraphScene _buildTrackerScene({
  required bool vertical,
  required Size viewport,
  required List<_TrackerGraphGroup> groups,
  required List<int> tiers,
}) {
  var viewportMain = max(1.0, vertical ? viewport.height : viewport.width);
  var viewportCross = max(1.0, vertical ? viewport.width : viewport.height);
  var byTier = <int, List<_TrackerGraphGroup>>{};
  for (var group in groups) {
    byTier.putIfAbsent(group.tier, () => []).add(group);
  }
  var left = <int, List<_TrackerGraphGroup>>{};
  var right = <int, List<_TrackerGraphGroup>>{};
  var satellites = <int>[];
  var leftLoad = 0;
  var rightLoad = 0;
  for (var tier in tiers) {
    var members = byTier[tier] ?? const <_TrackerGraphGroup>[];
    if (tiers.length == 1 && members.length > 1) {
      satellites.add(tier);
      for (var index = 0; index < members.length; index++) {
        var wing = index.isOdd ? left : right;
        wing.putIfAbsent(tier, () => []).add(members[index]);
      }
      continue;
    }
    if (leftLoad <= rightLoad) {
      left[tier] = members;
      leftLoad += members.length;
    } else {
      right[tier] = members;
      rightLoad += members.length;
    }
  }

  var tierLocal = <int, Offset>{};
  var trackerLocal = <String, Offset>{};

  void placeWing(Map<int, List<_TrackerGraphGroup>> wing, int side) {
    if (wing.isEmpty) return;
    var sideTiers = [
      for (var entry in wing.entries)
        if (entry.value.isNotEmpty && !satellites.contains(entry.key))
          entry.key,
    ];
    var members = [for (var entry in wing.entries) ...entry.value];
    if (sideTiers.isEmpty && members.isEmpty) return;
    var maxCross = max(_kTierPitch, viewportCross - _kGutter * 2);
    var tierInner = _kCenterGap;
    var tierPoints = _scatterWing(
      count: sideTiers.length,
      side: side,
      inner: tierInner,
      pitch: _kTierPitch,
      maxCross: maxCross,
    );
    for (var index = 0; index < sideTiers.length; index++) {
      tierLocal[sideTiers[index]] = tierPoints[index];
    }
    var tierOuter = tierInner;
    for (var point in tierPoints) {
      tierOuter = max(tierOuter, point.dx.abs());
    }
    var inner = tierOuter + _kTierToTracker;
    var trackerPoints = _scatterWing(
      count: members.length,
      side: side,
      inner: inner,
      pitch: _kTrackerPitch,
      maxCross: maxCross,
    );
    for (var index = 0; index < members.length; index++) {
      trackerLocal[members[index].id] = trackerPoints[index];
    }
  }

  placeWing(left, -1);
  placeWing(right, 1);
  for (var index = 0; index < satellites.length; index++) {
    tierLocal[satellites[index]] = Offset(0, -_kTierPitch * (index + 1));
  }

  var maxMain = 0.0;
  var maxCross = 0.0;
  for (var point in [
    Offset.zero,
    ...tierLocal.values,
    ...trackerLocal.values,
  ]) {
    maxMain = max(maxMain, point.dx.abs());
    maxCross = max(maxCross, point.dy.abs());
  }
  var sceneMain = max(viewportMain, (maxMain + _kGutter) * 2);
  var sceneCross = max(viewportCross, (maxCross + _kGutter) * 2);
  Offset world(Offset local) => vertical
      ? Offset(sceneCross / 2 + local.dy, sceneMain / 2 + local.dx)
      : Offset(sceneMain / 2 + local.dx, sceneCross / 2 + local.dy);
  return _GraphScene(
    size: vertical ? Size(sceneCross, sceneMain) : Size(sceneMain, sceneCross),
    root: world(Offset.zero),
    tiers: {for (var entry in tierLocal.entries) entry.key: world(entry.value)},
    trackers: {
      for (var entry in trackerLocal.entries) entry.key: world(entry.value),
    },
  );
}

class _TrackerGraphLink {
  const _TrackerGraphLink(this.from, this.to, this.color, this.active);

  final Offset from;
  final Offset to;
  final Color color;
  final bool active;
}

class _TrackerGraphStroke {
  _TrackerGraphStroke(this.link) {
    path = Path()..moveTo(link.from.dx, link.from.dy);
    var dx = link.to.dx - link.from.dx;
    var dy = link.to.dy - link.from.dy;
    var length = sqrt(dx * dx + dy * dy);
    var fan = (dy.abs() > dx.abs() ? dx : dy) * .32;
    var px = length < 1 ? 0.0 : -dy / length * fan;
    var py = length < 1 ? 0.0 : dx / length * fan;
    path.cubicTo(
      link.from.dx + dx * .38 + px,
      link.from.dy + dy * .38 + py,
      link.to.dx - dx * .28 + px,
      link.to.dy - dy * .28 + py,
      link.to.dx,
      link.to.dy,
    );
    var metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) {
      path
        ..moveTo(link.from.dx, link.from.dy)
        ..lineTo(link.from.dx + 1, link.from.dy);
      metrics = path.computeMetrics().toList();
    }
    metric = metrics.first;
  }

  final _TrackerGraphLink link;
  late final Path path;
  late final PathMetric metric;
}

class _TrackerGraphPainter extends CustomPainter {
  _TrackerGraphPainter(this.links, this.flow) : super(repaint: flow);

  static const _shuttleSamples = 16;
  static const _shuttleStops = [-1.0, -.58, -.24, 0.0, .24, .58, 1.0];
  static final _shuttleIndices = _buildShuttleIndices();

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
      _paintShuttle(canvas, stroke.metric, distance, link.color, link.active);
    }
  }

  void _paintShuttle(
    Canvas canvas,
    PathMetric metric,
    double distance,
    Color color,
    bool active,
  ) {
    var length = metric.length;
    if (length < 1) return;
    var coreSpan = min(active ? 32.0 : 16.0, length);
    var tipGlow = active ? 10.0 : 6.0;
    var span = min(coreSpan + 2 * tipGlow, length);
    var start = max(0.0, distance - span / 2);
    var end = min(length, distance + span / 2);
    var halfWidth = active ? 3.2 : 2.2;
    var edge = color.withValues(alpha: 0);
    var outer = color.withValues(alpha: active ? .26 : .19);
    var inner = color.withValues(alpha: active ? .68 : .52);
    var core = Color.lerp(
      color,
      const Color(0xFFFFFFFF),
      .65,
    )!.withValues(alpha: active ? 1 : .82);
    var tipOpacity = active ? .5 : .45;
    var palette = [edge, outer, inner, core, inner, outer, edge];
    var positions = <Offset>[];
    var colors = <Color>[];
    for (var step = 0; step <= _shuttleSamples; step++) {
      var t = step / _shuttleSamples;
      var tangent = metric.getTangentForOffset(start + (end - start) * t);
      if (tangent == null) return;
      var direction = tangent.vector;
      var normal = Offset(-direction.dy, direction.dx);
      // Collapse the cross-section at both tips, even at a link endpoint.
      var isTip = step == 0 || step == _shuttleSamples;
      var width = isTip ? 0.0 : halfWidth * sin(t * pi);
      var fromCenter = (t - .5).abs() * span;
      var glowFade = min(1.0, (span / 2 - fromCenter) / tipGlow);
      var coreFade = ((coreSpan / 2 - fromCenter) * _shuttleSamples / coreSpan)
          .clamp(0.0, 1.0);
      var glowStrength = tipOpacity * glowFade;
      var strength = glowStrength + (1 - glowStrength) * coreFade;
      for (var column = 0; column < _shuttleStops.length; column++) {
        positions.add(
          tangent.position + normal * (width * _shuttleStops[column]),
        );
        var shade = palette[column];
        colors.add(
          strength == 1 ? shade : shade.withValues(alpha: shade.a * strength),
        );
      }
    }
    canvas.drawVertices(
      Vertices(
        VertexMode.triangles,
        positions,
        colors: colors,
        indices: _shuttleIndices,
      ),
      BlendMode.dst,
      Paint(),
    );
  }

  static List<int> _buildShuttleIndices() {
    var indices = <int>[];
    var stride = _shuttleStops.length;
    for (var row = 0; row < _shuttleSamples; row++) {
      for (var column = 0; column < stride - 1; column++) {
        var topLeft = row * stride + column;
        var bottomLeft = topLeft + stride;
        indices.addAll([
          topLeft,
          topLeft + 1,
          bottomLeft,
          topLeft + 1,
          bottomLeft + 1,
          bottomLeft,
        ]);
      }
    }
    return indices;
  }

  @override
  bool shouldRepaint(covariant _TrackerGraphPainter oldDelegate) =>
      !identical(links, oldDelegate.links);
}
