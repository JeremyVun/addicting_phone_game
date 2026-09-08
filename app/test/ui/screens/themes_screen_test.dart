import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/ui/screens/themes_screen.dart';

import '../../app/harness.dart';
import 'fixtures.dart';

void main() {
  testWidgets('each slot shows its unlock state', (tester) async {
    final harness = Harness(now: fixtureNow);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(
          xp: Levels.xpForLevel(4),
          coins: 1600,
          selectedTheme: 2,
        ),
      ),
    );
    await pumpScreen(
      tester,
      harness,
      ThemesScreen(controller: harness.controller),
    );

    expect(find.text('Obsidian'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Select'), findsNWidgets(2));
    expect(find.text('Level 6'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Lagoon'), 200);
    expect(find.text('Level 30'), findsOneWidget);
    expect(find.text('Buy for 1500 coins'), findsOneWidget);
    expect(find.text('3000 coins'), findsOneWidget);
  });

  testWidgets('tapping an unlocked slot selects it and re-themes', (
    tester,
  ) async {
    final harness = Harness(now: fixtureNow);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(xp: Levels.xpForLevel(4))),
    );
    await pumpScreen(
      tester,
      harness,
      ThemesScreen(controller: harness.controller),
    );

    await tester.tap(find.text('Meadow'));
    await tester.pumpAndSettle();
    expect(harness.controller.profile.selectedTheme, 3);
    expect(harness.controller.palette.name, 'Meadow');
  });

  testWidgets('a coin theme is bought and selected in one tap', (tester) async {
    final harness = Harness(now: fixtureNow);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: 1600)),
    );
    await pumpScreen(
      tester,
      harness,
      ThemesScreen(controller: harness.controller),
    );

    await tester.scrollUntilVisible(find.text('Pearl'), 200);
    await tester.ensureVisible(find.text('Pearl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pearl'));
    await tester.pumpAndSettle();
    expect(harness.controller.profile.coins, 100);
    expect(harness.controller.profile.selectedTheme, 11);
  });
}
