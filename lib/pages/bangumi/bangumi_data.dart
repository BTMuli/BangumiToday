import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../components/app/app_dialog.dart';
import '../../controller/app/progress_controller.dart';
import '../../database/app/app_config.dart';
import '../../database/bangumi/bangumi_data.dart';
import '../../models/bangumi/data_meta.dart';
import '../../request/bangumi/bangumi_data.dart';
import '../../request/core/github.dart';
import '../../store/nav_store.dart';

/// BangumiData相关页面
/// Repo：https://github.com/bangumi-data/bangumi-data
class BangumiDataPage extends ConsumerStatefulWidget {
  /// 构造函数
  const BangumiDataPage({super.key});

  @override
  ConsumerState<BangumiDataPage> createState() => _BangumiDataPageState();
}

/// BangumiData相关页面状态
class _BangumiDataPageState extends ConsumerState<BangumiDataPage> {
  /// 数据库-AppConfig
  final BtsAppConfig appConfig = BtsAppConfig();

  /// 数据库-BangumiData
  final BtsBangumiData bangumiData = BtsBangumiData();

  /// 客户端-GithubAPI
  final GithubAPI githubAPI = GithubAPI();

  /// 版本号
  late String? version = 'unknown';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await init();
    });
  }

  /// 初始化
  Future<void> init() async {
    var progress = AppProgress(
      context,
      title: '开始获取数据',
      text: '正在获取本地数据库版本',
      progress: null,
    );
    progress.start();
    version = await appConfig.read('bangumiDataVersion');
    setState(() {});
    if (version != '') {
      progress.update(title: '成功获取本地版本', text: version);
      await Future.delayed(Duration(milliseconds: 500));
      progress.end();
      return;
    }
    progress.update(title: '未获取到本地版本', text: '开始获取远程版本');
    var verRemote = await GithubAPI().getLatestRelease(
      'bangumi-data',
      'bangumi-data',
    );
    progress.update(text: '成功获取远程版本$verRemote，开始更新数据');
    await updateData(progress);
    await appConfig.write('bangumiDataVersion', verRemote);
    progress.update(text: '已更新到最新版本');
    await Future.delayed(Duration(seconds: 1));
    progress.end();
  }

  /// 更新数据
  Future<void> updateData(AppProgress? ap) async {
    var progress;
    if (ap == null) {
      progress = AppProgress(
        context,
        title: '开始获取数据',
        text: '正在获取JSON数据',
        progress: null,
      );
    } else {
      progress = ap;
    }
    var client = BTBangumiData();
    var rawData = await client.getBangumiData();
    progress.update(title: '成功获取数据', text: '正在写入数据');
    var cnt, total;
    var sites = [];
    for (var entry in rawData.siteMeta.entries) {
      sites.add(BangumiDataSiteFull.fromSite(entry.key, entry.value));
    }
    total = sites.length;
    cnt = 0;
    for (var site in sites) {
      progress.update(
        title: '写入站点数据 $cnt/$total',
        text: site.title,
        progress: (cnt / total) * 100,
      );
      await bangumiData.writeSite(site);
      cnt++;
      await Future.delayed(Duration(milliseconds: 200));
    }
    var items = rawData.items;
    total = items.length;
    cnt = 0;
    for (var item in items) {
      progress.update(
        title: '写入条目数据 $cnt/$total',
        text: item.title,
        progress: (cnt / total) * 100,
      );
      await bangumiData.writeItem(item);
      cnt++;
    }
    progress.update(text: '写入完成');
    if (ap == null) {
      progress.end();
    }
  }

  /// 构建顶部栏
  Widget buildHeader() {
    return PageHeader(
      title: Text('BangumiData'),
      leading: IconButton(
        icon: Icon(FluentIcons.back),
        onPressed: () {
          var title = Text('BangumiData');
          ref.read(navStoreProvider).removeNavItemByTitle(title.toString());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: buildHeader(),
      content: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          ListTile(
            leading: Icon(FluentIcons.git_graph),
            title: Text('BangumiData'),
            subtitle: Text(version ?? 'unknown'),
            onPressed: () async {
              await launchUrlString(
                'https://github.com/bangumi-data/bangumi-data',
              );
            },
          ),
          ListTile(
            leading: Icon(FluentIcons.cloud_download),
            title: Text('检测更新'),
            subtitle: Text('更新BangumiData数据'),
            onPressed: () async {
              var progress = AppProgress(
                context,
                title: '开始获取数据',
                text: '正在获取远程版本',
                progress: null,
              );
              progress.start();
              var remote = await githubAPI.getLatestRelease(
                'bangumi-data',
                'bangumi-data',
              );
              progress.update(title: '成功获取远程版本', text: remote);
              // 等待0.5秒
              await Future.delayed(Duration(milliseconds: 500));
              progress.end();
              // 等待0.5秒
              await Future.delayed(Duration(milliseconds: 500));
              var confirm = false;
              if (remote == version) {
                showConfirmDialog(
                  context,
                  title: '确认更新？',
                  content: '远程数据版本与本地版本一致($version)，是否强制更新？',
                  onSubmit: () {
                    confirm = true;
                  },
                );
              }
              if (confirm) {
                await updateData(null);
                await appConfig.write('bangumiDataVersion', remote);
              }
            },
          ),
        ],
      ),
    );
  }
}
