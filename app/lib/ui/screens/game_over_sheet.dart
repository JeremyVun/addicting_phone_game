import 'package:flutter/material.dart';

import '../../app.dart';
import '../../meta/meta.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/coin_chip.dart';
import '../widgets/format.dart';
import '../widgets/sheet_scaffold.dart';
import 'daily_result_sheet.dart';

class GameOverSheet extends StatelessWidget {
  const GameOverSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final result = controller.lastResult;
      if (result == null && controller.continueAvailable) {
        return _ContinueOffer(controller: controller);
      }
      if (result == null) return const SizedBox.shrink();
      if (result.mode == GameMode.daily) {
        return DailyResultSheet(controller: controller, result: result);
      }
      return _FinalResult(controller: controller, result: result);
    },
  );
}

class _ContinueOffer extends StatelessWidget {
  const _ContinueOffer({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    return SheetScaffold(
      palette: palette,
      children: [
        Text(
          S.overNoRoomTitle,
          style: manrope(size: 15, weight: 700, color: palette.muted),
        ),
        const SizedBox(height: 12),
        SheetLabel(text: S.playScore, palette: palette),
        const SizedBox(height: 2),
        SheetHeadline(
          value: formatCount(controller.state.score),
          palette: palette,
        ),
        const SizedBox(height: 14),
        StatRow(
          label: S.playBest,
          palette: palette,
          value: formatCount(controller.bestScore),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: S.overContinue,
          palette: palette,
          showPlayIcon:
              controller.continuePayment == ContinuePayment.rewarded,
          trailing: controller.continuePriceLabel,
          onPressed: controller.continueGame,
        ),
        const SizedBox(height: 8),
        Text(
          S.overContinueSub,
          textAlign: TextAlign.center,
          style: manrope(size: 12, weight: 500, color: palette.faint),
        ),
        const SizedBox(height: 4),
        AppTextButton(
          label: S.overEndGame,
          palette: palette,
          onPressed: controller.endGame,
        ),
      ],
    );
  }
}

class _FinalResult extends StatelessWidget {
  const _FinalResult({required this.controller, required this.result});

  final AppController controller;
  final LastGameResult result;

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    final profile = controller.profile;
    final newThemes = [
      for (final level in result.levelUps)
        ...Themes.all.where(
          (slot) =>
              slot.unlockKind == ThemeUnlockKind.level &&
              slot.requirement == level,
        ),
    ];
    return SheetScaffold(
      palette: palette,
      children: [
        SheetLabel(text: S.playScore, palette: palette),
        const SizedBox(height: 2),
        SheetHeadline(
          value: formatCount(result.score),
          palette: palette,
          badge: controller.lastResultIsNewBest ? S.overNewBest : null,
        ),
        const SizedBox(height: 14),
        StatRow(
          label: S.playBest,
          palette: palette,
          value: formatCount(controller.bestScoreFor(result)),
        ),
        StatRow(
          label: S.overCoinsEarned,
          palette: palette,
          valueWidget: CoinChip(
            coins: result.totalCoins,
            palette: palette,
            size: 15,
            accented: true,
            prefix: '+',
          ),
        ),
        StatRow(
          label: S.overLevel(profile.level),
          palette: palette,
          valueWidget: _LevelBar(palette: palette, progress: profile.levelProgress),
        ),
        const SizedBox(height: 10),
        for (final level in result.levelUps)
          _Note(text: S.overLevelUp(level), palette: palette),
        for (final theme in newThemes)
          _Note(text: S.overNewTheme(theme.name), palette: palette),
        for (final id in result.newAchievements)
          _Note(
            text: S.overAchievement(
              Achievements.byId(id).name,
              Achievements.byId(id).coins,
            ),
            palette: palette,
          ),
        const SizedBox(height: 8),
        if (!result.doubled && controller.doubleCoinsAvailable) ...[
          SecondaryButton(
            label: S.overDoubleCoins,
            palette: palette,
            showPlayIcon: true,
            onPressed: controller.doubleCoins,
          ),
          const SizedBox(height: 10),
        ],
        PrimaryButton(
          label: S.overPlayAgain,
          palette: palette,
          onPressed: controller.playAgain,
        ),
        AppTextButton(
          label: S.overHome,
          palette: palette,
          onPressed: controller.goHome,
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.palette});

  final String text;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(
      text,
      style: manrope(size: 13, weight: 600, color: palette.accent),
    ),
  );
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.palette, required this.progress});

  final ThemePalette palette;
  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    height: 6,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: palette.hairline,
        valueColor: AlwaysStoppedAnimation(palette.accent),
      ),
    ),
  );
}
