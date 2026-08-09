import 'package:bangumi_today/widgets/app/nav_item_icon.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the first character of the title', (tester) async {
    await tester.pumpWidget(
      const FluentApp(
        home: ScaffoldPage(
          content: Center(child: NavItemIcon(title: 'とても長い日本語のタイトル')),
        ),
      ),
    );

    expect(find.text('と'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('falls back to a placeholder for empty titles', (tester) async {
    await tester.pumpWidget(
      const FluentApp(
        home: ScaffoldPage(
          content: Center(child: NavItemIcon(title: '  ')),
        ),
      ),
    );

    expect(find.text('#'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('right-click opens management menu and close all works', (
    tester,
  ) async {
    var closedAll = false;
    var closedOthers = false;
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: Center(
            child: NavItemIcon(
              title: '动画详情 12',
              onClose: () {},
              onCloseOthers: () {
                closedOthers = true;
              },
              onCloseAll: () {
                closedAll = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(NavItemIcon), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('关闭「动画详情 12」'), findsOneWidget);
    expect(find.text('关闭其他'), findsOneWidget);
    expect(find.text('关闭全部'), findsOneWidget);

    await tester.tap(find.text('关闭其他'));
    await tester.pumpAndSettle();
    expect(closedOthers, isTrue);
    expect(closedAll, isFalse);

    await tester.tap(find.byType(NavItemIcon), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭全部'));
    await tester.pumpAndSettle();
    expect(closedAll, isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('context menu key opens the management menu', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: Center(
            child: NavItemIcon(
              title: '动画详情 7',
              onClose: () {},
              onCloseOthers: () {},
              onCloseAll: () {},
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();

    expect(find.text('关闭「动画详情 7」'), findsOneWidget);
    expect(find.text('关闭全部'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
