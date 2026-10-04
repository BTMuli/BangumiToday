---
Author: 目棃
Description: 说明文档
Date: 2024-04-11
Update: 2026-10-04
---

> 本文档 [`Frontmatter`](https://github.com/BTMuli/MuCli#Frontmatter) 由 [MuCli](https://github.com/BTMuli/Mucli) 自动生成于 `2024-04-11 12:06:15`
>
> 更新于 `2026-10-04 19:28:53`

> **项目目前处于开发阶段，不保证稳定性。**

<div style="width:100%;display:flex;justify-content:center;align-items:center;margin:0 auto">
    <a href="./assets/images/logo.png">
      <img src="https://s2.loli.net/2024/04/18/xe7bEKiQMBCtPZo.png" alt="logo">
    </a>
</div>

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/BTMuli/BangumiToday)

[![](https://img.shields.io/github/license/BTMuli/BangumiToday)](./LICENSE)
[![](https://img.shields.io/github/v/release/BTMuli/BangumiToday)](https://github.com/BTMuli/BangumiToday/releases/latest)
[![](https://img.shields.io/github/last-commit/BTMuli/BangumiToday)](https://github.com/BTMuli/BangumiToday/commits/master/)
[![](https://img.shields.io/github/commits-since/BTMuli/BangumiToday/latest)](https://github.com/BTMuli/BangumiToday/commits/master/)

# BangumiToday

基于 [Bangumi.tv](https://bangumi.tv) 的桌面番剧应用，聚合 [蜜柑计划](https://mikanani.me)、Comicat 与 [AniBT](https://anibt.net) 的 RSS 资源。

结合本地目录，提供放送日历、RSS 订阅与内置下载、进度记录、系统托盘等功能；内置下载引擎与系统代理目前仅在 Windows 可用。

## 下载

> 程序已经通过微软商店审核，可以直接在商店下载。

<a href="https://apps.microsoft.com/detail/9phwnbm93jzn?mode=direct">
	<img src="https://get.microsoft.com/images/zh-cn%20dark.svg" width="200" alt="icon"/>
</a>

## 使用前提

应用的良好使用体验**基于如下前提**：

1. 用户已经拥有 [Bangumi.tv](https://bangumi.tv) 账号，并且通过应用相关页面完成了登录授权。
2. 用户登录 Bangumi 账号后对收藏数据进行了同步。
3. 用户在 BMF 工作台为番剧建立了关联，并配置了 RSS 订阅地址与本地目录。
4. 如需访问受限站点，可在设置中启用系统代理（仅 Windows）；下载引擎代理可单独开关。

## 应用预览

### 发现与管理番剧

按星期浏览 Bangumi 每日放送，快速查看开播时间、评分与收藏热度。

![今日放送：按星期浏览当季番剧](./screenshots/calendar.png)

使用类型筛选和关键词查找条目，在双栏结果中直接比较评分、标签与基本信息。

![条目搜索：筛选并浏览搜索结果](./screenshots/subjectSearch.png)

条目详情整合作品信息、评分分布、收藏状态、剧集进度与关联条目，默认使用更紧凑的新布局，也可切回原版。

![条目详情：查看作品信息、评分与剧集进度](./screenshots/subjectDetail.png)

登录 Bangumi 后，可按收藏状态集中浏览自己的追番列表。

![用户收藏：同步并管理 Bangumi 收藏](./screenshots/userCollection.png)

### 订阅与下载

BMF 工作台把番剧、RSS 订阅和本地目录组织成一个关联，可按更新状态、季度和关键词快速筛选。

![BMF 工作台：集中管理番剧、RSS 与本地目录](./screenshots/BMF.png)

选中关联后，可并排查看订阅内容与本地文件，并直接编辑、刷新或打开对应位置。

![BMF 关联详情：对照 RSS 更新与本地文件](./screenshots/BMF2.png)

应用聚合 Mikan、Comicat 与 AniBT 的最新资源，可从列表下载种子文件或直接添加到内置下载引擎（Windows）。Mikan 默认使用 `mikanani.kas.pub`，也可切换官方站或自定义镜像。

<table>
  <tr>
    <td width="50%">
      <strong>Mikan</strong><br>
      <img src="./screenshots/Mikan.png" alt="Mikan RSS 资源列表">
    </td>
    <td width="50%">
      <strong>Comicat</strong><br>
      <img src="./screenshots/Comicat.png" alt="Comicat RSS 资源列表">
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <strong>AniBT</strong><br>
      <img src="./screenshots/AniBT.png" alt="AniBT RSS 资源列表">
    </td>
  </tr>
</table>

Windows 下载管理页集中展示任务进度、速度、连接状态与做种信息，支持暂停、按文件选择、手动添加 HTTP / magnet / torrent，以及 Tracker 与限量做种。

![下载管理：查看任务进度与连接状态](./screenshots/download.png)

### 个性化与应用配置

Windows 内置播放器提供 Anime4K 轻量、标准和高质量超分，默认关闭，其中标准档为本项目自定义的中间组合，其余两档取自官方 Mode A。播放 1080p SDR 动画时，在 4K 播放区域选择“高质量”可请求 3840×2160 输出；信息窗显示请求/实际纹理尺寸。高质量使用较大的 CNN 模型，GPU 开销更高；小窗口按实际显示尺寸处理。

在统一设置页中调整主题、缓存与日志路径，配置下载引擎、Tracker、系统代理（以上三项仅 Windows），以及 Bangumi 账号与镜像站。

![应用设置：配置主题、缓存与目录，以及下载引擎与账号](./screenshots/settings.png)

## 依赖（按照字典序）

项目使用了如下依赖以实现相关功能：

- [Anime4K](https://github.com/bloc97/Anime4K) `4.0.1`：随包提供内置播放器超分所用的 GLSL 着色器，按 MIT 许可附带授权文本。
- [bt_download](https://github.com/BTMuli/bt_download) `0.2.0`：提供内置 BitTorrent 与 HTTP 多连接下载，并支持系统代理。
- [Drift](https://drift.simonbinder.eu/)：基于 SQLite 的本地数据库，保存应用配置、RSS、BMF 关联、Bangumi 收藏与播放进度等数据。
- [FlChart](https://app.flchart.dev/)：用于绘制条目评分柱状图。
- [Fluent UI](https://bdlukaa.github.io/fluent_ui/)：用于实现 Fluent Design 风格的 UI。
- [Hive CE](https://github.com/IO-Design-Team/hive_ce)：Hive v2 的社区延续版，用于保存导航、用户与 Tracker 等轻量本地数据。
- [media_kit](https://github.com/media-kit/media-kit)：提供内置播放器的 libmpv 渲染、字幕与原生超分接入。
- [Riverpod](https://riverpod.dev/)：用于状态管理与依赖注入。

## 参考（按照字典序）

- [Ani](https://github.com/open-ani/ani)
- [AniBT](https://anibt.net)
- [BangumiAPI(doc)](https://bangumi.github.io/api/)
- [BangumiAPI(server)](https://github.com/bangumi/server)
- [BangumiOAuth](https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md)
- [czy0729/Bangumi](https://github.com/czy0729/Bangumi)
- [KNKPAnime](https://github.com/KNKPA/KNKPAnime)

## Special Thanks（按照字典序）

- [Bangumi.tv](https://bangumi.tv)
- [BangumiData](https://github.com/bangumi-data/bangumi-data)

## License

[MIT](./LICENSE)
