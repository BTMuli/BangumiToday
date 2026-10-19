// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_subject_browse.dart';

/// 排行榜的时间筛选入口：先选年份，确认后才应用年份或年份 + 月份。
class BangumiRankingTimeFilter extends StatefulWidget {
  const BangumiRankingTimeFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final BangumiSubjectBrowseTime value;
  final ValueChanged<BangumiSubjectBrowseTime> onChanged;

  @override
  State<BangumiRankingTimeFilter> createState() =>
      _BangumiRankingTimeFilterState();
}

class _BangumiRankingTimeFilterState extends State<BangumiRankingTimeFilter> {
  static const _gap = 8.0;
  static const _margin = 8.0;
  static const _panelWidth = 328.0;
  static const _panelPadding = 12.0;
  static const _contentWidth = _panelWidth - _panelPadding * 2;
  static const _panelHeight = 392.0;
  static const _cellExtent = 32.0;
  static const _cellSpacing = 6.0;
  static const _gridColumns = 4;
  static const _yearGridHeight = 146.0;
  static const _monthGridHeight = 108.0;
  static const _yearFieldWidth = 96.0;

  /// Bangumi 收录的动画基本晚于该年份，更早的年份几乎没有榜单数据。
  static const _firstYear = 1940;

  final FlyoutController _controller = FlyoutController();
  final GlobalKey _targetKey = GlobalKey();
  final ScrollController _yearScroll = ScrollController(
    keepScrollOffset: false,
  );
  final TextEditingController _yearController = TextEditingController();
  bool _open = false;
  int? _draftYear;
  int? _draftMonth;
  bool _yearValid = true;

  /// 年份上限为当前年份，避免把尚未开播的明年混入筛选。
  int get _latestYear => DateTime.now().year;

