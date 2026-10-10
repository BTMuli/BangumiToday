// Project imports:
import '../../models/bangumi/bangumi_enum.dart';

/// 一次搜索的条件快照，供首屏和分页请求共用。
class SubjectSearchQuery {
  SubjectSearchQuery({
    String keyword = '',
    Iterable<String> tags = const [],
    Iterable<BangumiSubjectType> types = const [BangumiSubjectType.anime],
    this.sort = 'match',
    this.nsfw = false,
  }) : keyword = keyword.trim(),
       tags = List.unmodifiable(
         tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet(),
       ),
       types = List.unmodifiable(types);

  final String keyword;
  final List<String> tags;
  final List<BangumiSubjectType> types;
  final String sort;
  final bool? nsfw;

  bool get isEmpty => keyword.isEmpty && tags.isEmpty;

  List<String>? get tagFilter => tags.isEmpty ? null : tags;

  String? get description {
    var parts = [
      if (keyword.isNotEmpty) keyword,
      ...tags.map((tag) => '#$tag'),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }
}
