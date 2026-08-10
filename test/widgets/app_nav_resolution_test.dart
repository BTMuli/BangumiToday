// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/widgets/app/nav_item_icon.dart';

void main() {
  List<PaneItem> buildDynamicItems({int count = 50}) {
    return List.generate(count, (index) {
      var title = '动画详情 $index';
      return PaneItem(
        icon: NavItemIcon(
          title: title,
          onClose: () {},
          onCloseOthers: () {},
          onCloseAll: () {},
        ),
        title: Text(title),
        body: const SizedBox.shrink(),
      );
    });
  }

  testWidgets(
    '50-item dynamic nav renders without overflow at multiple sizes',
    (tester) async {
      const sizes = [
        Size(1280, 720),
        Size(1920, 1080),
        Size(2560, 1440),
        Size(960, 600),
      ];

      for (var size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          FluentApp(
            home: NavigationView(
              pane: NavigationPane(
                displayMode: PaneDisplayMode.compact,
                selected: 0,
                items: buildDynamicItems(),
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'overflow at $size');
        expect(find.byType(NavItemIcon), findsWidgets);
        expect(find.bySemanticsLabel(RegExp(r'^动画详情')), findsWidgets);

        tester.view.reset();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('long CJK titles ellipsize without overflow', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var longTitle =
        'とても長い日本語のタイトルで確認する「異世界おじさん」第１２話・最終回（前編）'
        '—— これはナビゲーションの省略を確認するための長いタイトルです';
    await tester.pumpWidget(
      FluentApp(
        home: NavigationView(
          pane: NavigationPane(
            displayMode: PaneDisplayMode.expanded,
            selected: 0,
            items: [
              PaneItem(
                icon: NavItemIcon(title: longTitle),
                title: Text(longTitle),
                body: const SizedBox.shrink(),
              ),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
