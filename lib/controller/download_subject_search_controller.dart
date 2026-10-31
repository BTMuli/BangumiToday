// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../core/utils/download_subject.dart';
import '../domain/repositories/bangumi_repository.dart';
import '../models/app/response.dart';
import '../models/bangumi/bangumi_model.dart';
import '../models/bangumi/request_subject.dart';
import '../models/database/app_bmf_model.dart';

typedef DownloadSubjectCandidate = ({
  int id,
  AppBmfModel? directoryMatch,
  BangumiSubjectSearchData? searchResult,
});

/// Directory matches remain available even without a successful remote search.
List<DownloadSubjectCandidate> prioritizeDownloadSubjectCandidates({
  required String savePath,
  required List<AppBmfModel> bmfs,
  required List<BangumiSubjectSearchData> results,
}) {
  var matchedIds = findDownloadDirectorySubjects(
    savePath: savePath,
    directories: bmfs.map(
      (bmf) => (subject: bmf.subject, directory: bmf.download),
    ),
  );
  var matches = {
    for (var bmf in bmfs)
      if (matchedIds.contains(bmf.subject)) bmf.subject: bmf,
  };
  var searched = {for (var result in results) result.id: result};
  return [
    for (var bmf in matches.values)
      (
        id: bmf.subject,
        directoryMatch: bmf,
        searchResult: searched[bmf.subject],
      ),
    for (var result in results)
      if (!matches.containsKey(result.id))
        (id: result.id, directoryMatch: null, searchResult: result),
  ];
}

class DownloadSubjectSearchController extends ChangeNotifier {
  DownloadSubjectSearchController(this._repository);

  final BTBangumiRepository _repository;
  String query = '';
  List<BangumiSubjectSearchData> results = [];
  bool loading = false;
  bool searched = false;
  bool hasMore = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;

  void changeQuery(String value) {
    _generation++;
    query = value.trim();
    results = [];
    loading = false;
    searched = false;
    hasMore = false;
    error = null;
    notifyListeners();
  }

  Future<void> search({bool more = false}) async {
    if (_disposed || loading || query.isEmpty || (more && !hasMore)) return;
    var generation = ++_generation;
    var offset = more ? results.length : 0;
    loading = true;
    error = null;
    notifyListeners();
    try {
      BTResponse<BangumiPageT<BangumiSubjectSearchData>> response =
          await _repository.searchSubjects(query, offset: offset, limit: 20);
      if (_disposed || generation != _generation) return;
      var page = response.data;
      if (response.code != 0 || page == null) {
        throw const FormatException('搜索失败');
      }
      results = [
        ...(more ? results : <BangumiSubjectSearchData>[]),
        ...page.data,
      ];
      hasMore = page.data.isNotEmpty && results.length < page.total;
      searched = true;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error = '搜索失败，请检查网络后重试。';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
