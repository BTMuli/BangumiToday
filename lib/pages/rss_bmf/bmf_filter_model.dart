// Project imports:
import '../../models/database/app_bmf_model.dart';
import 'bmf_subject_data.dart';

enum BmfConfigurationFilter { all, updates, incomplete }

enum BmfAssociationFilter {
  all('全部关联'),
  complete('RSS + 本地目录'),
  rssOnly('仅 RSS'),
  directoryOnly('仅本地目录'),
  unconfigured('尚未配置'),
  missingRss('缺少 RSS'),
  missingDirectory('缺少目录');

  const BmfAssociationFilter(this.label);
  final String label;
}

enum BmfUpdateFilter {
  all('全部更新方式'),
  automatic('自动更新 RSS'),
  manual('手动更新 RSS');

  const BmfUpdateFilter(this.label);
  final String label;
}

enum BmfSortOrder {
  attention('待处理优先'),
  airDate('首播从新到旧'),
  rssPublished('最近资源发布'),
  title('标题 A → Z'),
  added('最近添加关联');

  const BmfSortOrder(this.label);
  final String label;

  String get description => switch (this) {
    attention => '待处理更新置顶，其次为 RSS 有资源、RSS 暂无资源、未关联 RSS；组内按季度及最近资源发布排列',
    airDate => '只按首播日期排列，日期未知的条目置后',
    rssPublished => '只按 RSS 资源发布时间排列，没有发布记录的条目置后',
    title => '按显示标题排列，同名条目保持固定顺序',
    added => '按本地关联的创建顺序排列',
  };
}

class BmfFilterStats {
  final int total;
  final int updates;
  final int incomplete;

  const BmfFilterStats({this.total = 0, this.updates = 0, this.incomplete = 0});
}

class BmfQuarter {
  final int year;
  final int quarter;

  const BmfQuarter(this.year, this.quarter);

  static const all = BmfQuarter(0, 0);
  static const unknown = BmfQuarter(-1, 0);

  /// 季末最后一周提前首播的新番归入下一季，12 月末跨年。
  factory BmfQuarter.fromDate(DateTime date) {
    var seasonDate = date.month % 3 == 0 && date.day >= 25
        ? DateTime(date.year, date.month + 1)
        : date;
    return BmfQuarter(seasonDate.year, ((seasonDate.month - 1) ~/ 3) + 1);
  }

  /// 当前季度按日历计算，提前首播不会提前切换「本季」。
  factory BmfQuarter.current({DateTime? now}) {
    var date = now ?? DateTime.now();
    return BmfQuarter(date.year, ((date.month - 1) ~/ 3) + 1);
  }

  String get label => switch (this) {
    all => '全部季度',
    unknown => '首播日期未知',
    _ => '$year 年 ${(quarter - 1) * 3 + 1} 月番',
  };

  int get index => year * 4 + quarter;

  @override
  bool operator ==(Object other) =>
      other is BmfQuarter && other.year == year && other.quarter == quarter;

  @override
  int get hashCode => Object.hash(year, quarter);
}

/// 配置、季度、搜索先组合，再统计快捷筛选数量；排序使用独立的数据维度。
class BmfFilterModel {
  List<AppBmfModel> filteredList = [];
  BmfFilterStats filterStats = const BmfFilterStats();
  int totalCount = 0;
  BmfConfigurationFilter configurationFilter = BmfConfigurationFilter.all;
  BmfAssociationFilter associationFilter = BmfAssociationFilter.all;
  BmfUpdateFilter updateFilter = BmfUpdateFilter.all;
  BmfQuarter selectedQuarter = BmfQuarter.all;
  BmfSortOrder sortOrder = BmfSortOrder.attention;
  List<BmfQuarter> quarterOptions = [];
  String searchQuery = '';
  final Map<int, BmfSubjectData> subjectData = {};
  final Map<int, int> pendingCounts = {};
  final Map<int, int> rssItemCounts = {};
  final Map<int, DateTime> latestUpdateTimes = {};

  static bool hasRss(AppBmfModel item) => item.rss?.trim().isNotEmpty ?? false;

  static bool hasDirectory(AppBmfModel item) =>
      item.download?.trim().isNotEmpty ?? false;

  String titleFor(AppBmfModel item) {
    var title = item.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return subjectData[item.subject]?.names.firstOrNull ?? '未命名番剧';
  }

  String? airDateFor(AppBmfModel item) {
    return parseAirDate(item.airDate) != null
        ? item.airDate
        : subjectData[item.subject]?.airDate;
  }

  /// 不把不完整/非法日期自动纠正到另一个月或另一个季度。
  static DateTime? parseAirDate(String? value) {
    var match = RegExp(
      r'^(\d{4})-(\d{2})(?:-(\d{2}))?$',
    ).firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    var year = int.parse(match[1]!);
    var month = int.parse(match[2]!);
    var day = int.parse(match[3] ?? '1');
    if (year < 1 || month < 1 || month > 12 || day < 1) return null;
    var date = DateTime(year, month, day);
    return date.month == month && date.day == day ? date : null;
  }

  BmfQuarter quarterFor(AppBmfModel item) {
    var date = parseAirDate(airDateFor(item));
    return date == null ? BmfQuarter.unknown : BmfQuarter.fromDate(date);
  }

  bool get hasActiveFilters =>
      configurationFilter != BmfConfigurationFilter.all ||
      associationFilter != BmfAssociationFilter.all ||
      updateFilter != BmfUpdateFilter.all ||
      selectedQuarter != BmfQuarter.all ||
      searchQuery.trim().isNotEmpty;

