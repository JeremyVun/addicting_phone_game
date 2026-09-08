import 'dart:math' as math;

import 'economy.dart';

/// Design 7.2.
class Levels {
  const Levels._();

  static int xpForLevel(int level) => level <= 1
      ? 0
      : (Economy.levelXpFactor * math.pow(level - 1, Economy.levelXpExponent))
            .round();

  static int levelFor(int xp) {
    var level = 1;
    while (xpForLevel(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  static double progressWithinLevel(int xp) {
    final level = levelFor(xp);
    final floor = xpForLevel(level);
    final ceil = xpForLevel(level + 1);
    return ((xp - floor) / (ceil - floor)).clamp(0.0, 1.0);
  }

  static int levelUpReward(int newLevel) =>
      Economy.levelUpCoinsPerLevel * newLevel;
}
