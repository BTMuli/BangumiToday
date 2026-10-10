// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../models/bangumi/bangumi_model.dart';
import 'subject_detail_comments.dart';
import 'subject_detail_people.dart';
import 'subject_detail_prefetch.dart';
import 'subject_detail_relation.dart';
import 'subject_stat_providers.dart';
import 'subject_user_collection.dart';
import 'subject_user_episodes.dart';

typedef SubjectDetailContextMenuBuilder =
    Widget Function(BuildContext context, EditableTextState state);

/// 详情页的数据和子模块入口。
class SubjectDetailViewData {
  const SubjectDetailViewData({
    required this.subject,
    required this.user,
    required this.collectProvider,
    required this.onTagTap,
    required this.onOpenEpisode,
    required this.contextMenuBuilder,
    this.collectionKey,
    this.episodesKey,
    this.relationsKey,
    this.charactersKey,
    this.personsKey,
    this.commentsKey,
    this.prefetch,
  });

  final BangumiSubject subject;
  final BangumiUser? user;
  final SubjectCollectStatProvider collectProvider;
  final ValueChanged<String> onTagTap;

  /// 打开章节详情下一级页面
  final ValueChanged<int> onOpenEpisode;
  final SubjectDetailContextMenuBuilder contextMenuBuilder;
  final Key? collectionKey;
  final Key? episodesKey;
  final Key? relationsKey;
  final Key? charactersKey;
  final Key? personsKey;
  final Key? commentsKey;
  final SubjectDetailPrefetch? prefetch;

  Widget buildCollection({bool compact = false, bool filled = true}) {
    if (user == null) return const SizedBox.shrink();
    return SubjectUserCollection(
      subject,
      user!,
      collectProvider,
      key: collectionKey,
      compact: compact,
      filled: filled,
      prefetch: prefetch,
    );
  }

  Widget buildEpisodes({bool showSummary = false, bool showGrid = true}) {
    return SubjectUserEpisodes(
      subject,
      user,
      collectProvider,
      key: episodesKey,
      showSummary: showSummary,
      showGrid: showGrid,
      prefetch: prefetch,
      onOpenEpisode: onOpenEpisode,
    );
  }

  Widget buildRelations({ValueChanged<int>? onCountChanged}) {
    return SubjectDetailRelation(
      subject.id,
      key: relationsKey,
      onCountChanged: onCountChanged,
    );
  }

  Widget buildCharacters() => SubjectDetailPeople(
    key: charactersKey,
    subjectId: subject.id,
    kind: SubjectDetailPeopleKind.characters,
  );

  Widget buildPersons({
    SubjectDetailStaffGrouping grouping = SubjectDetailStaffGrouping.person,
  }) => SubjectDetailPeople(
    key: personsKey,
    subjectId: subject.id,
    kind: SubjectDetailPeopleKind.persons,
    staffGrouping: grouping,
  );

  Widget buildComments() =>
      SubjectDetailComments(key: commentsKey, subjectId: subject.id);
}
