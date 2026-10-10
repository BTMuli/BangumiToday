// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/tool_func.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import 'subject_detail_colors.dart';
import 'subject_detail_module_status.dart';
import 'subject_detail_refreshable.dart';

enum SubjectDetailPeopleKind { characters, persons }

/// 角色及制作人员各自挂载、请求和保留滚动位置。
class SubjectDetailPeople extends ConsumerStatefulWidget {
  const SubjectDetailPeople({
    super.key,
    required this.subjectId,
    required this.kind,
  });

  final int subjectId;
  final SubjectDetailPeopleKind kind;

  @override
  ConsumerState<SubjectDetailPeople> createState() =>
      _SubjectDetailPeopleState();
}

class _SubjectDetailPeopleState extends ConsumerState<SubjectDetailPeople>
    with SubjectDetailRefreshable {
  List<BangumiRelatedCharacter> _characters = [];
  List<BangumiRelatedPerson> _persons = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  bool get _isCharacters => widget.kind == SubjectDetailPeopleKind.characters;
  String get _label => _isCharacters ? '角色' : '制作人员';
  int get _count => _isCharacters ? _characters.length : _persons.length;

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  @override
  void didUpdateWidget(SubjectDetailPeople oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId ||
        oldWidget.kind != widget.kind) {
      _characters = [];
      _persons = [];
      unawaited(refresh());
    }
  }

  @override
  Future<void> refresh() async {
    var generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    var repository = ref.read(bangumiRepositoryProvider);
    if (_isCharacters) {
      var response = await repository.getSubjectCharacters(widget.subjectId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        if (response.code == 0 && response.data != null) {
          _characters = response.data!;
        } else {
          _error = response.message;
        }
      });
    } else {
      var response = await repository.getSubjectPersons(widget.subjectId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        if (response.code == 0 && response.data != null) {
          _persons = response.data!;
        } else {
          _error = response.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) {
      return Align(
        alignment: Alignment.topCenter,
        child: SubjectDetailModuleStatus(
          loading: _loading,
          message: _loading ? '正在加载$_label' : (_error ?? '暂无$_label'),
          onRetry: !_loading && _error != null ? refresh : null,
        ),
      );
    }
    return Column(
      children: [
        if (_loading) const ProgressBar(strokeWidth: 2),
        if (_error != null)
          SubjectDetailModuleStatus(message: _error!, onRetry: refresh),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              var columns = ((constraints.maxWidth - 40 + gap) / (340 + gap))
                  .floor()
                  .clamp(1, 4);
              return CustomScrollView(
                primary: false,
                key: PageStorageKey(
                  'subject-${widget.subjectId}-${widget.kind.name}',
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList.builder(
                      itemCount: (_count + columns - 1) ~/ columns,
                      itemBuilder: (context, row) => Padding(
                        padding: const EdgeInsets.only(bottom: gap),
                        child: _buildRow(row, columns, gap),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRow(int row, int columns, double gap) {
    var decoration = BoxDecoration(
      color: SubjectDetailColors.card(context),
      borderRadius: BTRadius.mediumBR,
      border: Border.all(color: BTColors.divider(context)),
    );
    // 内容决定整行高度，背景填满整行，图片仍按自身比例布局。
    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var col = 0; col < columns; col++) ...[
                if (col > 0) SizedBox(width: gap),
                Expanded(
                  child: row * columns + col < _count
                      ? DecoratedBox(decoration: decoration)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < columns; col++) ...[
              if (col > 0) SizedBox(width: gap),
              Expanded(
                child: row * columns + col < _count
                    ? _buildPerson(row * columns + col)
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPerson(int index) {
    if (_isCharacters) {
      var character = _characters[index];
      return _buildCard(
        id: character.id,
        name: character.name,
        images: character.images,
        relation: character.relation,
        path: 'character',
        actors: character.actors,
      );
    }
    var person = _persons[index];
    return _buildCard(
      id: person.id,
      name: person.name,
      images: person.images,
      relation: person.relation,
      path: 'person',
      eps: person.eps,
    );
  }

  Widget _buildCard({
    required int id,
    required String name,
    required BangumiPersonImages? images,
    required String relation,
    required String path,
    String eps = '',
    List<BangumiPerson> actors = const [],
  }) {
    var linkLabel = '在浏览器中查看${replaceEscape(name)}';
    const linkStyle = ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 88),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: SubjectDetailColors.content(context),
              borderRadius: BTRadius.smallBR,
            ),
            child: BtBangumiCover(
              imageUrl: images?.large,
              fit: BoxFit.contain,
              width: 88,
              maxRequestEdge: BangumiCoverUrl.gridMaxEdge,
              progressSize: 16,
              errorBuilder: (context, {err}) => SizedBox.square(
                dimension: 88,
                child: Icon(
                  FluentIcons.contact,
                  size: 28,
                  color: BTColors.textTertiary(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: linkLabel,
                  child: Semantics(
                    label: linkLabel,
                    link: true,
                    child: HyperlinkButton(
                      style: linkStyle,
                      onPressed: () => launchUrlString(
                        '${BtrBangumiApi.siteBaseUrl}/$path/$id',
                      ),
                      child: Text(
                        replaceEscape(name),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(relation, style: BTTypography.caption(context)),
                if (eps.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText('参与章节 / 曲目：$eps'),
                ],
                if (actors.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('声优 / 演员：', style: BTTypography.caption(context)),
                      for (var actor in actors)
                        HyperlinkButton(
                          style: linkStyle,
                          onPressed: () => launchUrlString(
                            '${BtrBangumiApi.siteBaseUrl}/person/${actor.id}',
                          ),
                          child: Text(replaceEscape(actor.name)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
