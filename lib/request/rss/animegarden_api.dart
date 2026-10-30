// Dart imports:
import 'dart:io';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../core/services/rss_fetch_scheduler.dart';
import '../../core/utils/keyed_request_pool.dart';
import '../../domain/rss/animegarden_query.dart';
import '../../models/app/response.dart';
import '../../models/rss/animegarden_detail.dart';
import '../../models/rss/animegarden_resource.dart';
import '../../models/rss/rss_request_failure.dart';
import '../core/client.dart';

class AnimeGardenAPI {
  AnimeGardenAPI({BtrClient? client}) : client = client ?? BtrClient() {
    _scheduler = RssFetchScheduler(request: _request);
  }

  final BtrClient client;
  late final RssFetchScheduler _scheduler;

  Future<BTResponse> resources(
    AnimeGardenQuery query, {
    required CancelToken cancelToken,
  }) => _fetch(query.resourceUri.toString(), cancelToken);

  Future<BTResponse> detail(
    String provider,
    String providerId, {
    required CancelToken cancelToken,
  }) => _fetch(
    Uri.parse(
      AnimeGardenQuery.apiOrigin,
    ).replace(pathSegments: ['detail', provider, providerId]).toString(),
    cancelToken,
  );

  Future<BTResponse> _fetch(String url, CancelToken cancelToken) async {
    try {
      // LatestRequest shares identical searches within a consumer. Separate
      // cancellation scopes must not reuse an already cancelled flight.
      return await _scheduler.fetch(
        '$url:${identityHashCode(cancelToken)}',
        url,
        cancelToken,
      );
    } on RequestPoolCancelled {
      return BTResponse.error(code: 499, message: '请求已取消', data: null);
    }
  }

  Future<BTResponse> _request(
    String url,
    CancelToken token,
    Duration timeout,
  ) async {
    try {
      var response = await client.dio.get<Map<String, dynamic>>(
        url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.json,
          connectTimeout: timeout,
          receiveTimeout: timeout,
          extra: {'requestTimeout': timeout},
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );
      var body = response.data!;
      return BTResponse.success(
        data: Uri.parse(url).pathSegments.first == 'detail'
            ? AnimeGardenDetailResponse.fromJson(body)
            : AnimeGardenPage.fromJson(body),
      );
    } on DioException catch (error) {
      var status = error.response?.statusCode;
      if (CancelToken.isCancel(error)) {
        return BTResponse.error(code: 499, message: '请求已取消', data: null);
      }
      return BTResponse.error(
        code: status ?? 666,
        message:
            'Anime Garden 请求失败'
            '${status == null ? '' : '（HTTP $status）'}，请重试',
        data: RssRequestFailure(
          retryable: switch (error.type) {
            DioExceptionType.connectionTimeout ||
            DioExceptionType.sendTimeout ||
            DioExceptionType.receiveTimeout ||
            DioExceptionType.connectionError => true,
            DioExceptionType.badResponse =>
              status == 429 || status == 503 || status == 504,
            _ => false,
          },
          retryAfter: retryAfter(error.response?.headers.value('retry-after')),
        ),
      );
    } catch (_) {
      return BTResponse.error(
        code: 666,
        message: '无法读取 Anime Garden 响应，请稍后重试',
        data: null,
      );
    }
  }

  static Duration? retryAfter(String? value, {DateTime? now}) {
    if (value == null) return null;
    var seconds = int.tryParse(value.trim());
    if (seconds != null) {
      return seconds >= 0 ? Duration(seconds: seconds) : null;
    }
    try {
      var delay = HttpDate.parse(value).difference(now ?? DateTime.now());
      return delay.isNegative ? Duration.zero : delay;
    } on HttpException {
      return null;
    }
  }
}
