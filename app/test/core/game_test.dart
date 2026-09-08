import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/board.dart';
import 'package:settle/core/cell.dart';
import 'package:settle/core/director.dart';
import 'package:settle/core/game.dart';
import 'package:settle/core/game_state.dart';
import 'package:settle/core/piece.dart';
import 'package:settle/core/rng.dart';
import 'package:settle/core/scoring.dart';
import 'package:settle/core/sim/bots.dart';

GameState stateWith({
  required Board board,
  required List<Piece?> set,
  int score = 0,
  int comboCount = 0,
  int missCount = 0,
  int setsGenerated = 1,
  int continuesUsed = 0,
  int rerollsUsed = 0,
  GameStatus status = GameStatus.playing,
}) =>
    GameState(
      id: 'test-0',
      board: board,
      set: set,
      score: score,
      comboCount: comboCount,
      missCount: missCount,
      setsGenerated: setsGenerated,
      placements: 0,
      maxCombo: 0,
      boardClears: 0,
      continuesUsed: continuesUsed,
      rerollsUsed: rerollsUsed,
      mode: GameMode.classic,
      seed: 5,
      rng: Rng(5),
      status: status,
      skill: 0.5,
      restricted: false,
      startedAtMs: 0,
      elapsedMs: 0,
    );

/// Every empty cell is isolated, so only a dot fits and dropping one clears
/// nothing.
Board isolatedBoard() {
  final grid = List<String>.filled(Board.cellCount, '0');
  for (var r = 0; r < Board.size; r++) {
    grid[r * Board.size + r] = Board.emptyChar;
    grid[r * Board.size + (r + 4) % Board.size] = Board.emptyChar;
  }
  return Board.fromJson(grid.join());
}

