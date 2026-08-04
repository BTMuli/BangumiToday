# 移除 flutter_screenutil 执行文档

## 一、背景与目标

BangumiToday 是仅面向 Windows / macOS 的桌面应用（仓库无 `android/`、`ios/`），窗口可自由拉伸与最大化。`flutter_screenutil` 的目标场景是移动端“固定设计稿 + 按屏幕等比缩放”，在桌面端会导致：

- 窗口越大，间距、字号、圆角、图标整体等比放大（例如 1920x1080 最大化时 `16.w` 实际为 24 逻辑像素）；
- `.sp` 字号随窗口宽度缩放，不跟随系统字体/DPI 设置；
- 最大化窗口下出现卡片溢出，需要额外适配（参见历史提交 `dfae42c`）。

目标：移除 `flutter_screenutil` 依赖，全部尺寸改为逻辑像素定值，窗口尺寸变化交由现有响应式布局（`BTBreakpoints`、`FittedBox`、`Row/Column/Expanded` 等）处理。

## 二、现状盘点

| 项目 | 数据 |
|------|------|
| 依赖声明 | `pubspec.yaml`: `flutter_screenutil: ^5.9.3` |
| 初始化 | `lib/app.dart`: `ScreenUtilInit(designSize: Size(1280, 720), ...)` |
| 引入文件数 | 45（`lib/` 44 + `test/` 1） |
| `.w` 用法 | 405 |
| `.h` 用法 | 278 |
| `.sp` 用法 | 223 |
| `.r` 用法 | 56 |
| 字面量合计 | 962（另有 3 处非字面量特例） |
| 主题常量 | `lib/core/theme/spacing.dart`（`BTSpacing` / `BTCardPadding` / `BTBorderRadius` / `BTFontSize` / `BTIconSize` / `BTImageSize`） |

## 三、替换规则

默认窗口尺寸 1280x720 与 `designSize` 一致，缩放系数为 1.0，因此字面量替换后默认窗口下视觉完全不变；仅在拉伸/最大化窗口下不再全局放大。

| 原写法 | 语义 | 替换为 |
|--------|------|--------|
| `16.w` | 宽度比例缩放 | `16` |
| `8.h` | 高度比例缩放 | `8` |
| `14.sp` | 字号缩放 | `14` |
| `8.r` | 圆角缩放 | `8` |
| `2.5.r` | 小数圆角缩放 | `2.5` |

### 特殊用例

| 位置 | 写法 | 处理 |
|------|------|------|
| `lib/widgets/common/bt_drawer.dart:51` | `width: width.w`（变量接收者） | 改为 `width: width` |
| `lib/widgets/common/bt_buttons.dart:156,166` | `(widget.isCompact ? 14 : 16).sp` 等条件表达式 | 去掉 `.sp`，保留条件表达式 |
| `lib/models/bangumi/bangumi_enum.dart:333` | `BangumiEpType.sp` | 枚举成员，非 screenutil，**忽略** |
| 注释中的写法（如 `// SizedBox(width: 4.w),`） | 注释 | 替换与否均无影响 |

## 四、执行步骤

1. **替换字面量用法**：对 `lib/`、`test/` 下所有 `.dart`（排除 `*.g.dart`）执行正则替换：
   ```
   \b\d+(?:\.\d+)?\.(?:w|h|sp|r)\b  ->  去掉后缀的字面量
   ```
2. **处理特例**：`width.w` 改为 `width`。
3. **移除初始化**：`lib/app.dart` 去掉 `ScreenUtilInit` 包裹，直接返回 `FluentApp`；`test/widgets/bcp_card_widget_test.dart` 去掉测试包裹层。
4. **清理 import**：删除所有 `import 'package:flutter_screenutil/flutter_screenutil.dart';`。
5. **移除依赖**：从 `pubspec.yaml` 删除 `flutter_screenutil`，执行 `flutter pub get`。
6. **验证**：见第五节。
7. **提交**：按仓库 Gitmoji 规范提交，如 `♻️ 移除 flutter_screenutil 依赖，尺寸改为逻辑像素定值`。

## 五、验证清单

- [ ] `rg -n "flutter_screenutil|ScreenUtil" lib test` 无结果
- [ ] `rg -n "\.w\b|\.h\b|\.sp\b|\.r\b" lib test --glob "*.dart"` 仅剩 `BangumiEpType.sp` 等非 screenutil 误报
- [ ] `dart analyze --fatal-infos --fatal-warnings` 通过
- [ ] `flutter test` 全部通过
- [ ] 手动运行：1280x720 默认窗口观感与移除前一致；最大化窗口无溢出

## 六、回滚方案

移除提交为独立提交，回滚方式：

```powershell
git revert <移除提交>
```

或将 `pubspec.yaml`、`lib/core/theme/spacing.dart` 等从移除提交还原。仓库完整历史保留原始状态，无数据丢失风险。
