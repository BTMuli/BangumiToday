/// 视频文件尚不可播放。
///
/// 资源校验失败与路径越界都用该异常表达，调用方按消息展示给用户。放在
/// core/errors 供路径工具与资源接口共用，避免实现层反向依赖 domain。
class PlaybackUnavailable implements Exception {
  const PlaybackUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
