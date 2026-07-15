# 剧集正则自动推断功能 — 技术方案设计

## 一、功能定义

**输入**：一组同系列的文件名（来自本地目录或 RSS 种子标题）

**输出**：一个正则表达式，满足：

1. 能匹配该系列所有文件名
2. 包含一个捕获组，可提取剧集编号
3. 尽量不匹配其他系列的文件名

**典型输入输出**：

```dart
// 输入
[
  "[喵萌奶茶屋] 葬送的芙莉莲 - 01 [1080p][HEVC_AAC].mkv",
  "[喵萌奶茶屋] 葬送的芙莉莲 - 02 [1080p][HEVC_AAC].mkv",
  "[喵萌奶茶屋] 葬送的芙莉莲 - 03 [1080p][HEVC_AAC].mkv",
]

// 输出
pattern:    r'\[喵萌奶茶屋\] 葬送的芙莉莲 - (\d+) \[1080p\]\[HEVC_AAC\]\.mkv'
groupIndex: 1
confidence: 0.95
```

---

## 二、算法设计

### 算法选择：两层策略

| 层级 | 策略 | 优势 | 场景 |
|------|------|------|------|
| **第一层** | 已知模式匹配 | 精确、快速 | 覆盖 80%+ 常见命名格式 |
| **第二层** | 差异分析推断 | 泛化能力强 | 兜底处理非标准命名 |

### 第一层：已知模式匹配

维护一组预定义的动漫文件名正则模板，按优先级依次尝试匹配：

```dart
/// 已知模式定义
class EpisodePattern {
  /// 模式名称
  final String name;

  /// 正则表达式（含命名捕获组 ?<ep>）
  final RegExp pattern;

  /// 优先级（越小越优先）
  final int priority;

  /// 描述
  final String description;
}
```

预定义模式列表（按优先级排序）：

| 优先级 | 模式名 | 正则 | 示例 |
|--------|--------|------|------|
| 1 | `sxxexx` | `(?i)s\d+e(?<ep>\d+)` | `S01E03` |
| 2 | `ep_prefix` | `(?i)ep\.?(?<ep>\d+)` | `EP03`, `Ep.5` |
| 3 | `cn_prefix` | `第(?<ep>\d+)[话話集]` | `第3话` |
| 4 | `dash_number` | `[-\s](?<ep>\d{1,3})\s` | `- 01 ` |
| 5 | `bracket_number` | `\[(?<ep>\d{1,3})\]` | `[01]` |
| 6 | `standalone_number` | `(?<ep>\d{2,3})` | `01`（兜底） |

**匹配逻辑**：

1. 对每个文件名，按优先级依次尝试所有模式
2. 统计每种模式在所有文件名上的匹配率
3. 选择**匹配率最高且优先级最优**的模式
4. 用该模式提取所有文件名的剧集编号，验证编号是否**单调递增且连续**（允许少量间隔）

### 第二层：差异分析推断

当已知模式都不匹配时，使用差异分析算法：

```
┌─────────────────────────────────────────────────────┐
│              差异分析算法流程                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  1. 预处理                                          │
│     ├─ 去除文件扩展名                                │
│     ├─ 统一全角/半角括号                             │
│     └─ 统一空格（连续空格→单空格）                    │
│                                                     │
│  2. Token 化                                        │
│     ├─ 数字串 → NumberToken                          │
│     ├─ 括号内容 → BracketToken                       │
│     ├─ 分隔符 → SeparatorToken                       │
│     └─ 普通文字 → TextToken                          │
│                                                     │
│  3. Token 对齐                                      │
│     ├─ 使用 LCS（最长公共子序列）对齐                 │
│     └─ 识别固定 Token 和变化 Token                    │
│                                                     │
│  4. 变化区域分类                                    │
│     ├─ 连续递增数字 → 剧集编号（高置信度）            │
│     ├─ 非连续数字 → 可能是文件大小/分辨率（低置信度） │
│     ├─ 变化文字 → 可能是字幕组/版本号（忽略）         │
│     └─ 多个数字变化区 → 选最短且递增的                │
│                                                     │
│  5. 正则生成                                        │
│     ├─ 固定 Token → 转义后的字面量                    │
│     ├─ 剧集编号变化区 → 捕获组 (\d+)                  │
│     └─ 其他变化区 → 非捕获组 (?:.*?)                  │
│                                                     │
│  6. 验证                                            │
│     ├─ 用生成正则回匹配所有文件名                     │
│     ├─ 验证捕获组提取的编号与预期一致                  │
│     └─ 计算置信度分数                                │
│                                                     │
└─────────────────────────────────────────────────────┘
```

#### 关键子算法：Token 对齐

使用**多序列对齐**的简化版本：

```dart
/// Token 类型
enum TokenType {
  number,    // 数字串：01, 1080, 2024
  bracket,   // 括号内容：[1080p], (HEVC)
  separator, // 分隔符：- , _ , 空格
  text,      // 普通文字
}

/// Token
class Token {
  final TokenType type;
  final String value;

  /// 两个 Token 是否"等价"（用于对齐）
  bool isEquivalent(Token other) {
    if (type != other.type) return false;
    if (type == TokenType.number) return true;  // 数字类型视为等价
    return value == other.value;                 // 其他类型需值相同
  }
}
```

