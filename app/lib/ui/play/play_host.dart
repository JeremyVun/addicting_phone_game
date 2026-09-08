import 'package:flutter/foundation.dart';

import '../../core/game.dart';
import '../../core/game_state.dart';
import '../theme/palettes.dart';

// The seam between the app shell and the Flame play screen (design 11, build plan 2b).
// Listeners fire on every state change the screen did not cause itself
// (reroll, continue, new game, theme change).
abstract class PlayHost implements Listenable {
  GameState get state;
  int get bestScore;
  int get coins;
  bool get rewardedRerollAvailable;
  int get rerollCoinPrice;
  bool get soundOn;
  bool get hapticsOn;
  bool get showFirstGameHints;
  ThemePalette get palette;
  PlacementResult place(int slot, int row, int col);
  void requestReroll();
  void requestPause();
  void onGameOver();
}
