import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 测试页面
class TestPage extends ConsumerStatefulWidget {
  /// 构造函数
  const TestPage({super.key});

  @override
  ConsumerState<TestPage> createState() => _TestPageState();
}

/// 测试页面状态
class _TestPageState extends ConsumerState<TestPage> {
  @override
  void initState() {
    super.initState();
  }

  /// 构建测试按钮
  Widget buildTest() {
    return Button(
      onPressed: () async {},
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
