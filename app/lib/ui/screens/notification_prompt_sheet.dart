import 'package:flutter/material.dart';

import '../../app.dart';
import '../strings.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/sheet_scaffold.dart';

/// Design 10: asked once, "Not now" never re-asks.
class NotificationPromptSheet extends StatelessWidget {
  const NotificationPromptSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    return SheetScaffold(
      palette: palette,
      children: [
        Text(
          S.notifyPromptTitle,
          style: manrope(size: 22, weight: 800, color: palette.ink),
        ),
        const SizedBox(height: 8),
        Text(
          S.notifyPromptBody,
          style: manrope(size: 15, weight: 500, color: palette.muted),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: S.notifyAllow,
          palette: palette,
          onPressed: () {
            controller.enableRemindersFromPrompt();
            Navigator.of(context).pop();
          },
        ),
        AppTextButton(
          label: S.notifyNotNow,
          palette: palette,
          onPressed: () {
            controller.declineReminderPrompt();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
