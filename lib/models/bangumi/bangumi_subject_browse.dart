// Project imports:
import 'request_subject.dart';

/// 与 Bangumi 浏览页一致的榜单排序。
enum BangumiSubjectBrowseSort {
  trends('趋势热度', '按 Bangumi 近期热度排序'),
  rank('评分排行', '按 Bangumi 综合排名排序');

  const BangumiSubjectBrowseSort(this.label, this.description);

  final String label;
  final String description;
}

/// 榜单的时间筛选：只选年份，或继续缩小到某个月份。
class BangumiSubjectBrowseTime {
  const BangumiSubjectBrowseTime({this.year, this.month})
    : assert(month == null || (year != null && month >= 1 && month <= 12));

  /// 不限制放送时间。
  static const all = BangumiSubjectBrowseTime();

  /// 放送年份；为空表示不限制时间。
  final int? year;

  /// 放送月份，必须与 [year] 一起使用。
  final int? month;

  bool get isActive => year != null;

  String get label {
    if (year == null) return '全部时间';
    if (month == null) return '$year年';
    return '$year年$month月';
  }

  @override
  bool operator ==(Object other) =>
      other is BangumiSubjectBrowseTime &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// 浏览接口的作品摘要，保留 SlimSubject 独有的作品信息。
class BangumiSubjectBrowseItem {
  const BangumiSubjectBrowseItem({required this.subject, required this.info});

  final BangumiSubjectSearchData subject;
  final String info;
}

/// /p1/subjects 的 total 表示总页数，每页固定 24 部。
class BangumiSubjectBrowsePage {
  const BangumiSubjectBrowsePage({
    required this.totalPages,
    required this.items,
  });

  static const pageSize = 24;

  final int totalPages;
  final List<BangumiSubjectBrowseItem> items;
}
