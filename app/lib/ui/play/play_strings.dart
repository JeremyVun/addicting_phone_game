/// Every word the play screen can show. The copy pass moves this file whole.
abstract final class PlayStrings {
  static const score = 'SCORE';
  static const best = 'BEST';

  static String combo(int count) => 'Combo x$count';

  static String points(int amount) => '+$amount';

  /// Design 5.5, final Codex copy.
  static const hintFirstPlacement = 'Drag a block onto the grid';
  static const hintFirstClear = 'Fill a row or column to clear it';

  static String rerollPrice(int coins) => '$coins';

  static const pauseSemantics = 'Pause';
  static const rerollSemantics = 'Reroll';
}