void main() {
  test('newGame starts with three pieces and setsGenerated 1', () {
    final state = Game.newGame(mode: GameMode.classic, seed: 1, skill: 0.5);
    expect(state.board.isEmpty, isTrue);
    expect(state.set.length, 3);
    expect(state.set.whereType<Piece>().length, 3);
    expect(state.setsGenerated, 1);
    expect(state.status, GameStatus.playing);
    expect(state.score, 0);
    expect(state.id, '1-0');
    expect(state.dayOrdinal, isNull);
  });

  test('daily ignores the caller skill and restriction', () {
    GameState play(double skill, {required bool restricted}) {
      var state = Game.newGame(
        mode: GameMode.daily,
        seed: 42,
        skill: skill,
        restricted: restricted,
        dayOrdinal: 42,
      );
      const bot = GreedyBot();
      final rng = Rng(1);
      while (!state.isOver) {
        final move = bot.choose(state, rng);
        if (move == null) break;
        state = Game.place(state, move.slot, move.row, move.col).state;
      }
      return state;
    }

    final a = play(0.0, restricted: true);
    final b = play(1.0, restricted: false);
    expect(a.skill, Director.skillMidpoint);
    expect(a.restricted, isFalse);
    expect(a, b);
  });

  test('placement scoring follows design 2.4', () {
    final board = Board.fromJson([
      '0000000.',
      ...List.filled(7, '........'),
    ].join());
    final state = stateWith(board: board, set: [Piece.dot, null, null]);
    final result = Game.place(state, 0, 0, 7);
    expect(result.rowsCleared, [0]);
    expect(result.colsCleared, isEmpty);
    expect(result.cellsCleared.length, 8);
    expect(result.cellsPlaced, [const Cell(0, 7)]);
    expect(result.placementPoints, 1);
    expect(result.comboCount, 1);
    expect(result.multiplier, 1);
    expect(result.clearPoints, Scoring.clearPoints(1) * 1);
    expect(result.boardCleared, isTrue);
    expect(result.boardClearPoints, Scoring.boardClearBonus);
    expect(result.pointsAwarded, 1 + 10 + 300);
    expect(result.state.score, 311);
    expect(result.newSetGenerated, isTrue);
  });

  test('illegal placements throw', () {
    final state = Game.newGame(mode: GameMode.classic, seed: 3);
    expect(() => Game.place(state, 3, 0, 0), throwsArgumentError);
    expect(() => Game.place(state, -1, 0, 0), throwsArgumentError);
    final piece = state.set[0]!;
    expect(() => Game.place(state, 0, 8 - piece.height + 1, 0),
        throwsArgumentError);
    final after = Game.place(state, 0, 0, 0).state;
    expect(() => Game.place(after, 0, 0, 0), throwsArgumentError);
  });

  test('game over with pieces still in the set (design 2.3 first branch)', () {
    final board = isolatedBoard();
    expect(board.filledCount, 48);
    final o3 = Piece.byId['o3:0']!;
    final state = stateWith(board: board, set: [Piece.dot, o3, o3]);
    final result = Game.place(state, 0, 0, 0);
    expect(result.linesCleared, 0);
    expect(result.newSetGenerated, isFalse);
    expect(result.gameOver, isTrue);
    expect(result.state.status, GameStatus.over);
  });

  test('game over checks the freshly generated set (design 2.3 second branch)',
      () {
    final board = Board.fromJson('0' * 63 + Board.emptyChar);
    final state = stateWith(board: board, set: [Piece.dot, null, null]);
    final result = Game.place(state, 0, 7, 7);
    expect(result.linesCleared, greaterThan(0));
    expect(result.newSetGenerated, isTrue);
    expect(result.state.setsGenerated, 2);
    expect(result.state.status, GameStatus.playing);
  });

  test('an exhausted set is refilled before the game over check', () {
    final board = isolatedBoard();
    var over = 0;
    var alive = 0;
    for (var seed = 0; seed < 60; seed++) {
      final state = GameState(
        id: 'test-\$seed',
        board: board,
        set: [Piece.dot, null, null],
        score: 0,
        comboCount: 0,
        missCount: 0,
        setsGenerated: 1,
        placements: 0,
        maxCombo: 0,
        boardClears: 0,
        continuesUsed: 0,
        rerollsUsed: 0,
        mode: GameMode.classic,
        seed: seed,
        rng: Rng(seed),
        status: GameStatus.playing,
        skill: 0.5,
        restricted: false,
        startedAtMs: 0,
        elapsedMs: 0,
      );
      final result = Game.place(state, 0, 0, 0);
      expect(result.linesCleared, 0);
      expect(result.newSetGenerated, isTrue);
      expect(result.state.setsGenerated, 2);
      final fits = result.state.set
          .any((p) => result.state.board.anyPlacement(p as Piece));
      expect(result.gameOver, !fits);
      if (result.gameOver) {
        over++;
      } else {
        alive++;
      }
    }
    // The fit guarantee makes an unfit fresh set unreachable in practice, so
    // this branch of 2.3 keeps the game alive; the rule is still checked.
    expect(alive, 60);
    expect(over, 0);
  });

  test('setsGenerated advances only on normal sets and drives onboarding', () {
    var state = Game.newGame(
        mode: GameMode.classic, seed: 8, skill: 0.5, restricted: true);
    final restrictedFamilies = Director.restrictedFamilies.toSet();
    const bot = GreedyBot();
    final rng = Rng(2);
    final setsByIndex = <int, List<String>>{0: [for (final p in state.set) p!.family]};
    while (!state.isOver && state.setsGenerated < 6) {
      final move = bot.choose(state, rng);
      if (move == null) break;
      final result = Game.place(state, move.slot, move.row, move.col);
      state = result.state;
      if (result.newSetGenerated) {
        setsByIndex[state.setsGenerated - 1] = [
          for (final p in state.set) p!.family,
        ];
      }
    }
    for (var i = 0; i < 3; i++) {
      expect(setsByIndex[i], everyElement(isIn(restrictedFamilies)),
          reason: 'set generated at setsGenerated=$i must be restricted');
    }
    expect(Game.pressureFor(0, 0.5, true), 0.0);
    expect(Game.pressureFor(2, 0.5, true), 0.0);
    expect(Game.pressureFor(3, 0.5, true), Director.pressure(3, 0.5));
    expect(Game.pressureFor(3, 0.5, false), Director.pressure(3, 0.5));
  });

  test('continue clears the three fullest rows, ties topmost', () {
    final board = Board.fromJson([
      '00000000',
      '0000....',
      '00000000',
      '000.....',
      '00000000',
      '0.......',
      '000000..',
      '00......',
    ].join());
    final state = stateWith(
      board: board,
      set: [Piece.byId['o3:0']!, null, null],
      score: 1234,
      comboCount: 4,
      missCount: 1,
      setsGenerated: 9,
      status: GameStatus.over,
    );
    final after = Game.continueGame(state);
    for (final row in [0, 2, 4]) {
      for (var c = 0; c < Board.size; c++) {
        expect(after.board.cellAt(row, c), isNull, reason: 'row $row');
      }
    }
    expect(after.board.cellAt(6, 0), isNotNull);
    expect(after.board.filledCount, board.filledCount - 24);
    expect(after.set.whereType<Piece>().length, 3);
    expect(after.continuesUsed, 1);
    expect(after.setsGenerated, 9);
    expect(after.score, 1234);
    expect(after.comboCount, 4);
    expect(after.missCount, 1);
    expect(after.status, GameStatus.playing);
    expect(() => Game.continueGame(after), throwsStateError);
  });

  test('reroll replaces the remaining slots in slot order', () {
    for (final placed in [0, 1, 2]) {
      var state = Game.newGame(mode: GameMode.classic, seed: 21, skill: 0.5);
      const bot = GreedyBot();
      final rng = Rng(4);
      for (var i = 0; i < placed; i++) {
        final move = bot.choose(state, rng)!;
        state = Game.place(state, move.slot, move.row, move.col).state;
      }
      expect(state.remainingSlots, 3 - placed);
      final before = state.set.toList();
      final open = [
        for (var i = 0; i < 3; i++)
          if (before[i] != null) i,
      ];
      final expected = Director.generateSet(
        state.board,
        Rng.fromState(state.rng.state),
        Game.pressureAt(state),
        open.length,
      );
      final after = Game.reroll(state);
      for (var i = 0; i < open.length; i++) {
        expect(after.set[open[i]], same(expected[i]));
      }
      expect(after.rerollsUsed, 1);
      expect(after.setsGenerated, state.setsGenerated);
      expect(after.board, state.board);
      expect(after.remainingSlots, open.length);
      for (var i = 0; i < 3; i++) {
        if (before[i] == null) expect(after.set[i], isNull);
      }
    }
  });

  test('reroll is capped at three per game', () {
    var state = Game.newGame(mode: GameMode.classic, seed: 77, skill: 0.5);
    for (var i = 0; i < GameState.maxRerolls; i++) {
      state = Game.reroll(state);
    }
    expect(state.rerollsUsed, 3);
    expect(() => Game.reroll(state), throwsStateError);
  });

  test('withElapsed only touches elapsedMs', () {
    final state = Game.newGame(mode: GameMode.classic, seed: 9);
    final after = Game.withElapsed(state, 4321);
    expect(after.elapsedMs, 4321);
    expect(after.copyWith(elapsedMs: 0), state);
  });

  test('json round trips with deep equality including rng state', () {
    var state = Game.newGame(
      mode: GameMode.daily,
      seed: 260,
      dayOrdinal: 260,
      startedAtMs: 1770000000000,
    );
    const bot = GreedyBot();
    final rng = Rng(6);
    for (var i = 0; i < 25 && !state.isOver; i++) {
      final move = bot.choose(state, rng);
      if (move == null) break;
      state = Game.place(state, move.slot, move.row, move.col).state;
    }
    state = Game.withElapsed(state, 91000);
    final back = GameState.fromJson(state.toJson());
    expect(back, state);
    expect(back.hashCode, state.hashCode);
    expect(back.rng.state, state.rng.state);
    expect(back.toJson(), state.toJson());
    expect(state.toJson()['v'], 1);
    expect(state.toJson().containsKey('bestScore'), isFalse);

    final move = bot.choose(state, Rng(6))!;
    expect(Game.place(state, move.slot, move.row, move.col).state,
        Game.place(back, move.slot, move.row, move.col).state);
    final bad = state.toJson()..['v'] = 2;
    expect(() => GameState.fromJson(bad), throwsArgumentError);
  });

  test('same seed and same moves replay to the same final state', () {
    List<Move> moves(int seed) {
      final out = <Move>[];
      var state = Game.newGame(mode: GameMode.classic, seed: seed, skill: 0.7);
      const bot = GreedyBot();
      final rng = Rng(seed);
      while (!state.isOver) {
        final move = bot.choose(state, rng);
        if (move == null) break;
        out.add(move);
        state = Game.place(state, move.slot, move.row, move.col).state;
      }
      return out;
    }

    GameState replay(int seed, List<Move> moves) {
      var state = Game.newGame(mode: GameMode.classic, seed: seed, skill: 0.7);
      for (final move in moves) {
        state = Game.place(state, move.slot, move.row, move.col).state;
      }
      return state;
    }

    final script = moves(31415);
    expect(script.length, greaterThan(10));
    final a = replay(31415, script);
    final b = replay(31415, script);
    expect(a, b);
    expect(a.isOver, isTrue);
    expect(a.toJson(), b.toJson());
  });

  test('combo survives one miss across real placements', () {
    final board = Board.fromJson([
      '0000000.',
      '0000000.',
      ...List.filled(6, '........'),
    ].join());
    var state = stateWith(
      board: board,
      set: [Piece.dot, Piece.dot, Piece.dot],
    );
    var result = Game.place(state, 0, 0, 7);
    expect(result.comboCount, 1);
    state = result.state;
    result = Game.place(state, 1, 5, 5);
    expect(result.comboCount, 1);
    expect(result.state.missCount, 1);
    state = result.state;
    result = Game.place(state, 2, 1, 7);
    expect(result.comboCount, 2);
    expect(result.multiplier, 2);
    expect(result.clearPoints, Scoring.clearPoints(1) * 2);
  });

  test('running totals accumulate and survive continue and reroll', () {
    var state = Game.newGame(mode: GameMode.classic, seed: 4242, skill: 0.5);
    expect(state.placements, 0);
    expect(state.maxCombo, 0);
    expect(state.boardClears, 0);
    const bot = GreedyBot();
    final rng = Rng(4242);
    var moves = 0;
    var clears = 0;
    var best = 0;
    while (!state.isOver) {
      final move = bot.choose(state, rng);
      if (move == null) break;
      final result = Game.place(state, move.slot, move.row, move.col);
      moves++;
      if (result.boardCleared) clears++;
      if (result.comboCount > best) best = result.comboCount;
      state = result.state;
      expect(state.placements, moves);
      expect(state.maxCombo, best);
      expect(state.boardClears, clears);
    }
    expect(state.placements, greaterThan(10));
    expect(state.maxCombo, greaterThan(0));
    final continued = Game.continueGame(state);
    expect(continued.placements, state.placements);
    expect(continued.maxCombo, state.maxCombo);
    expect(continued.boardClears, state.boardClears);
    final rerolled = Game.reroll(continued);
    expect(rerolled.placements, continued.placements);
    expect(rerolled.maxCombo, continued.maxCombo);
    expect(rerolled.boardClears, continued.boardClears);
  });

  test('reroll ends the game when the new set does not fit', () {
    final state = stateWith(
      board: Board.fromJson('0' * Board.cellCount),
      set: [Piece.dot, null, null],
    );
    expect(state.board.isFull, isTrue);
    final after = Game.reroll(state);
    expect(after.rerollsUsed, 1);
    expect(after.remainingSlots, 1);
    expect(after.status, GameStatus.over);
    expect(() => Game.reroll(after), throwsStateError);
  });

  test('continue resumes play with a set that fits', () {
    final board = Board.fromJson([
      ...List.filled(3, '........'),
      ...List.filled(5, '00000000'),
    ].join());
    final state = stateWith(
      board: board,
      set: [Piece.dot, null, null],
      status: GameStatus.over,
    );
    final after = Game.continueGame(state);
    expect(after.status, GameStatus.playing);
    expect(after.continuesUsed, 1);
  });
}
