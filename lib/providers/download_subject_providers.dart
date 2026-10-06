// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../core/cache/subject_cache.dart';
import '../core/utils/download_subject.dart';
import '../database/app/download_subjects.dart';
import '../models/bangumi/bangumi_model.dart';
import '../store/bmf_store.dart';
import 'bangumi_providers.dart';

typedef DownloadSubjectKey = ({String taskId, String savePath, bool manual});

final _downloadSubjectLinkProvider = StreamProvider.autoDispose
    .family<int?, String>((ref, taskId) {
      return downloadSubjectsStorage.watch(taskId);
    });

/// 参数只包含关联所需字段，进度、速率刷新不会重新加载条目。
final downloadTaskSubjectProvider = Provider.autoDispose
    .family<int?, DownloadSubjectKey>((ref, key) {
      if (key.manual) return null;
      var linkedSubject = ref.watch(_downloadSubjectLinkProvider(key.taskId));
      // 等持久化关联读取完成，避免先用目录关联加载另一个条目的封面。
      if (linkedSubject.isLoading) return null;
      var id = linkedSubject.value;
      if (id != null && id > 0) return id;
      var bmfs = ref.watch(bmfListProvider).value ?? const [];
      return findDownloadSubject(
        manual: key.manual,
        savePath: key.savePath,
        directories: bmfs.map(
          (bmf) => (subject: bmf.subject, directory: bmf.download),
        ),
      );
    });

/// 同一条目的所有任务共享展示数据，封面可复用过期的本地详情。
final downloadSubjectDetailsProvider =
    FutureProvider.family<BangumiSubject?, int>((ref, id) async {
      var repository = ref.watch(bangumiRepositoryProvider);
      var cached = await BgmSubjectCache().read(id, allowStale: true);
      if (cached != null) return cached;
      var response = await repository.getSubjectDetail(id.toString());
      return response.code == 0 ? response.data : null;
    });
