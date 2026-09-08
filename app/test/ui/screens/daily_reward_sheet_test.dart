import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/ui/screens/daily_reward_sheet.dart';

import '../../app/harness.dart';
import 'fixtures.dart';

void main() {
  testWidgets('the sheet names the cycle day and its coins', (tester) async {
    final harness = Harness(
      saved: envelope(
        profile: PlayerProfile.initial(
          analyticsUnitId: 'u',
          now: fixtureNow.subtract(const Duration(days: 5)),
        ).copyWith(rewardCycleDay: 4, lastRewardClaimOrdinal: fixtureOrdinal - 1),
      ),
      now: fixtureNow,
    );
    await harness.start();
    await pumpScreen(
      tester,
      harness,
      DailyRewardSheet(controller: harness.controller),
    );

    expect(find.text('DAY 4 OF 7'), findsOneWidget);
    expect(find.text('+${Economy.dailyRewardCycle[3]}'), findsOneWidget);
    expect(find.text('Claim'), findsOneWidget);

    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();
    expect(harness.controller.profile.coins, Economy.dailyRewardCycle[3]);
  });

  testWidgets('Not now suppresses the offer for the day', (tester) async {
    final harness = Harness(
      saved: envelope(
        profile: PlayerProfile.initial(
          analyticsUnitId: 'u',
          now: fixtureNow.subtract(const Duration(days: 5)),
        ),
      ),
      now: fixtureNow,
    );
    await harness.start();
    await pumpScreen(
      tester,
      harness,
      DailyRewardSheet(controller: harness.controller),
    );

    expect(find.text('DAY 1 OF 7'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(harness.controller.dailyRewardClaimable, isFalse);
    expect(harness.controller.profile.coins, 0);
  });
}
