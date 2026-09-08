import 'board.dart';
import 'cell.dart';
import 'director.dart';
import 'game_state.dart';
import 'piece.dart';
import 'rng.dart';
import 'scoring.dart';

class PlacementResult {
  const PlacementResult({
    required this.state,
    required this.cellsPlaced,
    required this.rowsCleared,
    required this.colsCleared,
    required this.cellsCleared,
    required this.placementPoints,
    required this.clearPoints,
    required this.boardClearPoints,
    required this.multiplier,
    required this.comboCount,
    required this.boardCleared,
    required this.newSetGenerated,
    required this.gameOver,
  });

  final GameState state;
  final List<Cell> cellsPlaced;
  final List<int> rowsCleared;
  final List<int> colsCleared;
  final List<Cell> cellsCleared;
  final int placementPoints;
  final int clearPoints;
  final int boardClearPoints;
  final int multiplier;
  final int comboCount;
  final bool boardCleared;
  final bool newSetGenerated;
  final bool gameOver;

  int get linesCleared => rowsCleared.length + colsCleared.length;

  int get pointsAwarded => placementPoints + clearPoints + boardClearPoints;
}

class Game {
  const Game._();

  static GameState newGame({
    required GameMode mode,
    required int seed,
    double skill = Director.skillMidpoint,
    bool restricted = false,
    int startedAtMs = 0,
    int? dayOrdinal,
  }) {
    final rng = Rng(seed);
    final board = Board.empty();
    final daily = mode == GameMode.daily;
    final effectiveSkill = daily ? Director.skillMidpoint : skill;
    final effectiveRestricted = !daily && restricted;
    final set = _generate(board, rng, 0, effectiveSkill, effectiveRestricted, 3);
    return GameState(
      id: '$seed-$startedAtMs',
      board: board,
      set: List.unmodifiable(set),
      score: 0,
      comboCount: 0,
      missCount: 0,
      setsGenerated: 1,
      continuesUsed: 0,
      rerollsUsed: 0,
      mode: mode,
      seed: seed,
      rng: rng,
      status: GameStatus.playing,
      skill: effectiveSkill,
      restricted: effectiveRestricted,
      startedAtMs: startedAtMs,
      elapsedMs: 0,
      dayOrdinal: dayOrdinal,
    );
  }

  static bool restrictedAt(GameState state) =>
      state.restricted && state.setsGenerated < onboardingSets;

  static const int onboardingSets = 3;

  static double pressureFor(int setsGenerated, double skill, bool restricted) =>
      (restricted && setsGenerated < onboardingSets)
          ? 0.0
          : Director.pressure(setsGenerated, skill);

  static double pressureAt(GameState state) =>
      pressureFor(state.setsGenerated, state.skill, state.restricted);

  static List<Piece> _generate(
    Board board,
    Rng rng,
    int setsGenerated,
    double skill,
    bool restricted,
    int count, {
    double? forcedPressure,
  }) {
    final restrictedNow = restricted && setsGenerated < onboardingSets;
    final p = forcedPressure ?? pressureFor(setsGenerated, skill, restricted);
    return Director.generateSet(board, rng, p, count,
        restricted: restrictedNow);
  }

