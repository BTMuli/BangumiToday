// Project imports:
import '../../domain/repositories/bangumi_repository.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../tools/log_tool.dart';

/// 保留请求的 Future 与结果，剧集及进度在页签消费时才发起请求。
class SubjectDetailPrefetch {
  SubjectDetailPrefetch({
    required BTBangumiRepository repository,
    required int subject,
    required String? username,
    required bool collected,
    required this.isCurrent,
    required this.progressAccount,
    required this.progressVersion,
  }) : _repository = repository,
       _subject = subject,
       _username = username,
       _collected = collected,
       collection = username == null
           ? null
           : _retain(repository.getCollectionSubject(username, subject));

  final BTBangumiRepository _repository;
  final int _subject;
  final String? _username;
  final bool _collected;

  late final Future<BTResponse<BangumiPageT<BangumiEpisode>>> episodes =
      _retain(_repository.getEpisodeList(_subject, offset: 0, limit: 100));
  final Future<BTResponse<BangumiUserSubjectCollection>>? collection;
  late final Future<BTResponse<BangumiPageT<BangumiUserEpisodeCollection>>>?
  progress = _username == null || !_collected
      ? null
      : _retain(
          _repository.getCollectionEpisodes(_subject, offset: 0, limit: 100),
        );

  /// 页面重载、切换条目或授权变化后，旧预取结果不再供组件使用。
  final bool Function() isCurrent;
  final String? progressAccount;
  final int progressVersion;

  static Future<BTResponse<T>> _retain<T>(Future<BTResponse<T>> request) async {
    try {
      return await request;
    } catch (error) {
      // 页面可能在请求结束前关闭，仍需处理异常，避免无人消费的 Future 报错。
      BTLogTool.warn('首屏数据预取失败：$error');
      return BTResponse<T>(code: 666, message: '获取首屏数据失败', data: null);
    }
  }
}
