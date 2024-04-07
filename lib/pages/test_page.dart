import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../request/bangumi/bangumi_api.dart';
import '../request/bangumi/bangumi_oauth.dart';

/// 测试页面
class TestPage extends ConsumerStatefulWidget {
  /// 构造函数
  const TestPage({super.key});

  @override
  ConsumerState<TestPage> createState() => _TestPageState();
}

/// 测试页面状态
class _TestPageState extends ConsumerState<TestPage> {
  /// 请求客户端
  final BangumiAPI bangumiAPI = BangumiAPI();

  final BangumiOauth bangumiOauth = BangumiOauth();

  @override
  void initState() {
    super.initState();
  }

  /// 构建测试按钮
  Widget buildTest() {
    return Button(
      onPressed: () async {
        await bangumiOauth.openAuthorizePage();
      },
      child: Text('Test'),
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text('Test Page'),
      ),
      content: Center(
        child: buildTest(),
      ),
    );
  }
}
