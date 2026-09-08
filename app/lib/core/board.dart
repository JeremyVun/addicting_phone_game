import 'dart:typed_data';

import 'cell.dart';
import 'piece.dart';

class FullLines {
  const FullLines(this.rows, this.cols);

  final List<int> rows;
  final List<int> cols;

  int get count => rows.length + cols.length;

  bool get isEmpty => rows.isEmpty && cols.isEmpty;
}

class ClearResult {
  const ClearResult(this.board, this.cells);

  final Board board;

  /// Row-major, only cells that held a block, each once even when it sits in
  /// both a cleared row and a cleared column.
  final List<Cell> cells;
}

class PlacementPreview {
  const PlacementPreview({
    required this.rowsCleared,
    required this.colsCleared,
    required this.filledAfter,
  });

  final int rowsCleared;
  final int colsCleared;
  final int filledAfter;

  int get linesCleared => rowsCleared + colsCleared;

  bool get boardCleared => filledAfter == 0;
}

class Board {
  Board._(this._colours, this._rowMasks, this._colMasks, this.filledCount);

  factory Board.empty() => Board._(
        Uint8List(size * size),
        Uint8List(size),
        Uint8List(size),
        0,
      );

  factory Board.fromJson(String json) {
    if (json.length != size * size) {
      throw ArgumentError.value(json, 'json', 'expected ${size * size} chars');
    }
    final colours = Uint8List(size * size);
    final rowMasks = Uint8List(size);
    final colMasks = Uint8List(size);
    var filled = 0;
    for (var i = 0; i < json.length; i++) {
      final ch = json[i];
      if (ch == emptyChar) continue;
      final colour = int.parse(ch);
      colours[i] = colour + 1;
      rowMasks[i ~/ size] |= 1 << (i % size);
      colMasks[i % size] |= 1 << (i ~/ size);
      filled++;
    }
    return Board._(colours, rowMasks, colMasks, filled);
  }

  static const int size = 8;
  static const int cellCount = size * size;
  static const int fullMask = 0xFF;
  static const String emptyChar = '.';

  final Uint8List _colours;
  final Uint8List _rowMasks;
  final Uint8List _colMasks;
  final int filledCount;

  int? cellAt(int row, int col) {
    final v = _colours[row * size + col];
    return v == 0 ? null : v - 1;
  }

  double get fill => filledCount / cellCount;

  bool get isEmpty => filledCount == 0;

  bool get isFull => filledCount == cellCount;

  bool canPlace(Piece piece, int row, int col) {
    if (row < 0 || col < 0) return false;
    if (row + piece.height > size || col + piece.width > size) return false;
    final masks = piece.rowMasks;
    for (var i = 0; i < masks.length; i++) {
      if ((_rowMasks[row + i] & (masks[i] << col)) != 0) return false;
    }
    return true;
  }

  Board place(Piece piece, int row, int col) {
    if (!canPlace(piece, row, col)) {
      throw ArgumentError('$piece does not fit at ($row,$col)');
    }
    final colours = Uint8List.fromList(_colours);
    final rowMasks = Uint8List.fromList(_rowMasks);
    final colMasks = Uint8List.fromList(_colMasks);
    for (final c in piece.cells) {
      final r = row + c.row;
      final k = col + c.col;
      colours[r * size + k] = piece.colourIndex + 1;
      rowMasks[r] |= 1 << k;
      colMasks[k] |= 1 << r;
    }
    return Board._(colours, rowMasks, colMasks, filledCount + piece.size);
  }

  FullLines fullLines() {
    final rows = <int>[];
    final cols = <int>[];
    for (var i = 0; i < size; i++) {
      if (_rowMasks[i] == fullMask) rows.add(i);
      if (_colMasks[i] == fullMask) cols.add(i);
    }
    return FullLines(rows, cols);
  }

  ClearResult clearLines(FullLines lines) {
    if (lines.isEmpty) return ClearResult(this, const []);
    final rowSet = lines.rows.toSet();
    final colSet = lines.cols.toSet();
    return _erase((r, c) => rowSet.contains(r) || colSet.contains(c));
  }

