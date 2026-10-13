// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import 'detail_discussion_comment.dart';
import 'subject_detail_module_status.dart';

/// 剧集评论页签。
///
/// 章节吐槽接口一次返回全部顶层吐槽及其回复，
/// 因此这里没有条目吐槽箱的筛选与分页，只保留刷新。
class EpisodeDetailComments extends ConsumerStatefulWidget {
  const EpisodeDetailComments({
    super.key,
    required this.episodeId,
    required this.total,
    required this.reloadToken,
  });

  final int episodeId;

  /// 章节详情给出的吐槽数，包含回复
  final int total;

  /// 父页面刷新计数，变化时重新拉取
  final int reloadToken;

  @override
  ConsumerState<EpisodeDetailComments> createState() =>
      _EpisodeDetailCommentsState();
}

class _EpisodeDetailCommentsState extends ConsumerState<EpisodeDetailComments> {
  List<BangumiEpisodeComment> _comments = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  int get _replyCount =>
      _comments.fold(0, (sum, comment) => sum + comment.replies.length);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(EpisodeDetailComments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeId != widget.episodeId ||
        oldWidget.reloadToken != widget.reloadToken) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    var generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    var response = await ref
        .read(bangumiRepositoryProvider)
        .getEpisodeComments(widget.episodeId);
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      if (response.code == 0 && response.data != null) {
        _comments = response.data!;
      } else {
        _error = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        if (_loading) const ProgressBar(strokeWidth: 2),
        if (_error != null && _comments.isNotEmpty)
          SubjectDetailModuleStatus(message: _error!, onRetry: _load),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  /// 总数与刷新集中在标题栏，列表只保留吐槽内容本身。
  Widget _buildToolbar(BuildContext context) {
    var label = _loading ? '正在加载吐槽' : '刷新吐槽';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Text('吐槽箱', style: BTTypography.bodyStrong(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loading ? '正在加载' : '共 ${widget.total} 条（含 $_replyCount 条回复）',
              style: BTTypography.caption(context),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: label,
            child: Semantics(
              label: label,
              child: IconButton(
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 14,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Icon(FluentIcons.refresh, size: 14),
                onPressed: _loading ? null : _load,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_comments.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: SubjectDetailModuleStatus(
          loading: _loading,
          message: _loading ? '正在加载吐槽' : (_error ?? '暂无吐槽'),
          onRetry: !_loading && _error != null ? _load : null,
        ),
      );
    }
    return ListView.separated(
      primary: false,
      key: PageStorageKey('episode-${widget.episodeId}-comments'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => DetailDiscussionComment(
        _comments[index],
        pageUrl: '${BtrBangumiApi.siteBaseUrl}/ep/${widget.episodeId}',
        floor: index + 1,
      ),
    );
  }
}
