// Project imports:
import '../../core/utils/bangumi_utils.dart';
import '../../models/bangumi/bangumi_data_model.dart';

/// 排期与所属 Bangumi 条目的本地已知总话数。
typedef RssPollSchedule = ({BangumiDataItem item, int? totalEpisodes});

/// 按本地放送排期调整 RSS 刷新窗口。
///
/// 放送前沿用 [baseWindow]；放送后等待新 RSS 时改用 feed 的 TTL，
/// 直到缓存中出现放送时间之后发布的条目，或超过 [afterBroadcast]
/// 仍未出现。AniBT 的 TTL 可能低于公开 RSS 建议的轮询下限，因此用
/// [fastFloor] 兜底。
class RssPollPolicy {
  const RssPollPolicy({
    this.baseWindow = const Duration(minutes: 15),
    this.fastFloor = const Duration(minutes: 5),
    this.afterBroadcast = const Duration(hours: 6),
  });

  final Duration baseWindow;
  final Duration fastFloor;
  final Duration afterBroadcast;

  /// 当前正在等待新 RSS 的放送时刻；放送前或超过等待上限时返回 null。
  DateTime? waitingAirTime({
    required DateTime now,
    required Iterable<RssPollSchedule> schedules,
  }) {
    DateTime? result;
    for (var schedule in schedules) {
      var item = schedule.item;
      var recent = bangumiAirSlot(
        begin: item.begin,
        broadcast: item.broadcast,
        end: item.end,
        at: now,
        upcoming: false,
        totalEpisodes: schedule.totalEpisodes,
      );
      if (recent == null || now.difference(recent.time) > afterBroadcast) {
        continue;
      }
      if (result == null || recent.time.isAfter(result)) {
        result = recent.time;
      }
    }
    return result;
  }

  /// 放送后按 TTL 加速；新条目已经出现则恢复默认窗口。
  Duration windowFor({
    required DateTime? airTime,
    required int ttlMinutes,
    DateTime? latestPublishedAt,
  }) {
    if (airTime == null) return baseWindow;
    if (latestPublishedAt != null && !latestPublishedAt.isBefore(airTime)) {
      return baseWindow;
    }
    var ttl = Duration(minutes: ttlMinutes);
    if (ttl < fastFloor) ttl = fastFloor;
    if (ttl > baseWindow) ttl = baseWindow;
    return ttl;
  }
}
