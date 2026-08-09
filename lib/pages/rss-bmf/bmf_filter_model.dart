// Project imports:
import '../../core/utils/rss_date.dart';
import '../../database/app/app_rss.dart';
import '../../models/database/app_bmf_model.dart';

/// BMF 工作台列表的配置筛选分类。
enum BmfConfigurationFilter {
  all,
  updates,
  hasRss,
  autoUpdate,
  manualUpdate,
  incomplete,
}

class BmfFilterStats {
  final int total;
  final int updates;
  final int hasRss;
  final int autoUpdate;
  final int manualUpdate;
  final int incomplete;

  const BmfFilterStats({
    required this.total,
    required this.updates,
    required this.hasRss,
    required this.autoUpdate,
    required this.manualUpdate,
    required this.incomplete,
  });

  static const empty = BmfFilterStats(
    total: 0,
    updates: 0,
    hasRss: 0,
    autoUpdate: 0,
    manualUpdate: 0,
    incomplete: 0,
  );
}

class BmfQuarter {
  final int year;
  final int quarter;

  const BmfQuarter(this.year, this.quarter);

  static const all = BmfQuarter(0, 0);

  factory BmfQuarter.fromDate(DateTime date) {
    return BmfQuarter(date.year, ((date.month - 1) ~/ 3) + 1);
  }

  factory BmfQuarter.current() => BmfQuarter.fromDate(DateTime.now());

  String get label => this == all ? '全部季度' : '$year Q$quarter';

  @override
  bool operator ==(Object other) =>
      other is BmfQuarter && other.year == year && other.quarter == quarter;

  @override
  int get hashCode => Object.hash(year, quarter);
}

/// BMF 工作台列表的筛选与 RSS 状态聚合。
///
/// 持有季度、搜索、配置分类等筛选条件，以及各番剧的待处理更新数量、
/// 最近更新时间等 RSS 状态，并负责从原始列表计算出统计与过滤结果。
class BmfFilterModel {
  BmfFilterModel({required this.rss});

  final BtsAppRss rss;

  List<AppBmfModel> filteredList = [];
  BmfFilterStats filterStats = BmfFilterStats.empty;
  BmfConfigurationFilter configurationFilter = BmfConfigurationFilter.all;
  BmfQuarter selectedQuarter = BmfQuarter.all;
  List<BmfQuarter> quarterOptions = [];
  String searchQuery = '';
  final Map<int, int> pendingCounts = {};
  final Map<int, DateTime> latestUpdateTimes = {};
  final Map<String, int> rssSubjectsByKey = {};
  String _loadedStatusSignature = '';

  void computeStats(List<AppBmfModel> bmfList) {
    var hasRss = 0;
    var autoUpdate = 0;
    var manualUpdate = 0;
    var incomplete = 0;
    var updates = 0;
    for (var item in bmfList) {
      var rssConfigured = item.rss != null && item.rss!.isNotEmpty;
      var directoryConfigured =
          item.download != null && item.download!.isNotEmpty;
      if (rssConfigured) hasRss++;
      if (item.autoUpdate) {
        autoUpdate++;
      } else {
        manualUpdate++;
      }
      if (!rssConfigured || !directoryConfigured) incomplete++;
      if ((pendingCounts[item.subject] ?? 0) > 0) updates++;
    }
    filterStats = BmfFilterStats(
      total: bmfList.length,
      updates: updates,
      hasRss: hasRss,
      autoUpdate: autoUpdate,
      manualUpdate: manualUpdate,
      incomplete: incomplete,
    );
  }

