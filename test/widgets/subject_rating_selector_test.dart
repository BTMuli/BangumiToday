// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/widgets/bangumi/subject_detail/bsd_user_collection.dart';

void main() {
  testWidgets('评分选择器展示十个分块和两端分数', (tester) async {
    var selectedRating = 0;

    await tester.pumpWidget(
      FluentApp(
        home: Center(
          child: SubjectRatingSelector(
            rating: 4,
            onChanged: (rating) async {
              selectedRating = rating;
            },
          ),
        ),
      ),
    );

    expect(find.text('0分'), findsOneWidget);
    expect(find.text('10分'), findsOneWidget);
    for (var score = 1; score <= 10; score++) {
      expect(
        find.byKey(ValueKey('subject-rating-block-$score')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey('subject-rating-block-7')));
    await tester.pump();

    expect(selectedRating, 7);
  });
}