对齐策略：

1. 以第一个文件名的 Token 序列为基准
2. 对每个后续文件名，与基准做 LCS 对齐
3. 统计每个位置上 Token 的变化频率
4. 变化频率 > 阈值的位置标记为"变化区域"

#### 关键子算法：变化区域分类

当存在多个变化区域时，如何判断哪个是剧集编号？

```dart
/// 变化区域分类器
class VaryingRegionClassifier {
  /// 分类标准（按优先级）：
  ///
  /// 1. 数字连续性：提取各变化区域的数字序列，
  ///    计算相邻差值，差值最接近1的优先级最高
  ///
  /// 2. 数字范围：1-999 范围内的优先（排除分辨率1080/2160、年份2024等）
  ///
  /// 3. 数字位数：1-3位优先（排除文件大小等长数字）
  ///
  /// 4. 位置偏好：文件名中间位置优先（排除开头的字幕组编号、
  ///    结尾的文件大小/CRC等）

  static int? classify(List<VaryingRegion> regions, List<String> filenames);
}
```

**排除规则**（不是剧集编号的数字）：

| 排除类型 | 特征 | 示例 |
|----------|------|------|
| 分辨率 | 值为 360/480/720/1080/2160/3840 | `1080p`, `4K` |
| 年份 | 值在 1990-2030 范围，且位于文件名前部 | `2024` |
| 文件大小 | 带单位 MB/GB | `1.2GB` |
| CRC/哈希 | 8位十六进制 | `A1B2C3D4` |
| 位深度 | 8/10 伴随 bit | `10bit` |

---

## 三、数据模型设计

遵循项目现有风格（`BT` 前缀、`///` 注释、`json_annotation` 序列化）：

```dart
/// 剧集正则推断结果
class BTEpisodeRegexResult {
  /// 推断出的正则字符串
  final String pattern;

  /// 剧集编号的捕获组索引
  final int episodeGroupIndex;

  /// 推断置信度 (0.0 - 1.0)
  final double confidence;

  /// 匹配的文件名数量
  final int matchedCount;

  /// 总文件名数量
  final int totalCount;

  /// 使用的推断策略
  final BTEpisodeInferStrategy strategy;

  /// 推断出的剧集编号列表（用于验证）
  final List<int> extractedEpisodes;

  /// 从文件名中提取剧集编号
  int? extractEpisode(String filename) {
    var regex = RegExp(pattern);
    var match = regex.firstMatch(filename);
    if (match == null) return null;
    return int.tryParse(match.group(episodeGroupIndex) ?? '');
  }
}

/// 推断策略枚举
enum BTEpisodeInferStrategy {
  /// 已知模式匹配
  knownPattern('known_pattern'),

  /// 差异分析推断
  diffAnalysis('diff_analysis');

  final String value;
  const BTEpisodeInferStrategy(this.value);
}

/// 推断选项
class BTEpisodeRegexOptions {
  /// 最低置信度阈值（低于此值返回 null）
  final double minConfidence;

  /// 是否允许不连续的剧集编号
  final bool allowDiscontinuous;

  /// 自定义排除规则（补充默认排除列表）
  final List<RegExp> customExclusions;

  /// 是否严格模式（严格模式下只返回高置信度结果）
  final bool strict;

  const BTEpisodeRegexOptions({
    this.minConfidence = 0.5,
    this.allowDiscontinuous = true,
    this.customExclusions = const [],
    this.strict = false,
  });
}
```

---

## 四、类设计

遵循项目工具类风格（静态工具方法，不需要单例，因为无状态）：

```dart
/// 剧集正则推断器
class BTEpisodeRegexInferer {
  BTEpisodeRegexInferer._();

  /// 从文件名列表推断剧集正则
  ///
  /// 返回 null 表示无法推断（文件名太少或格式不统一）
  static BTEpisodeRegexResult? infer(
    List<String> filenames, {
    BTEpisodeRegexOptions options = const BTEpisodeRegexOptions(),
  }) {
    if (filenames.length < 2) return null;

    // 1. 预处理
    var processed = _preprocess(filenames);

    // 2. 尝试已知模式
    var result = _tryKnownPatterns(processed, options);
    if (result != null && result.confidence >= options.minConfidence) {
      return result;
    }

    // 3. 回退到差异分析
    result = _diffAnalysis(processed, options);
    if (result != null && result.confidence >= options.minConfidence) {
      return result;
    }

    return null;
  }

  /// 预处理
  static List<String> _preprocess(List<String> filenames);

  /// 已知模式匹配
  static BTEpisodeRegexResult? _tryKnownPatterns(
    List<String> filenames,
    BTEpisodeRegexOptions options,
  );

  /// 差异分析推断
  static BTEpisodeRegexResult? _diffAnalysis(
    List<String> filenames,
    BTEpisodeRegexOptions options,
  );
}
```

