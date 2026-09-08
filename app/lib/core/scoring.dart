/// Design 2.4. Every number in this file is a rule number and lives nowhere
/// else in the codebase.
class Scoring {
  const Scoring._();

  static const int clearUnit = 10;
  static const int multiplierCap = 8;
  static const int boardClearBonus = 300;
  static const int missesToResetCombo = 2;
  static const int comboBannerThreshold = 2;

  static int placementPoints(int cells) => cells;

  static int clearPoints(int lines) => clearUnit * lines * (lines + 1) ~/ 2;

  static int multiplier(int comboCount) =>
      comboCount < multiplierCap ? comboCount : multiplierCap;

  static int boardClearPoints(bool boardCleared) =>
      boardCleared ? boardClearBonus : 0;
}

class ComboState {
  const ComboState(this.comboCount, this.missCount);

  final int comboCount;
  final int missCount;

  ComboState afterPlacement({required bool cleared}) {
    if (cleared) return ComboState(comboCount + 1, 0);
    final misses = missCount + 1;
    if (misses >= Scoring.missesToResetCombo) return const ComboState(0, 0);
    return ComboState(comboCount, misses);
  }

  @override
  bool operator ==(Object other) =>
      other is ComboState &&
      other.comboCount == comboCount &&
      other.missCount == missCount;

  @override
  int get hashCode => comboCount * 31 + missCount;

  @override
  String toString() => 'ComboState($comboCount,$missCount)';
}
