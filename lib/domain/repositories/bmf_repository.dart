// Project imports:
import '../../models/database/app_bmf_model.dart';

/// 订阅列表的变更类型。
///
/// 新建与更新分开，调用方才能保持“新建置顶、更新原位替换”的现有列表语义。
enum BmfChangeKind { added, updated, removed }

/// 一次 BMF 订阅变更。
class BmfChange {
  const BmfChange({required this.kind, required this.subject, this.model});

  final BmfChangeKind kind;

  /// 变更对应的 Bangumi 条目 ID。
  final int subject;

  /// 变更后的订阅，[BmfChangeKind.removed] 时为 null。
  final AppBmfModel? model;
}

/// Bangumi-Mikan-File 订阅的业务数据接口。
///
/// 只声明业务语义，不依赖 Riverpod、具体表访问或 RSS 服务实现。写入后的自动
/// RSS 调度由实现负责并恰好触发一次；用户刚设置 RSS 等需要立刻拉取的场景，按
/// [write] / [updateModel] 的返回值决定是否再显式调用 [refreshRss]。
abstract class BmfRepository {
  /// 订阅写入/删除事件流，供状态层同步列表。
  Stream<BmfChange> get changes;

  Future<List<AppBmfModel>> readAll();

  Future<AppBmfModel?> read(int subject);

  /// 新建订阅。
  ///
  /// 写入后由实现决定是否顺带刷新 RSS：已发起拉取时返回 true，此时调用方不要
  /// 再补一次 [refreshRss]；返回 false 表示没有自动调度，需要立即拉取时由调用方
  /// 显式调用 [refreshRss]。
  Future<bool> write(AppBmfModel model);

  /// 更新已有订阅，返回值语义同 [write]。
  Future<bool> updateModel(AppBmfModel model);

  Future<void> delete(int subject);

  Future<bool> checkRss(String rss, {int? excludeSubject});

  Future<bool> checkDir(String dir, {int? excludeSubject});

  /// 补全放送日期，只写库，不触发 RSS 调度。
  Future<void> updateAirDate(int subject, String airDate);

  /// 手动刷新单个订阅的 RSS，返回是否刷新成功。
  Future<bool> refreshRss(AppBmfModel model);

  /// Mikan 镜像变更后改写全部订阅的 RSS 地址。
  Future<void> updateMikanUrl(String url, String ori);
}