**为什么不用单例？** 推断器是纯函数式逻辑，无状态、无初始化依赖，使用静态方法更简洁。这与项目中 `tool_func.dart` 的纯函数风格一致。

---

## 五、文件组织

```
lib/
  utils/
    episode_regex_inferer.dart     # 核心推断器
    episode_regex_inferer/         # 内部实现（不对外暴露）
      known_patterns.dart          # 已知模式定义
      tokenizer.dart               # Token 化器
      aligner.dart                 # Token 对齐器
      classifier.dart              # 变化区域分类器
      regex_builder.dart           # 正则生成器
  models/
    app/
      episode_regex_result.dart    # 推断结果模型
```

---

## 六、置信度计算

```dart
/// 置信度 = 基础分 × 各因子加权
///
/// 基础分：
///   已知模式匹配 → 0.8
///   差异分析推断 → 0.5
///
/// 因子：
///   匹配率 = matchedCount / totalCount         → 权重 0.3
///   连续性 = 连续编号对数 / 总编号对数            → 权重 0.25
///   唯一性 = 唯一编号数 / 总编号数               → 权重 0.2
///   文件数  = min(1.0, fileCount / 3)           → 权重 0.15
///   排除命中 = 未命中排除规则的比例               → 权重 0.1
///
/// 最终置信度 = clamp(0.0, 1.0)
```

---

## 七、边界情况处理

| 场景 | 处理策略 |
|------|---------|
| 只有 1 个文件名 | 返回 `null`，无法推断 |
| 文件名格式完全不同 | 匹配率过低，返回 `null` |
| 多集合并 `01-12` | 正则 `(\d+)(?:-\d+)?`，取第一个数字 |
| SP/OVA 编号 | 作为独立系列处理，不与正片混合 |
| 版本号 `01v2` | 正则 `(\d+)(?:v\d+)?`，忽略版本号 |
| 季数+集数 `S02E03` | 两个捕获组，`episodeGroupIndex` 指向集数 |
| 合集 `01-12` | 标记为合集，`extractedEpisodes` 返回范围 |
| 文件名含多个数字 | 通过分类器排除分辨率/年份/文件大小 |

---

## 八、使用示例

```dart
// 场景1：从本地目录推断
var filenames = await BTFileTool().getFileNames('/path/to/anime');
var result = BTEpisodeRegexInferer.infer(filenames);
if (result != null) {
  print('正则: ${result.pattern}');
  print('置信度: ${result.confidence}');
  // 用正则匹配新文件
  var ep = result.extractEpisode('[字幕组] 动画 - 05 [1080p].mkv');
  print('剧集编号: $ep'); // 输出: 5
}

// 场景2：从 RSS 标题推断
var rssTitles = rssItems.map((e) => e.title).toList();
var result = BTEpisodeRegexInferer.infer(rssTitles);

// 场景3：严格模式（只接受高置信度结果）
var result = BTEpisodeRegexInferer.infer(
  filenames,
  options: BTEpisodeRegexOptions(strict: true, minConfidence: 0.8),
);
```

---

## 九、测试策略

| 测试类型 | 覆盖场景 |
|----------|---------|
| **已知模式单元测试** | 每种预定义模式各 3-5 组文件名 |
| **差异分析单元测试** | 非标准命名、多变化区域、中文命名 |
| **边界测试** | 单文件、空列表、格式混乱 |
| **回归测试** | 真实字幕组命名样本库 |
| **性能测试** | 1000+ 文件名的推断耗时 |

**测试样本库**（建议维护）：

```dart
final testSamples = {
  '喵萌奶茶屋': [
    '[喵萌奶茶屋] 葬送的芙莉莲 - 01 [1080p][HEVC_AAC].mkv',
    '[喵萌奶茶屋] 葬送的芙莉莲 - 02 [1080p][HEVC_AAC].mkv',
    // ...
  ],
  '桜都字幕组': [
    '[桜都字幕组] 药屋少女的呢喃 [01][1080p][简繁内封].mkv',
    '[桜都字幕组] 药屋少女的呢喃 [02][1080p][简繁内封].mkv',
    // ...
  ],
  'ANi': [
    '[ANi] 葬送的芙莉莲 - 01 [1080P][Baha][WEB-DL] AAC AVC.mp4',
    '[ANi] 葬送的芙莉莲 - 02 [1080P][Baha][WEB-DL] AAC AVC.mp4',
    // ...
  ],
};
```

---

## 十、后续扩展方向

1. **学习模式**：用户手动修正推断结果后，将修正后的正则作为新的已知模式缓存
2. **多季支持**：自动识别 `S01`/`S02` 等季数标识，生成含季数捕获组的正则
3. **与 BMF 联动**：在 `AppBmfModel` 中增加 `episodeRegex` 字段，推断结果持久化
4. **批量推断**：对整个下载目录自动分组+推断，识别出多个不同系列
