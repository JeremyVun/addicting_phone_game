import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/ui/app.dart';

import 'harness.dart';

Future<void> _finishOneGame(Harness harness) async {
  await harness.controller.startClassic();
  await playToGameOver(harness.controller);
  await harness.controller.finishGame();
  await harness.controller.goHome();
}

void main() {
  test('the prompt is due after the second finished game and never again', () async {
    final harness = Harness();
    await harness.start();

    await _finishOneGame(harness);
    expect(harness.controller.profile.gamesCompleted, 1);
    expect(harness.controller.reminderPromptDue, isFalse);

    await _finishOneGame(harness);
    expect(
      harness.controller.profile.gamesCompleted,
      Economy.reminderPromptAfterGames,
    );
    expect(harness.controller.reminderPromptDue, isTrue);

    await harness.controller.declineReminderPrompt();
    expect(harness.controller.reminderPromptDue, isFalse);
    expect(harness.controller.profile.reminderPermissionAsked, isTrue);

    await _finishOneGame(harness);
    expect(harness.controller.reminderPromptDue, isFalse);
  });

  test('allowing the prompt records the grant and the permission answer', () async {
    final harness = Harness();
    await harness.start();
    await harness.controller.enableRemindersFromPrompt();

    expect(harness.notifications.permissionRequests, 1);
    expect(harness.controller.profile.remindersEnabled, isTrue);
    expect(harness.controller.profile.reminderPermissionAsked, isTrue);
    expect(
      harness.analytics.named('notification_permission').single.dims['granted'],
      'true',
    );

    final denied = Harness();
    await denied.start();
    denied.notifications.grantPermission = false;
    await denied.controller.enableRemindersFromPrompt();
    expect(denied.controller.profile.remindersEnabled, isFalse);
    expect(denied.controller.profile.reminderPermissionAsked, isTrue);
  });

  test('scheduling is the 19:00 of the next local date, and only when enabled', () async {
    final harness = Harness();
    await harness.start();

    await harness.controller.scheduleReminderIfEnabled();
    expect(harness.notifications.scheduled, isEmpty);

    await harness.controller.setRemindersEnabled(true);
    expect(harness.notifications.scheduled, [
      Reminders.nextReminderTime(harness.clock.now()),
    ]);

    await harness.controller.setRemindersEnabled(false);
    expect(harness.controller.profile.remindersEnabled, isFalse);
    expect(harness.notifications.cancels, 1);

    await harness.controller.scheduleReminderIfEnabled();
    expect(harness.notifications.scheduled, hasLength(1));
  });

  testWidgets('backgrounding schedules the reminder and reopening cancels it', (
    tester,
  ) async {
    final harness = Harness();
    await harness.start();
    await harness.controller.mutate(
      (d) =>
          d.copyWith(profile: d.profile.copyWith(remindersEnabled: true)),
    );
    harness.notifications.scheduled.clear();

    await tester.pumpWidget(SettleApp(harness.controller));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(harness.notifications.scheduled, [
      Reminders.nextReminderTime(harness.clock.now()),
    ]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(harness.notifications.cancels, 1);
  });
}
