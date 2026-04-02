---
name: "fluent-design-flutter"
description: "Fluent Design 和现代化 Flutter 开发指南。Invoke when implementing Fluent Design UI, modern Flutter patterns, or Windows-style interfaces."
---

# Fluent Design & Modern Flutter Development

本 skill 提供在 Flutter 中实现 Microsoft Fluent Design System 的完整指南，以及现代化 Flutter 开发的最佳实践。

## Fluent Design 核心原则

### 1. Light (光照)
- 使用光照效果创造深度感
- 通过高光和阴影引导用户注意力
- 实现方式：`BoxShadow`、`PhysicalModel`、`Elevation`

### 2. Depth (深度)
- 分层界面设计
- 视差滚动效果
- Z-axis 动画过渡

### 3. Motion (动效)
- 流畅的页面过渡
- 有意义的微交互
- 使用 `AnimationController` 和 `ImplicitlyAnimatedWidget`

### 4. Material (材质)
- Acrylic (亚克力) 模糊效果
- Mica 背景效果
- 使用 `BackdropFilter` 和 `ImageFilter.blur`

### 5. Scale (缩放)
- 响应式布局适配不同屏幕尺寸
- 自适应导航模式

## 推荐依赖包

```yaml
dependencies:
  fluent_ui: ^4.9.1          # Fluent Design 组件库
  system_theme: ^3.0.0        # 系统主题同步
  window_manager: ^0.3.7      # 窗口管理
  flutter_acrylic: ^1.1.3     # 窗口透明/Acrylic效果
  bitsdojo_window: ^0.1.6     # 自定义窗口标题栏
```

## 项目结构规范

```
lib/
├── app/
│   ├── app.dart              # MaterialApp/FluentApp 配置
│   └── routes/               # 路由配置
├── core/
│   ├── theme/                # 主题定义
│   │   ├── app_theme.dart
│   │   └── fluent_theme.dart
│   ├── constants/            # 常量定义
│   └── utils/                # 工具函数
├── features/                 # 按功能模块组织
│   └── feature_name/
│       ├── data/             # 数据层
│       ├── domain/           # 业务逻辑层
│       └── presentation/     # UI层
│           ├── pages/
│           ├── widgets/
│           └── providers/
├── shared/
│   ├── widgets/              # 共享组件
│   └── extensions/           # 扩展方法
└── main.dart
```

## Fluent UI 组件使用

### 基础配置

```dart
import 'package:fluent_ui/fluent_ui.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Fluent App',
      theme: FluentThemeData(
        accentColor: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: FluentThemeData(
        accentColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: HomePage(),
    );
  }
}
```

### 导航模式

```dart
// 侧边导航
NavigationView(
  appBar: NavigationAppBar(
    title: Text('App Title'),
  ),
  pane: NavigationPane(
    selected: _selectedIndex,
    onChanged: (index) => setState(() => _selectedIndex = index),
    displayMode: PaneDisplayMode.auto,
    items: [
      PaneItem(
        icon: Icon(FluentIcons.home),
        title: Text('Home'),
        body: HomePage(),
      ),
      PaneItem(
        icon: Icon(FluentIcons.settings),
        title: Text('Settings'),
        body: SettingsPage(),
      ),
    ],
  ),
)
```

### 常用组件

```dart
// 按钮
FilledButton(child: Text('Primary'), onPressed: () {}),
Button(child: Text('Secondary'), onPressed: () {}),
HyperlinkButton(child: Text('Link'), onPressed: () {}),

// 输入框
TextBox(
  placeholder: 'Enter text',
  prefix: Icon(FluentIcons.search),
),

// 卡片
Card(
  child: Column(
    children: [
      Text('Card Title'),
      Text('Card Content'),
    ],
  ),
),

// 信息提示
InfoBar(
  title: Text('Info'),
  content: Text('This is an info message'),
  severity: InfoBarSeverity.info,
),
```

## 现代化 Flutter 开发实践

### 状态管理

推荐使用 Riverpod 或 Provider：

```dart
// Riverpod 示例
final counterProvider = StateProvider<int>((ref) => 0);

class CounterWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}
```

### 响应式布局

```dart
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const ResponsiveLayout({
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) return mobile;
        if (constraints.maxWidth < 1200) return tablet;
        return desktop;
      },
    );
  }
}
```

### Acrylic 效果实现

```dart
import 'dart:ui';

Widget acrylicEffect({required Widget child}) {
  return ClipRRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    ),
  );
}
```

### 窗口透明效果

```dart
import 'package:flutter_acrylic/flutter_acrylic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Window.initialize();
  await Window.setEffect(
    effect: WindowEffect.acrylic,
    color: Color(0xCC222222),
  );
  runApp(MyApp());
}
```

## 主题管理

### 动态主题切换

```dart
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  void toggleTheme() {
    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
```

### 系统主题同步

```dart
import 'package:system_theme/system_theme.dart';

await SystemTheme.accentColor.load();
final accentColor = SystemTheme.accentColor.accent;
```

## 动画最佳实践

### 隐式动画

```dart
// 使用 AnimatedContainer
AnimatedContainer(
  duration: Duration(milliseconds: 200),
  curve: Curves.easeInOut,
  decoration: BoxDecoration(
    color: isHovered ? Colors.blue : Colors.transparent,
  ),
  child: child,
)

// 使用 AnimatedOpacity
AnimatedOpacity(
  opacity: isVisible ? 1.0 : 0.0,
  duration: Duration(milliseconds: 200),
  child: child,
)
```

### Hero 动画

```dart
Hero(
  tag: 'image-hero',
  child: Image.network(url),
)
```

## 性能优化

### 图片优化

```dart
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => ProgressRing(),
  errorWidget: (context, url, error) => Icon(FluentIcons.error),
  fadeInDuration: Duration(milliseconds: 200),
  memCacheWidth: 300, // 限制内存缓存大小
)
```

### 列表优化

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
  cacheExtent: 500, // 预缓存区域
)
```

### 懒加载

```dart
FutureBuilder(
  future: _loadData(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ProgressRing();
    }
    return ContentWidget(snapshot.data);
  },
)
```

## 代码规范

### 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 文件 | snake_case | `user_profile_page.dart` |
| 类 | PascalCase | `UserProfilePage` |
| 变量 | camelCase | `userName` |
| 常量 | camelCase | `maxRetryCount` |
| 私有成员 | _camelCase | `_internalState` |

### Widget 组织

```dart
class MyWidget extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;

  const MyWidget({
    super.key,
    required this.title,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        _buildTitle(context),
        _buildBody(context),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(title);
  }

  Widget _buildBody(BuildContext context) {
    return Expanded(child: Container());
  }
}
```

### 常量提取

```dart
class AppConstants {
  static const double cardRadius = 8.0;
  static const double defaultPadding = 16.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 200);
}
```

## 调试技巧

### Flutter DevTools

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

### 性能面板

```dart
void main() {
  debugProfileBuildsEnabled = true;
  debugPrintMarkedBuilds = true;
  runApp(MyApp());
}
```

## 参考资源

- [Fluent Design System](https://fluent2.microsoft.design/)
- [fluent_ui package](https://pub.dev/packages/fluent_ui)
- [Flutter Windows Desktop](https://docs.flutter.dev/desktop)
- [Material Design 3](https://m3.material.io/)
