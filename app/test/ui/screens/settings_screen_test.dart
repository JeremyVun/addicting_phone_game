import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/ui/screens/settings_screen.dart';
import 'package:settle/ui/strings.dart';

import '../../app/harness.dart';

Widget wrap(AppController controller) =>
    MaterialApp(home: SettingsScreen(controller: controller));

void main() {
  testWidgets('shows the settings rows, without privacy options', (
    tester,
  ) async {
    final harness = Harness();
    await harness.start();
    await tester.pumpWidget(wrap(harness.controller));
    await tester.pumpAndSettle();

    expect(find.text(S.settingsSound), findsOneWidget);
    expect(find.text(S.settingsHaptics), findsOneWidget);
    expect(find.text(S.settingsReminder), findsOneWidget);
    expect(find.text(S.settingsRestore), findsOneWidget);
    expect(find.text(S.settingsPrivacyPolicy), findsOneWidget);
    expect(find.text(S.settingsPrivacyOptions), findsNothing);
  });

  testWidgets('privacy options appear only when the SDK requires them', (
    tester,
  ) async {
    final harness = Harness();
    harness.ads.privacyRequired = true;
    await harness.start();
    await tester.pumpWidget(wrap(harness.controller));
    await tester.pumpAndSettle();

    expect(find.text(S.settingsPrivacyOptions), findsOneWidget);
    await tester.tap(find.text(S.settingsPrivacyOptions));
    await tester.pumpAndSettle();
    expect(harness.ads.privacyOptionForms, 1);
  });

  testWidgets('the toggles write through to the profile', (tester) async {
    final harness = Harness();
    await harness.start();
    await tester.pumpWidget(wrap(harness.controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    expect(harness.controller.profile.remindersEnabled, isTrue);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(harness.controller.profile.soundEnabled, isFalse);
  });
}