  /// Design 6's continue: a demolition of whatever occupies [rows].
  ClearResult clearRows(Iterable<int> rows) {
    final rowSet = rows.toSet();
    if (rowSet.isEmpty) return ClearResult(this, const []);
    return _erase((r, c) => rowSet.contains(r));
  }

  ClearResult _erase(bool Function(int row, int col) selected) {
    final colours = Uint8List.fromList(_colours);
    final rowMasks = Uint8List.fromList(_rowMasks);
    final colMasks = Uint8List.fromList(_colMasks);
    final cleared = <Cell>[];
    var filled = filledCount;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (colours[r * size + c] == 0 || !selected(r, c)) continue;
        cleared.add(Cell(r, c));
        colours[r * size + c] = 0;
        rowMasks[r] &= ~(1 << c) & fullMask;
        colMasks[c] &= ~(1 << r) & fullMask;
        filled--;
      }
    }
    return ClearResult(Board._(colours, rowMasks, colMasks, filled), cleared);
  }

  List<Cell> placements(Piece piece) {
    final out = <Cell>[];
    for (var r = 0; r + piece.height <= size; r++) {
      for (var c = 0; c + piece.width <= size; c++) {
        if (canPlace(piece, r, c)) out.add(Cell(r, c));
      }
    }
    return out;
  }

  bool anyPlacement(Piece piece) {
    for (var r = 0; r + piece.height <= size; r++) {
      for (var c = 0; c + piece.width <= size; c++) {
        if (canPlace(piece, r, c)) return true;
      }
    }
    return false;
  }

  bool completesLine(Piece piece, int row, int col) {
    if (!canPlace(piece, row, col)) return false;
    final rowMasks = piece.rowMasks;
    for (var i = 0; i < rowMasks.length; i++) {
      if ((_rowMasks[row + i] | (rowMasks[i] << col)) == fullMask) return true;
    }
    final colMasks = piece.colMasks;
    for (var i = 0; i < colMasks.length; i++) {
      if ((_colMasks[col + i] | (colMasks[i] << row)) == fullMask) return true;
    }
    return false;
  }

  bool hasLineCompletingPlacement(Piece piece) {
    for (var r = 0; r + piece.height <= size; r++) {
      for (var c = 0; c + piece.width <= size; c++) {
        if (completesLine(piece, r, c)) return true;
      }
    }
    return false;
  }

  PlacementPreview preview(Piece piece, int row, int col) {
    var rows = 0;
    var cols = 0;
    final pieceRows = piece.rowMasks;
    final pieceCols = piece.colMasks;
    for (var r = 0; r < size; r++) {
      final add = (r >= row && r - row < pieceRows.length)
          ? pieceRows[r - row] << col
          : 0;
      if ((_rowMasks[r] | add) == fullMask) rows++;
    }
    for (var c = 0; c < size; c++) {
      final add = (c >= col && c - col < pieceCols.length)
          ? pieceCols[c - col] << row
          : 0;
      if ((_colMasks[c] | add) == fullMask) cols++;
    }
    final placed = filledCount + piece.size;
    final clearedCells = rows * size + cols * size - rows * cols;
    return PlacementPreview(
      rowsCleared: rows,
      colsCleared: cols,
      filledAfter: placed - clearedCells,
    );
  }

  String toJson() {
    final buf = StringBuffer();
    for (var i = 0; i < cellCount; i++) {
      final v = _colours[i];
      buf.write(v == 0 ? emptyChar : (v - 1).toString());
    }
    return buf.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Board || other.filledCount != filledCount) return false;
    for (var i = 0; i < cellCount; i++) {
      if (other._colours[i] != _colours[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var h = 17;
    for (var i = 0; i < cellCount; i++) {
      h = 0x1fffffff & (h * 31 + _colours[i]);
    }
    return h;
  }

  @override
  String toString() {
    final buf = StringBuffer();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = cellAt(r, c);
        buf.write(v == null ? emptyChar : v.toString());
      }
      buf.write('\n');
    }
    return buf.toString();
  }
}
