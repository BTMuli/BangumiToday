// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../core/utils/latest_request.dart';
import '../domain/rss/animegarden_query.dart';
import '../models/app/response.dart';
import '../models/rss/animegarden_resource.dart';
import '../request/rss/animegarden_api.dart';

/// Browsing state only: no subscription storage or unread mutations.
class AnimeGardenController extends ChangeNotifier {
  AnimeGardenController({AnimeGardenAPI? api}) : _api = api ?? AnimeGardenAPI();

  final AnimeGardenAPI _api;
  final _requests = LatestRequest<BTResponse>();
  AnimeGardenQuery query = const AnimeGardenQuery();
  List<AnimeGardenResource> resources = [];
  bool loading = false;
  bool loaded = false;
  bool complete = true;
  int page = 0;
  int? pendingPage;
  int? failedPage;
  String? error;
  DateTime? lastUpdated;
  int _generation = 0;
  bool _disposed = false;

  Future<void> search(AnimeGardenQuery value) async {
    var changed = value.atPage(1).resourceUri != query.atPage(1).resourceUri;
    query = value.atPage(1);
    if (changed) {
      resources = [];
      loaded = false;
      lastUpdated = null;
      page = 0;
      complete = true;
    }
    await _load(query);
  }

  bool get canGoPrevious => !loading && page > 1;
  bool get canGoNext => !loading && page > 0 && !complete;

  Future<void> previousPage() async {
    if (!canGoPrevious) return;
    await _load(query.atPage(page - 1));
  }

  Future<void> nextPage() async {
    if (!canGoNext) return;
    await _load(query.atPage(page + 1));
  }

  Future<void> refresh() => _load(query.atPage(page > 0 ? page : 1));

  Future<void> retry() =>
      _load(query.atPage(failedPage ?? (page > 0 ? page : 1)));

  Future<void> _load(AnimeGardenQuery value) async {
    var generation = ++_generation;
    pendingPage = value.page;
    failedPage = null;
    loading = true;
    error = null;
    notifyListeners();
    var response = await _requests.run(
      value.resourceUri.toString(),
      (token) => _api.resources(value, cancelToken: token),
    );
    if (_disposed || generation != _generation) return;
    loading = false;
    pendingPage = null;
    loaded = true;
    if (response.code == 0 && response.data is AnimeGardenPage) {
      var result = response.data as AnimeGardenPage;
      // Keep only the displayed page. Loading another page never accumulates
      // earlier resources or their display projections.
      resources = result.resources;
      page = result.pagination.page;
      complete = result.pagination.complete;
      lastUpdated = DateTime.now();
    } else if (response.code != 499) {
      error = response.message;
      failedPage = value.page;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _requests.cancel();
    _api.client.dispose();
    super.dispose();
  }
}
