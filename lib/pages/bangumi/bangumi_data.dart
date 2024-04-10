import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  @override
  void initState() {
    super.initState();
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
      content: Center(
        child: Text('BangumiData'),
      ),
    );
  }
}