  void resetFilters() {
    configurationFilter = BmfConfigurationFilter.all;
    associationFilter = BmfAssociationFilter.all;
    updateFilter = BmfUpdateFilter.all;
    selectedQuarter = BmfQuarter.all;
    searchQuery = '';
  }

  void applyFilter(List<AppBmfModel> bmfList, {DateTime? now}) {
    totalCount = bmfList.length;
    var at = now ?? DateTime.now();
    var today = DateTime(at.year, at.month, at.day);
    var current = BmfQuarter.current(now: at);
    var quarters = bmfList.map(quarterFor).toSet()..add(current);
    // 保留当前选择，让删除最后一条结果后的筛选仍可清除。
    if (selectedQuarter != BmfQuarter.all) quarters.add(selectedQuarter);
    quarterOptions = quarters.toList()
      ..sort((a, b) => b.index.compareTo(a.index));

    var queries = searchQuery.trim().toLowerCase().split(RegExp(r'\s+'));
    var scoped = bmfList.where((item) {
      if (selectedQuarter != BmfQuarter.all &&
          quarterFor(item) != selectedQuarter) {
        return false;
      }
      var searchText = [
        titleFor(item),
        item.subject.toString(),
        ...?subjectData[item.subject]?.names,
      ].join(' ').toLowerCase();
      if (!queries.every(searchText.contains)) return false;
      var rss = hasRss(item);
      var directory = hasDirectory(item);
      var matchesAssociation = switch (associationFilter) {
        BmfAssociationFilter.all => true,
        BmfAssociationFilter.complete => rss && directory,
        BmfAssociationFilter.rssOnly => rss && !directory,
        BmfAssociationFilter.directoryOnly => !rss && directory,
        BmfAssociationFilter.unconfigured => !rss && !directory,
        BmfAssociationFilter.missingRss => !rss,
        BmfAssociationFilter.missingDirectory => !directory,
      };
      var matchesUpdate = switch (updateFilter) {
        BmfUpdateFilter.all => true,
        BmfUpdateFilter.automatic => rss && item.autoUpdate,
        BmfUpdateFilter.manual => rss && !item.autoUpdate,
      };
      return matchesAssociation && matchesUpdate;
    }).toList();

    bool hasUpdates(AppBmfModel item) =>
        hasRss(item) && (pendingCounts[item.subject] ?? 0) > 0;
    bool incomplete(AppBmfModel item) => !hasRss(item) || !hasDirectory(item);
    filterStats = BmfFilterStats(
      total: scoped.length,
      updates: scoped.where(hasUpdates).length,
      incomplete: scoped.where(incomplete).length,
    );
    filteredList = scoped.where((item) {
      return switch (configurationFilter) {
        BmfConfigurationFilter.all => true,
        BmfConfigurationFilter.updates => hasUpdates(item),
        BmfConfigurationFilter.incomplete => incomplete(item),
      };
    }).toList()..sort((a, b) => _compare(a, b, current, today));
  }

  int _compare(
    AppBmfModel a,
    AppBmfModel b,
    BmfQuarter current,
    DateTime today,
  ) {
    var result = 0;
    switch (sortOrder) {
      case BmfSortOrder.attention:
        int resourcePriority(AppBmfModel item) {
          if (!hasRss(item)) return 3;
          if ((pendingCounts[item.subject] ?? 0) > 0) return 0;
          return (rssItemCounts[item.subject] ?? 0) > 0 ? 1 : 2;
        }
        result = resourcePriority(a).compareTo(resourcePriority(b));
        if (result != 0) return result;
        var aQuarter = quarterFor(a);
        var bQuarter = quarterFor(b);
        var aDate = parseAirDate(airDateFor(a));
        var bDate = parseAirDate(airDateFor(b));
        int priority(BmfQuarter quarter, DateTime? date) => date == null
            ? 3
            : date.isAfter(today)
            ? 1
            : quarter == current
            ? 0
            : 2;
        var aPriority = priority(aQuarter, aDate);
        var bPriority = priority(bQuarter, bDate);
        result = aPriority.compareTo(bPriority);
        if (result != 0) return result;
        if (aPriority == 1) {
          result = aDate!.compareTo(bDate!);
          break;
        }
        result = bQuarter.index.compareTo(aQuarter.index);
        if (result != 0) return result;
        result = _compareDates(
          hasRss(a) ? latestUpdateTimes[a.subject] : null,
          hasRss(b) ? latestUpdateTimes[b.subject] : null,
        );
        if (result != 0) return result;
        result = _compareDates(aDate, bDate);
      case BmfSortOrder.airDate:
        result = _compareDates(
          parseAirDate(airDateFor(a)),
          parseAirDate(airDateFor(b)),
        );
      case BmfSortOrder.rssPublished:
        result = _compareDates(
          hasRss(a) ? latestUpdateTimes[a.subject] : null,
          hasRss(b) ? latestUpdateTimes[b.subject] : null,
        );
      case BmfSortOrder.added:
        result = b.id.compareTo(a.id);
      case BmfSortOrder.title:
        break;
    }
    if (result != 0) return result;
    result = titleFor(a).toLowerCase().compareTo(titleFor(b).toLowerCase());
    return result != 0 ? result : a.subject.compareTo(b.subject);
  }

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null) return b == null ? 0 : 1;
    return b == null ? -1 : b.compareTo(a);
  }
}
