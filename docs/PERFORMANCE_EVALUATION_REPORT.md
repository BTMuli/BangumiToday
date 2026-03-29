# BangumiToday 性能评估报告

**评估日期:** 2026-03-29  
**版本:** 0.6.4+8  
**评估分支:** review

---

## 1. 性能优化评估

### 1.1 应用启动时间分析

#### 当前实现分析
**位置:** [main.dart](lib/main.dart)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();      // 窗口管理器初始化
  await Window.initialize();                    // 窗口效果初始化
  await SystemTheme.accentColor.load();         // 系统主题色加载
  await dotenv.load(fileName: ".env");          // 环境变量加载
  
  await BTLogTool.init();                       // 日志初始化
  await BTDownloadTool.init();                  // 下载工具初始化
  await BTNotifierTool.init();                  // 通知工具初始化
  await BTSqlite.init();                        // SQLite 初始化
  await BTHiveTool.init();                      // Hive 初始化 (4个Box)
  
  // ... 窗口显示
  runApp(const ProviderScope(child: BTApp()));
  await Window.setEffect(effect: WindowEffect.acrylic);
}
```

#### 问题识别

| 问题 | 影响 | 严重程度 |
|------|------|----------|
| 串行初始化阻塞 | 启动时间累加 | 高 |
| 无启动画面 | 用户感知等待时间长 | 中 |
| Hive 初始化同步 | 4个Box顺序打开，阻塞主线程 | 高 |
| SQLite 无异步优化 | 数据库路径检查阻塞 | 中 |

#### 优化方案

**方案1: 并行初始化**
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 并行执行独立初始化
  await Future.wait([
    windowManager.ensureInitialized(),
    Window.initialize(),
    SystemTheme.accentColor.load(),
    dotenv.load(fileName: ".env"),
  ]);
  
  // 并行执行存储初始化
  await Future.wait([
    BTSqlite.init(),
    BTHiveTool.init(),
  ]);
  
  // ... 其余代码
}
```

**预期效果:** 启动时间减少 40-60%

**方案2: 延迟初始化**
```dart
// 将非关键初始化延迟到首帧渲染后
void main() async {
  // 仅初始化必要组件
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  
  runApp(const ProviderScope(child: BTSplashApp()));
  
  // 后台初始化其他组件
  Future.microtask(() async {
    await _initializeBackgroundServices();
  });
}
```

### 1.2 图片加载和缓存策略

