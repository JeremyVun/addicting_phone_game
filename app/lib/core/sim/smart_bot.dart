import 'dart:typed_data';

import '../board.dart';
import '../game_state.dart';
import '../piece.dart';
import '../rng.dart';
import 'bots.dart';

class SmartWeights {
  const SmartWeights();

  static const int lineCleared = 120;
  static const int emptyCell = 2;
  static const int hole = -6;
  static const int smallPocket = -3;
  static const int largestRectCell = 1;
  static const int cramped = -40;
  static const int dead = -1000;
  static const int maxPositionsPerPiece = 12;
}

/// Full-set lookahead: every ordering of the remaining pieces, the best 12
/// positions each, scored on the board the set leaves behind.
class SmartBot extends Bot {
  SmartBot();

  final List<Move> _plan = [];
  Board? _planBoard;

  @override
  String get name => 'smart';

  @override
  Move? choose(GameState state, Rng rng) {
    if (_plan.isEmpty || _planBoard != state.board) {
      _replan(state);
    }
    if (_plan.isEmpty) return null;
    final move = _plan.removeAt(0);
    if (state.set[move.slot] == null ||
        !state.board.canPlace(state.set[move.slot]!, move.row, move.col)) {
      _plan.clear();
      _replan(state);
      if (_plan.isEmpty) return null;
      return _take(state);
    }
    _planBoard = _boardAfter(state.board, state.set[move.slot]!, move);
    return move;
  }

  Move _take(GameState state) {
    final move = _plan.removeAt(0);
    _planBoard = _boardAfter(state.board, state.set[move.slot]!, move);
    return move;
  }

  static Board _boardAfter(Board board, Piece piece, Move move) {
    final placed = board.place(piece, move.row, move.col);
    return placed.clearLines(placed.fullLines()).board;
  }

  void _replan(GameState state) {
    final rows = Uint8List(Board.size);
    for (var r = 0; r < Board.size; r++) {
      var mask = 0;
      for (var c = 0; c < Board.size; c++) {
        if (state.board.cellAt(r, c) != null) mask |= 1 << c;
      }
      rows[r] = mask;
    }
    final search = _Search(state.set);
    search.run(rows, 0, <Move>[]);
    _plan
      ..clear()
      ..addAll(search.best);
    _planBoard = state.board;
  }
}

final Uint8List _popcount = () {
  final table = Uint8List(256);
  for (var i = 1; i < 256; i++) {
    table[i] = table[i >> 1] + (i & 1);
  }
  return table;
}();

class _Search {
  _Search(List<Piece?> set) : pieces = List<Piece?>.of(set);

  final List<Piece?> pieces;
  List<Move> best = const [];
  int bestScore = -1 << 40;

  void run(Uint8List rows, int lines, List<Move> path) {
    var any = false;
    for (var slot = 0; slot < pieces.length; slot++) {
      final piece = pieces[slot];
      if (piece == null) continue;
      final candidates = _candidates(rows, piece, slot);
      if (candidates.isEmpty) continue;
      any = true;
      for (final candidate in candidates) {
        final next = Uint8List.fromList(rows);
        final cleared = _apply(next, piece, candidate.row, candidate.col);
        pieces[slot] = null;
        path.add(candidate);
        run(next, lines + cleared, path);
        path.removeLast();
        pieces[slot] = piece;
      }
    }
    if (any) return;
    final remaining = pieces.any((p) => p != null);
    final score = _evaluate(rows) +
        lines * SmartWeights.lineCleared +
        (remaining ? SmartWeights.dead : 0);
    if (score > bestScore) {
      bestScore = score;
      best = List<Move>.of(path);
    }
  }

  List<Move> _candidates(Uint8List rows, Piece piece, int slot) {
    final moves = <Move>[];
    final scores = <int>[];
    for (var r = 0; r + piece.height <= Board.size; r++) {
      for (var c = 0; c + piece.width <= Board.size; c++) {
        if (!_fits(rows, piece, r, c)) continue;
        moves.add(Move(slot, r, c));
        scores.add(_cheap(rows, piece, r, c));
      }
    }
    if (moves.length <= SmartWeights.maxPositionsPerPiece) return moves;
    final order = List<int>.generate(moves.length, (i) => i)
      ..sort((a, b) => scores[b] - scores[a]);
    return [
      for (final i in order.take(SmartWeights.maxPositionsPerPiece)) moves[i],
    ];
  }

  static bool _fits(Uint8List rows, Piece piece, int r, int c) {
    final masks = piece.rowMasks;
    for (var i = 0; i < masks.length; i++) {
      if ((rows[r + i] & (masks[i] << c)) != 0) return false;
    }
    return true;
  }

