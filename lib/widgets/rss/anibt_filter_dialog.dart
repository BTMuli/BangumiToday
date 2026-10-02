// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../models/rss/anibt_filters.dart';
import 'anibt_tag_chip.dart';

class AnibtFilterDialog extends StatefulWidget {
  final AnibtFilters filters;

  const AnibtFilterDialog({super.key, required this.filters});

  @override
  State<AnibtFilterDialog> createState() => _AnibtFilterDialogState();
}

class _AnibtFilterDialogState extends State<AnibtFilterDialog> {
  late AnibtFilters _draft;
  bool _languagesExpanded = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.filters;
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onChanged) {
    return AnibtTagChip(
      label: label,
      selected: selected,
      onPressed: () => onChanged(!selected),
      tooltip: '${selected ? '取消选择' : '选择'} $label',
    );
  }

  Widget _tags(
    String title,
    Map<String, String> options,
    Set<String> selected,
    ValueChanged<Set<String>> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.entries.map((option) {
              return _chip(option.value, selected.contains(option.key), (on) {
                var values = Set<String>.of(selected);
                if (on) {
                  values.add(option.key);
                } else {
                  values.remove(option.key);
                }
                onChanged(values);
              });
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _selectSort(AnibtSortField field) {
    setState(() {
      _draft = _draft.copyWith(
        sortField: field,
        descending: field != _draft.sortField || !_draft.descending,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    var languages = AnibtFilters.languageLabels.entries.where(
      (entry) =>
          _languagesExpanded ||
          AnibtFilters.languageLabels.keys.take(5).contains(entry.key) ||
          _draft.selectedLanguages.contains(entry.key),
    );

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
      title: Row(
        children: [
          const Expanded(child: Text('筛选资源')),
          Tooltip(
            message: '关闭筛选',
            child: IconButton(
              icon: const Icon(FluentIcons.clear, size: 14),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tags(
              '画质',
              {for (var value in AnibtFilters.resolutions) value: value},
              _draft.selectedResolutions,
              (values) => setState(() {
                _draft = _draft.copyWith(selectedResolutions: values);
              }),
            ),
            _tags(
              '语言',
              Map.fromEntries(languages),
              _draft.selectedLanguages,
              (values) => setState(() {
                _draft = _draft.copyWith(selectedLanguages: values);
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Button(
                onPressed: () => setState(() {
                  _languagesExpanded = !_languagesExpanded;
                }),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_languagesExpanded ? '收起语言' : '展开更多语言'),
                    ),
                    Icon(
                      _languagesExpanded
                          ? FluentIcons.chevron_up
                          : FluentIcons.chevron_down,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
            _tags(
              '字幕格式',
              AnibtFilters.subtitleLabels,
              _draft.selectedSubtitles,
              (values) => setState(() {
                _draft = _draft.copyWith(selectedSubtitles: values);
              }),
            ),
            _tags(
              '格式',
              {for (var value in AnibtFilters.formats) value: value},
              _draft.selectedFormats,
              (values) => setState(() {
                _draft = _draft.copyWith(selectedFormats: values);
              }),
            ),
            const Text('排序方式', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AnibtSortField.values.map((field) {
                var selected = field == _draft.sortField;
                var direction = _draft.descending ? '↓' : '↑';
                return _chip(
                  '${field.label}${selected ? ' $direction' : ''}',
                  selected,
                  (_) => _selectSort(field),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              '再次点击当前排序可切换升序或降序。\n'
              '字幕筛选与集数排序仅作用于当前 RSS 结果（最多 100 条）。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => setState(() {
            _draft = AnibtFilters(query: _draft.query);
          }),
          child: const Text('重置'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_draft),
          child: const Text('应用'),
        ),
      ],
    );
  }
}
