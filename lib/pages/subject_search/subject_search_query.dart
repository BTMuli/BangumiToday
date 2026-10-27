// Project imports:
import '../../models/bangumi/bangumi_enum.dart';

/// 一次搜索的条件快照，供首屏和分页请求共用。
class SubjectSearchQuery {
  SubjectSearchQuery({
    String keyword = '',
    Iterable<String> tags = const [],
    Iterable<String> metaTags = const [],
    Iterable<BangumiSubjectType> types = const [BangumiSubjectType.anime],
    this.sort = 'match',
    this.nsfw = false,
    String dateFrom = '',
    String dateTo = '',
    String ratingFrom = '',
    String ratingTo = '',
    String rankFrom = '',
    String rankTo = '',
  }) : keyword = keyword.trim(),
       tags = _tags(tags),
       metaTags = _tags(metaTags),
       types = List.unmodifiable(types),
       dateFrom = dateFrom.trim(),
       dateTo = dateTo.trim(),
       ratingFrom = ratingFrom.trim(),
       ratingTo = ratingTo.trim(),
       rankFrom = rankFrom.trim(),
       rankTo = rankTo.trim();

  final String keyword;
  final List<String> tags;
  final List<String> metaTags;
  final List<BangumiSubjectType> types;
  final String sort;
  final bool? nsfw;
  final String dateFrom;
  final String dateTo;
  final String ratingFrom;
  final String ratingTo;
  final String rankFrom;
  final String rankTo;

  static List<String> _tags(Iterable<String> values) => List.unmodifiable(
    values.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet(),
  );

  bool get hasRangeFilters => [
    dateFrom,
    dateTo,
    ratingFrom,
    ratingTo,
    rankFrom,
    rankTo,
  ].any((value) => value.isNotEmpty);

  bool get isEmpty =>
      keyword.isEmpty && tags.isEmpty && metaTags.isEmpty && !hasRangeFilters;

  List<String>? get tagFilter => tags.isEmpty ? null : tags;
  List<String>? get metaTagFilter => metaTags.isEmpty ? null : metaTags;
  List<String>? get airdateFilter => _range(dateFrom, dateTo);
  List<String>? get ratingFilter => _range(ratingFrom, ratingTo);
  // 排名 0 表示未上榜，不能混入排名排序或名次范围。
  List<String>? get rankFilter => _range(
    rankFrom.isEmpty && (rankTo.isNotEmpty || sort == 'rank') ? '1' : rankFrom,
    rankTo,
  );

  static List<String>? _range(String from, String to) =>
      from.isEmpty && to.isEmpty
      ? null
      : [if (from.isNotEmpty) '>=$from', if (to.isNotEmpty) '<=$to'];

  String? get validationError {
    if (types.isEmpty) return '请至少选择一个搜索类型';
    if (metaTags.any((tag) => tag.startsWith('-'))) {
      return '公共标签暂不支持排除，请去掉开头的 -';
    }
    for (var value in [dateFrom, dateTo]) {
      if (value.isEmpty) continue;
      var date = DateTime.tryParse(value);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          date == null ||
          date.toIso8601String().split('T').first != value) {
        return '日期请输入有效的 YYYY-MM-DD，例如 2024-01-01';
      }
    }
    if (dateFrom.isNotEmpty &&
        dateTo.isNotEmpty &&
        dateFrom.compareTo(dateTo) > 0) {
      return '开始日期不能晚于结束日期';
    }
    for (var value in [ratingFrom, ratingTo]) {
      if (value.isEmpty) continue;
      var score = double.tryParse(value);
      if (score == null || !score.isFinite || score < 0 || score > 10) {
        return '评分请输入 0 到 10 之间的数字';
      }
    }
    for (var value in [rankFrom, rankTo]) {
      if (value.isEmpty) continue;
      var rank = int.tryParse(value);
      if (rank == null || rank < 1) return '排名请输入大于 0 的整数';
    }
    for (var range in [
      (ratingFrom, ratingTo, '评分'),
      (rankFrom, rankTo, '排名'),
    ]) {
      if (range.$1.isNotEmpty &&
          range.$2.isNotEmpty &&
          num.parse(range.$1) > num.parse(range.$2)) {
        return '${range.$3}下限不能大于上限';
      }
    }
    return null;
  }

  String? get description {
    var parts = [
      if (keyword.isNotEmpty) keyword,
      ...tags.map((tag) => '#$tag'),
      ...metaTags.map((tag) => '公共标签:$tag'),
      if (dateFrom.isNotEmpty || dateTo.isNotEmpty)
        '日期 ${dateFrom.isEmpty ? '不限' : dateFrom}～'
            '${dateTo.isEmpty ? '不限' : dateTo}',
      if (ratingFrom.isNotEmpty || ratingTo.isNotEmpty)
        '评分 ${ratingFrom.isEmpty ? '不限' : ratingFrom}～'
            '${ratingTo.isEmpty ? '不限' : ratingTo}',
      if (rankFrom.isNotEmpty || rankTo.isNotEmpty)
        '排名 ${rankFrom.isEmpty ? '不限' : rankFrom}～'
            '${rankTo.isEmpty ? '不限' : rankTo}',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }
}
