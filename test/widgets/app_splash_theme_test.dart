// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/widgets/app/app_splash.dart';

void main() {
  Finder background(Color color) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color == color,
    );
  }

  Color? titleColor(WidgetTester tester) {
    return tester.widget<Text>(find.text('BangumiToday')).style?.color;
  }

  testWidgets('splash uses light colors in light theme mode', (tester) async {
    await tester.pumpWidget(const BTSplashScreen(themeMode: ThemeMode.light));
    await tester.pump();

    expect(background(const Color(0xFFF3F3F3)), findsOneWidget);
    expect(titleColor(tester), const Color(0xFF333333));
  });

  testWidgets('splash uses dark colors in dark theme mode', (tester) async {
    await tester.pumpWidget(const BTSplashScreen(themeMode: ThemeMode.dark));
    await tester.pump();

    expect(background(const Color(0xFF1B1B1B)), findsOneWidget);
    expect(titleColor(tester), const Color(0xFFF3F3F3));
  });

  testWidgets('splash follows system brightness in system theme mode', (
    tester,
  ) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await tester.pumpWidget(const BTSplashScreen(themeMode: ThemeMode.system));
    await tester.pump();

    expect(background(const Color(0xFF1B1B1B)), findsOneWidget);
    expect(titleColor(tester), const Color(0xFFF3F3F3));
  });

  testWidgets('splash stacks logo, title and loading row in order', (
    tester,
  ) async {
    await tester.pumpWidget(const BTSplashScreen(themeMode: ThemeMode.dark));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget, reason: '应有应用 LOGO');
    var logoBottom = tester.getBottomLeft(find.byType(Image)).dy;
    var titleTop = tester.getTopLeft(find.text('BangumiToday')).dy;
    expect(titleTop, greaterThan(logoBottom), reason: '应用名称应在 LOGO 下方');

    var loadingText = find.text('正在加载...');
    expect(loadingText, findsOneWidget);
    expect(
      titleTop,
      lessThan(tester.getTopLeft(loadingText).dy),
      reason: '加载描述应在应用名称下方',
    );

    var ring = find.byType(ProgressRing);
    expect(ring, findsOneWidget, reason: '加载描述左侧应有加载圈');
    expect(
      tester.getTopLeft(ring).dx,
      lessThan(tester.getTopLeft(loadingText).dx),
      reason: '加载圈应在描述文本左侧',
    );
    expect(
      tester.getCenter(ring).dy,
      closeTo(tester.getCenter(loadingText).dy, 2),
      reason: '加载圈与描述文本应在同一行',
    );
  });

  testWidgets('splash error state shows error icon instead of loading ring', (
    tester,
  ) async {
    await tester.pumpWidget(
      const BTSplashScreen(themeMode: ThemeMode.light, errorMessage: 'boom'),
    );
    await tester.pump();

    expect(find.byType(ProgressRing), findsNothing);
    expect(find.text('初始化失败，请重启应用后重试'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
  });
}
