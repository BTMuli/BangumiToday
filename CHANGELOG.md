---
Author: 目棃
Description: 更新日志
Date: 2024-04-17
Update: 2025-03-11
---

> 本文档 [`Frontmatter`](https://github.com/BTMuli/MuCli#Frontmatter) 由 [MuCli](https://github.com/BTMuli/Mucli) 自动生成于 `2024-04-17 17:46:15`
>
> 更新于 `2025-03-11 09:39:27`

## [v0.6.4](https://github.com/BTMuli/BangumiToday/releases/tag/v0.6.4) (2025-03-11)

- 💄 调整多处UI
- 🐛 修复更新RSS链接失败
- 🐛 修复rss页面下载异常
- 🐛 修复收藏时剧集未更新
- 👽️ 适配搜索结果返回，修复搜索异常
- 🚸 缩短底部提示显示间隔
- 🚸 短按剧集快速切换收藏状态，长按自定义收藏状态

## [v0.6.3](https://github.com/BTMuli/BangumiToday/releases/tag/v0.6.3) (2025-01-22)

- 💄 移除详情页站点信息，调整放缩
- 💄 调整BMF卡片UI
- 🚸 修改收藏状态时同步更新章节信息
- 🚸 订阅更新时单条目只发送一次通知
- 🚸 用户收藏页保持状态
- 🚸 调整侧边栏标题显示
- 🐛 修复首页更新数据后loading未消失

## [v0.6.2](https://github.com/BTMuli/BangumiToday/releases/tag/v0.6.2) (2025-01-02)

- 🐛 修复从查询结果添加时遗漏标题数据
- 🐛 修复放送日历初始化异常
- ♻️ 重构数据库，更新Mikan链接时同步更新订阅链接

## [v0.6.1](https://github.com/BTMuli/BangumiToday/releases/tag/v0.6.1) (2024-11-08)

尝试性的构建一下Store，不知道能不能过审。

- 💄 详情页搜索订阅源时显示loading
- ♻️ 用户页面移至设置页
- 🏷️ BMF配置增加title字段，支持对旧数据进行兼容
- 🐛 修复infobar延时
- ♻️ 重构元数据更新逻辑，启动自动检测更新，每天检测一次
- ✨ 支持自定义Mikan镜像站Url
- 💄调整详情页收藏情况的UI

## [v0.6.0](https://github.com/BTMuli/BangumiToday/releases/tag/v0.5.0) (2024-10-08)

由于媒体播放&下载功能存在重大问题，本版本移除了相关功能，后续会重新设计并实装。

- 🐛 修复缺失用户数据导致的程序异常
- 🐛 修复msix打包时的dll缺失
- 👽️ 调整返回类型
- 💄 支持用户数据删除，调整oauth报错返回
- 👽️ 更改Mikan镜像链接
- 👽️ 调整下载torrent命名
- 🔥 移除内置播放&内置下载
- ♻️ 支持从Mikan搜索结果中设置RSS
- 🐛 修复主题色显示异常
- 🐛 修复刷新进度异常&显示异常
- ♻️ BangumiData检测更新移至calendar

## [v0.5.0](https://github.com/BTMuli/BangumiToday/releases/tag/v0.5.0) (2024-05-21)

为了适配在线播放源，将播放记录的模型进行了重构，**该改动会使旧版本应用启动白屏**。

解决方法：将 `文档/BangumiToday/hive` 目录下的 `play.hive` 及 `play.lock` 删除后重启应用。

弹幕&在线播放源的支持还在测试阶段，暂未实装。

- ♻️ 重构请求客户端
- ✨ 重构播放记录模型，按照条目进行划分，并优化了播放记录的存储逻辑
- 🐛 修复令牌刷新bug

## [v0.4.0](https://github.com/BTMuli/BangumiToday/releases/tag/v0.4.0) (2024-05-10)

- ✨ 完善内置播放，视频支持倍速播放、切换字幕、截图等功能
- ✨ 记忆播放进度&播放列表，支持仅添加到播放列表
- 🧪 **由于下载极度消耗性能，故隐藏内置下载**，请采用 Motrix 下载
- ⚡️ BMF 文件/RSS 配置长按复制到剪贴板
- ⚡️ 侧边栏增加置顶，与窗口重置合并成一个入口
- ⚡️ 视频下载完成通知支持内置播放/添加到播放列表
- ♻️ 条目搜索结果卡片样式重构

## [v0.3.0](https://github.com/BTMuli/BangumiToday/releases/tag/v0.3.0) (2024-05-02)

- ✨ 条目搜索、用户收藏等页面支持分页查看
- 🔊 完善日志记录，便于快速定位问题
- ♻️ 重构代码格式化规范，完善贡献指南相关说明
- ⚡️ 修正评分逻辑，评分改成下拉
- ⚡️ 优化RSS更新逻辑，**可能产生重复通知**
- ✨ 侧边栏条目详情记忆打开项，应用关闭后再次打开时会自动填充未关闭的条目详情
- ♻️ 采用Hive存储用户登录状态
- ✨ 实装`torrent`下载功能，**目前仍处于测试阶段**
- ✨ 实装内置播放功能，**目前仍处于测试阶段**

## [v0.2.0](https://github.com/BTMuli/BangumiToday/releases/tag/v0.2.0) (2024-04-25)

`torrent` 下载还在测试当中，入口暂时隐藏，后续会继续完善。

### Feat

- [x] BMF: RSS定时检测更新，有更新时会自动推送通知
- [x] Bangumi: 启动时检测 `token` 是否过期，过期时会自动获取新的 `token`

### Fix

- [x] 条目详情：修复修改评分时的内容错误

### Change

- [x] RSS: RSS页面合并，采用 `tab` 方式切换查看 MikanRSS 和 ComicatRSS

## [v0.1.0](https://github.com/BTMuli/BangumiToday/releases/tag/v0.1.0) (2024-04-17)

BangumiToday 的第一个版本，实现了基本的功能。

### Bangumi 相关

- [x] 今日放送：支持查看今日的番剧放送情况，登录后支持只显示订阅的番剧
- [x] 用户界面：用于登录 Bangumi 账号，获取订阅的番剧
- [x] 用户收藏：支持查看用户收藏的番剧
- [x] 条目搜索：支持根据条目类型和关键字搜索条目
- [x] 条目详情：支持查看条目的详细信息，包括评分、简介、关联条目等
- [x] 进度管理：支持获取&修改条目的观看进度/收藏状态/评分，**暂不支持取消条目收藏**
- [x] 数据源：依赖 [Bangumi-data](https://github.com/bangumi-data/bangumi-data) 作为数据源，用于显示放送时间&条目播放平台

### RSS 相关

- [x] MikanRSS：支持查看 MikanRSS 更新，添加 `token` 后支持查看订阅的番剧的更新
- [x] ComicatRSS：支持查看 Comicat 的 RSS 更新

### 应用配置相关

- [x] 设置：支持设置应用的一些配置，如主题、主题色等
- [x] 数据：应用采用 BMF(Bangumi-Mikan-File)配置数据，在条目详情页支持查看条目的 BMF 数据并进行操作，也可以到单独的页面查看所有的 BMF 数据
- [x] BMF操作：支持对 BMF 数据进行增删改操作，支持调用 [Motrix](https://github.com/agalwood/Motrix) 将 `torrent` 下载到指定目录
- [x] BMF操作：支持调用 [PotPlayer](https://potplayer.daum.net/) 播放视频文件
