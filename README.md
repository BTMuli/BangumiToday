---
Author: 目棃
Description: 说明文档
Date: 2024-04-11
Update: 2024-05-01
---

> 本文档 [`Frontmatter`](https://github.com/BTMuli/MuCli#Frontmatter) 由 [MuCli](https://github.com/BTMuli/Mucli) 自动生成于 `2024-04-11 12:06:15`
>
> 更新于 `2024-05-01 02:58:48`

> **项目目前处于开发阶段，不保证稳定性。**

<div style="width:100%;display:flex;justify-content:center;align-items:center;margin:0 auto">
    <a href="./assets/images/logo.png">
      <img src="https://s2.loli.net/2024/04/18/xe7bEKiQMBCtPZo.png" alt="logo">
    </a>
</div>

[![](https://img.shields.io/github/license/BTMuli/BangumiToday)](./LICENSE)
[![](https://img.shields.io/github/v/release/BTMuli/BangumiToday)](https://github.com/BTMuli/BangumiToday/releases/latest)
[![](https://img.shields.io/github/last-commit/BTMuli/BangumiToday)](https://github.com/BTMuli/BangumiToday/commits/master/)
[![](https://img.shields.io/github/commits-since/BTMuli/BangumiToday/latest)](https://github.com/BTMuli/BangumiToday/commits/master/)

# BangumiToday

基于 [Bangumi.tv](https://bangumi.tv)、[蜜柑计划](https://mikanani.hacgn.fun/) 的番剧应用。

结合本地目录，提供番剧更新提醒、SSR订阅&下载、进度记录等功能。

## 开发

```shell
# build runner
dart run build_runner build --delete-conflicting-outputs
# build runner watch
dart run build_runner watch --delete-conflicting-outputs
# build windows
flutter build windows
# build msix --version 0.1.0.0
dart run msix:create --sign-msix true
```

## 使用前提

应用的良好使用体验**基于如下前提**：

1. 用户已经拥有 [Bangumi.tv](https://bangumi.tv) 账号，并且通过应用相关页面完成了登录授权。
2. 用户本地安装了 [Motrix](https://motrix.app/) 且将 `torrent` 默认关联到 Motrix。
3. 用户本地安装了 [PotPlayer](https://potplayer.daum.net/)。
4. 用户登录 Bangumi 账号后对收藏数据进行了同步。
5. 用户在特定条目页面设置了 `SSR` 订阅地址和下载目录。

## 发行

> 项目更新日志请查看 [CHANGELOG.md](./CHANGELOG.md)

应用预期会有如下几个发行渠道：

- [Github Release](https://github.com/BTMuli/BangumiToday/releases)：包括打包后的 `zip` 和 `msix` 文件（`msix` 视情况包括签名文件）。
- `Microsoft Store`：如果没有申请到 SignPath 的 OSS，应用将会发行到 Microsoft Store。
  > 在这种情况下，Github Release 会提供用于上传到 Microsoft Store 的 `msix` 文件。
- `Github Action`: 通过 Github Action 自动打包并发布到 Github Release。~~还在测试中~~

## 关于证书

> 截止 2024-05-02，应用使用的证书为自签名证书，需要将证书导入到系统。

为了正常安装应用，需要将 [BTMuli.cer](./BTMuli.cer) 证书导入到系统。

下载证书后，双击打开，选择`安装证书`，选择`本地计算机`，选择`将所有的证书都放入下列存储`，点击`浏览`，

选择`受信任的发布者`或者`受信任人`，点击`确定`，点击`下一步`，点击`完成`。

## 依赖（按照字典序）

项目使用了如下依赖以实现相关功能：

- [DTorrentTask](https://github.com/moham96/dtorrent_task)：用于 `torrent` 下载。
- [FlChart](https://app.flchart.dev/)：用于绘制条目评分柱状图。
- [Fluent UI](https://bdlukaa.github.io/fluent_ui/)：用于实现 Fluent Design 风格的 UI。
- [Hive](https://github.com/isar/hive)：用于本地数据存储。
- [MediaKit](https://github.com/media-kit/media-kit)：用于视频播放。

## 参考（按照字典序）

- [Ani](https://github.com/open-ani/ani)
- [BangumiAPI(doc)](https://bangumi.github.io/api/)
- [BangumiAPI(server)](https://github.com/bangumi/server)
- [BangumiOAuth](https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md)
- [czy0729/Bangumi](https://github.com/czy0729/Bangumi)

## Special Thanks（按照字典序）

- [Bangumi.tv](https://bangumi.tv)
- [BangumiData](https://github.com/bangumi-data/bangumi-data)

## License

[MIT](LICENSE)
