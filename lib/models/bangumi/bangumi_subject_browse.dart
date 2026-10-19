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
