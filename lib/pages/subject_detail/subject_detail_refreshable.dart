/// 条目详情页里可由刷新按钮重新拉取数据的子模块。
///
/// 详情页按 GlobalKey 遍历收藏 / 章节 / 关联三个模块，
/// 对实现了本 mixin 的 State 调用 [refresh]，
/// 让子模块的接口随页面一起重新请求，而不是只在挂载时拉一次。
mixin SdpRefreshable {
  /// 重新拉取本模块数据。
  Future<void> refresh();
}
