// Dart imports:
import 'dart:async';

// Project imports:
import '../../core/cache/cache_manager.dart';
import '../../core/utils/async_pool.dart';
import '../../domain/repositories/bangumi_repository.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';

/// 一次条目详情请求的结果：`rateLimited` 表示被接口限流，本轮收工。
typedef _SubjectFetch = ({BangumiSubject? subject, bool rateLimited});

/// 首页日历的 bgm 条目补全
///
/// bangumi-data 只有排期，没有封面、评分、收藏数；bgm 的 `/calendar` 只覆盖
/// 当季新番（实测 128 个在播条目里只命中 9 个），所以这里按 subject id 逐个
/// 取条目详情来补展示字段。结果写进持久缓存，之后直接读缓存。
class BcpEnricher {
  BcpEnricher._();

  /// 实例
  static final BcpEnricher _instance = BcpEnricher._();

  /// 获取实例
  factory BcpEnricher() => _instance;

  /// 同时进行的条目详情请求数
  static const int maxConcurrent = 3;

  /// 两次请求之间的最小间隔：条目详情是逐条拉的，错峰一下别把接口打太密
  static const Duration requestGap = Duration(milliseconds: 300);

  /// 单条失败后的冷却时间，冷却期内不再重试，避免反复撞限流
  static const Duration failureCooldown = Duration(minutes: 10);

  /// 缓存有效期：封面与评分几乎不变，缓存长一点，别每次启动都重新拉
  static const Duration maxAge = CacheDuration.extended;

  /// 每补齐多少条回调一次，避免每个条目都重建一次日历
  static const int flushSize = 6;

  /// 正在请求中的条目详情，按 subject id 合并。
  ///
  /// 首页刷新、滚动补全与过滤重算可能同时要同一个 bgmId（例如刚换完数据就
  /// 滚到新分组），没有合并就会对同一条目重复请求。
  final Map<int, Future<_SubjectFetch>> _pending = {};

  /// 读取仍然有效的缓存，返回 subject id -> bgm 条目。
  Future<Map<int, BangumiLegacySubjectSmall>> readCache(
    Iterable<int> ids,
  ) async {
    var map = <int, BangumiLegacySubjectSmall>{};
    for (var id in ids) {
      var subject = await readSubject(id);
      if (subject == null) continue;
      map[id] = toLegacySubject(subject);
    }
    return map;
  }

  /// 读取单条缓存，过期或不存在时返回 null。
  Future<BangumiSubject?> readSubject(int id) {
    return BTCacheManager.instance.getJson<BangumiSubject>(
      CacheKeys.subject(id),
      fromJson: BangumiSubject.fromJson,
      maxAge: maxAge,
    );
  }

  /// 拉取 [ids]（缓存里缺失的 subject，顺序即优先级），边拉边按批回调。
  ///
  /// 单条失败会进冷却期，冷却期内不再重试；一旦被限流（429）就本轮收工，
  /// 免得越撞越限。同一个 id 的请求会被多个调用方复用，见 [_fetchSubject]。
  /// [isActive] 返回 false 时本轮不再收集结果（在途请求照常完成并写缓存）。
  Future<void> fetchMissing({
    required Iterable<int> ids,
    required BTBangumiRepository repository,
    required void Function(Map<int, BangumiLegacySubjectSmall> filled) onFilled,
    bool Function()? isActive,
  }) async {
    var batch = <int, BangumiLegacySubjectSmall>{};
    var cache = BTCacheManager.instance;
    var stopped = false;
    await forEachConcurrent(
      ids,
      maxConcurrent: maxConcurrent,
      action: (id) async {
        if (stopped) return;
        if (isActive != null && !isActive()) return;
        if (await _inCooldown(cache, id)) return;
        var result = await _fetchSubject(id, repository);
        if (result.rateLimited) {
          // 被限流：本轮不再继续，等冷却后再补
          stopped = true;
          return;
        }
        var subject = result.subject;
        if (subject == null) return;
        if (isActive != null && !isActive()) return;
        batch[id] = toLegacySubject(subject);
        if (batch.length >= flushSize) {
          onFilled(Map.of(batch));
          batch.clear();
        }
      },
    );
    if (batch.isNotEmpty) onFilled(Map.of(batch));
  }

