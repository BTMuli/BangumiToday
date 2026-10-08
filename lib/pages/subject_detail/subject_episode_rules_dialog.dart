// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/utils/playback_episode_rule_generator.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/playback/playback_episode_rule.dart';
import '../../providers/playback_episode_link_providers.dart';

Future<bool?> showSubjectEpisodeRules(
  BuildContext context, {
  required int subject,
  required List<BangumiEpisode> episodes,
  String? filePath,
  BangumiEpisode? target,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _SubjectEpisodeRulesDialog(
    subject: subject,
    episodes: episodes,
    filePath: filePath,
    target: target,
  ),
);

class _SubjectEpisodeRulesDialog extends ConsumerStatefulWidget {
  const _SubjectEpisodeRulesDialog({
    required this.subject,
    required this.episodes,
    this.filePath,
    this.target,
  });

  final int subject;
  final List<BangumiEpisode> episodes;
  final String? filePath;
  final BangumiEpisode? target;

  @override
  ConsumerState<_SubjectEpisodeRulesDialog> createState() =>
      _SubjectEpisodeRulesDialogState();
}

class _SubjectEpisodeRulesDialogState
    extends ConsumerState<_SubjectEpisodeRulesDialog> {
  final _file = TextEditingController();
  final _target = TextEditingController();
  final _pattern = TextEditingController();
  final _offset = TextEditingController(text: '0');
  EpisodeRuleNumber? _number;
  BangumiEpType _type = BangumiEpType.main;
  String? _editingId;
  String? _error;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _file.text = widget.filePath ?? '';
    _target.text = _label(widget.target?.sort ?? 1);
    _type = widget.target?.type ?? BangumiEpType.main;
    _suggestNumber();
  }

  @override
  void dispose() {
    for (var controller in [_file, _target, _pattern, _offset]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _label(double number) => number == number.truncateToDouble()
      ? number.toInt().toString()
      : number.toString();

  void _suggestNumber() {
    _number = suggestEpisodeRuleNumber(
      _file.text,
      double.tryParse(_target.text) ?? 1,
    );
  }

  PlaybackEpisodeRule _rule({String? id}) => PlaybackEpisodeRule(
    id: id ?? _editingId ?? DateTime.now().microsecondsSinceEpoch.toString(),
    subject: widget.subject,
    pattern: _pattern.text.trim(),
    offset: double.parse(_offset.text.trim()),
    type: _type.value,
    exampleFile: _file.text.trim(),
  );

  BangumiEpisode? _preview() {
    try {
      var rule = _rule();
      var number = rule.numberFor(_file.text);
      return widget.episodes
          .where((episode) => episode.type == _type && episode.sort == number)
          .singleOrNull;
    } on FormatException {
      return null;
    }
  }

  void _generate() {
    setState(() {
      _error = null;
      var target = double.tryParse(_target.text.trim());
      if (_number == null ||
          target == null ||
          !target.isFinite ||
          target <= 0) {
        _error = '请输入目标集数，并选择文件名中表示集数的数字。';
        return;
      }
      _pattern.text = generateEpisodeRulePattern(_file.text, _number!);
      _offset.text = _label(target - _number!.number);
    });
  }

  void _edit(PlaybackEpisodeRule rule) {
    setState(() {
      _editingId = rule.id;
      _file.text = rule.exampleFile;
      _pattern.text = rule.pattern;
      _offset.text = _label(rule.offset);
      _type = BangumiEpType.values.singleWhere(
        (type) => type.value == rule.type,
      );
      _target.text = _label(rule.numberFor(rule.exampleFile)!);
      _error = null;
      _suggestNumber();
    });
  }

  Future<void> _write({PlaybackEpisodeRule? removing}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var storage = ref.read(playbackEpisodeLinksProvider);
      if (removing != null) {
        await storage.removeRule(removing);
        _changed = true;
        if (mounted && removing.id == _editingId) {
          setState(() {
            _editingId = null;
            _pattern.clear();
          });
        }
      } else {
        var target = double.tryParse(_target.text.trim());
        var episode = _preview();
        if (_pattern.text.trim().isEmpty ||
            episode == null ||
            episode.sort != target) {
          throw const FormatException('规则必须将样例唯一匹配到目标集数，请先生成或修正规则。');
        }
        var rules = await storage.readRules();
        var existing = rules
            .where(
              (rule) =>
                  rule.subject == widget.subject &&
                  rule.pattern == _pattern.text.trim(),
            )
            .firstOrNull;
        await storage.writeRule(_rule(id: _editingId ?? existing?.id));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _numberContext(EpisodeRuleNumber number) {
    var name = PlaybackEpisodeRule.filename(_file.text);
    var start = (number.start - 10).clamp(0, name.length);
    var end = (number.end + 10).clamp(0, name.length);
    return '${start > 0 ? '…' : ''}${name.substring(start, end)}'
        '${end < name.length ? '…' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    var snapshot = ref.watch(playbackEpisodeRuleSnapshotProvider);
    var rules = (snapshot.value ?? const <PlaybackEpisodeRule>[])
        .where((rule) => rule.subject == widget.subject)
        .toList();
    var numbers = episodeRuleNumbers(_file.text);
    var preview = _pattern.text.isEmpty ? null : _preview();
    var target = double.tryParse(_target.text.trim());
    var canSave =
        !_saving &&
        !snapshot.isLoading &&
        !snapshot.hasError &&
        preview != null &&
        preview.sort == target;
    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: 660,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      title: Text(_editingId == null ? '添加剧集匹配规则' : '修改剧集匹配规则'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('规则仅用于当前条目。保留字幕组和标题前缀，自动匹配后续同格式文件。'),
            const SizedBox(height: 16),
            InfoLabel(
              label: '样例文件名或完整路径',
              child: TextBox(
                controller: _file,
                enabled: !_saving,
                placeholder: '粘贴一个视频文件名',
                onChanged: (_) => setState(() {
                  _pattern.clear();
                  _error = null;
                  _suggestNumber();
                }),
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: '目标集数（条目章节编号）',
              child: TextBox(
                controller: _target,
                enabled: !_saving,
                placeholder: '例如 1、13 或 13.5',
                onChanged: (_) => setState(() {
                  if (_pattern.text.isEmpty) _suggestNumber();
                }),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var type in BangumiEpType.values)
                  if (type == _type ||
                      widget.episodes.any((e) => e.type == type))
                    ToggleButton(
                      checked: _type == type,
                      onChanged: _saving
                          ? null
                          : (_) => setState(() {
                              _type = type;
                            }),
                      child: Text(type.label),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('选择文件名中表示集数的数字'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var number in numbers)
                  Tooltip(
                    message: _numberContext(number),
                    child: ToggleButton(
                      checked: _number?.start == number.start,
                      onChanged: _saving
                          ? null
                          : (_) => setState(() {
                              _number = number;
                              _pattern.clear();
                            }),
                      child: Text('${number.text} · ${_numberContext(number)}'),
                    ),
                  ),
                if (numbers.isEmpty) const Text('未找到数字，可在下方手动填写正则。'),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Button(
                onPressed: !_saving && _number != null ? _generate : null,
                child: const Text('生成匹配正则'),
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: '匹配正则（第一个捕获组为文件集数）',
              child: TextBox(
                controller: _pattern,
                enabled: !_saving,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: '集数偏移（文件集数 + 偏移 = 目标集数）',
              child: TextBox(
                controller: _offset,
                enabled: !_saving,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              preview == null
                  ? '样例尚未匹配到唯一章节。'
                  : '样例匹配：${preview.type.label} ${_label(preview.sort)} 集',
            ),
            if (rules.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('已保存的规则'),
              for (var rule in rules) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rule.exampleFile,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Button(
                      onPressed: _saving ? null : () => _edit(rule),
                      child: const Text('修改'),
                    ),
                    const SizedBox(width: 8),
                    Button(
                      onPressed: _saving ? null : () => _write(removing: rule),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              ],
            ],
            if (snapshot.hasError || _error != null) ...[
              const SizedBox(height: 12),
              Text(_error ?? '加载规则失败：${snapshot.error}'),
              if (snapshot.hasError)
                Button(
                  onPressed: _saving
                      ? null
                      : () =>
                            ref.invalidate(playbackEpisodeRuleSnapshotProvider),
                  child: const Text('重试'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: canSave ? _write : null,
          child: const Text('保存规则'),
        ),
        Button(
          onPressed: _saving ? null : () => Navigator.of(context).pop(_changed),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
