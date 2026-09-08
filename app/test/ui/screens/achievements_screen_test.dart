import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/ui/screens/achievements_screen.dart';

import '../../app/harness.dart';
import 'fixtures.dart';

void main() {
  testWidgets('all sixteen achievements with their rewards and Done state', (
    tester,
  ) async {
    final harness = Harness(now: fixtureNow);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(achievements: {'first_clear', 'combo_3'}),
      ),
    );
    await pumpScreen(
      tester,
      harness,
      AchievementsScreen(controller: harness.controller),
    );

    expect(Achievements.all, hasLength(16));
    expect(find.text('First clear'), findsOneWidget);
    expect(find.text('Clear your first line.'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('Done'), findsNWidgets(2));

    await tester.scrollUntilVisible(find.text('Level 10'), 200);
    expect(find.text('Reach level 10.'), findsOneWidget);
    expect(find.text('Thirty-day streak'), findsOneWidget);
    expect(find.text('+500'), findsOneWidget);
  });
}
