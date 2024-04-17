---
Author: 目棃
Description: 更新日志
Date: 2024-04-17
Update: 2024-04-17
---

> 本文档 [`Frontmatter`](https://github.com/BTMuli/MuCli#Frontmatter) 由 [MuCli](https://github.com/BTMuli/Mucli) 自动生成于 `2024-04-17 17:46:42`
>
> 更新于 `2024-04-17 17:46:42`

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
