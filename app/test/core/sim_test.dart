import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/board.dart';
import 'package:settle/core/game.dart';
import 'package:settle/core/game_state.dart';
import 'package:settle/core/piece.dart';
import 'package:settle/core/rng.dart';
import 'package:settle/core/sim/bots.dart';

void main() {
  test('greedy takes the clearing move', () {
    final board = Board.fromJson([
      '0000000.',
      ...List.filled(7, '........'),
    ].join());
    final state = GameState(
      id: 't',
      board: board,
      set: [Piece.dot, null, null],
      score: 0,
      comboCount: 0,
      missCount: 0,
      setsGenerated: 1,
      continuesUsed: 0,
      rerollsUsed: 0,
      mode: GameMode.classic,
      seed: 1,
      rng: Rng(1),
      status: GameStatus.playing,
      skill: 0.5,
      restricted: false,
      startedAtMs: 0,
      elapsedMs: 0,
    );
    final move = const GreedyBot().choose(state, Rng(1))!;
    expect(move.row, 0);
    expect(move.col, 7);
  });

  test('bots return null when nothing fits', () {
    final board = Board.fromJson('0' * (Board.cellCount - 1) + Board.emptyChar);
    final state = GameState(
      id: 't',
      board: board,
      set: [Piece.byId['o3:0']!, null, null],
      score: 0,
      comboCount: 0,
      missCount: 0,
      setsGenerated: 1,
      continuesUsed: 0,
      rerollsUsed: 0,
      mode: GameMode.classic,
      seed: 1,
      rng: Rng(1),
      status: GameStatus.playing,
      skill: 0.5,
      restricted: false,
      startedAtMs: 0,
      elapsedMs: 0,
    );
    expect(const GreedyBot().choose(state, Rng(1)), isNull);
    expect(const RandomBot().choose(state, Rng(1)), isNull);
  });

  test('a simulated game is reproducible and records every set', () {
    final a = playGame(const GreedyBot(), 1234, 0.5);
    final b = playGame(const GreedyBot(), 1234, 0.5);
    expect(a.score, b.score);
    expect(a.placements, b.placements);
    expect(a.sets.length, a.setsGenerated);
    expect(a.placements, greaterThan(10));
    for (final set in a.sets) {
      expect(set.fill, inInclusiveRange(0.0, 1.0));
      expect(set.pressure, inInclusiveRange(0.0, 1.0));
    }
    expect(a.sets.first.pressure, Game.pressureFor(0, 0.5, false));
  });

  test('random and greedy differ in length', () {
    var random = 0;
    var greedy = 0;
    for (var seed = 0; seed < 25; seed++) {
      random += playGame(const RandomBot(), seed, 0.5).placements;
      greedy += playGame(const GreedyBot(), seed, 0.5).placements;
    }
    expect(greedy, greaterThan(random * 2));
  });
}
