import 'package:flutter_test/flutter_test.dart';
import 'package:settle/ui/strings.dart';
import 'package:settle/app.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/ui/screens/streak_sheet.dart';

import '../../app/harness.dart';
import 'fixtures.dart';

Future<Harness> _pump(
  WidgetTester tester,
  PlayerProfile Function(PlayerProfile) profile,
) async {
  final harness = Harness(now: fixtureNow);
  await harness.start();
  await harness.controller.mutate(
    (d) => d.copyWith(profile: profile(d.profile)),
  );
  await pumpScreen(
    tester,
    harness,
    StreakSheet(controller: harness.controller),
  );
  return harness;
}

void main() {
  testWidgets('buying a freeze spends 200 coins', (tester) async {
    final harness = await _pump(
      tester,
      (p) => p.copyWith(streak: 9, freezesHeld: 0, coins: 260),
    );

    expect(find.text('9'), findsOneWidget);
    expect(find.text('Coins'), findsOneWidget);
    expect(find.text('0 of 2 freezes'), findsOneWidget);
    expect(
      find.text('A freeze keeps your streak if you miss one day.'),
      findsOneWidget,
    );

    await tester.tap(find.text(S.streakBuyFreeze(200)));
    await tester.pumpAndSettle();
    expect(harness.controller.profile.freezesHeld, 1);
    expect(harness.controller.profile.coins, 60);
  });

  testWidgets('under 200 coins the button is disabled and Get coins appears', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      (p) => p.copyWith(streak: 3, freezesHeld: 1, coins: 150),
    );

    expect(find.text('1 of 2 freezes'), findsOneWidget);
    expect(find.text('Get coins'), findsOneWidget);
    expect(harness.controller.canBuyStreakFreeze, isFalse);

    await tester.tap(find.text(S.streakBuyFreeze(200)));
    await tester.pumpAndSettle();
    expect(harness.controller.profile.freezesHeld, 1);
    expect(harness.controller.profile.coins, 150);
  });

  testWidgets('at two freezes held the purchase is refused', (tester) async {
    final harness = await _pump(
      tester,
      (p) => p.copyWith(
        streak: 30,
        freezesHeld: Economy.maxFreezesHeld,
        coins: 5000,
      ),
    );

    expect(find.text('2 of 2 freezes'), findsOneWidget);
    expect(find.text('Get coins'), findsNothing);
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text(S.streakBuyFreeze(200)));
    await tester.pumpAndSettle();
    expect(harness.controller.profile.coins, 5000);
  });
}
