import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../store/nav_store.dart';

/// bangumi 用户界面
class BangumiUser extends ConsumerStatefulWidget {
  /// 构造函数
  const BangumiUser({super.key});

  @override
  ConsumerState<BangumiUser> createState() => _BangumiUserState();
}

/// bangumi 用户界面状态
class _BangumiUserState extends ConsumerState<BangumiUser> {
  @override
  void initState() {
    super.initState();
  }

  /// 构建顶部栏
  Widget buildHeader() {
    var titleW = Text('Bangumi 用户界面');
    return PageHeader(
      title: titleW,
      leading: IconButton(
        icon: Icon(FluentIcons.back),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItemByTitle(titleW.toString());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: buildHeader(),
      content: Center(
        child: Text('bangumi 用户界面'),
      ),
    );
  }
}
