# BangumiToday 业务需求评估报告

**评估日期:** 2026-03-29  
**版本:** 0.6.4+8  
**评估分支:** review

---

## 1. 业务场景概述

### 1.1 产品定位
BangumiToday 是一款面向 Bangumi（番组计划）用户的桌面客户端应用，主要功能包括：
- 番剧放送日历浏览
- 用户收藏管理
- RSS/BMF 订阅管理
- 条目搜索与详情查看

### 1.2 目标用户
- Bangumi 平台注册用户
- 追番/追剧用户
- 需要管理观看进度的用户

### 1.3 核心业务流程
```
用户登录 → 浏览放送日历 → 查看条目详情 → 管理收藏状态 → 追踪观看进度
```

---

## 2. 用户交互逻辑评估

### 2.1 发现的问题

#### 问题 1: 导航逻辑混乱 (严重)
**位置:** [app_nav.dart](lib/widgets/app/app_nav.dart)

**问题描述:**
- 动态标签页与固定导航项混合管理，逻辑复杂
- `navStoreProvider` 在多处重复定义（`nav_store.dart` 和 `app_providers.dart`）
- 标签页关闭后索引跳转逻辑不直观

**影响:** 用户在多个标签页间切换时容易迷失，关闭标签页后跳转位置不可预期

**优化方案:**
```dart
// 建议使用统一的导航管理
enum NavDestination {
  calendar,  // 今日放送
  rss,       // RSS & BMF
  collection, // 用户收藏
  settings,  // 设置
}

// 动态标签页应独立管理，与主导航分离
```

