---
Author: 目棃
Description: 说明文档
Date: 2024-04-11
Update: 2024-04-11
---

> 本文档 [`Frontmatter`](https://github.com/BTMuli/MuCli#Frontmatter) 由 [MuCli](https://github.com/BTMuli/Mucli) 自动生成于 `2024-04-11 12:06:15`
>
> 更新于 `2024-04-11 12:06:15`

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
# build msix 
dart run msix:create --version
```

因为数据库用的是 [`sqflite_common_ffi`](https://pub.dev/packages/sqflite_common_ffi)， 打包的时候需要 `sqlite3.dll`,
详见 [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi#windows)。

## 参考（按照字典序）

- [BangumiAPI](https://bangumi.github.io/api/)
- [BangumiOAuth](https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md)
- [Comicat](https://comicat.org)
- [czy0729/Bangumi](https://github.com/czy0729/Bangumi)
- [FlChart](https://app.flchart.dev/)
- [MikanProject](https://mikanime.tv)

## Special Thanks（按照字典序）

- [Bangumi.tv](https://bangumi.tv)
- [BangumiData](https://github.com/bangumi-data/bangumi-data)
