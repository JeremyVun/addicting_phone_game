import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../meta/meta.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/coin_chip.dart';
import '../widgets/format.dart';
import '../widgets/sheet_scaffold.dart';

/// Design 6.1, daily final state. With no [result] it is the read-only reopen
/// from Home, which has only the day's numbers to show.
class DailyResultSheet extends StatelessWidget {
  const DailyResultSheet({super.key, required this.controller, this.result});

  final AppController controller;
  final LastGameResult? result;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final palette = controller.palette;
      final live = result;
      final day = live?.dayOrdinal ?? controller.today;
      final score = live?.score ?? controller.dailyBestToday;
      final streak = live?.streakAfter ?? controller.profile.streak;
      return SheetScaffold(
        palette: palette,
        children: [
          Text(
            S.dailyDay(day),
            style: manrope(size: 15, weight: 700, color: palette.muted),
          ),
          const SizedBox(height: 12),
          SheetLabel(text: S.playScore, palette: palette),
          const SizedBox(height: 2),
          SheetHeadline(
            value: formatCount(score),
            palette: palette,
            badge: live != null && controller.lastResultIsNewBest
                ? S.overNewBest
                : null,
          ),
          const SizedBox(height: 14),
          StatRow(
            label: S.dailyBestToday,
            palette: palette,
            value: formatCount(controller.dailyBestToday),
          ),
          StatRow(
            label: S.dailyStreakToday,
            palette: palette,
            valueWidget: _StreakValue(
              palette: palette,
              streak: streak,
              incrementedToday:
                  controller.profile.lastCompletedOrdinal == controller.today,
            ),
          ),
          if (live != null)
            StatRow(
              label: S.overCoinsEarned,
              palette: palette,
              valueWidget: CoinChip(
                coins: live.totalCoins,
                palette: palette,
                size: 15,
                accented: true,
                prefix: '+',
              ),
            ),
          const SizedBox(height: 18),
          if (live != null &&
              !live.doubled &&
              controller.doubleCoinsAvailable) ...[
            SecondaryButton(
              label: S.overDoubleCoins,
              palette: palette,
              showPlayIcon: true,
              onPressed: controller.doubleCoins,
            ),
            const SizedBox(height: 10),
          ],
          if (controller.secondDailyAttemptOffered) ...[
            PrimaryButton(
              label: S.dailySecondAttempt,
              palette: palette,
              showPlayIcon: true,
              onPressed: controller.startSecondDailyAttempt,
            ),
            const SizedBox(height: 8),
            Text(
              S.dailySecondAttemptSub,
              textAlign: TextAlign.center,
              style: manrope(size: 12, weight: 500, color: palette.faint),
            ),
            const SizedBox(height: 10),
          ],
          SecondaryButton(
            label: S.dailyShare,
            palette: palette,
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: S.dailyShareText(day, score, streak)),
            ),
          ),
          AppTextButton(
            label: S.overHome,
            palette: palette,
            onPressed: live != null
                ? controller.goHome
                : () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}

class _StreakValue extends StatelessWidget {
  const _StreakValue({
    required this.palette,
    required this.streak,
    required this.incrementedToday,
  });

  final ThemePalette palette;
  final int streak;
  final bool incrementedToday;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (incrementedToday) ...[
        Text(
          S.dailyStreakIncrement(1),
          style: manrope(size: 13, weight: 700, color: palette.accent),
        ),
        const SizedBox(width: 10),
      ],
      Text(
        '$streak',
        style: manrope(size: 15, weight: 800, color: palette.ink),
      ),
    ],
  );
}
