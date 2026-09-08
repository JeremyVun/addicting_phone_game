import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/board.dart';
import 'package:settle/core/cell.dart';
import 'package:settle/core/piece.dart';

Board boardFrom(List<String> rows) => Board.fromJson(rows.join());

void main() {
  test('empty board', () {
    final board = Board.empty();
    expect(board.isEmpty, isTrue);
    expect(board.filledCount, 0);
    expect(board.fill, 0.0);
    expect(board.cellAt(3, 4), isNull);
    expect(board.fullLines().isEmpty, isTrue);
  });

  test('place writes the family colour and rejects overlaps', () {
    final piece = Piece.byId['o2:0']!;
    final board = Board.empty().place(piece, 2, 3);
    expect(board.filledCount, 4);
    expect(board.cellAt(2, 3), piece.colourIndex);
    expect(board.cellAt(3, 4), piece.colourIndex);
    expect(board.cellAt(2, 5), isNull);
    expect(board.canPlace(piece, 2, 3), isFalse);
    expect(board.canPlace(piece, 2, 4), isFalse);
    expect(board.canPlace(piece, 0, 0), isTrue);
    expect(() => board.place(piece, 2, 3), throwsArgumentError);
  });

  test('canPlace refuses out of bounds', () {
    final board = Board.empty();
    final i5 = Piece.byId['i5:0']!;
    expect(board.canPlace(i5, 0, 3), isTrue);
    expect(board.canPlace(i5, 0, 4), isFalse);
    expect(board.canPlace(i5, -1, 0), isFalse);
    expect(board.canPlace(i5, 0, -1), isFalse);
    expect(board.canPlace(Piece.byId['o3:0']!, 6, 0), isFalse);
  });

  test('a cell in a full row and a full column clears once', () {
    final board = boardFrom([
      '0000000.',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
    ]);
    expect(board.filledCount, 14);
    final placed = board.place(Piece.dot, 0, 7);
    final lines = placed.fullLines();
    expect(lines.rows, [0]);
    expect(lines.cols, [0]);
    final result = placed.clearLines(lines);
    expect(result.cells.length, 15);
    expect(result.cells.toSet().length, 15);
    expect(result.board.isEmpty, isTrue);
    expect(result.board.filledCount, 0);
  });

  test('clearing removes only the full lines', () {
    final board = boardFrom([
      '11111111',
      '1.......',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final lines = board.fullLines();
    expect(lines.rows, [0]);
    expect(lines.cols, isEmpty);
    final result = board.clearLines(lines);
    expect(result.board.filledCount, 1);
    expect(result.board.cellAt(1, 0), 1);
    expect(result.cells.length, 8);
  });

  test('clearLines with nothing full returns the same board', () {
    final board = Board.empty().place(Piece.dot, 0, 0);
    final result = board.clearLines(board.fullLines());
    expect(result.board, board);
    expect(result.cells, isEmpty);
  });

  test('placements and anyPlacement agree', () {
    final board = boardFrom([
      '00000000',
      '00000000',
      '00000000',
      '00000000',
      '00000000',
      '00000000',
      '000000..',
      '000000..',
    ]);
    final o2 = Piece.byId['o2:0']!;
    expect(board.placements(o2), [const Cell(6, 6)]);
    expect(board.anyPlacement(o2), isTrue);
    expect(board.anyPlacement(Piece.byId['o3:0']!), isFalse);
    expect(board.placements(Piece.dot).length, 4);
  });

  test('completesLine sees rows and columns', () {
    final board = boardFrom([
      '0000000.',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '........',
    ]);
    expect(board.completesLine(Piece.dot, 0, 7), isTrue);
    expect(board.completesLine(Piece.dot, 7, 0), isTrue);
    expect(board.completesLine(Piece.dot, 5, 5), isFalse);
    expect(board.hasLineCompletingPlacement(Piece.dot), isTrue);
    expect(board.completesLine(Piece.dot, 0, 0), isFalse);
    expect(
      boardFrom(List.filled(8, '........')).hasLineCompletingPlacement(
        Piece.byId['i5:0']!,
      ),
      isFalse,
    );
  });

  test('preview matches an actual place and clear', () {
    final board = boardFrom([
      '0000000.',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
      '0.......',
    ]);
    for (final piece in Piece.all) {
      for (final at in board.placements(piece)) {
        final preview = board.preview(piece, at.row, at.col);
        final placed = board.place(piece, at.row, at.col);
        final lines = placed.fullLines();
        final cleared = placed.clearLines(lines);
        expect(preview.rowsCleared, lines.rows.length);
        expect(preview.colsCleared, lines.cols.length);
        expect(preview.filledAfter, cleared.board.filledCount);
        expect(preview.boardCleared, cleared.board.isEmpty);
      }
    }
  });

  test('json round trip and value equality', () {
    var board = Board.empty();
    board = board.place(Piece.byId['l5:2']!, 1, 1);
    board = board.place(Piece.byId['s4:0']!, 5, 2);
    final json = board.toJson();
    expect(json.length, 64);
    final back = Board.fromJson(json);
    expect(back, board);
    expect(back.hashCode, board.hashCode);
    expect(back.filledCount, board.filledCount);
    expect(back.toJson(), json);
    expect(Board.empty(), isNot(board));
    expect(() => Board.fromJson('short'), throwsArgumentError);
  });
}
