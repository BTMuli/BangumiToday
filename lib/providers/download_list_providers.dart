// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 按条目记录折叠状态，仅在本次运行期间保留。
///
/// 不自动释放，避免滚动回收、搜索过滤和页面切换重置用户的选择。
final downloadCollapsedSubjectsProvider =
    NotifierProvider<DownloadCollapsedSubjects, Set<int>>(
      DownloadCollapsedSubjects.new,
    );

class DownloadCollapsedSubjects extends Notifier<Set<int>> {
  @override
  Set<int> build() => const <int>{};

  void toggle(int subjectId) {
    var collapsed = {...state};
    if (!collapsed.remove(subjectId)) collapsed.add(subjectId);
    state = Set.unmodifiable(collapsed);
  }
}
