// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/progress_controller.dart';
import '../../core/errors/error_handler.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/async_pool.dart';
import '../../core/utils/bangumi_utils.dart';
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
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../subject_search/subject_search_page.dart';
import 'bangumi_calendar_data.dart';
import 'bangumi_calendar_day.dart';
import 'bangumi_calendar_enrich.dart';

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

  /// 收藏过滤的重读代号，连点开关时只让最后一次生效
  int _collectGeneration = 0;

  /// 本地收藏里标记为看过的 subject id
  Set<int> _watchedIds = {};

  /// BMF 订阅列表里的 subject id
  Set<int> _bmfIds = {};

  /// 已确认放完的 subject id，不排进日历
  final Set<int> _finishedIds = {};

  /// 本地在播条目（组装日历的输入）
  List<BangumiDataItem> _items = [];

  /// bangumi-data 站点元数据
  Map<String, BangumiDataSite> _siteMeta = {};

  /// 已拿到的 bgm 条目（封面/评分/话数/总话数），按 subject id 累积
  final Map<int, BangumiLegacySubjectSmall> _enrich = {};

  /// 候选分组（索引 0=周一 … 6=周日），由本地数据组装，不做就绪与收藏过滤
  List<List<BcpCalendarItem>> _rawDays = List.generate(7, (_) => []);

  /// 已经补全并确认完结状态、可以填充展示的分组
  final Set<int> _readySlots = {};

  /// 整周的补全正在进行
  bool _isPreparing = false;

  /// 补全进行中又有新的准备请求，收工后需要再来一轮
  bool _preparePending = false;

  /// [_enrich] 在上一轮填充之后又有更新，需要重新组装
  bool _enrichDirty = false;

  /// 分组落地（确认完结 + 填充）的串行队列：请求回调会连续触发，串起来做
  final KeyedAsyncSerialExecutor<int> _settleQueue =
      KeyedAsyncSerialExecutor<int>();

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
  /// subject id 补封面、评分、收藏数。
  ///
  /// 分组是「先置空再填充」的：换数据时所有分组先清空显示加载态，等某个分组
  /// 补齐详情、确认完结状态后再整组填充。这样不会先把候选条目画出来，又因为
  /// 已经放完而剔除掉，页面上不会出现数量先多后少。整周合并成一轮请求，已有
  /// 缓存的分组先落地。
  Future<void> getData({bool freshTab = false}) async {
    if (isRequesting) return;
    isRequesting = true;
    if (freshTab) {
      _activeSlot.value = 0;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
    setState(() {});
    try {
      var repository = ref.read(bangumiRepositoryProvider);
      _watchedIds = await loadWatchedIds(repository);
      _bmfIds = await loadBmfIds();
      var items = await sqliteBd.readItemsOnAir();
      if (!mounted) return;
      if (items.isEmpty) {
        await loadRemoteFallback(repository);
        return;
      }
      _items = items;
      _siteMeta = await sqliteBd.readSiteMap();
      _collectedIds = await loadCollectedIds();
      if (!mounted) return;
      // 新一轮数据：先置空全部分组，再按分组填充。已经拿到的补全结果
      // （[_enrich]）与完结判定（[_finishedIds]）按 subject id 保留，重来一遍
      // 会让封面重新拉一次。
      _readySlots.clear();
      _enrichDirty = false;
      _enrichGeneration++;
      await rebuildDays();

      // 整周一次性补齐（后台进行，不挡住提示）：缓存命中的直接落地，
      // 已有记录的条目也重读一遍，吸收条目详情页刷新的数据
      unawaited(prepareDays(refreshKnown: true));
      if (!mounted) return;
      await BtInfobar.success(context, '成功刷新放送数据');
    } catch (error) {
      // 出错也要让分组落地：展示手上的数据或空状态，不要一直转圈
      await markAllSlotsReady();
      if (mounted) {
        await BtInfobar.error(context, '刷新放送数据失败：$error');
      }
    } finally {
      isRequesting = false;
      if (mounted) setState(() {});
    }
  }

  /// 把全部分组标记为就绪。
  ///
  /// 没有可准备的数据时（远程兜底、加载失败）用它落地：分组直接按现有数据
  /// 填充或显示空状态，不会永远停在加载态。
  Future<void> markAllSlotsReady() async {
    _readySlots
      ..clear()
      ..addAll(List.generate(7, (slot) => slot));
    _enrichDirty = false;
    await applyDisplay();
  }

  /// 用本地 bangumi-data 重新组装候选分组，并刷新展示。
  Future<void> rebuildDays() async {
    if (_items.isEmpty) {
      // 远程兜底：候选分组不来自 bangumi-data，直接用现成的
      await applyDisplay();
      return;
    }
    _rawDays = BcpCalendarData.buildDays(
      items: _items,
      siteMeta: _siteMeta,
      enrich: _enrich,
      watchedIds: _watchedIds,
      bmfIds: _bmfIds,
      finishedIds: _finishedIds,
    );
    await applyDisplay();
  }

  /// 按就绪状态与「只显示收藏」生成展示用的分组。
  ///
  /// 还没准备好的分组一律置空：先置空、准备好再整组填充，避免先渲染出候选
  /// 条目、再把已完结的剔除掉，页面上不会出现数量先多后少。
  Future<void> applyDisplay() async {
    // 先量一份当前分组相对视口的位置，内容替换后按同样的位置摆回去。
    var anchor = measureSlot(_activeSlot.value)?.delta;
    calendarData = [
      for (var slot = 0; slot < 7; slot++)
        if (_readySlots.contains(slot))
          filterDay(_rawDays[weekdayIndexAt(slot)])
        else
          const <BcpCalendarItem>[],
    ];
    if (mounted) setState(() {});
    realignActiveSlot(anchor);
  }

  /// 按当前过滤条件筛出一天要展示的条目；未开启过滤时原样返回。
  List<BcpCalendarItem> filterDay(List<BcpCalendarItem> day) {
    var collected = _collectedIds;
    if (collected == null) return day;
    return [
      for (var item in day)
        if (collected.contains(item.subject.id)) item,
    ];
  }

  /// 一次性准备整周条目：缓存命中的直接补齐，缺的合并成一轮请求。
  ///
  /// 不再按天分别请求：本地缓存有效期足够长，整周合并成一轮吃的就是同一份
  /// 缓存。某个分组补齐后立刻确认完结状态并填充，先补完的先出现。
  /// [refreshKnown] 为 true 时连已有记录的条目也重读一遍缓存，用来吸收条目
  /// 详情页刷新的数据。
  Future<void> prepareDays({bool refreshKnown = false}) async {
    if (_isPreparing) {
      _preparePending = true;
      return;
    }
    _isPreparing = true;
    try {
      do {
        _preparePending = false;
        await prepareRound(refreshKnown: refreshKnown);
      } while (_preparePending && mounted);
    } catch (error, stackTrace) {
      BTLogTool.warn(['补全日历条目失败', error.toString(), stackTrace.toString()]);
      // 出错也要落地：按现有数据填充，不要一直转圈
      await markAllSlotsReady();
    } finally {
      _isPreparing = false;
    }
  }

  /// 跑一轮整周补全。
  ///
  /// 中途换了数据轮次（用户又刷新了一次）就置 [_preparePending] 交给外层按新
  /// 数据重来，不能在旧轮次上收工。
  Future<void> prepareRound({bool refreshKnown = false}) async {
    var generation = _enrichGeneration;
    var enricher = BcpEnricher();
    var repository = ref.read(bangumiRepositoryProvider);
    // 按展示顺序收集整周要展示的条目：今天在最前，先完成的分组先填充
    var ids = <int>[];
    var seen = <int>{};
    for (var slot = 0; slot < 7; slot++) {
      for (var item in filterDay(candidateItems(slot))) {
        if (seen.add(item.subject.id)) ids.add(item.subject.id);
      }
    }
    var wanted = refreshKnown
        ? ids
        : ids.where((id) => !_enrich.containsKey(id)).toList();
    if (wanted.isNotEmpty) {
      var cached = await enricher.readCache(wanted);
      if (!mounted) return;
      if (generation != _enrichGeneration) {
        _preparePending = true;
        return;
      }
      if (cached.isNotEmpty) {
        _enrich.addAll(cached);
        _enrichDirty = true;
      }
    }
    var missing = ids.where((id) => !_enrich.containsKey(id)).toList();
    if (missing.isEmpty) {
      // 全部命中缓存，直接落地
      await settleSlots(enricher, repository, generation, force: true);
      if (generation != _enrichGeneration) _preparePending = true;
      return;
    }
    // 缓存补上的部分先落地，剩下的合并成一轮请求
    await settleSlots(enricher, repository, generation);
    await enricher.fetchMissing(
      ids: missing,
      repository: repository,
      // 换了一轮数据就收工：在途请求由 BcpEnricher 合并后交给新一轮复用，
      // 不会再对同一个 bgmId 发第二次。
      isActive: () => mounted && generation == _enrichGeneration,
      onFilled: (filled) {
        if (!mounted || generation != _enrichGeneration) return;
        _enrich.addAll(filled);
        _enrichDirty = true;
        unawaited(settleSlots(enricher, repository, generation));
      },
    );
    if (!mounted) return;
    if (generation != _enrichGeneration) {
      _preparePending = true;
      return;
    }
    // 收尾：没命中的条目不再等，剩下的分组按现有数据填充
    await settleSlots(enricher, repository, generation, force: true);
    if (generation != _enrichGeneration) _preparePending = true;
  }

  /// 把条目齐了的分组确认完结状态后填充；[force] 时不再等没命中的条目。
  ///
  /// 走 [_settleQueue] 串起来：请求回调会一批批地触发，重叠着跑会把同一个
  /// 分组的完结判定重复做一遍。
  Future<void> settleSlots(
    BcpEnricher enricher,
    BTBangumiRepository repository,
    int generation, {
    bool force = false,
  }) {
    return _settleQueue.run(
      0,
      () => settleSlotsNow(enricher, repository, generation, force: force),
    );
  }

  /// 实际的落地流程，由 [settleSlots] 串行调用。
  Future<void> settleSlotsNow(
    BcpEnricher enricher,
    BTBangumiRepository repository,
    int generation, {
    bool force = false,
  }) async {
    try {
      if (!mounted || generation != _enrichGeneration) return;
      var changed = false;
      for (var slot = 0; slot < 7; slot++) {
        if (_readySlots.contains(slot)) continue;
        if (!force && !slotFilled(slot)) continue;
        await confirmFinishedForSlot(slot, enricher, repository, generation);
        if (!mounted || generation != _enrichGeneration) return;
        _readySlots.add(slot);
        changed = true;
      }
      if (!changed && !force && !_enrichDirty) return;
      _enrichDirty = false;
      await rebuildDays();
    } catch (error, stackTrace) {
      // 这一轮没落地成功不要紧，收尾那轮会把剩下的分组补上
      BTLogTool.warn(['填充日历分组失败', error.toString(), stackTrace.toString()]);
    }
  }

  /// 第 [slot] 个分组要展示的条目是否都已经拿到 bgm 详情。
  bool slotFilled(int slot) {
    return filterDay(
      candidateItems(slot),
    ).every((item) => _enrich.containsKey(item.subject.id));
  }

  /// 确认第 [slot] 个分组里哪些条目其实已经放完，准备好之后再整组填充。
  ///
  /// bangumi-data 的 `end` 更新滞后，季度刚完结的作品会一直留在日历里，所以
  /// 按 bgm 章节数据确认后就不排进日历。只对已经拿到详情的条目生效。
  Future<void> confirmFinishedForSlot(
    int slot,
    BcpEnricher enricher,
    BTBangumiRepository repository,
    int generation,
  ) async {
    var pending = BcpCalendarData.pendingFinished(
      items: _items,
      enrich: _enrich,
      weekday: weekdayIndexAt(slot) + 1,
    );
    if (pending.isEmpty) return;
    var finished = await enricher.confirmFinished(
      pending: pending,
      repository: repository,
      isActive: () => mounted,
    );
    // 判定用到的章节数据与在途补全无关，但旧一轮的结果不再写回页面，
    // 免得把新一轮刚排好的分组覆盖掉。
    if (!mounted || generation != _enrichGeneration) return;
    // 只累加：确认放完的条目不再回到日历里，刷新后也不会又冒出来
    _finishedIds.addAll(finished);
  }

  /// 读取「只显示收藏」需要的本地收藏 subject id；开关关闭时返回 null。
  ///
  /// 读取失败会退回未过滤，并把开关同步关掉，避免开关开着却不生效。
  Future<Set<int>?> loadCollectedIds() async {
    if (!isShowCollection) return null;
    try {
      return await ref.read(bangumiRepositoryProvider).getCollectedSubjectIds();
    } catch (error, stackTrace) {
      BTLogTool.warn(['读取本地收藏条目失败', error.toString(), stackTrace.toString()]);
      if (mounted) setState(() => isShowCollection = false);
      return null;
    }
  }

  /// 切换「只显示收藏」。
  ///
  /// 只重读本地收藏与订阅状态，然后就地重算分组：条目集合、封面与完结判定
  /// 都与上一轮一致，重新取数除了让页面先塌再撑，还会对同一个 bgmId 重复请求。
  Future<void> toggleShowCollection(bool value) async {
    setState(() => isShowCollection = value);
    var generation = ++_collectGeneration;
    var repository = ref.read(bangumiRepositoryProvider);
    var watched = await loadWatchedIds(repository);
    var bmf = await loadBmfIds();
    var collected = await loadCollectedIds();
    if (!mounted || generation != _collectGeneration) return;
    _watchedIds = watched;
    _bmfIds = bmf;
    _collectedIds = collected;
    await applyDisplay();
    // 展示范围变了：整周重新准备一轮，只补还没拿到的条目
    // （关掉过滤时新露出来的条目平时不会被补全）。
    unawaited(prepareDays());
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
      var list = await ref.read(bmfRepositoryProvider).readAll();
      return {for (var item in list) item.subject};
    } catch (_) {
      return {};
    }
  }

  /// 本地 bangumi-data 为空时用 bgm 日历兜底，避免首页空白。
  ///
  /// 兜底数据本身就是条目详情，没有补全一说，直接整周填充。
  Future<void> loadRemoteFallback(BTBangumiRepository repository) async {
    var remote = await repository.getToday();
    if (!mounted) return;
    if (remote.code != 0 || remote.data == null) {
      await markAllSlotsReady();
      if (!mounted) return;
      await BTErrorHandler.handle(context, remote, title: '获取放送数据失败');
      return;
    }
    _rawDays = BcpCalendarData.buildDaysFromRemote(
      remote.data!,
      watchedIds: _watchedIds,
      bmfIds: _bmfIds,
    );
    _enrichGeneration++;
    await markAllSlotsReady();
    if (!mounted) return;
    await BtInfobar.warn(context, '本地 BangumiData 为空，已回退到 Bangumi 日历数据');
  }

  /// 内容更新后分组高度会变，修正滚动偏移，让视线停在原来的位置上。
  ///
  /// [anchor] 是更新前选中分组相对视口顶部的位置。原本的做法是把分组顶回
  /// 视口顶部：用户停在分组中间时会被拉回分组开头，补全结果每刷一批就跳一次。
  /// 现在按分组位置的位移补回去，等价于「内容变了，视线不动」；拿不到更新前
  /// 的位置时（分组之前没挂载）退回原来的对齐方式。
  void realignActiveSlot(double? anchor) {
    if (!mounted || !_scrollController.hasClients) return;
    var slot = _activeSlot.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.isScrollingNotifier.value) return;
      var measured = measureSlot(slot);
      if (measured == null) return;
      var delta = anchor == null ? measured.delta : measured.delta - anchor;
      if (delta.abs() <= 1) {
        syncActiveSlot();
        return;
      }
      var position = _scrollController.position;
      var next = (_scrollController.offset + delta).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _scrollController.jumpTo(next);
      syncActiveSlot();
    });
  }

  /// 获取第 [slot] 个展示分组要渲染的条目，未准备好的分组为空。
  List<BcpCalendarItem> getTabData(int slot) {
    if (slot < 0 || slot >= calendarData.length) return [];
    return calendarData[slot];
  }

  /// 获取第 [slot] 个展示分组的候选条目（不受就绪状态影响）。
  ///
  /// 准备分组时用它取 subject id：分组还没填充，展示数据是空的。
  List<BcpCalendarItem> candidateItems(int slot) {
    var index = weekdayIndexAt(slot);
    if (index >= _rawDays.length) return [];
    return _rawDays[index];
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
            // 分组准备好之前是置空的，显示加载态；处理好之后才是空数据
            loading: !_readySlots.contains(slot),
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
        onChanged: (v) {
          if (isShowCollection == v) return;
          unawaited(toggleShowCollection(v));
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
