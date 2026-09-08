import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/board.dart';
import 'package:settle/core/director.dart';
import 'package:settle/core/piece.dart';
import 'package:settle/core/rng.dart';

Board randomBoard(Rng rng, int targetFilled) {
  final cells = List<int>.generate(Board.cellCount, (i) => i);
  for (var i = cells.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = cells[i];
    cells[i] = cells[j];
    cells[j] = tmp;
  }
  final grid = List<String>.filled(Board.cellCount, Board.emptyChar);
  for (var i = 0; i < targetFilled; i++) {
    grid[cells[i]] = '0';
  }
  final board = Board.fromJson(grid.join());
  // A random fill can complete a line; the invariant is about the returned set.
  return board.clearLines(board.fullLines()).board;
}

Board checkerboard() => Board.fromJson([
      for (var r = 0; r < Board.size; r++)
        for (var c = 0; c < Board.size; c++)
          (r + c).isEven ? '0' : Board.emptyChar,
    ].join());

void main() {
  test('pressure follows design 5.2', () {
    expect(Director.pressure(0, 0.5), closeTo(0.15, 1e-12));
    expect(Director.pressure(20, 0.5), closeTo(0.50, 1e-12));
    expect(Director.pressure(40, 0.5), closeTo(0.85, 1e-12));
    expect(Director.pressure(400, 0.5), closeTo(0.85, 1e-12));
    expect(Director.pressure(40, 1.0), closeTo(1.0, 1e-12));
    expect(Director.pressure(0, 0.0), closeTo(0.0, 1e-12));
    expect(Director.pressure(20, 0.0), closeTo(0.35, 1e-12));
  });

  test('sampling weights follow design 5.3', () {
    for (final piece in Piece.all) {
      final base = piece.familyWeight / piece.familyRotations;
      final p = (Director.sizeBiasOffset) / Director.sizeBiasScale;
      expect(Director.pieceWeight(piece, p), closeTo(base, 1e-9));
    }
    final low = Director.pieceWeight(Piece.byId['o3:0']!, 0.0) /
        Director.pieceWeight(Piece.dot, 0.0);
    final high = Director.pieceWeight(Piece.byId['o3:0']!, 1.0) /
        Director.pieceWeight(Piece.dot, 1.0);
    expect(low, lessThan(high));
    expect(Director.weights(Piece.all, 0.4).length, Piece.all.length);
  });

  test('fit guarantee holds over 10,000 random boards below 70% fill', () {
    final rng = Rng(4242);
    final gen = Rng(99);
    for (var i = 0; i < 10000; i++) {
      final targetFilled = rng.nextInt(45);
      final board = randomBoard(rng, targetFilled);
      expect(board.fill, lessThan(Director.mercyFillThreshold));
      final p = rng.nextDouble();
      final count = 1 + rng.nextInt(3);
      final set = Director.generateSet(board, gen, p, count);
      expect(set.length, count);
      expect(
        set.any(board.anyPlacement),
        isTrue,
        reason: 'fill ${board.fill} p $p set $set',
      );
    }
  });

  test('the dot fallback rescues a board no other piece fits', () {
    final board = checkerboard();
    expect(board.fill, lessThan(Director.mercyFillThreshold));
    final pool = Piece.all.where((p) => p.family != 'dot').toList();
    for (var seed = 0; seed < 20; seed++) {
      final set = Director.generateSet(board, Rng(seed), 0.5, 3, pool: pool);
      expect(set[0], same(Piece.dot));
      expect(set.any(board.anyPlacement), isTrue);
    }
  });

  test('a dead board above 70% fill returns an unfit set', () {
    final board = Board.fromJson('0' * Board.cellCount);
    expect(board.isFull, isTrue);
    final set = Director.generateSet(board, Rng(5), 0.5, 3);
    expect(set.length, 3);
    expect(set.any(board.anyPlacement), isFalse);
  });

  test('mercy fires only above the fill threshold', () {
    double smallSetRate(Board board) {
      final rng = Rng(31337);
      var small = 0;
      const runs = 400;
      for (var i = 0; i < runs; i++) {
        final set = Director.generateSet(board, rng, 0.0, 3);
        if (set.every((p) => p.size <= Director.mercyMaxCells)) small++;
      }
      return small / runs;
    }

    final roomyRows = [
      '00000000',
      '00000000',
      '00000000',
      '00000000',
      '00000000',
      '000000..',
      '........',
      '........',
    ];
    final mercyBoard = Board.fromJson(roomyRows.join());
    expect(mercyBoard.fill, greaterThanOrEqualTo(Director.mercyFillThreshold));
    final calmBoard = Board.fromJson(('0' * 24).padRight(64, '.'));
    expect(calmBoard.fill, lessThan(Director.mercyFillThreshold));

    final mercyRate = smallSetRate(mercyBoard);
    final calmRate = smallSetRate(calmBoard);
    expect(mercyRate, greaterThan(0.5));
    expect(mercyRate, greaterThan(calmRate + 0.2));
  });

  test('assist raises the line-completing rate at low pressure', () {
    final board = Board.fromJson([
      '0000000.',
      ...List.filled(7, '........'),
    ].join());
    expect(board.fill, lessThan(Director.mercyFillThreshold));

    double assistedRate(double p) {
      final rng = Rng(777);
      var assisted = 0;
      const runs = 600;
      for (var i = 0; i < runs; i++) {
        final set = Director.generateSet(board, rng, p, 3);
        if (Director.setIsAssisted(board, set)) assisted++;
      }
      return assisted / runs;
    }

    final low = assistedRate(0.0);
    final high = assistedRate(1.0);
    expect(low, greaterThan(high + 0.10));
  });

  test('the onboarding restriction limits the catalogue', () {
    final board = Board.empty();
    final rng = Rng(11);
    final seen = <String>{};
    for (var i = 0; i < 500; i++) {
      for (final piece in Director.generateSet(board, rng, 0.0, 3,
          restricted: true)) {
        seen.add(piece.family);
      }
    }
    expect(seen, Director.restrictedFamilies.toSet());
    expect(Director.restrictedFamilies,
        ['dot', 'i2', 'i3', 'o2', 'l3', 'l4', 't4']);
  });

  test('count is validated', () {
    final board = Board.empty();
    expect(() => Director.generateSet(board, Rng(1), 0.5, 0), throwsArgumentError);
    expect(() => Director.generateSet(board, Rng(1), 0.5, 4), throwsArgumentError);
    for (var count = 1; count <= 3; count++) {
      expect(Director.generateSet(board, Rng(1), 0.5, count).length, count);
    }
  });

  test('generation is deterministic for a given rng state', () {
    final board = Board.empty().place(Piece.byId['o3:0']!, 0, 0);
    final a = Director.generateSet(board, Rng(2026), 0.6, 3);
    final b = Director.generateSet(board, Rng(2026), 0.6, 3);
    expect(a.map((p) => p.id).toList(), b.map((p) => p.id).toList());
  });
}
