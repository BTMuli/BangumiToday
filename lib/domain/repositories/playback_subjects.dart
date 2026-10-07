/// 本地视频与 Bangumi 条目的归属解析接口。
///
/// 播放入口只依赖该契约，不再直接查询 BMF 表。
abstract class PlaybackSubjectResolver {
  /// 视频显式关联或所属订阅的 Bangumi 条目 ID，未匹配时为 null。
  Future<int?> subjectForFile(String filePath);

  /// 使用所属条目的下载根目录；文件不在该目录时使用文件的父目录。
  Future<String> directoryForFile(String filePath, {int? subject});
}