  static PlacementResult place(GameState state, int slot, int row, int col) {
    if (slot < 0 || slot >= GameState.slotCount) {
      throw ArgumentError.value(slot, 'slot', 'out of range');
    }
    if (state.isOver) {
      throw ArgumentError('cannot place in a finished game');
    }
    final piece = state.set[slot];
    if (piece == null) {
      throw ArgumentError.value(slot, 'slot', 'already played');
    }
    if (!state.board.canPlace(piece, row, col)) {
      throw ArgumentError('$piece does not fit at ($row,$col)');
    }

    final placed = state.board.place(piece, row, col);
    final lines = placed.fullLines();
    final cleared = placed.clearLines(lines);
    final board = cleared.board;

    final combo = ComboState(state.comboCount, state.missCount)
        .afterPlacement(cleared: lines.count > 0);
    final multiplier = Scoring.multiplier(combo.comboCount);
    final placementPoints = Scoring.placementPoints(piece.size);
    final clearPoints = Scoring.clearPoints(lines.count) * multiplier;
    final boardCleared = board.isEmpty;
    final boardClearPoints = Scoring.boardClearPoints(boardCleared);

    final slots = List<Piece?>.of(state.set)..[slot] = null;
    final rng = state.rng.clone();
    var setsGenerated = state.setsGenerated;
    var newSetGenerated = false;
    if (slots.every((p) => p == null)) {
      final next = _generate(
        board,
        rng,
        setsGenerated,
        state.skill,
        state.restricted,
        GameState.slotCount,
      );
      for (var i = 0; i < GameState.slotCount; i++) {
        slots[i] = next[i];
      }
      setsGenerated += 1;
      newSetGenerated = true;
    }

    final gameOver = !_anyFits(board, slots);
    final next = state.copyWith(
      board: board,
      set: List.unmodifiable(slots),
      score: state.score + placementPoints + clearPoints + boardClearPoints,
      comboCount: combo.comboCount,
      missCount: combo.missCount,
      setsGenerated: setsGenerated,
      rng: rng,
      status: gameOver ? GameStatus.over : GameStatus.playing,
    );

    return PlacementResult(
      state: next,
      cellsPlaced: List.unmodifiable(
        [for (final c in piece.cells) Cell(row + c.row, col + c.col)],
      ),
      rowsCleared: List.unmodifiable(lines.rows),
      colsCleared: List.unmodifiable(lines.cols),
      cellsCleared: List.unmodifiable(cleared.cells),
      placementPoints: placementPoints,
      clearPoints: clearPoints,
      boardClearPoints: boardClearPoints,
      multiplier: multiplier,
      comboCount: combo.comboCount,
      boardCleared: boardCleared,
      newSetGenerated: newSetGenerated,
      gameOver: gameOver,
    );
  }

  static bool _anyFits(Board board, List<Piece?> slots) {
    for (final piece in slots) {
      if (piece != null && board.anyPlacement(piece)) return true;
    }
    return false;
  }

  /// Design 6. Score, combo and `setsGenerated` survive; the clear itself
  /// awards nothing.
  static GameState continueGame(GameState state) {
    if (state.continuesUsed >= GameState.maxContinues) {
      throw StateError('continue already used');
    }
    final rows = List<int>.generate(Board.size, (i) => i)
      ..sort((a, b) {
        final diff = _rowFill(state.board, b) - _rowFill(state.board, a);
        return diff != 0 ? diff : a - b;
      });
    final board = state.board
        .clearLines(FullLines(rows.take(3).toList()..sort(), const []))
        .board;
    final rng = state.rng.clone();
    final set = _generate(
      board,
      rng,
      state.setsGenerated,
      state.skill,
      state.restricted,
      GameState.slotCount,
      forcedPressure: 0.0,
    );
    return state.copyWith(
      board: board,
      set: List.unmodifiable(set),
      continuesUsed: state.continuesUsed + 1,
      rng: rng,
      status: _anyFits(board, set) ? GameStatus.playing : GameStatus.over,
    );
  }

  static int _rowFill(Board board, int row) {
    var n = 0;
    for (var c = 0; c < Board.size; c++) {
      if (board.cellAt(row, c) != null) n++;
    }
    return n;
  }

  /// Design 6. Throws once [GameState.maxRerolls] have been used.
  static GameState reroll(GameState state) {
    if (state.isOver) throw StateError('cannot reroll a finished game');
    if (state.rerollsUsed >= GameState.maxRerolls) {
      throw StateError('no rerolls left');
    }
    final open = [
      for (var i = 0; i < state.set.length; i++)
        if (state.set[i] != null) i,
    ];
    if (open.isEmpty) throw StateError('nothing to reroll');
    final rng = state.rng.clone();
    final pieces = _generate(
      state.board,
      rng,
      state.setsGenerated,
      state.skill,
      state.restricted,
      open.length,
    );
    final slots = List<Piece?>.of(state.set);
    for (var i = 0; i < open.length; i++) {
      slots[open[i]] = pieces[i];
    }
    return state.copyWith(
      set: List.unmodifiable(slots),
      rerollsUsed: state.rerollsUsed + 1,
      rng: rng,
      status:
          _anyFits(state.board, slots) ? GameStatus.playing : GameStatus.over,
    );
  }

  static GameState withElapsed(GameState state, int elapsedMs) =>
      state.copyWith(elapsedMs: elapsedMs);
}
