// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../models/database/app_bmf_model.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';
import '../drift/bt_database.dart';

/// Bangumi-Mikan-File Map
/// 用于存储特定条目对应的MikanRSS及下载目录
///
/// 只负责表存取：写入/删除后的 RSS 调度由 `BmfRepositoryImpl` 统一触发，
/// 保证每次成功写入恰好刷新一次。建表与补列由 `BtDatabase` 拥有。
class BtsAppBmf {
  BtsAppBmf._();

  /// 实例
  static final BtsAppBmf _instance = BtsAppBmf._();

  /// 获取实例
  factory BtsAppBmf() => _instance;

  /// 数据库
  BtDatabase get _db => BTSqlite().db;

  /// 读取全部配置，按条目 ID 降序
  Future<List<AppBmfModel>> readAll() async {
    var query = _db.select(_db.appBmf)
      ..orderBy([(table) => OrderingTerm.desc(table.subject)]);
    var rows = await query.get();
    return rows.map((row) => AppBmfModel.fromJson(row.toJson())).toList();
  }

  /// 读取配置
  Future<AppBmfModel?> read(int subject) async {
    var row = await _findBySubject(subject);
    if (row == null) return null;
    return AppBmfModel.fromJson(row.toJson());
  }

  /// 写入/更新配置
  ///
  /// `subject` 是唯一约束而不是主键（主键是自增 `id`），所以先按 subject
  /// 查一次再决定 INSERT / UPDATE，让既有行的 id 保持不变。
  Future<void> write(AppBmfModel model) async {
    if (model.rss != null && model.rss!.isNotEmpty) {
      var url = Uri.parse(model.rss!);
      model.mkBgmId = url.queryParameters['bangumiId'];
      model.mkGroupId = url.queryParameters['subgroupid'];
    }
    var existing = await _findBySubject(model.subject);
    if (existing == null) {
      await _db.into(_db.appBmf).insert(_companion(model));
    } else {
      var update = _db.update(_db.appBmf)
        ..where((table) => table.id.equals(existing.id));
      await update.write(_companion(model));
    }
    BTLogTool.info('Write AppBmf subject: ${model.subject}');
  }

  /// Updates only the subject air date while backfilling old records.
  Future<void> updateAirDate(int subject, String airDate) async {
    var update = _db.update(_db.appBmf)
      ..where((table) => table.subject.equals(subject));
    await update.write(AppBmfCompanion(airDate: Value(airDate)));
  }

  /// 删除配置
  Future<void> delete(int subject) async {
    var delete = _db.delete(_db.appBmf)
      ..where((table) => table.subject.equals(subject));
    await delete.go();
    BTLogTool.info('Delete AppBmf subject: $subject');
  }

  /// 检测RSS链接是否存在
  /// [excludeSubject] 排除的条目ID，用于修改时排除自身
  Future<bool> checkRss(String input, {int? excludeSubject}) async {
    var query = _db.select(_db.appBmf)
      ..where(
        (table) => excludeSubject == null
            ? table.rss.equals(input)
            : table.rss.equals(input) &
                  table.subject.equals(excludeSubject).not(),
      );
    var rows = await query.get();
    return rows.isNotEmpty;
  }

  /// 检测下载目录是否存在
  /// [excludeSubject] 排除的条目ID，用于修改时排除自身
  Future<bool> checkDir(String dir, {int? excludeSubject}) async {
    var query = _db.select(_db.appBmf)
      ..where(
        (table) => excludeSubject == null
            ? table.download.equals(dir)
            : table.download.equals(dir) &
                  table.subject.equals(excludeSubject).not(),
      );
    var rows = await query.get();
    return rows.isNotEmpty;
  }

  Future<BmfRow?> _findBySubject(int subject) {
    var query = _db.select(_db.appBmf)
      ..where((table) => table.subject.equals(subject));
    return query.getSingleOrNull();
  }

  AppBmfCompanion _companion(AppBmfModel model) {
    return AppBmfCompanion(
      subject: Value(model.subject),
      title: Value(model.title),
      airDate: Value(model.airDate),
      rss: Value(model.rss),
      download: Value(model.download),
      mkBgmId: Value(model.mkBgmId),
      mkGroupId: Value(model.mkGroupId),
      autoUpdate: Value(model.autoUpdate ? 1 : 0),
    );
  }
}
