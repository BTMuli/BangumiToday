// Dart imports:
import 'dart:async';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../core/services/bmf_rss_service.dart';
import '../../database/app/app_bmf.dart';
import '../../database/app/app_rss.dart';
import '../../domain/repositories/bmf_repository.dart';
import '../../models/database/app_bmf_model.dart';

/// 基于 SQLite 表访问器与 BMF RSS 会话服务的订阅仓储实现。
///
/// 这里是“写入后刷新 RSS”的唯一责任方：每次成功写入/删除都会通知
/// [BmfRssService] 恰好一次，[BtsAppBmf] 自身不再产生副作用。表访问器只负责
/// 存取，调度顺序为“先落库、再广播变更、最后拉取 RSS”，避免订阅已保存但列表
/// 因网络失败而不同步。
class BmfRepositoryImpl implements BmfRepository {
  BmfRepositoryImpl({BtsAppBmf? table, BtsAppRss? rssTable, BmfRssService? rss})
    : _table = table ?? BtsAppBmf(),
      _rssTable = rssTable ?? BtsAppRss(),
      _rss = rss ?? BmfRssService.instance;

  final BtsAppBmf _table;
  final BtsAppRss _rssTable;
  final BmfRssService _rss;

  final StreamController<BmfChange> _changes =
      StreamController<BmfChange>.broadcast();

  @override
  Stream<BmfChange> get changes => _changes.stream;

  @override
  Future<List<AppBmfModel>> readAll() => _table.readAll();

  @override
  Future<AppBmfModel?> read(int subject) => _table.read(subject);

  @override
  Future<bool> write(AppBmfModel model) => _persist(model, BmfChangeKind.added);

  @override
  Future<bool> updateModel(AppBmfModel model) =>
      _persist(model, BmfChangeKind.updated);

  @override
  Future<void> delete(int subject) async {
    var existing = await _table.read(subject);
    if (existing != null && existing.rss != null && existing.rss!.isNotEmpty) {
      await _rssTable.delete(existing.rss!);
    }
    await _table.delete(subject);
    _emit(BmfChangeKind.removed, subject);
    if (existing != null) {
      await _rss.onBmfDeleted(subject, existing.mkBgmId, existing.rss);
    }
  }

  @override
  Future<bool> checkRss(String rss, {int? excludeSubject}) {
    return _table.checkRss(rss, excludeSubject: excludeSubject);
  }

  @override
  Future<bool> checkDir(String dir, {int? excludeSubject}) {
    return _table.checkDir(dir, excludeSubject: excludeSubject);
  }

  @override
  Future<void> updateAirDate(int subject, String airDate) {
    return _table.updateAirDate(subject, airDate);
  }

  @override
  Future<bool> refreshRss(AppBmfModel model) {
    return _rss.refreshBmf(model);
  }

  @override
  Future<void> updateMikanUrl(String url, String ori) async {
    var target = BTAppConstants.normalizeMikanUrl(url);
    var origin = BTAppConstants.normalizeMikanUrl(ori);
    var allBmf = await _table.readAll();
    for (var item in allBmf) {
      if (item.rss == null || item.rss!.isEmpty) continue;
      var newRss = BTAppConstants.rewriteMikanUrl(item.rss!, target);
      if (newRss == item.rss && item.rss!.startsWith(origin)) {
        newRss = item.rss!.replaceFirst(origin, target);
      }
      if (newRss == item.rss) continue;
      await _persist(item.copyWith(rss: newRss), BmfChangeKind.updated);
    }
  }

  /// 落库后广播变更，再触发一次 RSS 拉取。
  ///
  /// 返回本次写入是否已经发起拉取，供调用方避免重复刷新。
  Future<bool> _persist(AppBmfModel model, BmfChangeKind kind) async {
    await _table.write(model);
    _emit(kind, model.subject, model: model);
    if (!_rss.willRefreshOnWrite(model)) return false;
    await _rss.onBmfWritten(model);
    return true;
  }

  void _emit(BmfChangeKind kind, int subject, {AppBmfModel? model}) {
    if (_changes.isClosed) return;
    _changes.add(BmfChange(kind: kind, subject: subject, model: model));
  }

  /// 释放变更流，由组装它的 provider 在容器销毁时调用。
  void dispose() {
    unawaited(_changes.close());
  }
}