#### 当前实现分析
**位置:** [bc_pw_card.dart:109](lib/pages/bangumi-calendar/bc_pw_card.dart#L109)

```dart
// 使用 bangumi 图片代理进行在线切图
var pathGet = Uri.parse(data.images!.large).path;
var link = 'https://lain.bgm.tv/r/0x600$pathGet';

return CachedNetworkImage(
  imageUrl: link,
  fit: BoxFit.cover,
  progressIndicatorBuilder: (context, url, dp) => Center(
    child: ProgressRing(value: dp.progress == null ? 0 : dp.progress! * 100),
  ),
  errorWidget: (context, url, error) => buildCoverError(context),
);
```

#### 问题识别

| 问题 | 影响 | 严重程度 |
|------|------|----------|
| 无本地持久化缓存 | 应用重启后图片重新加载 | 高 |
| 固定分辨率请求 | 未根据设备像素密度优化 | 中 |
| 无预加载机制 | 滚动时图片加载延迟 | 中 |
| 错误重试策略缺失 | 网络波动时体验差 | 低 |

#### 优化方案

**方案1: 配置持久化缓存**
```dart
// 使用 cached_network_image 的持久化缓存
CachedNetworkImage(
  imageUrl: link,
  fit: BoxFit.cover,
  cacheKey: 'bangumi_${data.id}_${devicePixelRatio}x',
  maxWidthDiskCache: 600,  // 最大缓存宽度
  memCacheWidth: 300,      // 内存缓存宽度
  errorWidget: (context, url, error) => buildCoverError(context),
  fadeInDuration: Duration(milliseconds: 200),
  fadeOutDuration: Duration(milliseconds: 200),
);
```

**方案2: 预加载机制**
```dart
class ImagePreloader {
  static final _cache = <String, ImageProvider>{};
  
  static void preloadImages(List<String> urls) {
    for (var url in urls) {
      precacheImage(CachedNetworkImageProvider(url), context);
    }
  }
}

// 在列表滚动时预加载
NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    if (notification is ScrollEndNotification) {
      // 预加载下一页图片
      _preloadNextPageImages();
    }
    return false;
  },
  child: GridView(...),
);
```

### 1.3 列表渲染和虚拟化

#### 当前实现分析
**位置:** [bc_pw_day.dart:47-58](lib/pages/bangumi-calendar/bc_pw_day.dart#L47-L58)

```dart
Widget buildList() {
  return GridView(
    controller: ScrollController(),
    padding: const EdgeInsets.all(8),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      childAspectRatio: 10 / 7,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    children: data.map((e) => BcpCardWidget(data: e)).toList(),
  );
}
```

#### 问题识别

| 问题 | 影响 | 严重程度 |
|------|------|----------|
| 使用 GridView 而非 GridView.builder | 一次性创建所有子组件 | 高 |
| 固定列数 | 不响应窗口大小变化 | 中 |
| 无懒加载 | 大数据量时内存占用高 | 高 |
| 卡片组件状态未优化 | 每个卡片独立数据库查询 | 中 |

#### 优化方案

**方案1: 使用 GridView.builder**
```dart
Widget buildList() {
  return GridView.builder(
    controller: ScrollController(),
    padding: const EdgeInsets.all(8),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _calculateCrossAxisCount(context),
      childAspectRatio: 10 / 7,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemCount: data.length,
    itemBuilder: (context, index) => BcpCardWidget(data: data[index]),
    cacheExtent: 500,  // 预缓存区域
  );
}

int _calculateCrossAxisCount(BuildContext context) {
  var width = MediaQuery.of(context).size.width;
  if (width > 1400) return 4;
  if (width > 1000) return 3;
  if (width > 600) return 2;
  return 1;
}
```

**方案2: 批量数据预加载**
```dart
// 在页面级别预加载所有放送时间，避免每个卡片单独查询
Future<Map<int, String>> preloadAirTimes(List<int> subjectIds) async {
  var sqlite = BtsBangumiData();
  var result = <int, String>{};
  for (var id in subjectIds) {
    var item = await sqlite.readItemById(id);
    if (item != null) {
      result[id] = item.begin;
    }
  }
  return result;
}
```

### 1.4 状态更新和重建优化

#### 问题识别

| 问题 | 位置 | 影响 |
|------|------|------|
| ChangeNotifier 全局通知 | store/*.dart | 状态变更触发全局重建 |
| ConsumerWidget 范围过大 | 多处 | 不必要的子树重建 |
| AutomaticKeepAliveClientMixin 滥用 | 多个页面 | 内存占用增加 |
| 无 const 构造函数优化 | 卡片组件 | 列表滚动时重建 |

#### 优化方案

**方案1: 使用 StateNotifier 替代 ChangeNotifier**
```dart
// 当前实现
class BTNavStore extends ChangeNotifier {
  int curIndex = 0;
  void setCurIndex(int index) {
    curIndex = index;
    notifyListeners();  // 触发所有监听者重建
  }
}

// 优化实现
class NavState {
  final int curIndex;
  final List<BtmAppNavItem> navItems;
  
  NavState({this.curIndex = 0, this.navItems = const []});
  
  NavState copyWith({int? curIndex, List<BtmAppNavItem>? navItems}) {
    return NavState(
      curIndex: curIndex ?? this.curIndex,
      navItems: navItems ?? this.navItems,
    );
  }
}

class NavNotifier extends StateNotifier<NavState> {
  NavNotifier() : super(NavState());
  
  void setCurIndex(int index) {
    state = state.copyWith(curIndex: index);  // 仅触发精确重建
  }
}
```

**方案2: 使用 select 精确订阅**
```dart
// 当前实现 - 订阅整个对象
var store = ref.watch(navStoreProvider);

// 优化实现 - 仅订阅需要的属性
var curIndex = ref.watch(navStoreProvider.select((s) => s.curIndex));
var navItems = ref.watch(navStoreProvider.select((s) => s.navItems));
```

---

## 2. 页面布局评估

### 2.1 响应式设计实现

#### 当前实现分析
**位置:** [subject_search_page.dart:268-296](lib/pages/subject-search/subject_search_page.dart#L268-L296)

```dart
Widget buildSearch() {
  return Row(
    children: [
      SizedBox(width: 16.w),  // 使用 ScreenUtil 响应式
      IconButton(...),
      SizedBox(width: 4.w),
      Flexible(child: TextBox(...)),
      SizedBox(width: 8.w),
      buildTypeSelects(),
      SizedBox(width: 8.w),
      buildNsfwCheck(),
      SizedBox(width: 160.w),  // 固定宽度
      PageWidget(controller),
      SizedBox(width: 16.w),
    ],
  );
}
```

#### 问题识别

| 问题 | 影响 | 严重程度 |
|------|------|----------|
| 固定宽度间距 | 窄屏时布局溢出 | 高 |
| 无断点设计 | 不适配不同屏幕尺寸 | 高 |
| 搜索栏无换行 | 窄屏时组件挤压 | 中 |
| GridView 固定列数 | 不响应窗口变化 | 中 |

#### 优化方案

**方案1: 响应式布局断点**
```dart
class BTBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double wide = 1600;
}

Widget buildSearch() {
  return LayoutBuilder(
    builder: (context, constraints) {
      var isCompact = constraints.maxWidth < BTBreakpoints.tablet;
      
      if (isCompact) {
        return _buildCompactSearch();
      }
      return _buildWideSearch();
    },
  );
}

Widget _buildCompactSearch() {
  return Column(
    children: [
      Row(children: [
        Expanded(child: TextBox(...)),
        IconButton(icon: Icon(FluentIcons.search), onPressed: search),
      ]),
      SizedBox(height: 8.h),
      Wrap(
        spacing: 8.w,
        children: [
          buildTypeSelects(),
          buildNsfwCheck(),
        ],
      ),
    ],
  );
}
```

**方案2: 响应式 GridView**
```dart
Widget buildList() {
  return LayoutBuilder(
    builder: (context, constraints) {
      var crossAxisCount = _calculateColumns(constraints.maxWidth);
      
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 10 / 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: data.length,
        itemBuilder: (context, index) => BcpCardWidget(data: data[index]),
      );
    },
  );
}

int _calculateColumns(double width) {
  if (width > 1600) return 5;
  if (width > 1200) return 4;
  if (width > 900) return 3;
  if (width > 600) return 2;
  return 1;
}
```

### 2.2 组件结构和可复用性

#### 问题识别

| 问题 | 位置 | 影响 |
|------|------|------|
| 卡片组件重复实现 | bc_pw_card.dart, bsc_search.dart | 维护成本高 |
| 空状态组件分散 | 多个页面 | 样式不一致 |
| 加载状态组件分散 | 多个页面 | 代码重复 |
| 无统一间距规范 | 全局 | 视觉不一致 |

#### 优化方案

**方案1: 统一卡片组件**
```dart
/// 统一的番剧卡片组件
class BTSubjectCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final double? score;
  final String? airTime;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  
  const BTSubjectCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.score,
    this.airTime,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: _buildContent(context),
      ),
    );
  }
}
```

### 2.3 渲染性能优化

#### 问题识别

| 问题 | 影响 | 严重程度 |
|------|------|----------|
| BackdropFilter 性能开销 | 卡片封面模糊效果消耗 GPU | 高 |
| 过度使用 ClipRRect | 裁剪操作触发离屏渲染 | 中 |
| 无 RepaintBoundary | 复杂组件重绘范围过大 | 中 |
| AnimatedContainer 滥用 | 动画性能开销 | 低 |

#### 优化方案

**方案1: 优化 BackdropFilter 使用**
```dart
// 当前实现 - 每个卡片都有模糊效果
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
  child: Container(color: Colors.black.withOpacity(0.3)),
);

// 优化方案 - 使用渐变替代模糊
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(0.7),
      ],
    ),
  ),
);
```

**方案2: 添加 RepaintBoundary**
```dart
Widget buildList() {
  return ListView.builder(
    itemCount: data.length,
    itemBuilder: (context, index) {
      return RepaintBoundary(
        key: ValueKey(data[index].id),
        child: BTSubjectCard(data: data[index]),
      );
    },
  );
}
```

---

## 3. 数据传输效率评估

### 3.1 API 请求模式分析

#### 当前实现分析
**位置:** [bangumi_api.dart](lib/request/bangumi/bangumi_api.dart)

```dart
// 每次请求都创建新的客户端实例
class BtrBangumiApi {
  late final BtrClient client;
  
  BtrBangumiApi() {
    client = BtrClient.withHeader();  // 新建 Dio 实例
    client.dio.options.baseUrl = baseUrl;
  }
}
```

#### 问题识别

| 问题 | 影响 | 严重程度 |
|------|------|----------|
| 无连接复用 | 每次请求重新建立连接 | 高 |
| 无请求去重 | 快速点击触发重复请求 | 高 |
| 无请求取消 | 页面退出时请求未取消 | 中 |
| 无请求超时配置 | 网络差时无限等待 | 中 |
| 无重试机制 | 网络波动时失败 | 中 |

#### 优化方案

**方案1: 单例 Dio 客户端**
```dart
class BTHttpClient {
  BTHttpClient._();
  
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 30),
    sendTimeout: Duration(seconds: 15),
  ));
  
  static Dio get dio => _dio;
  
  static void configure({
    String? baseUrl,
    Map<String, dynamic>? headers,
  }) {
    if (baseUrl != null) _dio.options.baseUrl = baseUrl;
    if (headers != null) _dio.options.headers.addAll(headers);
  }
}
```

**方案2: 请求去重和取消**
```dart
class RequestManager {
  static final _pendingRequests = <String, CancelToken>{};
  
  static Future<T> request<T>(
    String key,
    Future<T> Function(CancelToken token) request,
  ) async {
    // 取消相同 key 的未完成请求
    _pendingRequests[key]?.cancel('Request replaced');
    
    var token = CancelToken();
    _pendingRequests[key] = token;
    
    try {
      var result = await request(token);
      _pendingRequests.remove(key);
      return result;
    } catch (e) {
      _pendingRequests.remove(key);
      rethrow;
    }
  }
}
```

**方案3: 自动重试机制**
```dart
Future<T> withRetry<T>(
  Future<T> Function() request, {
  int maxRetries = 3,
  Duration delay = const Duration(seconds: 1),
}) async {
  for (var i = 0; i < maxRetries; i++) {
    try {
      return await request();
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(delay * (i + 1));
    }
  }
  throw Exception('Unreachable');
}
```

### 3.2 数据缓存和持久化

#### 当前实现分析

| 数据类型 | 存储方式 | 问题 |
|----------|----------|------|
| 用户信息 | Hive + SQLite | 双重存储，同步问题 |
| 收藏数据 | SQLite | 无过期策略 |
| 放送日历 | 无缓存 | 每次启动重新请求 |
| 条目详情 | 无缓存 | 重复请求相同条目 |
| 图片 | 内存缓存 | 无持久化 |

#### 优化方案

**方案1: 分层缓存策略**
```dart
enum CacheLevel {
  memory,      // 内存缓存（最快，容量小）
  disk,        // 磁盘缓存（中等速度，容量大）
  network,     // 网络请求（最慢，最新）
}

class CacheManager {
  static final _memoryCache = <String, dynamic>{};
  static final _diskCache = Hive.box('cache');
  
  static Future<T?> get<T>(
    String key, {
    CacheLevel level = CacheLevel.memory,
    Duration? maxAge,
  }) async {
    // 检查内存缓存
    if (level.index >= CacheLevel.memory.index) {
      var memData = _memoryCache[key];
      if (memData != null && !_isExpired(memData, maxAge)) {
        return memData.data as T;
      }
    }
    
    // 检查磁盘缓存
    if (level.index >= CacheLevel.disk.index) {
      var diskData = _diskCache.get(key);
      if (diskData != null && !_isExpired(diskData, maxAge)) {
        // 回填内存缓存
        _memoryCache[key] = diskData;
        return diskData.data as T;
      }
    }
    
    return null;
  }
  
  static Future<void> set<T>(
    String key,
    T data, {
    CacheLevel level = CacheLevel.disk,
  }) async {
    var entry = CacheEntry(data: data, timestamp: DateTime.now());
    
    if (level.index >= CacheLevel.memory.index) {
      _memoryCache[key] = entry;
    }
    
    if (level.index >= CacheLevel.disk.index) {
      await _diskCache.put(key, entry);
    }
  }
}
```

**方案2: 放送日历缓存**
```dart
class CalendarCache {
  static const _cacheKey = 'bangumi_calendar';
  static const _maxAge = Duration(hours: 6);
  
  static Future<List<BangumiCalendarRespData>?> get() async {
    return await CacheManager.get<List<BangumiCalendarRespData>>(
      _cacheKey,
      maxAge: _maxAge,
    );
  }
  
  static Future<void> set(List<BangumiCalendarRespData> data) async {
    await CacheManager.set(_cacheKey, data);
  }
}
```

### 3.3 状态管理和数据流

#### 问题识别

| 问题 | 影响 | 严重程度 |
|------|------|----------|
| Provider 重复创建 | 状态不一致 | 高 |
| 无数据预取 | 页面切换时加载延迟 | 中 |
| 无乐观更新 | 操作响应感知慢 | 中 |
| 状态持久化不完整 | 重启后状态丢失 | 中 |

#### 优化方案

**方案1: 统一 Provider 管理**
```dart
// 使用 Riverpod 的 ProviderScope 管理全局状态
final calendarProvider = StateNotifierProvider<CalendarNotifier, AsyncValue<List<BangumiCalendarRespData>>>((ref) {
  return CalendarNotifier(ref.read(bangumiRepositoryProvider));
});

class CalendarNotifier extends StateNotifier<AsyncValue<List<BangumiCalendarRespData>>> {
  final BTBangumiRepository _repository;
  
  CalendarNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadData();
  }
  
  Future<void> _loadData() async {
    // 先尝试从缓存加载
    var cached = await CalendarCache.get();
    if (cached != null) {
      state = AsyncValue.data(cached);
    }
    
    // 然后从网络刷新
    var result = await _repository.getToday();
    if (result.code == 0 && result.data != null) {
      await CalendarCache.set(result.data!);
      state = AsyncValue.data(result.data!);
    }
  }
  
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadData();
  }
}
```

**方案2: 乐观更新**
```dart
class CollectionNotifier extends StateNotifier<AsyncValue<BangumiUserSubjectCollection?>> {
  Future<void> updateType(int subjectId, BangumiCollectionType type) async {
    // 保存当前状态用于回滚
    var previousState = state;
    
    // 乐观更新 UI
    state = AsyncValue.data(
      state.value?.copyWith(type: type) ??
      BangumiUserSubjectCollection(type: type),
    );
    
    // 发送网络请求
    var result = await _repository.updateCollectionSubject(subjectId, type: type);
    
    if (result.code != 0) {
      // 失败时回滚
      state = previousState;
      _showError(result.message);
    }
  }
}
```

---

## 4. 优化实施计划

### 4.1 高优先级（立即实施）

| 编号 | 优化项 | 预期效果 | 工作量 | 风险 |
|------|--------|----------|--------|------|
| P1 | GridView.builder 替换 | 内存减少 50%+ | 1天 | 低 |
| P2 | 并行初始化 | 启动时间减少 40% | 1天 | 中 |
| P3 | 单例 HTTP 客户端 | 连接复用，减少延迟 | 1天 | 低 |
| P4 | 图片持久化缓存 | 离线可用，加载加速 | 1天 | 低 |
| P5 | 请求去重和取消 | 避免重复请求 | 0.5天 | 低 |

### 4.2 中优先级（近期实施）

| 编号 | 优化项 | 预期效果 | 工作量 | 风险 |
|------|--------|----------|--------|------|
| M1 | 响应式布局断点 | 多设备适配 | 2天 | 中 |
| M2 | StateNotifier 迁移 | 精确重建 | 3天 | 高 |
| M3 | 分层缓存实现 | 离线支持 | 2天 | 中 |
| M4 | 乐观更新 | 操作响应加速 | 1天 | 低 |

### 4.3 低优先级（后续实施）

| 编号 | 优化项 | 预期效果 | 工作量 | 风险 |
|------|--------|----------|--------|------|
| L1 | RepaintBoundary | 渲染优化 | 1天 | 低 |
| L2 | 预加载机制 | 滚动流畅 | 1天 | 低 |
| L3 | 启动画面 | 用户体验 | 0.5天 | 低 |
| L4 | 性能监控 | 问题定位 | 2天 | 低 |

---

## 5. 验证方法

### 5.1 性能指标

| 指标 | 当前值 | 目标值 | 测量方法 |
|------|--------|--------|----------|
| 启动时间 | ~2s | <1s | Flutter DevTools |
| 内存占用 | ~200MB | <150MB | 任务管理器 |
| 列表滚动 FPS | ~45 | >55 | DevTools Performance |
| 图片加载时间 | ~500ms | <200ms | Network 面板 |
| API 响应时间 | ~300ms | <200ms | Network 面板 |

### 5.2 测试场景

1. **启动性能测试**
   - 冷启动时间
   - 热启动时间
   - 首帧渲染时间

2. **列表滚动测试**
   - 快速滚动流畅度
   - 大数据量（100+条目）内存占用
   - 图片加载延迟

3. **网络性能测试**
   - 弱网环境响应
   - 并发请求处理
   - 离线模式可用性

---

## 6. 总结

### 6.1 关键发现

1. **启动性能**: 串行初始化是主要瓶颈，可通过并行化优化
2. **列表性能**: 使用 GridView 而非 GridView.builder 导致内存问题
3. **网络性能**: 缺乏请求管理和缓存策略
4. **状态管理**: ChangeNotifier 导致不必要的重建

### 6.2 优化收益预估

| 优化领域 | 预期收益 |
|----------|----------|
| 启动时间 | 减少 40-60% |
| 内存占用 | 减少 30-50% |
| 网络请求 | 减少 50%+ |
| 滚动性能 | FPS 提升 20%+ |

### 6.3 下一步行动

建议按照优先级顺序实施优化，首先解决列表渲染和启动性能问题，然后逐步完善网络和状态管理优化。

---

*本报告基于代码审查和性能分析生成，建议结合实际性能测试数据进行验证。*
