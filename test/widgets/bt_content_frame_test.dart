import 'package:bangumi_today/widgets/common/bt_content_frame.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('constrains and centers content at multiple sizes', (
    tester,
  ) async {
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
          home: ScaffoldPage(
            content: BTContentFrame(
              child: const SizedBox(
                key: ValueKey('frame-child'),
                width: 1600,
                height: 200,
                child: Text('内容'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'overflow at $size');

      var rect = tester.getRect(find.byKey(const ValueKey('frame-child')));
      var expectedWidth = size.width < 1200 ? size.width : 1200.0;
      expect(rect.width, expectedWidth, reason: 'maxWidth at $size');
      expect(
        rect.left,
        (size.width - expectedWidth) / 2,
        reason: 'centered at $size',
      );

      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    }
  });

  testWidgets('narrow window keeps content full width', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const FluentApp(
        home: ScaffoldPage(
          content: BTContentFrame(child: SizedBox(height: 200)),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
