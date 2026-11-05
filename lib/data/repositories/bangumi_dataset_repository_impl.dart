// Project imports:
import '../../database/bangumi/bangumi_data.dart';
import '../../domain/repositories/bangumi_dataset_repository.dart';
import '../../models/bangumi/bangumi_data_model.dart';

/// 基于 [BtsBangumiData] 表访问器的 bangumi-data 数据集仓储。
class BangumiDatasetRepositoryImpl implements BangumiDatasetRepository {
  BangumiDatasetRepositoryImpl({BtsBangumiData? dataset})
    : _dataset = dataset ?? BtsBangumiData();

  final BtsBangumiData _dataset;

  @override
  Future<List<BangumiDataItem>> readItemsForCalendar({
    DateTime? at,
    bool nightMode = false,
  }) => _dataset.readItemsForCalendar(at: at, nightMode: nightMode);

  @override
  Future<Map<String, BangumiDataSite>> readSiteMap() => _dataset.readSiteMap();

  @override
  Future<void> replaceDataset(
    BangumiDataJson data, {
    required String version,
    required String checkedAt,
    void Function(int completed, int total)? onProgress,
  }) => _dataset.replaceDataset(
    data,
    version: version,
    checkedAt: checkedAt,
    onProgress: onProgress,
  );

  @override
  Future<List<BangumiDataItem>> readItemsForSubjects(Set<int> subjectIds) =>
      _dataset.readItemsForSubjects(subjectIds);
}
