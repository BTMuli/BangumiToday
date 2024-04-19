import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../components/app/app_dialog.dart';
import '../../components/app/app_dialog_resp.dart';
import '../../controller/app/progress_controller.dart';
import '../../database/app/app_config.dart';
import '../../database/bangumi/bangumi_data.dart';
import '../../models/bangumi/bangumi_data_model.dart';
import '../../request/bangumi/bangumi_data.dart';
import '../../store/nav_store.dart';
import '../../tools/notifier_tool.dart';

/// BangumiData相关页面
/// Repo：https://github.com/bangumi-data/bangumi-data
class BangumiDataPage extends ConsumerStatefulWidget {
  /// 构造函数
  const BangumiDataPage({super.key});

  @override
  ConsumerState<BangumiDataPage> createState() => _BangumiDataPageState();
}

/// BangumiData相关页面状态
class _BangumiDataPageState extends ConsumerState<BangumiDataPage>
    with AutomaticKeepAliveClientMixin {
  /// 数据库-AppConfig
  final BtsAppConfig appConfig = BtsAppConfig();

  /// 数据库-BangumiData
  final BtsBangumiData bgmDataSqlite = BtsBangumiData();

  /// 请求客户端
  final BtrBangumiData bgmDataClient = BtrBangumiData();

  /// 版本号
  late String? version = 'unknown';

  /// progress
  late ProgressController progress = ProgressController();

  /// 保持状态
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await init();
    });
  }

  /// 初始化
  Future<void> init() async {
    progress = ProgressWidget.show(
      context,
      title: '开始获取数据',
      text: '正在获取本地数据库版本',
      progress: null,
    );
    version = await appConfig.read('bangumiDataVersion');
    setState(() {});
    if (version != '') {
      progress.update(title: '成功获取本地版本', text: version);
      await Future.delayed(const Duration(milliseconds: 500));
      progress.end();
      return;
    }
    progress.update(title: '未获取到本地版本', text: '开始获取远程版本');
    if (!mounted) {
      progress.end();
      return;
    }
    var confirm = await showConfirmDialog(
      context,
      title: '未获取到本地版本',
      content: '是否强制更新数据？',
    );
    if (!confirm) {
      progress.end();
      return;
    }
    progress.onTaskbar = true;
    var verGet = await bgmDataClient.getVersion();
    if (verGet.code != 0 || verGet.data == null) {
      progress.update(text: '获取远程版本失败');
      await Future.delayed(const Duration(seconds: 1));
      progress.end();
      if (mounted) showRespErr(verGet, context);
      return;
    }
    var verRemote = verGet.data as String;
    progress.update(text: '成功获取远程版本$verRemote，开始更新数据');
    await updateData();
    await appConfig.write('bangumiDataVersion', verRemote);
    progress.update(text: '已更新到最新版本');
    await Future.delayed(const Duration(seconds: 1));
    progress.end();
  }

  /// 更新数据
  Future<void> updateData() async {
    progress.update(title: '开始获取数据', text: '正在获取JSON数据', progress: null);
    progress.onTaskbar = true;
    var dataGet = await bgmDataClient.getData();
    if (dataGet.code != 0) {
      progress.update(text: '获取数据失败');
      await Future.delayed(const Duration(seconds: 1));
      progress.end();
      if (mounted) showRespErr(dataGet, context);
      return;
    }
    var rawData = dataGet.data as BangumiDataJson;
    progress.update(title: '成功获取数据', text: '正在写入数据');
    int cnt, total;
    var sites = [];
    for (var entry in rawData.siteMeta.entries) {
      sites.add(BangumiDataSiteFull.fromSite(entry.key, entry.value));
    }
    total = sites.length;
    cnt = 1;
    for (var site in sites) {
      progress.update(
        title: '写入站点数据 $cnt/$total',
        text: site.title,
        progress: (cnt / total) * 100,
      );
      await bgmDataSqlite.writeSite(site);
      cnt++;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    var items = rawData.items;
    total = items.length;
    cnt = 1;
    for (var item in items) {
      progress.update(
        title: '写入条目数据 $cnt/$total',
        text: item.title,
        progress: (cnt / total) * 100,
      );
      await bgmDataSqlite.writeItem(item);
      cnt++;
    }
    await BTNotifierTool.showMini(title: 'BangumiData', body: '数据更新完成');
  }

  /// 构建顶部栏
  Widget buildHeader() {
    return PageHeader(
      title: const Text('BangumiData'),
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItem('BangumiData');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      header: buildHeader(),
      content: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        children: [
          ListTile(
            leading: const Icon(FluentIcons.git_graph),
            title: const Text('BangumiData'),
            subtitle: Text(version ?? 'unknown'),
            onPressed: () async {
              await launchUrlString(
                'https://github.com/bangumi-data/bangumi-data',
              );
            },
          ),
          ListTile(
            leading: const Icon(FluentIcons.cloud_download),
            title: const Text('检测更新'),
            subtitle: const Text('更新BangumiData数据'),
            onPressed: () async {
              progress = ProgressWidget.show(
                context,
                title: '开始获取数据',
                text: '正在获取远程版本',
                progress: null,
              );
              var remoteGet = await bgmDataClient.getVersion();
              if (remoteGet.code != 0 || remoteGet.data == null) {
                progress.update(text: '获取远程版本失败');
                await Future.delayed(const Duration(seconds: 1));
                progress.end();
                if (context.mounted) showRespErr(remoteGet, context);
                return;
              }
              var remote = remoteGet.data as String;
              progress.update(title: '成功获取远程版本', text: remote);
              await Future.delayed(const Duration(milliseconds: 500));
              progress.end();
              if (!context.mounted) return;
              var confirm = await showConfirmDialog(
                context,
                title: '确认更新？',
                content: '远程版本：$remote，本地版本：$version',
              );
              if (confirm && context.mounted) {
                progress = ProgressWidget.show(
                  context,
                  title: '开始更新数据',
                  text: '正在更新数据',
                  progress: null,
                );
                await updateData();
                await appConfig.write('bangumiDataVersion', remote);
                progress.update(text: '已更新到最新版本');
                version = remote;
                setState(() {});
                await Future.delayed(const Duration(seconds: 1));
                progress.end();
              }
            },
          ),
        ],
      ),
    );
  }
}
