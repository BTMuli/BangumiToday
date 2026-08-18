// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../models/bangumi/bangumi_model.dart';
import '../../widgets/bangumi/subject_detail/bsd_user_collection.dart';
import '../../widgets/bangumi/subject_detail/bsd_user_episodes.dart';
import 'sd_pw_relation.dart';
import 'subject_stat_providers.dart';

typedef SdpContextMenuBuilder =
    Widget Function(BuildContext context, EditableTextState state);

/// 详情页布局共用的数据和入口。
class SubjectDetailViewData {
  const SubjectDetailViewData({
    required this.subject,
    required this.user,
    required this.collectProvider,
    required this.onTagTap,
    required this.contextMenuBuilder,
    required this.openBmfDrawer,
    this.collectionKey,
    this.episodesKey,
    this.relationsKey,
  });

  final BangumiSubject subject;
  final BangumiUser? user;
  final SubjectCollectStatProvider collectProvider;
  final ValueChanged<String> onTagTap;
  final SdpContextMenuBuilder contextMenuBuilder;
  final VoidCallback openBmfDrawer;
  final Key? collectionKey;
  final Key? episodesKey;
  final Key? relationsKey;

  Widget buildCollection({bool compact = false, bool filled = true}) {
    if (user == null) return const SizedBox.shrink();
    return BsdUserCollection(
      subject,
      user!,
      collectProvider,
      key: collectionKey,
      compact: compact,
      filled: filled,
    );
  }

  Widget buildEpisodes({bool showSummary = false, bool showGrid = true}) {
    return BsdUserEpisodes(
      subject,
      user,
      collectProvider,
      key: episodesKey,
      showSummary: showSummary,
      showGrid: showGrid,
    );
  }

  Widget buildRelations() {
    return SdpRelationWidget(subject.id, key: relationsKey);
  }
}
