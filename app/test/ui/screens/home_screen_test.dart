import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/ui/app.dart';
import 'package:settle/ui/screens/home_screen.dart';

import '../../app/harness.dart';
import 'fixtures.dart';

void main() {
  testWidgets('Home renders the profile numbers', (tester) async {
    final harness = Harness();
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(coins: 1240, xp: 6285, streak: 12),
      ),
    );

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: settleTheme(harness.controller.palette),
        home: HomeScreen(controller: harness.controller),
      ),
    );

    expect(find.text('1,240'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('SETTLE'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Not played today'), findsOneWidget);
    expect(find.text('DAY STREAK'), findsOneWidget);
    expect(find.text('THEMES'), findsOneWidget);
    expect(find.text('SHOP'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
  });

  testWidgets('the daily card names its state and offers the second attempt', (
    tester,
  ) async {
    final harness = Harness(now: fixtureNow);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(
          dailyBest: {fixtureOrdinal: 3300},
          dailyAttempts: {fixtureOrdinal: 1},
        ),
      ),
    );
    await pumpScreen(
      tester,
      harness,
      HomeScreen(controller: harness.controller),
    );

    expect(harness.controller.dailyCardState, DailyCardState.done);
    expect(find.text('Today\u2019s score: 3,300'), findsOneWidget);
    expect(find.text('One more try is available'), findsOneWidget);
  });

  testWidgets('an unfinished daily reads as in progress and resumes', (
    tester,
  ) async {
    final harness = Harness(now: fixtureNow);
    await harness.start();
    await harness.controller.startDaily();
    harness.navigator.calls.clear();
    await pumpScreen(
      tester,
      harness,
      HomeScreen(controller: harness.controller),
    );

    expect(find.text('In progress'), findsOneWidget);
    await tester.tap(find.text('In progress'));
    await tester.pumpAndSettle();
    expect(harness.navigator.calls, ['goPlay']);
  });
}
