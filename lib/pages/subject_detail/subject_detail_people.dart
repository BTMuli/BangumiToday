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
import 'subject_detail_staff_groups.dart';

enum SubjectDetailPeopleKind { characters, persons }

enum SubjectDetailStaffGrouping { person, position }

/// 角色及制作人员各自挂载、请求和保留滚动位置。
class SubjectDetailPeople extends ConsumerStatefulWidget {
  const SubjectDetailPeople({
    super.key,
    required this.subjectId,
    required this.kind,
    this.staffGrouping = SubjectDetailStaffGrouping.person,
  });

  final int subjectId;
  final SubjectDetailPeopleKind kind;
  final SubjectDetailStaffGrouping staffGrouping;

  @override
  ConsumerState<SubjectDetailPeople> createState() =>
      _SubjectDetailPeopleState();
}

class _SubjectDetailPeopleState extends ConsumerState<SubjectDetailPeople>
    with SubjectDetailRefreshable {
  List<BangumiRelatedCharacter> _characters = [];
  SubjectStaffGroups _staff = const SubjectStaffGroups(
    members: [],
    positions: [],
  );
  bool _loading = true;
  String? _error;
  int _generation = 0;

  bool get _isCharacters => widget.kind == SubjectDetailPeopleKind.characters;
  String get _label => _isCharacters ? '角色' : '制作人员';
  int get _count => _isCharacters ? _characters.length : _staff.members.length;

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
      _staff = const SubjectStaffGroups(members: [], positions: []);
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
          _staff = SubjectStaffGroups.fromPersons(response.data!);
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  'subject-${widget.subjectId}-${widget.kind.name}'
                  '${_isCharacters ? '' : '-${widget.staffGrouping.name}'}',
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        if (_isCharacters)
                          _buildGrid(
                            _characters.length,
                            columns,
                            gap,
                            _buildCharacter,
                          )
                        else if (widget.staffGrouping ==
                            SubjectDetailStaffGrouping.person)
                          _buildGrid(
                            _staff.members.length,
                            columns,
                            gap,
                            (index) => _buildStaffMember(_staff.members[index]),
                          )
                        else
                          for (var group in _staff.positions) ...[
                            _buildPositionHeading(group),
                            _buildGrid(
                              group.members.length,
                              columns,
                              gap,
                              (index) => _buildStaffMember(
                                group.members[index],
                                showPositions: false,
                              ),
                            ),
                          ],
                      ],
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

  Widget _buildPositionHeading(SubjectStaffPositionGroup group) {
    var label = group.position.isEmpty ? '未标注职位' : group.position;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          '$label · ${group.members.length}',
          style: BTTypography.bodyStrong(context),
        ),
      ),
    );
  }

  Widget _buildGrid(
    int count,
    int columns,
    double gap,
    Widget Function(int) itemBuilder,
  ) {
    return SliverList.builder(
      itemCount: (count + columns - 1) ~/ columns,
      itemBuilder: (context, row) => Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: _buildRow(row, columns, gap, count, itemBuilder),
      ),
    );
  }

  Widget _buildRow(
    int row,
    int columns,
    double gap,
    int count,
    Widget Function(int) itemBuilder,
  ) {
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
                  child: row * columns + col < count
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
                child: row * columns + col < count
                    ? itemBuilder(row * columns + col)
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCharacter(int index) {
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

  Widget _buildStaffMember(
    SubjectStaffMember member, {
    bool showPositions = true,
  }) {
    var person = member.person;
    return _buildCard(
      id: person.id,
      name: person.name,
      images: person.images,
      relation: showPositions ? member.positions.keys.join(' / ') : '',
      path: 'person',
      participation: [
        for (var entry in member.positions.entries)
          if (entry.value.isNotEmpty)
            '${member.positions.length > 1 ? '${entry.key} · ' : ''}'
                '参与章节 / 曲目：${entry.value.join('；')}',
      ],
    );
  }

  Widget _buildCard({
    required int id,
    required String name,
    required BangumiPersonImages? images,
    required String relation,
    required String path,
    List<String> participation = const [],
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
                if (relation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(relation, style: BTTypography.caption(context)),
                ],
                for (var detail in participation) ...[
                  const SizedBox(height: 6),
                  SelectableText(detail),
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
