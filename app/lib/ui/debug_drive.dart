import 'package:flutter/material.dart';

import '../app.dart';
import 'theme/typography.dart';
import 'widgets/sheet_scaffold.dart';

/// TEMPORARY emulator-drive menu (phase 3b). Removed before the final commit.
void showDebugDrive(BuildContext context, AppController controller) {
  final palette = controller.palette;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0x00000000),
    builder: (sheetContext) => SheetScaffold(
      palette: palette,
      children: [
        for (final entry in <String, Future<void> Function()>{
          'Seed a played daily': controller.debugSeedPlayedDaily,
          'Open the daily result': controller.debugShowDailyResult,
          'Arm the reward sheet': controller.debugArmRewardSheet,
          'Arm the notification prompt': controller.debugArmNotificationPrompt,
          'Reminder in 2 minutes': controller.debugScheduleReminderSoon,
        }.entries)
          TextButton(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              entry.value();
            },
            child: Text(
              entry.key,
              style: manrope(size: 15, weight: 700, color: palette.ink),
            ),
          ),
      ],
    ),
  );
}