  bool get _hasDraft =>
      _draftYear != null ||
      _draftMonth != null ||
      _yearController.text.isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    _yearScroll.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    if (_open) return;
    var target = _targetKey.currentContext!.findRenderObject()! as RenderBox;
    var root = Navigator.of(context).context.findRenderObject()! as RenderBox;
    var targetTop = target.localToGlobal(Offset.zero, ancestor: root).dy;
    var below =
        root.size.height - targetTop - target.size.height - _gap - _margin;
    var above = targetTop - _gap - _margin;
    var showBelow = below >= _panelHeight || below >= above;
    var maxHeight = (showBelow ? below : above)
        .clamp(120.0, _panelHeight)
        .toDouble();
    _draftYear = widget.value.year;
    _draftMonth = widget.value.month;
    _yearValid = true;
    _setYearText(_draftYear);
    setState(() => _open = true);
    var opening = _controller.showFlyout<void>(
      placementMode: showBelow
          ? FlyoutPlacementMode.bottomLeft
          : FlyoutPlacementMode.topLeft,
      additionalOffset: _gap,
      margin: _margin,
      forceAvailableSpace: true,
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (flyoutContext) => _buildPanel(flyoutContext, maxHeight),
    );
    var initialYear = _draftYear;
    if (initialYear != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _draftYear == initialYear) _scrollToYear(initialYear);
      });
    }
    try {
      await opening;
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  void _setYearText(int? year) {
    var text = year?.toString() ?? '';
    _yearController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _scrollToYear(int year) {
    if (!mounted || !_yearScroll.hasClients) return;
    var index = 1 + (_latestYear - year);
    if (index < 0 || index > _latestYear - _firstYear + 1) return;
    var offset = (index ~/ _gridColumns) * (_cellExtent + _cellSpacing);
    _yearScroll.jumpTo(
      offset.clamp(0.0, _yearScroll.position.maxScrollExtent).toDouble(),
    );
  }

  void _selectAll(StateSetter update) {
    _draftYear = null;
    _draftMonth = null;
    _yearValid = true;
    _setYearText(null);
    update(() {});
  }

  void _selectYear(StateSetter update, int year) {
    _draftYear = year;
    _draftMonth = null;
    _yearValid = true;
    _setYearText(year);
    update(() {});
  }

  void _selectMonth(StateSetter update, int month) {
    if (!_yearValid || _draftYear == null) return;
    _draftMonth = _draftMonth == month ? null : month;
    update(() {});
  }

  void _onYearChanged(String value, StateSetter update) {
    var text = value.trim();
    if (text.isEmpty) {
      _yearValid = true;
      _draftYear = null;
      _draftMonth = null;
      update(() {});
      return;
    }
    var year = text.length == 4 ? int.tryParse(text) : null;
    if (year == null || year < _firstYear || year > _latestYear) {
      _yearValid = false;
      _draftYear = null;
      _draftMonth = null;
      update(() {});
      return;
    }
    _yearValid = true;
    if (_draftYear != year) _draftMonth = null;
    _draftYear = year;
    update(() {});
    _scrollToYear(year);
  }

  void _confirm(BuildContext flyoutContext) {
    if (!_yearValid) return;
    var year = _draftYear;
    _apply(
      year == null
          ? BangumiSubjectBrowseTime.all
          : BangumiSubjectBrowseTime(year: year, month: _draftMonth),
    );
    Navigator.of(flyoutContext).pop();
  }

  void _apply(BangumiSubjectBrowseTime time) {
    if (time != widget.value) widget.onChanged(time);
  }

  Widget _buildPanel(BuildContext flyoutContext, double maxHeight) {
    return FlyoutContent(
      padding: const EdgeInsets.all(_panelPadding),
      constraints: BoxConstraints(maxWidth: _panelWidth, maxHeight: maxHeight),
      child: SizedBox(
        width: _contentWidth,
        child: StatefulBuilder(
          builder: (context, update) {
            var monthEnabled = _yearValid && _draftYear != null;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('时间筛选', style: BTTypography.bodyStrong(context)),
                      const Spacer(),
                      if (_hasDraft)
                        HyperlinkButton(
                          onPressed: () => _selectAll(update),
                          child: const Text('重置'),
                        ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _yearValid
                            ? () => _confirm(flyoutContext)
                            : null,
                        child: const Text('确认'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('年份', style: BTTypography.caption(context)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: _yearFieldWidth,
                        child: TextBox(
                          controller: _yearController,
                          placeholder: '输入年份',
                          placeholderStyle: BTTypography.caption(context),
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          onChanged: (value) => _onYearChanged(value, update),
                          onSubmitted: (_) {
                            if (_yearValid) _confirm(flyoutContext);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _yearValid
                              ? '留空为全部 · $_firstYear–$_latestYear'
                              : '请输入 $_firstYear–$_latestYear 的年份',
                          style: BTTypography.caption(context).copyWith(
                            color: _yearValid
                                ? BTColors.textTertiary(context)
                                : BTColors.errorLight(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: _yearGridHeight,
                    child: Scrollbar(
                      controller: _yearScroll,
                      child: GridView.builder(
                        controller: _yearScroll,
                        primary: false,
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _gridColumns,
                              mainAxisExtent: _cellExtent,
                              crossAxisSpacing: _cellSpacing,
                              mainAxisSpacing: _cellSpacing,
                            ),
                        itemCount: 1 + _latestYear - _firstYear + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildChoice(
                              context,
                              label: '全部',
                              selected: _draftYear == null && _yearValid,
                              onPressed: () => _selectAll(update),
                            );
                          }
                          var year = _latestYear - (index - 1);
                          return _buildChoice(
                            context,
                            label: '$year',
                            selected: _draftYear == year,
                            onPressed: () => _selectYear(update, year),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('月份', style: BTTypography.caption(context)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: _monthGridHeight,
                    child: monthEnabled
                        ? GridView.builder(
                            primary: false,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _gridColumns,
                                  mainAxisExtent: _cellExtent,
                                  crossAxisSpacing: _cellSpacing,
                                  mainAxisSpacing: _cellSpacing,
                                ),
                            itemCount: 12,
                            itemBuilder: (context, index) {
                              var month = index + 1;
                              return _buildChoice(
                                context,
                                label: '$month',
                                selected: _draftMonth == month,
                                onPressed: () => _selectMonth(update, month),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              '选择年份后可按月份筛选',
                              style: BTTypography.caption(context),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChoice(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    var theme = FluentTheme.of(context);
    var accent = theme.accentColor.defaultBrushFor(theme.brightness);
    var radius = BorderRadius.circular(6);
    var style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: BTColors.divider(context)),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
    );
    var checkedStyle = style.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => FilledButton.backgroundColor(theme, states),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => FilledButton.foregroundColor(theme, states),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: accent, width: 1.5),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
    return ToggleButton(
      checked: selected,
      style: ToggleButtonThemeData(
        checkedButtonStyle: checkedStyle,
        uncheckedButtonStyle: style,
      ),
      onChanged: (checked) {
        if (checked) onPressed();
      },
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    var accent = theme.accentColor.defaultBrushFor(theme.brightness);
    var active = widget.value.isActive;
    var color = active ? accent : BTColors.textSecondary(context);
    return FlyoutTarget(
      key: _targetKey,
      controller: _controller,
      child: Semantics(
        label: '时间筛选：${widget.value.label}',
        expanded: _open,
        child: Tooltip(
          message: '按放送年份和月份筛选',
          child: Button(
            onPressed: _show,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.calendar, size: 12, color: color),
                const SizedBox(width: 6),
                Text(
                  widget.value.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(FluentIcons.chevron_down, size: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
