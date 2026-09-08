import 'package:flutter/material.dart';

import '../../app.dart';
import '../../meta/meta.dart';
import '../strings.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/coin_chip.dart';
import '../widgets/format.dart';
import '../widgets/sheet_scaffold.dart';

/// Design 7.5.
class StreakSheet extends StatelessWidget {
  const StreakSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final palette = controller.palette;
      final profile = controller.profile;
      final full = profile.freezesHeld >= Economy.maxFreezesHeld;
      final poor = profile.coins < Economy.freezeCost;
      return SheetScaffold(
        palette: palette,
        children: [
          Text(
            S.streakTitle,
            style: manrope(size: 15, weight: 700, color: palette.muted),
          ),
          const SizedBox(height: 12),
          SheetHeadline(value: formatCount(profile.streak), palette: palette),
          const SizedBox(height: 14),
          StatRow(
            label: S.streakFreezesHeld,
            palette: palette,
            value: S.streakFreezes(profile.freezesHeld),
          ),
          StatRow(
            label: S.overCoinsEarned,
            palette: palette,
            valueWidget: CoinChip(
              coins: profile.coins,
              palette: palette,
              size: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            S.streakFreezeExplain,
            style: manrope(size: 13, weight: 500, color: palette.faint),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: S.streakBuyFreeze,
            trailing: S.themesCoinLock(Economy.freezeCost),
            palette: palette,
            onPressed: full || poor ? null : controller.buyStreakFreeze,
          ),
          if (!full && poor)
            AppTextButton(
              label: S.streakGetCoins,
              palette: palette,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/shop');
              },
            )
          else
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
