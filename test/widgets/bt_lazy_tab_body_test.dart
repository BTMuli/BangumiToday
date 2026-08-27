// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/widgets/common/bt_lazy_tab_body.dart';

void main() {
  setUp(() => _InitProbe.initCount = 0);

  testWidgets('does not inflate child until visited', (tester) async {
    await tester.pumpWidget(
      const FluentApp(
        home: BtLazyTabBody(visited: false, child: _InitProbe(label: 'lazy')),
      ),
    );
    expect(_InitProbe.initCount, 0);
    expect(find.text('lazy'), findsNothing);

    await tester.pumpWidget(
      const FluentApp(
        home: BtLazyTabBody(visited: true, child: _InitProbe(label: 'lazy')),
      ),
    );
    await tester.pump();
    expect(_InitProbe.initCount, 1);
    expect(find.text('lazy'), findsOneWidget);
  });
}

class _InitProbe extends StatefulWidget {
  const _InitProbe({required this.label});

  final String label;

  static var initCount = 0;

  @override
  State<_InitProbe> createState() => _InitProbeState();
}

class _InitProbeState extends State<_InitProbe> {
  @override
  void initState() {
    super.initState();
    _InitProbe.initCount++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}
