import 'package:flutter/material.dart';

import '../../app.dart';
import '../../meta/meta.dart';
import '../strings.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/sheet_scaffold.dart';

class RerollSheet extends StatelessWidget {
  const RerollSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final palette = controller.palette;
      if (!controller.canReroll) {
        return SheetScaffold(
          palette: palette,
          children: [
            SheetLabel(text: S.rerollTitle, palette: palette),
            const SizedBox(height: 12),
            Text(
              S.rerollLimit,
              style: manrope(size: 14, weight: 600, color: palette.muted),
            ),
            const SizedBox(height: 14),
            AppTextButton(
              label: S.commonClose,
              palette: palette,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      }
      return SheetScaffold(
        palette: palette,
        children: [
          SheetLabel(text: S.rerollTitle, palette: palette),
          const SizedBox(height: 8),
          Text(
            S.rerollSub,
            style: manrope(size: 13, weight: 500, color: palette.muted),
          ),
          const SizedBox(height: 18),
          if (controller.rewardedRerollAvailable) ...[
            PrimaryButton(
              label: S.rerollWatchAd,
              palette: palette,
              showPlayIcon: true,
              onPressed: () {
                Navigator.of(context).pop();
                controller.rerollWithAd();
              },
            ),
            const SizedBox(height: 10),
          ],
          SecondaryButton(
            label: S.rerollUseCoins(Economy.rerollCost),
            palette: palette,
            onPressed: controller.coins < Economy.rerollCost
                ? null
                : () {
                    Navigator.of(context).pop();
                    controller.rerollWithCoins();
                  },
          ),
          AppTextButton(
            label: S.commonClose,
            palette: palette,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}
