// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/pages/rss-bmf/rb_pw_anibt.dart';
import 'package:bangumi_today/pages/rss-bmf/rb_pw_bmf.dart';
import 'package:bangumi_today/pages/rss-bmf/rb_pw_comicat.dart';
import 'package:bangumi_today/pages/rss-bmf/rb_pw_mikan.dart';
import 'package:bangumi_today/pages/rss-bmf/rss_bmf_page.dart';
import 'package:bangumi_today/store/bmf_store.dart';

void main() {
  testWidgets('does not mount source tabs until selected', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [bmfListProvider.overrideWith(_EmptyBmfList.new)],
        child: const FluentApp(home: RssBmfPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(RbpBmfWidget), findsOneWidget);
    expect(find.byType(RbpMikanWidget), findsNothing);
    expect(find.byType(RbpComicatWidget), findsNothing);
    expect(find.byType(RbpAnibtWidget), findsNothing);
  });
}

class _EmptyBmfList extends BmfListNotifier {
  @override
  Future<List<AppBmfModel>> build() async => [];
}
