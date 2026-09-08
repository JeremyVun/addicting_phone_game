import '../board.dart';
import '../game.dart';
import '../game_state.dart';
import '../rng.dart';

class Move {
  const Move(this.slot, this.row, this.col);

  final int slot;
  final int row;
  final int col;
}

abstract class Bot {
  const Bot();

  String get name;

  Move? choose(GameState state, Rng rng);
}

class RandomBot extends Bot {
  const RandomBot();

  @override
  String get name => 'random';

  @override
  Move? choose(GameState state, Rng rng) {
    final legal = <Move>[];
    for (var slot = 0; slot < state.set.length; slot++) {
      final piece = state.set[slot];
      if (piece == null) continue;
      for (var r = 0; r + piece.height <= Board.size; r++) {
        for (var c = 0; c + piece.width <= Board.size; c++) {
          if (state.board.canPlace(piece, r, c)) legal.add(Move(slot, r, c));
        }
      }
    }
    if (legal.isEmpty) return null;
    return legal[rng.nextInt(legal.length)];
  }
}

/// 1-ply: most lines cleared, then most empty cells after clearing, then the
/// first found in (slot, row, col) order.
class GreedyBot extends Bot {
  const GreedyBot();

  @override
  String get name => 'greedy';

  @override
  Move? choose(GameState state, Rng rng) {
    Move? best;
    var bestLines = -1;
    var bestFilled = Board.cellCount + 1;
    for (var slot = 0; slot < state.set.length; slot++) {
      final piece = state.set[slot];
      if (piece == null) continue;
      for (var r = 0; r + piece.height <= Board.size; r++) {
        for (var c = 0; c + piece.width <= Board.size; c++) {
          if (!state.board.canPlace(piece, r, c)) continue;
          final preview = state.board.preview(piece, r, c);
          final lines = preview.linesCleared;
          if (lines > bestLines ||
              (lines == bestLines && preview.filledAfter < bestFilled)) {
            bestLines = lines;
            bestFilled = preview.filledAfter;
            best = Move(slot, r, c);
          }
        }
      }
    }
    return best;
  }
}

class GameRecord {
  GameRecord(this.score, this.placements, this.setsGenerated, this.sets);

  final int score;
  final int placements;
  final int setsGenerated;

  /// One entry per set returned by the director, board and pressure as they
  /// were at generation time (design 5.6).
  final List<GeneratedSet> sets;
}

class GeneratedSet {
  const GeneratedSet(this.fill, this.pressure, this.assisted);

  final double fill;
  final double pressure;
  final bool assisted;
}

GameRecord playGame(Bot bot, int seed, double skill, {bool restricted = false}) {
  final botRng = Rng(seed ^ 0x5deece66d);
  var state = Game.newGame(
    mode: GameMode.classic,
    seed: seed,
    skill: skill,
    restricted: restricted,
  );
  final sets = <GeneratedSet>[
    GeneratedSet(state.board.fill, _currentPressure(state), _assisted(state)),
  ];
  var placements = 0;
  while (!state.isOver) {
    final move = bot.choose(state, botRng);
    if (move == null) break;
    final result = Game.place(state, move.slot, move.row, move.col);
    state = result.state;
    placements++;
    if (result.newSetGenerated) {
      sets.add(GeneratedSet(
          state.board.fill, _currentPressure(state), _assisted(state)));
    }
  }
  return GameRecord(state.score, placements, state.setsGenerated, sets);
}

double _currentPressure(GameState state) => Game.pressureFor(
    state.setsGenerated - 1, state.skill, state.firstGameEver);

bool _assisted(GameState state) {
  for (final piece in state.set) {
    if (piece != null && state.board.hasLineCompletingPlacement(piece)) {
      return true;
    }
  }
  return false;
}
