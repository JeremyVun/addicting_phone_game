import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/ui/app.dart';
import 'package:settle/ui/screens/game_over_sheet.dart';

import '../../app/harness.dart';

Future<void> _pumpSheet(WidgetTester tester, Harness harness) => tester.pumpWidget(
  MaterialApp(
    theme: settleTheme(harness.controller.palette),
    home: Scaffold(body: GameOverSheet(controller: harness.controller)),
  ),
);

void main() {
  group('continue offer price label', () {
    testWidgets('shows Watch an ad when a rewarded ad is loaded', (tester) async {
      final harness = Harness();
      await harness.start();
      await harness.controller.startClassic();
      await playToGameOver(harness.controller);

      await _pumpSheet(tester, harness);

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Watch an ad'), findsOneWidget);
      expect(find.text('End game'), findsOneWidget);
    });

    testWidgets('shows the coin price when no rewarded ad is loaded', (tester) async {
      final harness = Harness();
      harness.ads.rewardedReady = false;
      await harness.start();
      await harness.controller.startClassic();
      await playToGameOver(harness.controller);

      await _pumpSheet(tester, harness);

      expect(find.text('Use 150 coins'), findsOneWidget);
    });

    testWidgets('shows Free for an ad-free buyer', (tester) async {
      final harness = Harness();
      await harness.start();
      await harness.controller.mutate(
        (d) => d.copyWith(profile: d.profile.copyWith(adFree: true)),
      );
      await harness.controller.startClassic();
      await playToGameOver(harness.controller);

      await _pumpSheet(tester, harness);

      expect(find.text('Free'), findsOneWidget);
    });
  });

  testWidgets('the final state shows score, coins, level and the actions', (tester) async {
    final harness = Harness();
    await harness.start();
    await harness.controller.startClassic();
    await playToGameOver(harness.controller);
    await harness.controller.endGame();
    final result = harness.controller.lastResult!;

    await _pumpSheet(tester, harness);

    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('NEW BEST'), findsOneWidget);
    expect(find.text('+${result.totalCoins}'), findsOneWidget);
    expect(find.text('Coins'), findsOneWidget);
    expect(find.text('Double coins'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
