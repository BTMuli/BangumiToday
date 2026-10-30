/// GET filters for Anime Garden resource browsing and search.
class AnimeGardenQuery {
  const AnimeGardenQuery({
    this.subjects = const [],
    this.search = '',
    this.include = const [],
    this.keywords = const [],
    this.exclude = const [],
    this.fansub = '',
    this.publisher = '',
    this.type = '动画',
    this.provider = '',
    this.after,
    this.before,
    this.page = 1,
    this.pageSize = 50,
  });

  final List<int> subjects;
  final String search;
  final List<String> include;
  final List<String> keywords;
  final List<String> exclude;
  final String fansub;
  final String publisher;
  final String type;
  final String provider;
  final DateTime? after;
  final DateTime? before;
  final int page;
  final int pageSize;

  static const apiOrigin = 'https://api.animes.garden';

  Map<String, dynamic> _parameters() {
    var result = <String, dynamic>{};
    void text(String key, String value) {
      if (value.trim().isNotEmpty) result[key] = value.trim();
    }

    void texts(String key, Iterable<String> values) {
      var cleaned = values.map((v) => v.trim()).where((v) => v.isNotEmpty);
      var sorted = cleaned.toSet().toList()..sort();
      if (sorted.isNotEmpty) result[key] = sorted;
    }

    var ids = subjects.where((id) => id > 0).toSet().toList()..sort();
    if (ids.isNotEmpty) result['subject'] = ids.map((id) => '$id').toList();
    text('search', search);
    if (search.trim().isEmpty) texts('include', include);
    texts('keyword', keywords);
    texts('exclude', exclude);
    text('fansub', fansub);
    text('publisher', publisher);
    text('type', type);
    text('provider', provider);
    if (after != null) result['after'] = after!.toUtc().toIso8601String();
    if (before != null) result['before'] = before!.toUtc().toIso8601String();
    result['page'] = '$page';
    result['pageSize'] = '$pageSize';
    result['tracker'] = 'true';
    return result;
  }

  Uri get resourceUri =>
      Uri.parse('$apiOrigin/resources').replace(queryParameters: _parameters());

  AnimeGardenQuery atPage(int value) => AnimeGardenQuery(
    subjects: subjects,
    search: search,
    include: include,
    keywords: keywords,
    exclude: exclude,
    fansub: fansub,
    publisher: publisher,
    type: type,
    provider: provider,
    after: after,
    before: before,
    page: value,
    pageSize: pageSize,
  );
}