  /// 取单个条目详情：同一个 id 的并发调用复用同一次请求。
  Future<_SubjectFetch> _fetchSubject(int id, BTBangumiRepository repository) {
    var pending = _pending[id];
    if (pending != null) return pending;
    var future = _requestSubject(id, repository);
    _pending[id] = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_pending[id], future)) _pending.remove(id);
      }),
    );
    return future;
  }

  /// 实际发起一次条目详情请求，成功时写入持久缓存。
  Future<_SubjectFetch> _requestSubject(
    int id,
    BTBangumiRepository repository,
  ) async {
    var cache = BTCacheManager.instance;
    try {
      await Future<void>.delayed(requestGap);
      var response = await repository.getSubjectDetail('$id');
      if (response.code == 429) {
        await _markFailed(cache, id);
        return (subject: null, rateLimited: true);
      }
      var subject = response.data;
      if (response.code != 0 || subject == null) {
        await _markFailed(cache, id);
        return (subject: null, rateLimited: false);
      }
      await cache.setJson<BangumiSubject>(
        CacheKeys.subject(id),
        subject,
        toJson: (value) => value.toJson(),
        fromJson: BangumiSubject.fromJson,
      );
      return (subject: subject, rateLimited: false);
    } catch (_) {
      await _markFailed(cache, id);
      return (subject: null, rateLimited: false);
    }
  }

  /// 该条目是否处于失败冷却期。
  Future<bool> _inCooldown(BTCacheManager cache, int id) async {
    var miss = await cache.getJson<Map<String, dynamic>>(
      CacheKeys.subjectMiss(id),
      fromJson: (json) => json,
      maxAge: failureCooldown,
    );
    return miss != null;
  }

  /// 记录一次失败。
  Future<void> _markFailed(BTCacheManager cache, int id) async {
    await cache.setJson<Map<String, dynamic>>(
      CacheKeys.subjectMiss(id),
      {'at': DateTime.now().toIso8601String()},
      toJson: (value) => value,
      fromJson: (json) => json,
    );
  }

  /// 确认哪些条目其实已经放完。
  ///
  /// [pending] 为可疑项（id -> 放送周期），来自 `BcpCalendarData.pendingFinished`。
  /// 判据是 bgm 登记的最新一话放送日期已经过去一个周期：还在放送的条目上一话
  /// 不会隔这么久，而长期停播又是推算不出来的情况，所以拿不到日期时保守保留。
  Future<Set<int>> confirmFinished({
    required Map<int, Duration> pending,
    required BTBangumiRepository repository,
    bool Function()? isActive,
  }) async {
    var finished = <int>{};
    await forEachConcurrent(
      pending.entries.toList(),
      maxConcurrent: maxConcurrent,
      action: (entry) async {
        if (isActive != null && !isActive()) return;
        var lastAir = await readLastAirDate(entry.key, repository);
        if (lastAir == null) return;
        if (isActive != null && !isActive()) return;
        if (lastAir.add(entry.value).isBefore(DateTime.now())) {
          finished.add(entry.key);
        }
      },
    );
    return finished;
  }

  /// bgm 登记的最新一话放送日期，按 [CacheDuration.long] 缓存。
  Future<DateTime?> readLastAirDate(
    int id,
    BTBangumiRepository repository,
  ) async {
    var cache = BTCacheManager.instance;
    if (await _inCooldown(cache, id)) return null;
    var key = CacheKeys.airing(id);
    var cached = await cache.getJson<Map<String, dynamic>>(
      key,
      fromJson: (json) => json,
      maxAge: CacheDuration.long,
    );
    if (cached != null) return DateTime.tryParse('${cached['lastAir']}');

    var subject = await readSubject(id);
    if (subject == null) {
      // 详情缓存缺失时顺手取一次：既拿到总话数，也补上面板要的字段
      await Future<void>.delayed(requestGap);
      var detail = await repository.getSubjectDetail('$id');
      if (detail.code == 429) {
        await _markFailed(cache, id);
        return null;
      }
      subject = detail.data;
      if (subject != null) {
        await cache.setJson<BangumiSubject>(
          CacheKeys.subject(id),
          subject,
          toJson: (value) => value.toJson(),
          fromJson: BangumiSubject.fromJson,
        );
      }
    }
    var total = subject?.totalEpisodes ?? 0;
    if (total <= 0) return null;
    // 只取登记的最后几话，长篇不用整份章节表
    await Future<void>.delayed(requestGap);
    var response = await repository.getEpisodeList(
      id,
      type: BangumiLegacyEpisodeType.main,
      limit: 5,
      offset: total > 5 ? total - 5 : 0,
    );
    if (response.code == 429) {
      await _markFailed(cache, id);
      return null;
    }
    var episodes = response.data?.data ?? const <BangumiEpisode>[];
    DateTime? last;
    for (var episode in episodes) {
      var air = DateTime.tryParse(episode.airDate);
      if (air == null) continue;
      if (last == null || air.isAfter(last)) last = air;
    }
    await cache.setJson<Map<String, dynamic>>(
      key,
      {'lastAir': last?.toIso8601String() ?? ''},
      toJson: (value) => value,
      fromJson: (json) => json,
    );
    return last;
  }

  /// 把 bgm 条目详情转成卡片使用的结构。
  ///
  /// 标题、放送星期、放送时刻都由 bangumi-data 决定，这里只提供它没有的
  /// 展示字段；`airWeekday` 因此留空由日历组装覆盖。
  BangumiLegacySubjectSmall toLegacySubject(BangumiSubject subject) {
    var images = subject.images;
    return BangumiLegacySubjectSmall(
      id: subject.id,
      url: 'https://bangumi.tv/subject/${subject.id}',
      type: BangumiLegacySubjectType.anime,
      name: subject.name,
      nameCn: subject.nameCn,
      summary: subject.summary,
      airDate: subject.date ?? '',
      airWeekday: 0,
      images: BangumiPersonImages(
        large: images.large,
        medium: images.medium,
        small: images.small,
        grid: images.grid,
      ),
      eps: subject.eps,
      epsCount: subject.totalEpisodes,
      rating: subject.rating,
      rank: subject.rating.rank,
      collection: subject.collection,
    );
  }
}