#### 问题 2: 登录流程不直观 (中等)
**位置:** [app_nav.dart:179-216](lib/widgets/app/app_nav.dart#L179-L216)

**问题描述:**
- OAuth 授权流程依赖系统浏览器，用户可能不知道发生了什么
- 授权成功后没有明确的视觉反馈
- Token 过期处理在应用启动时静默进行，用户无感知

**优化方案:**
```dart
// 建议：添加授权状态指示器
Widget buildAuthStatus() {
  if (hive.user == null) {
    return Button(
      child: Row(children: [
        Icon(FluentIcons.signin),
        Text('登录 Bangumi'),
      ]),
      onPressed: () => showOAuthDialog(), // 显示授权说明对话框
    );
  }
  return UserAvatarWithMenu();
}
```

#### 问题 3: 收藏状态切换操作冗余 (中等)
**位置:** [bsd_user_collection.dart:98-114](lib/widgets/bangumi/subject_detail/bsd_user_collection.dart#L98-L114)

**问题描述:**
- 修改收藏状态需要：点击按钮 → 显示菜单 → 选择状态 → 确认
- 每次状态变更后重新获取整个收藏信息
- 没有批量操作功能

**优化方案:**
```dart
// 建议：添加快捷状态切换按钮
Widget buildQuickActions() {
  return Row(children: [
    IconButton(icon: Icon(FluentIcons.check_mark), onPressed: () => markAsWatched()),
    IconButton(icon: Icon(FluentIcons.pin), onPressed: () => toggleWish()),
    // 长按显示完整菜单
  ]);
}
```

#### 问题 4: 搜索功能体验不佳 (中等)
**位置:** [subject_search_page.dart:113-165](lib/pages/subject-search/subject_search_page.dart#L113-L165)

**问题描述:**
- 搜索类型选择使用下拉菜单，无法直观看到已选类型
- 排序方式功能已注释掉（API 问题）
- 搜索结果列表不支持网格视图
- 没有搜索历史记录

**优化方案:**
```dart
// 建议：使用标签式类型选择
Widget buildTypeChips() {
  return Wrap(
    spacing: 8,
    children: BangumiSubjectType.values.map((type) => 
      FilterChip(
        label: Text(type.label),
        selected: types.contains(type),
        onSelected: (selected) => toggleType(type),
      ),
    ).toList(),
  );
}
```

### 2.2 交互流程优化建议

| 场景 | 当前流程 | 建议流程 | 改进点 |
|------|----------|----------|--------|
| 首次登录 | 点击"未登录" → 浏览器授权 → 回调 | 显示登录说明 → 浏览器授权 → 欢迎页面 | 增加引导 |
| 查看条目 | 日历点击 → 新标签页 | 日历点击 → 侧边预览 → 可选新标签页 | 减少标签页 |
| 更新进度 | 点击剧集 → 菜单 → 选择状态 | 点击剧集直接切换 + 长按菜单 | 减少步骤 |
| 搜索条目 | 输入 → 选择类型 → 搜索 | 输入时实时搜索建议 | 提升效率 |

---

## 3. 页面UI布局评估

### 3.1 布局问题

#### 问题 1: 今日放送页面布局不合理 (中等)
**位置:** [bangumi_calendar_page.dart](lib/pages/bangumi-calendar/bangumi_calendar_page.dart)

**问题描述:**
- Tab 底部按钮过多且排列紧密（搜索、刷新、收藏切换、更多）
- 卡片布局固定为左右结构，窄屏时显示不佳
- 放送时间需要异步获取，导致卡片内容闪烁

**优化方案:**
```dart
// 建议：将操作按钮移至顶部工具栏
Widget buildToolbar() {
  return CommandBar(
    primaryItems: [
      CommandBarButton(icon: Icon(FluentIcons.search), label: Text('搜索')),
      CommandBarButton(icon: Icon(FluentIcons.refresh), label: Text('刷新')),
      CommandBarToggleButton(icon: Icon(FluentIcons.favorite), label: Text('仅收藏')),
    ],
  );
}

// 卡片布局响应式调整
Widget buildCard() {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 400) {
        return buildVerticalLayout();
      }
      return buildHorizontalLayout();
    },
  );
}
```

#### 问题 2: 条目详情页面信息层级不清晰 (中等)
**位置:** [subject_detail_page.dart:353-436](lib/pages/subject-detail/subject_detail_page.dart#L353-L436)

**问题描述:**
- 所有内容模块使用相同的 Card 样式，视觉层级不明显
- 重要信息（收藏状态、评分）与次要信息（简介、关联）平级展示
- 页面过长，没有快速导航

**优化方案:**
```dart
// 建议：使用分组和折叠优化信息层级
Widget buildContent() {
  return SingleChildScrollView(
    child: Column(children: [
      // 核心信息区（始终展开）
      buildPrimarySection(), // 封面、标题、评分、收藏状态
      
      // 功能操作区（可折叠）
      Expander(
        header: Text('观看进度'),
        content: buildEpisodeSection(),
      ),
      
      // 详细信息区（默认折叠）
      Expander(
        initiallyExpanded: false,
        header: Text('详细信息'),
        content: buildDetailSection(),
      ),
    ]),
  );
}
```

#### 问题 3: 设置页面布局不对称 (轻微)
**位置:** [app_setting_page.dart:86-109](lib/pages/app-setting/app_setting_page.dart#L86-L109)

**问题描述:**
- 左侧配置列表使用 ListView，右侧徽章固定宽度
- 宽屏时右侧空白过多
- 窄屏时布局挤压

**优化方案:**
```dart
// 建议：响应式布局
Widget buildLayout() {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 1000) {
        return Row(children: [
          Expanded(flex: 2, child: buildConfigList()),
          Expanded(flex: 1, child: buildAppBadge()),
        ]);
      }
      return Column(children: [
        buildAppBadge(),
        Expanded(child: buildConfigList()),
      ]);
    },
  );
}
```

### 3.2 视觉一致性评估

| 组件 | 问题 | 建议 |
|------|------|------|
| 卡片组件 | bc_pw_card 和 bsc_search 样式不统一 | 统一使用 Card 组件封装 |
| 按钮样式 | FilledButton、Button、IconButton 混用 | 定义统一的按钮使用规范 |
| 间距规范 | 使用 SizedBox 和 EdgeInsets 混乱 | 定义统一的间距常量 |
| 颜色使用 | accentColor 使用方式不一致 | 创建统一的颜色主题类 |

---

## 4. 功能完整性评估

### 4.1 核心功能覆盖度

| 功能模块 | 实现状态 | 完整度 | 备注 |
|----------|----------|--------|------|
| 用户认证 | ✅ 已实现 | 90% | 缺少登录状态持久化提示 |
| 放送日历 | ✅ 已实现 | 95% | 缺少自定义排序 |
| 条目搜索 | ✅ 已实现 | 80% | 排序功能受 API 限制 |
| 条目详情 | ✅ 已实现 | 90% | 页面结构待优化 |
| 收藏管理 | ✅ 已实现 | 85% | 缺少批量操作 |
| 进度追踪 | ✅ 已实现 | 85% | 缺少批量更新 |
| RSS订阅 | ✅ 已实现 | 90% | 功能完整 |
| BMF管理 | ✅ 已实现 | 90% | 功能完整 |
| 应用设置 | ✅ 已实现 | 95% | 功能完整 |

### 4.2 功能缺失项

#### 缺失 1: 离线模式支持 (重要)
**影响:** 网络不可用时应用无法使用

**建议实现:**
```dart
// 离线数据缓存策略
class OfflineCacheManager {
  Future<void> cacheCalendarData(List<BangumiCalendarRespData> data);
  Future<List<BangumiCalendarRespData>?> getCachedCalendarData();
  Future<bool> isCacheValid(String key, Duration maxAge);
}
```

#### 缺失 2: 数据同步机制 (重要)
**影响:** 多设备数据不一致

**建议实现:**
- 收藏状态变更时记录时间戳
- 启动时检查远程数据更新
- 提供手动同步按钮

#### 缺失 3: 通知提醒功能 (次要)
**影响:** 用户错过番剧更新

**建议实现:**
- 放送时间提醒
- 新剧集更新通知
- RSS 更新通知

#### 缺失 4: 数据导出功能 (次要)
**影响:** 用户无法备份收藏数据

**建议实现:**
- 导出收藏列表为 JSON/CSV
- 导出观看进度
- 导入数据恢复

---

## 5. 业务逻辑合理性评估

### 5.1 数据流问题

#### 问题 1: 状态管理分散 (严重)
**位置:** 多处

**问题描述:**
- 同一数据在多处重复实例化（如 `BgmUserHive`）
- Provider 和 Hive 状态同步机制不清晰
- 数据更新后 UI 刷新不及时

**示例:**
```dart
// bangumi_calendar_page.dart
final BgmUserHive hive = BgmUserHive();

// subject_detail_page.dart
final BgmUserHive hiveUser = BgmUserHive();

// app_nav.dart
final BgmUserHive hive = BgmUserHive();
```

**优化方案:**
```dart
// 使用 Riverpod 统一管理
final bgmUserHiveProvider = ChangeNotifierProvider<BgmUserHive>((ref) {
  return BgmUserHive.instance;
});

// 页面中使用
final hive = ref.watch(bgmUserHiveProvider);
```

#### 问题 2: API 错误处理不一致 (中等)
**位置:** 多处 API 调用

**问题描述:**
- 部分错误使用 `showRespErr`，部分使用 `BtInfobar.error`
- 错误信息对用户不够友好
- 没有错误分类处理（网络错误、认证错误、业务错误）

**优化方案:**
```dart
// 建议：统一错误处理
enum AppError {
  networkError,
  authError,
  notFound,
  serverError,
  unknown,
}

class ErrorHandler {
  static Future<void> handle(BuildContext context, BTResponse response) {
    switch (response.code) {
      case 401:
        return _handleAuthError(context);
      case 404:
        return _handleNotFoundError(context, response);
      case >= 500:
        return _handleServerError(context, response);
      default:
        return _handleGenericError(context, response);
    }
  }
}
```

### 5.2 边界条件处理

#### 问题 1: 空数据处理不完善 (中等)
**位置:** 多处列表展示

**问题描述:**
- 搜索无结果时显示"没有数据"，但无操作建议
- 收藏列表为空时无引导内容
- 网络错误时只显示错误，无重试机制

**优化方案:**
```dart
Widget buildEmptyState(String type) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(FluentIcons.search_and_apps, size: 48),
        SizedBox(height: 16),
        Text('没有找到相关内容'),
        SizedBox(height: 8),
        Button(child: Text('清除筛选条件'), onPressed: resetFilters),
      ],
    ),
  );
}
```

#### 问题 2: 大数据量处理 (中等)
**位置:** [bsd_user_episodes.dart:30](lib/widgets/bangumi/subject_detail/bsd_user_episodes.dart#L30)

**问题描述:**
- 剧集数量过多时（如柯南 1000+ 集）加载缓慢
- 没有虚拟化列表，内存占用高
- 分页加载按钮不明显

**优化方案:**
```dart
// 使用虚拟化列表
Widget buildEpisodeList() {
  return ListView.builder(
    itemCount: episodes.length + (hasMore ? 1 : 0),
    itemBuilder: (context, index) {
      if (index == episodes.length) {
        return buildLoadMoreButton();
      }
      return BsdEpisode(episodes[index]);
    },
  );
}
```

---

## 6. 优化实施计划

### 6.1 高优先级（建议立即实施）

| 编号 | 优化项 | 预期效果 | 工作量 |
|------|--------|----------|--------|
| H1 | 统一状态管理 Provider | 解决数据同步问题 | 2天 |
| H2 | 优化登录流程引导 | 提升新用户体验 | 1天 |
| H3 | 添加离线数据缓存 | 提升可用性 | 2天 |
| H4 | 统一错误处理机制 | 提升用户体验 | 1天 |

### 6.2 中优先级（建议近期实施）

| 编号 | 优化项 | 预期效果 | 工作量 |
|------|--------|----------|--------|
| M1 | 重构条目详情页布局 | 提升信息可读性 | 2天 |
| M2 | 优化搜索功能体验 | 提升搜索效率 | 1天 |
| M3 | 添加批量操作功能 | 提升操作效率 | 2天 |
| M4 | 响应式布局优化 | 支持更多屏幕尺寸 | 2天 |

### 6.3 低优先级（建议后续实施）

| 编号 | 优化项 | 预期效果 | 工作量 |
|------|--------|----------|--------|
| L1 | 添加数据导出功能 | 数据备份 | 1天 |
| L2 | 添加通知提醒功能 | 提升用户粘性 | 2天 |
| L3 | 添加数据同步机制 | 多设备同步 | 3天 |
| L4 | 完善单元测试 | 提升代码质量 | 3天 |

---

## 7. 总结

### 7.1 整体评价
BangumiToday 作为一款 Bangumi 客户端，核心功能实现完整，能够满足用户的基本需求。但在用户体验、交互流程、代码架构等方面存在优化空间。

### 7.2 关键改进点
1. **统一状态管理** - 解决数据同步和状态不一致问题
2. **优化交互流程** - 减少操作步骤，提升效率
3. **完善边界处理** - 提升应用稳定性和用户体验
4. **改进UI布局** - 提升信息可读性和视觉一致性

### 7.3 下一步行动
建议按照优先级顺序实施优化，首先解决状态管理和登录流程问题，然后逐步完善其他功能。

---

*本报告基于代码审查和业务分析生成，建议结合实际用户反馈进行调整。*
