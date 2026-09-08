import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/day_ordinal.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/ui/app.dart';
import 'package:settle/ui/screens/daily_result_sheet.dart';

import '../../app/harness.dart';

final DateTime _today = DateTime(2026, 9, 8, 12);
final int _ordinal = dayOrdinalOf(_today);

LastGameResult _result({int score = 4820, bool doubled = false}) =>
    LastGameResult(
      gameId: 'g',
      mode: GameMode.daily,
      score: score,
      baseCoins: 96,
      bonusCoins: 25,
      xp: 482,
      streakAfter: 12,
      elapsedMs: 214000,
      dayOrdinal: _ordinal,
      doubled: doubled,
    );

Future<Harness> _pump(
  WidgetTester tester, {
  LastGameResult? result,
  PlayerProfile Function(PlayerProfile)? profile,
}) async {
  final harness = Harness(now: _today);
  await harness.start();
  if (profile != null) {
    await harness.controller.mutate(
      (d) => d.copyWith(profile: profile(d.profile)),
    );
  }
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: settleTheme(harness.controller.palette),
      home: Scaffold(
        body: DailyResultSheet(controller: harness.controller, result: result),
      ),
    ),
  );
  return harness;
}

void main() {
  testWidgets('the final state shows the score, best, streak and coins', (
    tester,
  ) async {
    await _pump(
      tester,
      result: _result(),
      profile: (p) => p.copyWith(
        dailyBest: {_ordinal: 5200},
        dailyAttempts: {_ordinal: 2},
        streak: 12,
        lastCompletedOrdinal: _ordinal,
        dailySecondAttemptUsed: _ordinal,
      ),
    );

    expect(find.text('4,820'), findsOneWidget);
    expect(find.text('Best today'), findsOneWidget);
    expect(find.text('5,200'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('+1 today'), findsOneWidget);
    expect(find.text('+121'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('Try again is offered while the second attempt is unused', (
    tester,
  ) async {
    await _pump(
      tester,
      result: _result(),
      profile: (p) => p.copyWith(
        dailyBest: {_ordinal: 4820},
        dailyAttempts: {_ordinal: 1},
        streak: 12,
        lastCompletedOrdinal: _ordinal,
      ),
    );

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Double coins'), findsOneWidget);
  });

  testWidgets('reopened from Home it shows the day without the coin row', (
    tester,
  ) async {
    await _pump(
      tester,
      profile: (p) => p.copyWith(
        dailyBest: {_ordinal: 3300},
        dailyAttempts: {_ordinal: 1},
        streak: 4,
        lastCompletedOrdinal: _ordinal,
        dailySecondAttemptUsed: _ordinal,
      ),
    );

    expect(find.text('3,300'), findsNWidgets(2));
    expect(find.text('Coins'), findsNothing);
    expect(find.text('Double coins'), findsNothing);
    expect(find.text('Share'), findsOneWidget);
  });
}
