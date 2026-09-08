import 'cell.dart';

class PieceFamily {
  const PieceFamily({
    required this.id,
    required this.baseWeight,
    required this.colourIndex,
    required this.base,
    this.mirrored = false,
  });

  final String id;
  final int baseWeight;
  final int colourIndex;
  final List<Cell> base;

  /// Only the L tetromino counts its mirror (J) as separate pieces; every other
  /// family is either mirror-symmetric or has its mirror listed as its own
  /// family (s4 / z4), per design 2.2.
  final bool mirrored;
}

const List<PieceFamily> pieceFamilies = [
  PieceFamily(
    id: 'dot',
    baseWeight: 4,
    colourIndex: 0,
    base: [Cell(0, 0)],
  ),
  PieceFamily(
    id: 'i2',
    baseWeight: 8,
    colourIndex: 1,
    base: [Cell(0, 0), Cell(0, 1)],
  ),
  PieceFamily(
    id: 'i3',
    baseWeight: 8,
    colourIndex: 1,
    base: [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
  ),
  PieceFamily(
    id: 'i4',
    baseWeight: 6,
    colourIndex: 2,
    base: [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(0, 3)],
  ),
  PieceFamily(
    id: 'i5',
    baseWeight: 4,
    colourIndex: 2,
    base: [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(0, 3), Cell(0, 4)],
  ),
  PieceFamily(
    id: 'o2',
    baseWeight: 8,
    colourIndex: 3,
    base: [Cell(0, 0), Cell(0, 1), Cell(1, 0), Cell(1, 1)],
  ),
  PieceFamily(
    id: 'o3',
    baseWeight: 4,
    colourIndex: 4,
    base: [
      Cell(0, 0), Cell(0, 1), Cell(0, 2),
      Cell(1, 0), Cell(1, 1), Cell(1, 2),
      Cell(2, 0), Cell(2, 1), Cell(2, 2),
    ],
  ),
  PieceFamily(
    id: 'r23',
    baseWeight: 5,
    colourIndex: 4,
    base: [
      Cell(0, 0), Cell(0, 1), Cell(0, 2),
      Cell(1, 0), Cell(1, 1), Cell(1, 2),
    ],
  ),
  PieceFamily(
    id: 'l3',
    baseWeight: 8,
    colourIndex: 5,
    base: [Cell(0, 0), Cell(1, 0), Cell(1, 1)],
  ),
  PieceFamily(
    id: 'l4',
    baseWeight: 8,
    colourIndex: 5,
    mirrored: true,
    base: [Cell(0, 0), Cell(1, 0), Cell(2, 0), Cell(2, 1)],
  ),
  PieceFamily(
    id: 'l5',
    baseWeight: 6,
    colourIndex: 6,
    base: [Cell(0, 0), Cell(1, 0), Cell(2, 0), Cell(2, 1), Cell(2, 2)],
  ),
  PieceFamily(
    id: 't4',
    baseWeight: 8,
    colourIndex: 7,
    base: [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 1)],
  ),
  PieceFamily(
    id: 's4',
    baseWeight: 3,
    colourIndex: 7,
    base: [Cell(0, 1), Cell(0, 2), Cell(1, 0), Cell(1, 1)],
  ),
  PieceFamily(
    id: 'z4',
    baseWeight: 3,
    colourIndex: 7,
    base: [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 2)],
  ),
];

class Piece {
  Piece._({
    required this.id,
    required this.family,
    required this.rotation,
    required this.cells,
    required this.colourIndex,
    required this.familyWeight,
    required this.familyRotations,
  })  : height = cells.map((c) => c.row).reduce(_max) + 1,
        width = cells.map((c) => c.col).reduce(_max) + 1,
        rowMasks = _rowMasks(cells),
        colMasks = _colMasks(cells);

  final String id;
  final String family;
  final int rotation;
  final List<Cell> cells;
  final int colourIndex;
  final int familyWeight;
  final int familyRotations;
  final int width;
  final int height;

  /// Bit `c` of `rowMasks[r]` is set when the piece occupies its own (r, c).
  final List<int> rowMasks;

  /// Bit `r` of `colMasks[c]` is set when the piece occupies its own (r, c).
  final List<int> colMasks;

  int get size => cells.length;

  static int _max(int a, int b) => a > b ? a : b;

  static List<int> _rowMasks(List<Cell> cells) {
    final h = cells.map((c) => c.row).reduce(_max) + 1;
    final masks = List<int>.filled(h, 0);
    for (final c in cells) {
      masks[c.row] |= 1 << c.col;
    }
    return List.unmodifiable(masks);
  }

  static List<int> _colMasks(List<Cell> cells) {
    final w = cells.map((c) => c.col).reduce(_max) + 1;
    final masks = List<int>.filled(w, 0);
    for (final c in cells) {
      masks[c.col] |= 1 << c.row;
    }
    return List.unmodifiable(masks);
  }

  static final List<Piece> all = _buildCatalogue();

  static final Map<String, Piece> byId = {for (final p in all) p.id: p};

  static final Piece dot = byId['dot:0']!;

  static final Map<String, List<Piece>> byFamily = {
    for (final f in pieceFamilies)
      f.id: List.unmodifiable(all.where((p) => p.family == f.id).toList()),
  };

  static List<Piece> _buildCatalogue() {
    final pieces = <Piece>[];
    for (final family in pieceFamilies) {
      final shapes = <List<Cell>>[];
      final seen = <String>{};
      final variants = family.mirrored
          ? [family.base, _mirror(family.base)]
          : [family.base];
      for (final variant in variants) {
        var shape = _normalise(variant);
        for (var i = 0; i < 4; i++) {
          final key = _key(shape);
          if (seen.add(key)) shapes.add(shape);
          shape = _normalise(_rotate(shape));
        }
      }
      for (var i = 0; i < shapes.length; i++) {
        pieces.add(Piece._(
          id: '${family.id}:$i',
          family: family.id,
          rotation: i,
          cells: List.unmodifiable(shapes[i]),
          colourIndex: family.colourIndex,
          familyWeight: family.baseWeight,
          familyRotations: shapes.length,
        ));
      }
    }
    return List.unmodifiable(pieces);
  }

  static List<Cell> _rotate(List<Cell> cells) {
    final maxRow = cells.map((c) => c.row).reduce(_max);
    return [for (final c in cells) Cell(c.col, maxRow - c.row)];
  }

  static List<Cell> _mirror(List<Cell> cells) {
    final maxCol = cells.map((c) => c.col).reduce(_max);
    return [for (final c in cells) Cell(c.row, maxCol - c.col)];
  }

  static List<Cell> _normalise(List<Cell> cells) {
    final minRow = cells.map((c) => c.row).reduce((a, b) => a < b ? a : b);
    final minCol = cells.map((c) => c.col).reduce((a, b) => a < b ? a : b);
    final moved = [
      for (final c in cells) Cell(c.row - minRow, c.col - minCol),
    ]..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    return moved;
  }

  static String _key(List<Cell> cells) =>
      cells.map((c) => '${c.row},${c.col}').join(';');

  @override
  String toString() => id;
}
