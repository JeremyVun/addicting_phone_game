import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/ui/app.dart';
import 'package:settle/ui/screens/pause_sheet.dart';

import '../../app/harness.dart';

void main() {
  testWidgets('the pause sheet toggles persist', (tester) async {
    final harness = Harness();
    await harness.start();
    await harness.controller.startClassic();

    await tester.pumpWidget(
      MaterialApp(
        theme: settleTheme(harness.controller.palette),
        home: Scaffold(body: PauseSheet(controller: harness.controller)),
      ),
    );

    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await harness.controller.idle;

    expect(harness.controller.soundOn, isFalse);
    expect((await harness.storage.load())!.profile.soundEnabled, isFalse);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await harness.controller.idle;

    expect(harness.controller.hapticsOn, isFalse);
    expect((await harness.storage.load())!.profile.hapticsEnabled, isFalse);
  });
}
