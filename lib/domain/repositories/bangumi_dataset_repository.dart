// Project imports:
import '../../models/bangumi/bangumi_data_model.dart';

/// 本地 bangumi-data 数据集的业务读取与替换接口。
///
/// 覆盖日历与工作台用到的排期/站点查询，以及整包数据集原子更新；不暴露底层表访问器。
abstract class BangumiDatasetRepository {
  /// 读取首页七个本地放送日内的候选条目，包括本周尚未首播的新番。
  Future<List<BangumiDataItem>> readItemsForCalendar({
    DateTime? at,
    bool nightMode = false,
  });

  /// 读取站点元数据映射，键为站点 key（如 `bangumi`）。
  Future<Map<String, BangumiDataSite>> readSiteMap();

  /// 完整数据集、站点及版本原子更新，失败时保留上一份完整快照。
  Future<void> replaceDataset(
    BangumiDataJson data, {
    required String version,
    required String checkedAt,
    void Function(int completed, int total)? onProgress,
  });

  /// 工作台按关联的 Bangumi ID 批量读取本地排期。
  Future<List<BangumiDataItem>> readItemsForSubjects(Set<int> subjectIds);
}
