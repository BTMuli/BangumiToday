// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/progress_controller.dart';
import '../../core/errors/error_handler.dart';
import '../../core/theme/bt_theme.dart';
import '../../database/app/app_bmf.dart';
import '../../database/app/app_config.dart';
import '../../database/bangumi/bangumi_data.dart';
import '../../domain/repositories/bangumi_repository.dart';
import '../../models/bangumi/bangumi_data_model.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_data.dart';
import '../../store/bgm_user_hive.dart';
import '../../tools/log_tool.dart';
import '../../tools/notifier_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/bangumi_utils.dart';
import '../subject-search/subject_search_page.dart';
import 'bc_pw_day.dart';
import 'bcp_calendar_data.dart';
import 'bcp_enrich.dart';

/// 今日放送
class BangumiCalendarPage extends ConsumerStatefulWidget {
  /// 构造函数
  const BangumiCalendarPage({super.key});

  @override
  ConsumerState<BangumiCalendarPage> createState() =>
      _BangumiCalendarPageState();
}

/// 今日放送状态
class _BangumiCalendarPageState extends ConsumerState<BangumiCalendarPage>
    with AutomaticKeepAliveClientMixin {
  /// bangumiDataAPI
  final BtrBangumiDataApi apiBgd = BtrBangumiDataApi();

  /// 正在请求数据
  bool isRequesting = false;

  /// 请求数据，索引 0=周一 ... 6=周日，按日本放送日归属
  List<List<BcpCalendarItem>> calendarData = List.generate(7, (_) => []);

  /// 是否只显示收藏
  bool isShowCollection = false;

  /// 数据库-AppConfig
  final BtsAppConfig sqliteAc = BtsAppConfig();

  /// bangumiData数据库
  final BtsBangumiData sqliteBd = BtsBangumiData();

  /// BMF 数据库
  final BtsAppBmf sqliteBmf = BtsAppBmf();

  /// 用户hive
  final BgmUserHive hive = BgmUserHive();

  /// bangumiData版本号
  late String version = 'unknown';

  /// progress
  late ProgressController progress = ProgressController();

  /// 顶部吸附栏当前选中的分组，0 为今天
  final ValueNotifier<int> _activeSlot = ValueNotifier<int>(0);

  /// 日历滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 滚动视口，用于测量分组位置
  final GlobalKey _viewportKey = GlobalKey();

  /// 各分组的位置键，下标即展示顺序
  late final List<GlobalKey> _dayKeys = List.generate(7, (_) => GlobalKey());

  /// 已测得的星期分组高度，用于估算未挂载分组的位置
  final Map<int, double> _weekdayHeights = {};

  /// 正在按点击定位，期间暂停滚动联动
  bool _isScrollingToSlot = false;

  /// 定位请求代号，连续点击时只让最后一次生效
  int _scrollGeneration = 0;

  /// 补全请求代号，只有最后一次刷新的结果会写回页面
  int _enrichGeneration = 0;

  /// 当前展示范围里的本地收藏 subject id，为空表示不过滤
  Set<int>? _collectedIds;

  /// 本地收藏里标记为看过的 subject id
  Set<int> _watchedIds = {};

  /// BMF 订阅列表里的 subject id
  Set<int> _bmfIds = {};

  /// 已确认放完的 subject id，不排进日历
  Set<int> _finishedIds = {};

  /// 本地在播条目（组装日历的输入）
  List<BangumiDataItem> _items = [];

  /// bangumi-data 站点元数据
  Map<String, BangumiDataSite> _siteMeta = {};

  /// 已拿到的 bgm 条目（封面/评分/话数/总话数）
  Map<int, BangumiLegacySubjectSmall> _enrich = {};

  /// 已经触发过补全的展示分组，避免重复请求
  final Set<int> _enrichedSlots = {};

  /// 滚动触发的补全防抖，翻页时不要一路狂发请求
  Timer? _enrichDebounce;

  /// 判定分组已滚到顶部的容差
  static const double _slotTolerance = 8;

  /// 星期列表
  List<String> weekday = ['一', '二', '三', '四', '五', '六', '日'];

  /// 今天；星期归属与日历一致，按日本放送日（JST）计算。
  int get today => bangumiJstWeekday(DateTime.now()) - 1;

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    if (hive.user != null) {
      isShowCollection = true;
      setState(() {});
    }
    _scrollController.addListener(syncActiveSlot);
    Future.microtask(() async {
      await getData(freshTab: true);
      version = await sqliteAc.readBangumiDataVersion() ?? 'unknown';
      await checkDataUpdate();
    });
  }

  /// 清理
  @override
  void dispose() {
    _enrichDebounce?.cancel();
    _scrollController.removeListener(syncActiveSlot);
    _scrollController.dispose();
    _activeSlot.dispose();
    super.dispose();
  }

  /// 展示顺序从今天开始向后排 7 天，[slot] 为展示下标。
  int weekdayIndexAt(int slot) => (today + slot) % 7;

  /// [slot] 对应的日期。
  DateTime dateAt(int slot) {
    var jst = bangumiJstNow();
    return DateTime(jst.year, jst.month, jst.day + slot);
  }

  /// 获取数据
  ///
  /// 条目集合、星期归属、放送时刻与话数都来自本地 bangumi-data；bgm 只按
  /// subject id 补封面、评分、收藏数。因此先用本地数据出图，再读缓存补一次，
  /// 剩下的条目在后台逐个补，边补边刷新，不让网络拖住首屏。本地
  /// bangumi-data 为空（首次安装或尚未同步）时才回退到 bgm 日历。
  Future<void> getData({bool freshTab = false}) async {
    if (isRequesting) return;
    isRequesting = true;
    calendarData = List.generate(7, (_) => []);
    if (freshTab) {
      _activeSlot.value = 0;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
    setState(() {});
    try {
      var repository = ref.read(bangumiRepositoryProvider);
      _collectedIds = isShowCollection
          ? await repository.getCollectedSubjectIds()
          : null;
      _watchedIds = await loadWatchedIds(repository);
      _bmfIds = await loadBmfIds();
      if (!mounted) return;
      var items = await sqliteBd.readItemsOnAir();
      if (items.isEmpty) {
        await loadRemoteFallback(repository);
        return;
      }
      // 新一轮数据：清掉上一轮的补全状态
      _items = items;
      _siteMeta = await sqliteBd.readSiteMap();
      _enrich = {};
      _enrichedSlots.clear();
      _finishedIds = {};
      _enrichGeneration++;

      // 1. 本地 bangumi-data 直接出图。
      await applyDays(buildDays());
      // 2. 只补今天与明天（后台进行，不挡住提示），其余等用户滚过去再说。
      unawaited(ensureEnriched({_activeSlot.value, _activeSlot.value + 1}));
      if (!mounted) return;
      await BtInfobar.success(context, '成功刷新放送数据');
    } catch (error) {
      if (mounted) {
        await BtInfobar.error(context, '刷新放送数据失败：$error');
      }
    } finally {
      isRequesting = false;
      if (mounted) setState(() {});
    }
  }

  /// 按当前数据组装日历。
  List<List<BcpCalendarItem>> buildDays() {
    return BcpCalendarData.buildDays(
      items: _items,
      siteMeta: _siteMeta,
      enrich: _enrich,
      watchedIds: _watchedIds,
      bmfIds: _bmfIds,
      finishedIds: _finishedIds,
    );
  }

  /// 确保 [slots] 这些展示分组的条目拿到 bgm 详情（封面/评分/话数）。
  ///
  /// 每个分组只触发一次；能读本地缓存的先读，剩下的逐条拉，拉完再核对有没有
  /// 已完结的条目。没滚到过的星期不产生任何请求；失败只记日志，不影响页面。
  Future<void> ensureEnriched(Set<int> slots) async {
    var wanted = slots.where((slot) => slot >= 0 && slot < 7).toSet()
      ..removeAll(_enrichedSlots);
    if (wanted.isEmpty) return;
    _enrichedSlots.addAll(wanted);
    try {
      var ids = <int>[];
      var seen = <int>{};
      for (var slot in wanted) {
        for (var item in getTabData(slot)) {
          if (seen.add(item.subject.id)) ids.add(item.subject.id);
        }
      }
      if (ids.isEmpty) return;
      var generation = _enrichGeneration;
      var repository = ref.read(bangumiRepositoryProvider);
      var enricher = BcpEnricher();

      var cached = await enricher.readCache(ids);
      if (!mounted || generation != _enrichGeneration) return;
      if (cached.isNotEmpty) {
        _enrich.addAll(cached);
        await applyDays(buildDays());
      }
      await enricher.fetchMissing(
        ids: ids.where((id) => !_enrich.containsKey(id)),
        repository: repository,
        isActive: () => mounted,
        onFilled: (filled) {
          if (!mounted || generation != _enrichGeneration) return;
          _enrich.addAll(filled);
          unawaited(applyDays(buildDays()));
        },
      );
      if (!mounted || generation != _enrichGeneration) return;
      await dropFinished(enricher, repository, generation);
    } catch (error, stackTrace) {
      BTLogTool.warn([
        '补全日历条目详情失败: slots=$wanted',
        error.toString(),
        stackTrace.toString(),
      ]);
    }
  }

  /// 丢掉已经放完的条目。
  ///
  /// bangumi-data 的 `end` 更新滞后，季度刚完结的作品会一直留在日历里，
  /// 所以按 bgm 章节数据确认后把它们摘掉。只对已经拿到详情的条目生效。
  Future<void> dropFinished(
    BcpEnricher enricher,
    BTBangumiRepository repository,
    int generation,
  ) async {
    var pending = BcpCalendarData.pendingFinished(
      items: _items,
      enrich: _enrich,
    );
    var finished = pending.isEmpty
        ? const <int>{}
        : await enricher.confirmFinished(
            pending: pending,
            repository: repository,
            isActive: () => mounted,
          );
    if (!mounted) return;
    if (setEquals(finished, _finishedIds)) return;
    _finishedIds = finished;
    if (generation != _enrichGeneration) return;
    await applyDays(buildDays());
  }

  /// 本地收藏里标记为看过的条目。
  ///
  /// 未登录时本地收藏不可信，直接当作没有。
  Future<Set<int>> loadWatchedIds(BTBangumiRepository repository) async {
    if (hive.user == null) return {};
    try {
      var collections = await repository.getLocalCollections();
      return {
        for (var item in collections)
          if (item.type == BangumiCollectionType.collect) item.subjectId,
      };
    } catch (_) {
      return {};
    }
  }

  /// BMF 订阅列表里的 subject id。
  Future<Set<int>> loadBmfIds() async {
    try {
      var list = await sqliteBmf.readAll();
      return {for (var item in list) item.subject};
    } catch (_) {
      return {};
    }
  }

  /// 本地 bangumi-data 为空时用 bgm 日历兜底，避免首页空白。
  Future<void> loadRemoteFallback(BTBangumiRepository repository) async {
    var remote = await repository.getToday();
    if (!mounted) return;
    if (remote.code != 0 || remote.data == null) {
      await BTErrorHandler.handle(context, remote, title: '获取放送数据失败');
      return;
    }
    var days = BcpCalendarData.buildDaysFromRemote(
      remote.data!,
      watchedIds: _watchedIds,
      bmfIds: _bmfIds,
    );
    await applyDays(days);
    if (!mounted) return;
    await BtInfobar.warn(context, '本地 BangumiData 为空，已回退到 Bangumi 日历数据');
  }

  /// 写入日历数据，并按「只显示收藏」过滤。
  Future<void> applyDays(List<List<BcpCalendarItem>> days) async {
    var collected = _collectedIds;
    if (collected != null) {
      for (var day in days) {
        day.removeWhere((item) => !collected.contains(item.subject.id));
      }
    }
    calendarData = days;
    if (mounted) setState(() {});
    realignActiveSlot();
  }

  /// 刷新数据后分组高度会变，把当前选中的分组重新对齐到顶部。
  ///
  /// 否则用户看到的星期和顶部高亮会对不上（例如切换「只显示收藏」后
  /// 分组变矮，滚动位置就落到了别的星期上）。
  void realignActiveSlot() {
    if (!mounted || !_scrollController.hasClients) return;
    var slot = _activeSlot.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.isScrollingNotifier.value) return;
      var measured = measureSlot(slot);
      if (measured == null || measured.delta.abs() <= 1) {
        syncActiveSlot();
        return;
      }
      var position = _scrollController.position;
      var next = (_scrollController.offset + measured.delta).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _scrollController.jumpTo(next);
      syncActiveSlot();
    });
  }

  /// 获取第 [slot] 个展示分组的条目。
  List<BcpCalendarItem> getTabData(int slot) {
    var index = weekdayIndexAt(slot);
    if (index >= calendarData.length) return [];
    return calendarData[index];
  }

  /// 滚动时把顶部选中的分组同步成当前滚到顶部的那个。
  void syncActiveSlot() {
    if (_isScrollingToSlot) return;
    var active = 0;
    var found = false;
    for (var slot = 0; slot < 7; slot++) {
      var measured = measureSlot(slot);
      if (measured == null) continue;
      if (measured.delta <= _slotTolerance) {
        active = slot;
        found = true;
      }
    }
    if (!found || _activeSlot.value == active) return;
    _activeSlot.value = active;
    scheduleEnrich(active);
  }

  /// 滚动到新分组后，补上它附近那几天的 bgm 详情（防抖，翻页途中不狂发请求）。
  void scheduleEnrich(int slot) {
    _enrichDebounce?.cancel();
    _enrichDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(ensureEnriched({slot, slot + 1}));
    });
  }

  /// 测量分组相对滚动视口顶部的位置；分组未挂载时返回 null。
  ({double delta, double height})? measureSlot(int slot) {
    var box = _dayKeys[slot].currentContext?.findRenderObject();
    var viewport = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox || viewport is! RenderBox) return null;
    if (!box.attached || !box.hasSize || !viewport.hasSize) return null;
    var delta = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    _weekdayHeights[weekdayIndexAt(slot)] = box.size.height;
    return (delta: delta, height: box.size.height);
  }

  /// 估算第 [slot] 个分组的滚动位置：已测高度优先，未知的按均值兜底。
  double estimateSlotOffset(int slot) {
    var known = _weekdayHeights.values;
    var fallback = known.isEmpty
        ? 320.0
        : known.reduce((a, b) => a + b) / known.length;
    var offset = 0.0;
    for (var i = 0; i < slot; i++) {
      offset += _weekdayHeights[weekdayIndexAt(i)] ?? fallback;
    }
    return offset;
  }

  /// 定位到第 [slot] 个分组。
  ///
  /// 已挂载的分组直接平滑滚动；未挂载的先按估算位置跳过去（跳完即可测量），
  /// 再按测量结果修正，最多几轮。连续点击时只有最后一次定位生效。
  Future<void> scrollToSlot(int slot) async {
    var generation = ++_scrollGeneration;
    _isScrollingToSlot = true;
    try {
      for (var round = 0; round < 4; round++) {
        if (generation != _scrollGeneration) return;
        if (!mounted || !_scrollController.hasClients) return;
        var measured = measureSlot(slot);
        if (measured != null && measured.delta.abs() <= 1) return;
        var position = _scrollController.position;
        var next = measured == null
            ? estimateSlotOffset(slot)
            : _scrollController.offset + measured.delta;
        next = next.clamp(0.0, position.maxScrollExtent);
        // 已经到头（例如末尾分组撑不满一屏）就没必要再动。
        if ((next - position.pixels).abs() <= 1) return;
        if (measured == null) {
          _scrollController.jumpTo(next);
          await WidgetsBinding.instance.endOfFrame;
        } else {
          await _scrollController.animateTo(
            next,
            duration: BTTheme.animationDurationNormal,
            curve: Curves.easeOutCubic,
          );
        }
      }
    } finally {
      if (generation == _scrollGeneration) _isScrollingToSlot = false;
    }
  }

  /// 点击顶部吸附栏切换分组。
  void onTapSlot(int slot) {
    if (_activeSlot.value != slot) _activeSlot.value = slot;
    unawaited(ensureEnriched({slot, slot + 1}));
    unawaited(scrollToSlot(slot));
  }

  /// 更新远程数据
  Future<void> updateData(String remote) async {
    progress = ProgressWidget.show(
      context,
      title: '开始更新数据',
      text: '正在更新数据',
      progress: null,
    );
    progress.update(title: '开始获取数据', text: '正在获取JSON数据', progress: null);
    progress.onTaskbar = true;
    var dataGet = await apiBgd.getData();
    if (dataGet.code != 0) {
      progress.update(text: '获取数据失败');
      await Future.delayed(const Duration(seconds: 1));
      progress.end();
      if (mounted) await showRespErr(dataGet, context);
      return;
    }
    var rawData = dataGet.data as BangumiDataJson;
    progress.update(title: '成功获取数据', text: '正在写入数据');
    try {
      var sites = <BangumiDataSiteFull>[
        for (var entry in rawData.siteMeta.entries)
          BangumiDataSiteFull.fromSite(entry.key, entry.value),
      ];
      var siteTotal = sites.length;
      for (var i = 0; i < siteTotal; i++) {
        var site = sites[i];
        progress.update(
          title: '写入站点数据 ${i + 1}/$siteTotal',
          text: site.title,
          progress: siteTotal == 0 ? 0 : (i + 1) * 100 / siteTotal,
        );
        await sqliteBd.writeSite(site);
        await Future.delayed(const Duration(milliseconds: 200));
      }
      var items = rawData.items;
      await sqliteBd.writeItemBatch(
        items,
        onProgress: (completed, total) {
          progress.update(
            title: '写入条目数据',
            text: '$completed/$total',
            progress: total == 0 ? 0 : completed * 100 / total,
          );
        },
      );
    } catch (error) {
      progress.update(text: '写入数据失败');
      await Future.delayed(const Duration(seconds: 1));
      progress.end();
      if (mounted) await BtInfobar.error(context, 'BangumiData 写入失败：$error');
      return;
    }
    await BTNotifierTool.showMini(title: 'BangumiData', body: '数据更新完成');
    await sqliteAc.writeBangumiDataVersion(remote);
    var timeNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await sqliteAc.writeBangumiDataCheckTime(timeNow.toString());
    progress.update(text: '已更新到最新版本');
    version = remote;
    setState(() {});
    await Future.delayed(const Duration(seconds: 1));
    progress.end();
    // 本地 bangumi-data 换新后日历以它为准，重新组装一次。
    if (mounted) await getData();
  }

  /// 尝试更新元数据
  Future<void> checkDataUpdate() async {
    var lastCheckTime = await sqliteAc.readBangumiDataCheckTime();
    // 为秒级时间戳
    var now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (lastCheckTime != null) {
      var last = int.tryParse(lastCheckTime);
      if (last != null && now - last < 86400) return;
    }
    if (mounted) {
      progress = ProgressWidget.show(
        context,
        title: '尝试获取远程元数据',
        text: '正在获取远程版本',
        progress: null,
      );
    }
    var remoteGet = await apiBgd.getVersion();
    if (remoteGet.code != 0 || remoteGet.data == null) {
      progress.update(text: '获取远程版本失败');
      await Future.delayed(const Duration(seconds: 1));
      progress.end();
      if (mounted) await showRespErr(remoteGet, context);
      return;
    }
    var remote = remoteGet.data as String;
    progress.update(title: '成功获取远程版本', text: remote);
    if (version == remote) {
      progress.update(title: '获取远程版本成功', text: '与数据库版本一致，无需更新');
      await Future.delayed(const Duration(seconds: 1));
      await sqliteAc.writeBangumiDataCheckTime(now.toString());
      progress.end();
      return;
    }
    progress.update(title: '成功获取远程版本，即将更新', text: '$version→$remote');
    await Future.delayed(const Duration(milliseconds: 500));
    progress.end();
    await updateData(remote);
  }

  /// 刷新BangumiData
  Future<void> refreshBgmData() async {
    progress = ProgressWidget.show(
      context,
      title: '开始获取数据',
      text: '正在获取远程版本',
      progress: null,
    );
    var remoteGet = await apiBgd.getVersion();
    if (remoteGet.code != 0 || remoteGet.data == null) {
      progress.update(text: '获取远程版本失败');
      await Future.delayed(const Duration(seconds: 1));
      progress.end();
      if (mounted) await showRespErr(remoteGet, context);
      return;
    }
    var remote = remoteGet.data as String;
    progress.update(title: '成功获取远程版本', text: remote);
    await Future.delayed(const Duration(milliseconds: 500));
    progress.end();
    if (!mounted) return;
    var confirm = await showConfirm(
      context,
      title: '确认更新？',
      content: '远程版本：$remote，本地版本：$version',
    );
    if (!confirm) return;
    await updateData(remote);
  }

  /// 构建顶部吸附栏：左侧星期切换，右侧工具按钮
  Widget buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: BTColors.divider(context))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                for (var slot = 0; slot < 7; slot++)
                  Expanded(child: buildDayTab(context, slot)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ...buildHeaderActions(context),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// 构建吸附栏右侧的工具按钮
  List<Widget> buildHeaderActions(BuildContext context) {
    return [
      buildSearch(context),
      const SizedBox(width: 8),
      buildRefresh(context),
      const SizedBox(width: 8),
      buildCollectSwitch(context),
      const SizedBox(width: 8),
      buildDataUpdate(context),
    ];
  }

  /// 构建单个星期切换项
  Widget buildDayTab(BuildContext context, int slot) {
    var isActive = slot == _activeSlot.value;
    var accent = FluentTheme.of(context).accentColor;
    var color = isActive ? accent : BTColors.textSecondary(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTapSlot(slot),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  dateAt(slot).day.toString().padLeft(2, '0'),
                  style: BTTypography.subtitle(context).copyWith(color: color),
                ),
                const SizedBox(width: 6),
                Text(
                  '周${weekday[weekdayIndexAt(slot)]}',
                  style: BTTypography.body(context).copyWith(color: color),
                ),
                if (slot == 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '·今天',
                    style: BTTypography.caption(
                      context,
                    ).copyWith(color: accent, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建按天分组的滚动列表
  Widget buildDaysSliver() {
    return SliverList.builder(
      itemCount: 7,
      itemBuilder: (context, slot) {
        var index = weekdayIndexAt(slot);
        return KeyedSubtree(
          key: _dayKeys[slot],
          child: BcpDayWidget(
            weekday: '周${weekday[index]}',
            date: dateAt(slot),
            isToday: slot == 0,
            data: getTabData(slot),
            loading: isRequesting,
          ),
        );
      },
    );
  }

  /// 构建数据更新按钮
  Widget buildDataUpdate(BuildContext context) {
    return Tooltip(
      message: '更新 BangumiData：$version',
      child: FilledButton(
        onPressed: refreshBgmData,
        child: const Icon(
          FluentIcons.database_source,
          color: Colors.white,
          semanticLabel: '更新 BangumiData',
        ),
      ),
    );
  }

  /// 构建搜索按钮
  Widget buildSearch(BuildContext context) {
    return Tooltip(
      message: '搜索条目',
      child: FilledButton(
        child: const Icon(FluentIcons.search, color: Colors.white),
        onPressed: () {
          ref
              .read(navStoreProvider)
              .addNavItem(
                PaneItem(
                  icon: const Icon(FluentIcons.search),
                  title: const Text('Bangumi-条目搜索'),
                  body: const SubjectSearchPage(),
                ),
                'Bangumi-条目搜索',
              );
        },
      ),
    );
  }

  /// 构建刷新按钮
  Widget buildRefresh(BuildContext context) {
    return Tooltip(
      message: '刷新数据',
      child: FilledButton(
        onPressed: getData,
        child: const Icon(FluentIcons.refresh, color: Colors.white),
      ),
    );
  }

  /// 构建收藏按钮
  Widget buildCollectSwitch(BuildContext context) {
    return Tooltip(
      message: '只显示收藏',
      child: ToggleButton(
        checked: isShowCollection,
        onChanged: (v) async {
          isShowCollection = v;
          setState(() {});
          await getData();
        },
        child: const Icon(FluentIcons.favorite_star, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 整页是一个滚动列表，星期栏（含工具按钮）吸附在顶部；内容滚到边界
    // 就被裁掉，不会从吸附栏下面透出来。
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _activeSlot,
          builder: (context, value, child) => buildHeader(context),
        ),
        Expanded(
          child: SizedBox.expand(
            key: _viewportKey,
            child: CustomScrollView(
              controller: _scrollController,
              scrollCacheExtent: const ScrollCacheExtent.pixels(160),
              slivers: [
                buildDaysSliver(),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
