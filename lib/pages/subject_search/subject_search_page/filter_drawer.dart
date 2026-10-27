part of '../subject_search_page.dart';

/// 范围条件在抽屉内独立编辑，确认后再更新页面和搜索结果。
class _SubjectFilterDrawer extends StatefulWidget {
  const _SubjectFilterDrawer({required this.initialQuery});

  final SubjectSearchQuery initialQuery;

  @override
  State<_SubjectFilterDrawer> createState() => _SubjectFilterDrawerState();
}

class _SubjectFilterDrawerState extends State<_SubjectFilterDrawer> {
  final DateTime _today = DateTime.now();
  late SubjectSearchDateRange _dates;
  late int _year;
  late final Map<String, TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    var query = widget.initialQuery;
    _dates = SubjectSearchDateRange(
      from: DateTime.tryParse(query.dateFrom),
      to: DateTime.tryParse(query.dateTo),
    );
    _year = _dates.from?.year ?? _dates.to?.year ?? _today.year;
    _controllers = {
      'ratingFrom': TextEditingController(text: query.ratingFrom),
      'ratingTo': TextEditingController(text: query.ratingTo),
      'rankFrom': TextEditingController(text: query.rankFrom),
      'rankTo': TextEditingController(text: query.rankTo),
    };
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setDates(SubjectSearchDateRange dates) => setState(() {
    _dates = dates;
    _year = dates.from?.year ?? dates.to?.year ?? _year;
    _error = null;
  });

  void _reset() => setState(() {
    _dates = const SubjectSearchDateRange();
    _year = _today.year;
    for (var controller in _controllers.values) {
      controller.clear();
    }
    _error = null;
  });

  void _apply() {
    var query = SubjectSearchQuery(
      dateFrom: _dates.dateFrom,
      dateTo: _dates.dateTo,
      ratingFrom: _controllers['ratingFrom']!.text,
      ratingTo: _controllers['ratingTo']!.text,
      rankFrom: _controllers['rankFrom']!.text,
      rankTo: _controllers['rankTo']!.text,
    );
    var error = query.validationError;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(query);
  }

  @override
  Widget build(BuildContext context) {
    var earliest = _dates.from?.year ?? _dates.to?.year ?? 1900;
    var latest = _dates.to?.year ?? _dates.from?.year ?? _today.year;
    var firstYear = earliest < 1900 ? earliest : 1900;
    var lastYear = latest > _today.year + 20 ? latest : _today.year + 20;
    var currentQuarter = (_today.month - 1) ~/ 3 + 1;
    var presets = {
      '不限日期': const SubjectSearchDateRange(),
      '本季度': SubjectSearchDateRange.quarter(_today.year, currentQuarter),
      '本年': SubjectSearchDateRange.year(_today.year),
      '去年': SubjectSearchDateRange.year(_today.year - 1),
    };
    return BTDrawer(
      title: '条件筛选',
      actions: [
        Tooltip(
          message: '重置日期、评分和排名条件',
          child: IconButton(
            icon: const Icon(
              FluentIcons.clear_filter,
              size: 14,
              semanticLabel: '重置范围筛选',
            ),
            onPressed: _reset,
          ),
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('播出 / 发售日期', style: BTTypography.bodyStrong(context)),
                const SizedBox(height: 6),
                Text(
                  '可按年份、季度或具体日期选择；留空表示不限。',
                  style: BTTypography.caption(context),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var preset in presets.entries)
                      ToggleButton(
                        checked: _dates == preset.value,
                        onChanged: (_) => _setDates(preset.value),
                        child: Text(preset.key),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InfoLabel(
                        label: '年份',
                        child: BtSelect<int>(
                          value: _year,
                          isExpanded: true,
                          items: [
                            for (var year = lastYear; year >= firstYear; year--)
                              ComboBoxItem(value: year, child: Text('$year 年')),
                          ],
                          onChanged: (year) {
                            if (year == null) return;
                            var quarter = _dates.quarterNumber;
                            _setDates(
                              quarter == null
                                  ? SubjectSearchDateRange.year(year)
                                  : SubjectSearchDateRange.quarter(
                                      year,
                                      quarter,
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InfoLabel(
                        label: '季度',
                        child: BtSelect<int>(
                          value: _dates.wholeYear == _year
                              ? 0
                              : _dates.quarterNumber,
                          isExpanded: true,
                          items: const [
                            ComboBoxItem(value: 0, child: Text('全年')),
                            ComboBoxItem(value: 1, child: Text('一季度 · 1～3 月')),
                            ComboBoxItem(value: 2, child: Text('二季度 · 4～6 月')),
                            ComboBoxItem(value: 3, child: Text('三季度 · 7～9 月')),
                            ComboBoxItem(
                              value: 4,
                              child: Text('四季度 · 10～12 月'),
                            ),
                          ],
                          onChanged: (quarter) {
                            if (quarter == null) return;
                            _setDates(
                              quarter == 0
                                  ? SubjectSearchDateRange.year(_year)
                                  : SubjectSearchDateRange.quarter(
                                      _year,
                                      quarter,
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _dateField(true, firstYear, lastYear)),
                    const SizedBox(width: 12),
                    Expanded(child: _dateField(false, firstYear, lastYear)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '起止日期均包含当天，也可只设置一端。',
                  style: BTTypography.caption(context),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                _numberRange('rating', '评分范围', '最低评分', '最高评分'),
                const SizedBox(height: 6),
                Text('0～10 分，支持小数。', style: BTTypography.caption(context)),
                const SizedBox(height: 20),
                _numberRange('rank', '排名范围', '名次起点', '名次终点'),
                const SizedBox(height: 6),
                Text(
                  '名次从 1 开始，范围内不含未上榜条目。',
                  style: BTTypography.caption(context),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: InfoBar(
                title: Text(_error!),
                severity: InfoBarSeverity.error,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: BTColors.divider(context))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Button(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _apply, child: const Text('应用并搜索')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(bool start, int firstYear, int lastYear) {
    var value = start ? _dates.from : _dates.to;
    var label = start ? '开始日期' : '结束日期';
    void change(DateTime? day) =>
        _setDates(start ? _dates.withFrom(day) : _dates.withTo(day));
    return InfoLabel(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: CalendarDatePicker(
              initialStart: value,
              placeholderText: '不限',
              dateFormatter: DateFormat('yyyy-MM-dd'),
              firstDayOfWeek: DateTime.monday,
              minDate: DateTime(firstYear),
              maxDate: DateTime(lastYear, 12, 31),
              displayDateStart: DateTime(firstYear),
              displayDateEnd: DateTime(lastYear + 1),
              placement: start
                  ? FlyoutPlacementMode.bottomLeft
                  : FlyoutPlacementMode.bottomRight,
              verticalOffset: 6,
              onSelectionChanged: (selection) => change(selection.startDate),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: '清除$label',
            child: IconButton(
              icon: Icon(
                FluentIcons.clear,
                size: 12,
                semanticLabel: '清除$label',
              ),
              onPressed: value == null ? null : () => change(null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberRange(String key, String title, String from, String to) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: BTTypography.bodyStrong(context)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var side in [('From', from), ('To', to)]) ...[
                if (side.$1 == 'To') const SizedBox(width: 12),
                Expanded(
                  child: InfoLabel(
                    label: side.$2,
                    child: TextBox(
                      controller: _controllers['$key${side.$1}'],
                      placeholder: '不限',
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: key == 'rating',
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _apply(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
}
