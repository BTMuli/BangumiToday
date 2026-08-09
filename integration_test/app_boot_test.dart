import 'package:bangumi_today/main.dart' as app;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 桌面关键旅程：真实启动应用并进入“应用设置”页。
///
/// CI 执行：`flutter test integration_test -d windows`
void main() {
  var binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 让后台服务初始化等真实异步持续推进，避免测试停在首帧。
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('应用启动并可进入应用设置', (tester) async {
    await app.main();

    // 主界面在后台服务初始化完成后出现；用有界轮询等待，
    // 避免 pumpAndSettle 被持续动画（acrylic/进度环）卡住。
    var navVisible = false;
    for (var i = 0; i < 60 && !navVisible; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      navVisible = find.byType(NavigationView).evaluate().isNotEmpty;
    }
    expect(navVisible, isTrue, reason: '应用主界面未在 30 秒内出现');

    var semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    // compact 导航栏中“应用设置”仅渲染图标，需按语义标签定位。
    var settingsEntry = find.bySemanticsLabel(RegExp(r'^应用设置'));
    expect(settingsEntry, findsOneWidget, reason: '未找到“应用设置”导航项');
    await tester.tap(settingsEntry);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('配置应用、下载引擎与 Bangumi 账号'),
      findsOneWidget,
      reason: '设置页未渲染',
    );
    semantics.dispose();
  });
}