  void applyFilter(List<AppBmfModel> bmfList) {
    var quarters = bmfList
        .map((bmf) => DateTime.tryParse(bmf.airDate ?? ''))
        .whereType<DateTime>()
        .map(BmfQuarter.fromDate)
        .toSet();
    quarters.add(BmfQuarter.current());
    quarterOptions = quarters.toList()
      ..sort((a, b) {
        var yearCompare = b.year.compareTo(a.year);
        return yearCompare != 0 ? yearCompare : b.quarter.compareTo(a.quarter);
      });

    var quarterFilteredList = bmfList.where((bmf) {
      if (selectedQuarter == BmfQuarter.all) return true;
      var airDate = DateTime.tryParse(bmf.airDate ?? '');
      return airDate != null && BmfQuarter.fromDate(airDate) == selectedQuarter;
    }).toList();
    computeStats(quarterFilteredList);

    var query = searchQuery.trim().toLowerCase();
    filteredList =
        quarterFilteredList.where((bmf) {
          var matchesSearch =
              query.isEmpty ||
              (bmf.title?.toLowerCase().contains(query) ?? false) ||
              bmf.subject.toString().contains(query);
          if (!matchesSearch) return false;

          var hasRss = bmf.rss != null && bmf.rss!.isNotEmpty;
          var hasDirectory = bmf.download != null && bmf.download!.isNotEmpty;
          return switch (configurationFilter) {
            BmfConfigurationFilter.all => true,
            BmfConfigurationFilter.updates =>
              (pendingCounts[bmf.subject] ?? 0) > 0,
            BmfConfigurationFilter.hasRss => hasRss,
            BmfConfigurationFilter.autoUpdate => bmf.autoUpdate,
            BmfConfigurationFilter.manualUpdate => !bmf.autoUpdate,
            BmfConfigurationFilter.incomplete => !hasRss || !hasDirectory,
          };
        }).toList()..sort((a, b) {
          var aDate =
              latestUpdateTimes[a.subject] ??
              DateTime.tryParse(a.airDate ?? '');
          var bDate =
              latestUpdateTimes[b.subject] ??
              DateTime.tryParse(b.airDate ?? '');
          if (aDate != null && bDate != null) {
            var dateCompare = bDate.compareTo(aDate);
            if (dateCompare != 0) return dateCompare;
          } else if (aDate != null) {
            return -1;
          } else if (bDate != null) {
            return 1;
          }
          return b.subject.compareTo(a.subject);
        });
  }

  /// 记录当前 RSS 配置签名并返回是否首次加载，调用方据此安排状态加载。
  bool scheduleStatusLoad(List<AppBmfModel> bmfList) {
    rssSubjectsByKey
      ..clear()
      ..addEntries(
        bmfList
            .where((item) => item.rss != null && item.rss!.isNotEmpty)
            .map(
              (item) => MapEntry(
                item.mkBgmId != null && item.mkBgmId!.isNotEmpty
                    ? item.mkBgmId!
                    : item.rss!,
                item.subject,
              ),
            ),
      );
    var signature = bmfList
        .map((item) => '${item.subject}:${item.rss}:${item.mkBgmId}')
        .join('|');
    if (_loadedStatusSignature == signature) return false;
    _loadedStatusSignature = signature;
    return true;
  }

  Future<void> loadUpdateStates(List<AppBmfModel> bmfList) async {
    var sources = bmfList
        .where((item) => item.rss != null && item.rss!.isNotEmpty)
        .toList();
    var values = await Future.wait(
      sources.map((item) async {
        var model = item.mkBgmId != null && item.mkBgmId!.isNotEmpty
            ? await rss.readByMkId(item.mkBgmId!)
            : await rss.read(item.rss!);
        return (
          item.subject,
          model?.pendingItemKeys.length ?? 0,
          model == null ? null : latestRssPublishedAtFromXml(model.data),
        );
      }),
    );
    pendingCounts
      ..clear()
      ..addEntries(values.map((value) => MapEntry(value.$1, value.$2)));
    latestUpdateTimes
      ..clear()
      ..addEntries(
        values
            .where((value) => value.$3 != null)
            .map((value) => MapEntry(value.$1, value.$3!)),
      );
  }
}
