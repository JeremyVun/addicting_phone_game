import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/ui/app.dart';
import 'package:settle/ui/screens/home_screen.dart';

import '../../app/harness.dart';

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
}
