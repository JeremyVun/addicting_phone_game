import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/board.dart';
import 'package:settle/core/director.dart';
import 'package:settle/core/game.dart';
import 'package:settle/core/game_state.dart';
import 'package:settle/core/piece.dart';
import 'package:settle/core/rng.dart';

Board gridOf(String rows) => Board.fromJson(rows.replaceAll('\n', ''));

String rowOf(bool Function(int col) filled) =>
    [for (var c = 0; c < Board.size; c++) filled(c) ? '0' : '.'].join();

/// A board with `target` cells that has no full row or column.
Board scatter(Random random, int target) {
  var board = Board.empty();
  var guard = 0;
  while (board.filledCount < target && guard < 4000) {
    guard += 1;
    final r = random.nextInt(Board.size);
    final c = random.nextInt(Board.size);
    if (board.cellAt(r, c) != null) continue;
    final next = board.place(Piece.dot, r, c);
    if (next.fullLines().isEmpty) board = next;
  }
  return board;
}

void main() {
  group('design 5.4 fit guarantee', () {
    test('a checkerboard, where only a dot fits, always gets a fitting set', () {
      final board = gridOf([
        for (var r = 0; r < Board.size; r++) rowOf((c) => (r + c).isEven),
      ].join());
      expect(board.fill, lessThan(Director.mercyFillThreshold));
      final rng = Rng(1);
      for (var i = 0; i < 500; i++) {
        for (var count = 1; count <= 3; count++) {
          final set = Director.generateSet(board, rng, 0.85, count);
          expect(set, hasLength(count));
          expect(set.any(board.anyPlacement), isTrue);
        }
      }
    });

    test('adversarial boards at every fill from 0 to 69% always get a fit', () {
      final random = Random(7);
      final rng = Rng(99);
      for (var filled = 0; filled <= 44; filled++) {
        for (var trial = 0; trial < 40; trial++) {
          final board = scatter(random, filled);
          if (board.fill >= Director.mercyFillThreshold) continue;
          final set = Director.generateSet(board, rng, 0.85, 3);
          expect(set.any(board.anyPlacement), isTrue,
              reason: 'fill ${board.filledCount}/64 got an unfit set');
        }
      }
    });

    test('a single free cell is served a dot at any pressure', () {
      for (var hole = 0; hole < Board.cellCount; hole++) {
        final grid = [
          for (var i = 0; i < Board.cellCount; i++) i == hole ? '.' : '0',
        ].join();
        final board = gridOf(grid);
        expect(board.filledCount, 63);
        final set = Director.generateSet(board, Rng(hole + 1), 0.5, 3);
        expect(set, hasLength(3));
      }
    });

    test('a full board is not rescued and reports an unfit set', () {
      final board = gridOf('0' * Board.cellCount);
      expect(board.isFull, isTrue);
      final set = Director.generateSet(board, Rng(3), 0.5, 3);
      expect(set.any(board.anyPlacement), isFalse);
    });

    test('mercy and assist never leave a set unplayable below 70% fill', () {
      final random = Random(11);
      final rng = Rng(5);
      for (var trial = 0; trial < 400; trial++) {
        final board = scatter(random, 20 + random.nextInt(24));
        if (board.fill >= Director.mercyFillThreshold) continue;
        for (final p in [0.0, 0.15, 0.5, 0.85, 1.0]) {
          final set = Director.generateSet(board, rng, p, 3);
          expect(set.any(board.anyPlacement), isTrue);
        }
      }
    });

    test('count is honoured for 1..3 and refused outside it', () {
      final board = scatter(Random(2), 30);
      for (var count = 1; count <= 3; count++) {
        expect(Director.generateSet(board, Rng(count), 0.4, count),
            hasLength(count));
      }
      expect(() => Director.generateSet(board, Rng(1), 0.4, 0), throwsArgumentError);
      expect(() => Director.generateSet(board, Rng(1), 0.4, 4), throwsArgumentError);
    });
  });

  group('design 5.5 setsGenerated boundary', () {
    test('sets 0, 1 and 2 are restricted and set 3 is not', () {
      const allowed = Director.restrictedFamilies;
      var restrictedSets = 0;
      var freeSets = 0;
      for (var seed = 0; seed < 60; seed++) {
        var state = Game.newGame(
            mode: GameMode.classic, seed: seed, restricted: true);
        expect(Game.restrictedAt(state), isTrue);
        expect(Game.pressureAt(state), 0.0);
        while (!state.isOver && state.setsGenerated <= Game.onboardingSets) {
          final generatedAt = state.setsGenerated;
          final move = _firstLegal(state);
          if (move == null) break;
          final result = Game.place(state, move.$1, move.$2, move.$3);
          state = result.state;
          if (!result.newSetGenerated) continue;
          final families = state.set.map((p) => p!.family);
          if (generatedAt < Game.onboardingSets) {
            expect(families, everyElement(isIn(allowed)));
            restrictedSets += 1;
          } else {
            freeSets += 1;
            expect(Game.restrictedAt(state), isFalse);
            expect(Game.pressureAt(state),
                Director.pressure(state.setsGenerated, state.skill));
          }
        }
      }
      expect(restrictedSets, greaterThan(0));
      expect(freeSets, greaterThan(0));
    });

    test('a reroll and a continue never advance setsGenerated', () {
      var state = Game.newGame(mode: GameMode.classic, seed: 4, restricted: true);
      final sets = state.setsGenerated;
      state = Game.reroll(state);
      expect(state.setsGenerated, sets);
      expect(Game.restrictedAt(state), isTrue);
      while (!state.isOver) {
        final move = _firstLegal(state)!;
        state = Game.place(state, move.$1, move.$2, move.$3).state;
      }
      final before = state.setsGenerated;
      expect(Game.continueGame(state).setsGenerated, before);
    });
  });
}

(int, int, int)? _firstLegal(GameState state) {
  for (var slot = 0; slot < GameState.slotCount; slot++) {
    final piece = state.set[slot];
    if (piece == null) continue;
    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        if (state.board.canPlace(piece, row, col)) return (slot, row, col);
      }
    }
  }
  return null;
}
