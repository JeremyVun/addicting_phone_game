import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/piece.dart';

const Map<String, List<int>> designTable = {
  'dot': [1, 1, 4, 0],
  'i2': [2, 2, 8, 1],
  'i3': [3, 2, 8, 1],
  'i4': [4, 2, 6, 2],
  'i5': [5, 2, 4, 2],
  'o2': [4, 1, 8, 3],
  'o3': [9, 1, 4, 4],
  'r23': [6, 2, 5, 4],
  'l3': [3, 4, 8, 5],
  'l4': [4, 8, 8, 5],
  'l5': [5, 4, 6, 6],
  't4': [4, 4, 8, 7],
  's4': [4, 2, 3, 7],
  'z4': [4, 2, 3, 7],
};

void main() {
  test('catalogue matches design 2.2 exactly', () {
    expect(Piece.byFamily.keys.toSet(), designTable.keys.toSet());
    for (final entry in designTable.entries) {
      final pieces = Piece.byFamily[entry.key]!;
      final [cells, rotations, weight, colour] = entry.value;
      expect(pieces.length, rotations, reason: '${entry.key} rotations');
      for (final piece in pieces) {
        expect(piece.size, cells, reason: '${piece.id} cells');
        expect(piece.familyWeight, weight, reason: '${piece.id} weight');
        expect(piece.colourIndex, colour, reason: '${piece.id} colour');
        expect(piece.familyRotations, rotations, reason: '${piece.id} rots');
      }
    }
    expect(Piece.all.length, 37);
    expect(
      designTable.values.map((v) => v[2]).reduce((a, b) => a + b),
      83,
      reason: 'design 2.2 total base weight',
    );
  });

  test('catalogue printout', () {
    final buf = StringBuffer();
    for (final family in pieceFamilies) {
      final pieces = Piece.byFamily[family.id]!;
      buf.writeln('${family.id}  weight=${family.baseWeight} '
          'colour=${family.colourIndex} rotations=${pieces.length}');
      for (final piece in pieces) {
        final grid = [
          for (var r = 0; r < piece.height; r++)
            [
              for (var c = 0; c < piece.width; c++)
                piece.cells.any((x) => x.row == r && x.col == c) ? '#' : '.',
            ].join(),
        ].join('/');
        buf.writeln('  ${piece.id.padRight(7)} ${piece.height}x${piece.width} '
            '${piece.size} cells  $grid');
      }
    }
    // ignore: avoid_print
    print(buf);
    expect(buf.isNotEmpty, isTrue);
  });

  test('every piece is anchored at (0,0) with no gaps in the bounding box', () {
    for (final piece in Piece.all) {
      expect(piece.cells.map((c) => c.row).reduce((a, b) => a < b ? a : b), 0);
      expect(piece.cells.map((c) => c.col).reduce((a, b) => a < b ? a : b), 0);
      expect(piece.cells.map((c) => c.row).reduce((a, b) => a > b ? a : b),
          piece.height - 1);
      expect(piece.cells.map((c) => c.col).reduce((a, b) => a > b ? a : b),
          piece.width - 1);
      expect(piece.cells.toSet().length, piece.size);
    }
  });

  test('ids are stable, unique and resolvable', () {
    expect(Piece.byId.length, Piece.all.length);
    for (final piece in Piece.all) {
      expect(piece.id, '${piece.family}:${piece.rotation}');
      expect(Piece.byId[piece.id], same(piece));
    }
    expect(Piece.dot.id, 'dot:0');
    expect(Piece.byId['l4:3']!.family, 'l4');
  });

  test('rotations within a family are distinct shapes', () {
    for (final pieces in Piece.byFamily.values) {
      final keys = pieces
          .map((p) => p.cells.map((c) => '${c.row},${c.col}').join(';'))
          .toSet();
      expect(keys.length, pieces.length);
    }
  });
}
