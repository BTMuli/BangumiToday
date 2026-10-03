/// 条目封面与名称解析接口。
///
/// 主窗口负责解析与缓存，独立播放窗口通过通信适配器实现同一契约；播放会话
/// 不直接持有 Bangumi 仓储。
abstract class PlaybackCoverResolver {
  /// Whether [subject] has already been resolved (with data or a miss).
  bool contains(int subject);

  /// The cached cover URL for [subject], or `null` when it is not yet
  /// resolved or the subject has no usable cover.
  String? coverOf(int subject);

  /// The cached display name for [subject], or `null` when unknown.
  String? nameOf(int subject);

  /// Resolves and caches the subject detail for [subject].
  Future<String?> resolve(int subject);
}
