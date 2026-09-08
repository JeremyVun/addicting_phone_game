import 'package:flutter/material.dart';

import '../../app.dart';
import '../../meta/meta.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';
import '../widgets/coin_chip.dart';

/// Design 7.7.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    final done = controller.profile.achievements;
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        foregroundColor: palette.ink,
        elevation: 0,
        title: Text(
          S.achievementsTitle,
          style: manrope(size: 18, weight: 800, color: palette.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          for (final achievement in Achievements.all)
            _AchievementRow(
              palette: palette,
              achievement: achievement,
              done: done.contains(achievement.id),
            ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.palette,
    required this.achievement,
    required this.done,
  });

  final ThemePalette palette;
  final Achievement achievement;
  final bool done;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: done ? 1 : 0.62,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: manrope(size: 15, weight: 800, color: palette.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: manrope(size: 13, weight: 500, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CoinChip(
                coins: achievement.coins,
                palette: palette,
                size: 14,
                accented: done,
                prefix: '+',
              ),
              const SizedBox(height: 3),
              if (done)
                Text(
                  S.achievementsDone,
                  style: manrope(
                    size: 11,
                    weight: 800,
                    color: palette.accent,
                    letterSpacing: 1.2,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
