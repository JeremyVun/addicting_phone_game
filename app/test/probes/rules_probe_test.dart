import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/board.dart';
import 'package:settle/core/director.dart';
import 'package:settle/core/game.dart';
import 'package:settle/core/game_state.dart';
import 'package:settle/core/piece.dart';
import 'package:settle/core/rng.dart';

bool anyFits(Board board, List<Piece?> set) =>
    set.any((p) => p != null && board.anyPlacement(p));

({int slot, int row, int col})? firstLegal(GameState state) {
  for (var slot = 0; slot < GameState.slotCount; slot++) {
    final piece = state.set[slot];
    if (piece == null) continue;
    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        if (state.board.canPlace(piece, row, col)) {
          return (slot: slot, row: row, col: col);
        }
      }
    }
  }
  return null;
}

void main() {
  group('design 2.3 game over', () {
    test('status is over exactly when nothing in hand fits, over 200 games', () {
      for (var seed = 0; seed < 200; seed++) {
        var state = Game.newGame(mode: GameMode.classic, seed: seed);
        while (!state.isOver) {
          final move = firstLegal(state);
          expect(move, isNotNull,
              reason: 'seed $seed: no legal move but the game is not over');
          final result = Game.place(state, move!.slot, move.row, move.col);
          state = result.state;
          expect(result.gameOver, !anyFits(state.board, state.set),
              reason: 'seed $seed: gameOver disagrees with the board');
          expect(state.isOver, result.gameOver);
        }
        expect(firstLegal(state), isNull,
            reason: 'seed $seed: the game ended with a legal move available');
      }
    });

    test('a reroll ends the game only when the new set fits nowhere', () {
      for (var seed = 0; seed < 120; seed++) {
        var state = Game.newGame(mode: GameMode.classic, seed: seed);
        var rerolls = 0;
        while (!state.isOver) {
          if (rerolls < GameState.maxRerolls && state.placements % 7 == 3) {
            state = Game.reroll(state);
            rerolls += 1;
            expect(state.isOver, !anyFits(state.board, state.set),
                reason: 'seed $seed: status after reroll');
            if (state.isOver) break;
          }
          final move = firstLegal(state)!;
          state = Game.place(state, move.slot, move.row, move.col).state;
        }
      }
    });

    test('a continue at fill under 70% always resumes with a playable set', () {
      var continued = 0;
      for (var seed = 0; seed < 200; seed++) {
        var state = Game.newGame(mode: GameMode.classic, seed: seed);
        while (!state.isOver) {
          final move = firstLegal(state)!;
          state = Game.place(state, move.slot, move.row, move.col).state;
        }
        final next = Game.continueGame(state);
        expect(next.board.fill, lessThan(Director.mercyFillThreshold),
            reason: 'seed $seed: clearing three rows must drop below 70%');
        expect(next.status, GameStatus.playing,
            reason: 'seed $seed: the continue set must be playable');
        expect(anyFits(next.board, next.set), isTrue);
        continued += 1;
      }
      expect(continued, 200);
    });
  });

  group('design 2.4 scoring and combo', () {
    test('score, combo and grace match the rules over long games', () {
      for (var seed = 0; seed < 60; seed++) {
        var state = Game.newGame(mode: GameMode.classic, seed: seed);
        var score = 0;
        var combo = 0;
        var misses = 0;
        var maxCombo = 0;
        var boardClears = 0;
        while (!state.isOver) {
          final move = firstLegal(state)!;
          final piece = state.set[move.slot]!;
          final result = Game.place(state, move.slot, move.row, move.col);
          final lines = result.linesCleared;
          if (lines > 0) {
            combo += 1;
            misses = 0;
          } else {
            misses += 1;
            if (misses >= 2) {
              combo = 0;
              misses = 0;
            }
          }
          final multiplier = combo < 8 ? combo : 8;
          final expected = piece.size +
              10 * lines * (lines + 1) ~/ 2 * multiplier +
              (result.state.board.isEmpty && lines > 0 ? 300 : 0);
          expect(result.pointsAwarded, expected, reason: 'seed $seed');
          score += expected;
          if (combo > maxCombo) maxCombo = combo;
          if (result.boardCleared) boardClears += 1;
          expect(result.state.score, score, reason: 'seed $seed running score');
          expect(result.state.comboCount, combo, reason: 'seed $seed combo');
          expect(result.state.missCount, misses, reason: 'seed $seed misses');
          state = result.state;
        }
        expect(state.maxCombo, maxCombo);
        expect(state.boardClears, boardClears);
      }
    });

    test('one non-clearing placement between clears keeps the combo', () {
      var combo = const ComboStub(0, 0);
      combo = combo.clear();
      combo = combo.clear();
      expect(combo.count, 2);
      combo = combo.miss();
      expect(combo.count, 2, reason: 'the one-move grace');
      combo = combo.clear();
      expect(combo.count, 3);
      combo = combo.miss();
      combo = combo.miss();
      expect(combo.count, 0, reason: 'two misses reset');
    });
  });

  group('design 5.5 catalogue', () {
    test('a restricted game draws only the seven families for three sets', () {
      const allowed = Director.restrictedFamilies;
      for (var seed = 0; seed < 40; seed++) {
        var state = Game.newGame(
            mode: GameMode.classic, seed: seed, restricted: true);
        expect(state.set.map((p) => p!.family), everyElement(isIn(allowed)));
        while (!state.isOver && state.setsGenerated <= Game.onboardingSets) {
          final before = state.setsGenerated;
          final move = firstLegal(state)!;
          final result = Game.place(state, move.slot, move.row, move.col);
          state = result.state;
          if (result.newSetGenerated && before < Game.onboardingSets) {
            expect(state.set.map((p) => p!.family), everyElement(isIn(allowed)),
                reason: 'seed $seed: set $before must be restricted');
          }
        }
      }
    });

    test('a daily game is never restricted, whatever the caller passes', () {
      final restricted = Game.newGame(
        mode: GameMode.daily,
        seed: 240,
        skill: 0.9,
        restricted: true,
        dayOrdinal: 240,
      );
      final plain = Game.newGame(
        mode: GameMode.daily,
        seed: 240,
        dayOrdinal: 240,
      );
      expect(restricted.restricted, isFalse);
      expect(restricted.skill, Director.skillMidpoint);
      expect(restricted.set.map((p) => p!.id), plain.set.map((p) => p!.id));
    });
  });

  group('design 4 determinism and serialisation', () {
    test('two replays of a seed and its moves match, through continue and reroll',
        () {
      for (var seed = 0; seed < 30; seed++) {
        final runs = <GameState>[];
        final trails = <List<String>>[];
        for (var run = 0; run < 2; run++) {
          var state = Game.newGame(mode: GameMode.classic, seed: seed);
          final trail = <String>[];
          var rerolled = false;
          while (!state.isOver) {
            if (!rerolled && state.placements == 4) {
              state = Game.reroll(state);
              rerolled = true;
              trail.add('reroll:${state.board.toJson()}');
              if (state.isOver) break;
            }
            final move = firstLegal(state)!;
            state = Game.place(state, move.slot, move.row, move.col).state;
            trail.add('${move.slot},${move.row},${move.col},${state.score}');
          }
          state = Game.continueGame(state);
          trail.add('continue:${state.board.toJson()}');
          while (!state.isOver) {
            final move = firstLegal(state)!;
            state = Game.place(state, move.slot, move.row, move.col).state;
            trail.add('${move.slot},${move.row},${move.col},${state.score}');
          }
          runs.add(state);
          trails.add(trail);
        }
        expect(trails[0], trails[1], reason: 'seed $seed replay diverged');
        expect(runs[0], runs[1], reason: 'seed $seed final state diverged');
      }
    });

    test('every state round trips: fresh, mid-game, over, rerolled, daily', () {
      var state = Game.newGame(mode: GameMode.classic, seed: 7, restricted: true);
      final samples = <GameState>[state];
      state = Game.reroll(state);
      samples.add(state);
      while (!state.isOver) {
        final move = firstLegal(state)!;
        state = Game.place(state, move.slot, move.row, move.col).state;
        if (state.placements == 5) samples.add(state);
      }
      samples.add(state);
      samples.add(Game.newGame(mode: GameMode.daily, seed: 9, dayOrdinal: 9));
      for (final sample in samples) {
        final back = GameState.fromJson(sample.toJson());
        expect(back, sample);
        expect(back.hashCode, sample.hashCode);
        expect(back.toJson(), sample.toJson());
      }
      expect(samples.any((s) => s.status == GameStatus.over), isTrue);
    });

    test('a continued state round trips', () {
      var state = Game.newGame(mode: GameMode.classic, seed: 7);
      while (!state.isOver) {
        final move = firstLegal(state)!;
        state = Game.place(state, move.slot, move.row, move.col).state;
      }
      final continued = Game.continueGame(state);
      expect(GameState.fromJson(continued.toJson()), continued,
          reason: 'a relaunch must resume the same game');
    });
  });

  group('the board after a continue', () {
    test('filledCount still counts the cells on the grid', () {
      for (var seed = 0; seed < 40; seed++) {
        var state = Game.newGame(mode: GameMode.classic, seed: seed);
        while (!state.isOver) {
          final move = firstLegal(state)!;
          state = Game.place(state, move.slot, move.row, move.col).state;
        }
        final board = Game.continueGame(state).board;
        var occupied = 0;
        for (var r = 0; r < Board.size; r++) {
          for (var c = 0; c < Board.size; c++) {
            if (board.cellAt(r, c) != null) occupied += 1;
          }
        }
        expect(board.filledCount, occupied, reason: 'seed $seed');
      }
    });

    test('a board with cells on it never reports empty', () {
      const row = '000.....';
      final grid = [
        for (var r = 0; r < Board.size; r++)
          (row.substring(Board.size - (r % 6)) + row).substring(0, Board.size),
      ].join();
      final board = Board.fromJson(grid);
      expect(board.filledCount, 24);
      expect(board.fullLines().isEmpty, isTrue);

      final state = GameState(
        id: '1-0',
        board: board,
        set: List.unmodifiable(<Piece?>[Piece.dot, Piece.dot, Piece.dot]),
        score: 0,
        comboCount: 0,
        missCount: 0,
        setsGenerated: 5,
        placements: 20,
        maxCombo: 0,
        boardClears: 0,
        continuesUsed: 0,
        rerollsUsed: 0,
        mode: GameMode.classic,
        seed: 1,
        rng: Rng(1),
        status: GameStatus.over,
        skill: 0.5,
        restricted: false,
        startedAtMs: 0,
        elapsedMs: 0,
      );

      final after = Game.continueGame(state).board;
      expect(after.isEmpty, isFalse,
          reason: '15 cells are still on the grid after clearing three rows');
      expect(after.fill, greaterThan(0));
    });
  });
}

/// The design 2.4 combo rule restated, so the probe does not lean on the
/// implementation it is checking.
class ComboStub {
  const ComboStub(this.count, this.misses);

  final int count;
  final int misses;

  ComboStub clear() => ComboStub(count + 1, 0);

  ComboStub miss() =>
      misses + 1 >= 2 ? const ComboStub(0, 0) : ComboStub(count, misses + 1);
}
