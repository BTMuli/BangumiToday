// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_subject_browse.dart';
import '../../providers/app_providers.dart';

typedef BangumiRankingQuery = ({
  BangumiSubjectBrowseSort sort,
  int page,
  int? year,
  int? month,
});

/// 短期复用已浏览页；切换账号或 API 设置后重新获取。
final bangumiRankingProvider = FutureProvider.autoDispose
    .family<BTResponse<BangumiSubjectBrowsePage>, BangumiRankingQuery>((
      ref,
      query,
    ) async {
      ref.watch(
        appStoreProvider.select(
          (settings) => (settings.bangumiUrl, settings.bangumiUsePrivateApi),
        ),
      );
      ref.watch(
        bgmUserStoreProvider.select(
          (account) => (account.user?.id, account.sessionGeneration),
        ),
      );
      var response = await ref
          .watch(bangumiRepositoryProvider)
          .getSubjectBrowse(
            sort: query.sort,
            page: query.page,
            year: query.year,
            month: query.month,
          );
      if (ref.mounted && response.code == 0) {
        var cache = ref.keepAlive();
        var timer = Timer(const Duration(minutes: 5), cache.close);
        ref.onDispose(timer.cancel);
      }
      return response;
    });