  static int _cheap(Uint8List rows, Piece piece, int r, int c) {
    var lines = 0;
    var contacts = 0;
    final masks = piece.rowMasks;
    for (var i = 0; i < masks.length; i++) {
      final m = masks[i] << c;
      final row = r + i;
      if ((rows[row] | m) == Board.fullMask) lines++;
      final up = row == 0 ? Board.fullMask : rows[row - 1];
      final down = row == Board.size - 1 ? Board.fullMask : rows[row + 1];
      contacts += _popcount[m & up] +
          _popcount[m & down] +
          _popcount[m & (((rows[row] << 1) | 1) & Board.fullMask)] +
          _popcount[m & ((rows[row] >> 1) | 0x80)];
    }
    final colMasks = piece.colMasks;
    for (var i = 0; i < colMasks.length; i++) {
      var full = true;
      for (var row = 0; row < Board.size; row++) {
        final bit = 1 << (c + i);
        final occupied = (rows[row] & bit) != 0 ||
            (row >= r &&
                row - r < masks.length &&
                (masks[row - r] & (1 << i)) != 0);
        if (!occupied) {
          full = false;
          break;
        }
      }
      if (full) lines++;
    }
    return lines * SmartWeights.lineCleared + contacts;
  }

  static int _apply(Uint8List rows, Piece piece, int r, int c) {
    final masks = piece.rowMasks;
    for (var i = 0; i < masks.length; i++) {
      rows[r + i] |= masks[i] << c;
    }
    var cleared = 0;
    var colMask = 0;
    for (var col = 0; col < Board.size; col++) {
      var full = true;
      for (var row = 0; row < Board.size; row++) {
        if ((rows[row] & (1 << col)) == 0) {
          full = false;
          break;
        }
      }
      if (full) {
        colMask |= 1 << col;
        cleared++;
      }
    }
    for (var row = 0; row < Board.size; row++) {
      if (rows[row] == Board.fullMask) {
        rows[row] = 0;
        cleared++;
      } else {
        rows[row] &= ~colMask & Board.fullMask;
      }
    }
    return cleared;
  }

  static int _evaluate(Uint8List rows) {
    var empty = 0;
    var holes = 0;
    for (var r = 0; r < Board.size; r++) {
      final free = ~rows[r] & Board.fullMask;
      empty += _popcount[free];
      final up = r == 0 ? Board.fullMask : rows[r - 1];
      final down = r == Board.size - 1 ? Board.fullMask : rows[r + 1];
      final left = ((rows[r] << 1) | 1) & Board.fullMask;
      final right = (rows[r] >> 1) | 0x80;
      holes += _popcount[free & up & down & left & right & Board.fullMask];
    }
    return empty * SmartWeights.emptyCell +
        holes * SmartWeights.hole +
        _smallPockets(rows) * SmartWeights.smallPocket +
        _largestRectangle(rows) * SmartWeights.largestRectCell +
        (_hasTwoBigSlots(rows) ? 0 : SmartWeights.cramped);
  }

  static int _smallPockets(Uint8List rows) {
    final seen = Uint8List(Board.size);
    final stack = Uint8List(Board.cellCount);
    var pockets = 0;
    for (var r = 0; r < Board.size; r++) {
      for (var c = 0; c < Board.size; c++) {
        final bit = 1 << c;
        if ((rows[r] & bit) != 0 || (seen[r] & bit) != 0) continue;
        var top = 0;
        stack[top++] = r * Board.size + c;
        seen[r] |= bit;
        var size = 0;
        while (top > 0) {
          final cell = stack[--top];
          final cr = cell ~/ Board.size;
          final cc = cell % Board.size;
          size++;
          for (final step in const [-1, 1]) {
            final nr = cr + step;
            if (nr >= 0 && nr < Board.size) {
              final nb = 1 << cc;
              if ((rows[nr] & nb) == 0 && (seen[nr] & nb) == 0) {
                seen[nr] |= nb;
                stack[top++] = nr * Board.size + cc;
              }
            }
            final nc = cc + step;
            if (nc >= 0 && nc < Board.size) {
              final nb = 1 << nc;
              if ((rows[cr] & nb) == 0 && (seen[cr] & nb) == 0) {
                seen[cr] |= nb;
                stack[top++] = cr * Board.size + nc;
              }
            }
          }
        }
        if (size <= 2) pockets++;
      }
    }
    return pockets;
  }

  static int _largestRectangle(Uint8List rows) {
    final heights = Uint8List(Board.size);
    var best = 0;
    for (var r = 0; r < Board.size; r++) {
      for (var c = 0; c < Board.size; c++) {
        heights[c] = (rows[r] & (1 << c)) != 0 ? 0 : heights[c] + 1;
      }
      for (var c = 0; c < Board.size; c++) {
        var height = heights[c];
        if (height == 0) continue;
        var width = 1;
        for (var k = c - 1; k >= 0 && heights[k] >= height; k--) {
          width++;
        }
        for (var k = c + 1; k < Board.size && heights[k] >= height; k++) {
          width++;
        }
        final area = height * width;
        if (area > best) best = area;
      }
    }
    return best;
  }

  static bool _hasTwoBigSlots(Uint8List rows) {
    var found = 0;
    for (var r = 0; r + 3 <= Board.size; r++) {
      for (var c = 0; c + 3 <= Board.size; c++) {
        final mask = 7 << c;
        if ((rows[r] & mask) == 0 &&
            (rows[r + 1] & mask) == 0 &&
            (rows[r + 2] & mask) == 0) {
          if (++found >= 2) return true;
        }
      }
    }
    return false;
  }
}
