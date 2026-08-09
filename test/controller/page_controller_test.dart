import 'dart:async';

import 'package:bangumi_today/controller/app/page_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignores page changes while a previous page is loading', () async {
    var calls = <int>[];
    var requestFinished = Completer<void>();
    var controller = BtcPageController(
      total: 3,
      cur: 1,
      onChanged: (page) async {
        calls.add(page);
        await requestFinished.future;
      },
    );

    var firstJump = controller.jump(2);
    expect(controller.isLoading, isTrue);

    await controller.jump(3);
    expect(calls, [2]);
    expect(controller.cur, 1);

    requestFinished.complete();
    await firstJump;
    expect(controller.isLoading, isFalse);
    expect(controller.cur, 2);
  });

  testWidgets('disables pagination controls while changing pages', (
    tester,
  ) async {
    var requestFinished = Completer<void>();
    var controller = BtcPageController(
      total: 3,
      cur: 1,
      onChanged: (_) async => requestFinished.future,
    );

    await tester.pumpWidget(FluentApp(home: PageWidget(controller)));
    var iconButtons = find.byType(IconButton);
    expect(iconButtons, findsNWidgets(2));
    expect(tester.widget<IconButton>(iconButtons.last).onPressed, isNotNull);

    var jump = controller.jump(2);
    await tester.pump();
    expect(tester.widget<IconButton>(iconButtons.last).onPressed, isNull);
    expect(find.byType(Button), findsNWidgets(3));

    requestFinished.complete();
    await jump;
    await tester.pump();
    expect(tester.widget<IconButton>(iconButtons.last).onPressed, isNotNull);
  });
}
