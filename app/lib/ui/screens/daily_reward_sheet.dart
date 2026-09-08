import 'package:flutter/material.dart';

import '../../app.dart';
import '../strings.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/coin_chip.dart';
import '../widgets/sheet_scaffold.dart';

/// Design 7.4.
class DailyRewardSheet extends StatelessWidget {
  const DailyRewardSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    return SheetScaffold(
      palette: palette,
      children: [
        Text(
          S.rewardTitle,
          style: manrope(size: 15, weight: 700, color: palette.muted),
        ),
        const SizedBox(height: 12),
        SheetLabel(
          text: S.rewardDay(controller.dailyRewardCycleDay),
          palette: palette,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            CoinChip(
              coins: controller.dailyRewardAmount,
              palette: palette,
              size: 40,
              accented: true,
              prefix: '+',
            ),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: S.rewardClaim,
          palette: palette,
          onPressed: () {
            controller.claimDailyReward();
            Navigator.of(context).pop();
          },
        ),
        AppTextButton(
          label: S.rewardNotNow,
          palette: palette,
          onPressed: () {
            controller.dismissDailyReward();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
