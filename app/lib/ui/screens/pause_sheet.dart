import 'package:flutter/material.dart';

import '../../app.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/sheet_scaffold.dart';

class PauseSheet extends StatelessWidget {
  const PauseSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final palette = controller.palette;
      return SheetScaffold(
        palette: palette,
        children: [
          SheetLabel(text: S.pauseTitle, palette: palette),
          const SizedBox(height: 16),
          _Toggle(
            label: S.pauseSound,
            value: controller.soundOn,
            palette: palette,
            onChanged: controller.setSound,
          ),
          _Toggle(
            label: S.pauseHaptics,
            value: controller.hapticsOn,
            palette: palette,
            onChanged: controller.setHaptics,
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: S.pauseResume,
            palette: palette,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppTextButton(
            label: S.pauseHome,
            palette: palette,
            onPressed: controller.goHome,
          ),
        ],
      );
    },
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ThemePalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: palette.hairline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: manrope(size: 15, weight: 700, color: palette.ink),
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: palette.onAccent,
          activeTrackColor: palette.accent,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
