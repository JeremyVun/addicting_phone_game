import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/board.dart';
import '../../core/cell.dart';
import 'play_geometry.dart';
import 'tile_painter.dart';

/// The well and its 64 cells, drawn in one `render` from preallocated arrays.
/// Nothing here allocates per frame and no layout runs in `render`.
class BoardComponent extends PositionComponent {
  BoardComponent({required this.geom, required TilePainter painter})
      : _painter = painter,
        super(position: Vector2(geom.well.left, geom.well.top));

  static const placeDuration = 0.12;
  static const clearFlash = 0.08;
  static const clearFade = 0.18;
  static const clearStagger = 0.015;
  static const shakeDuration = 0.15;

  final PlayGeometry geom;
  TilePainter _painter;

  final _colours = Int8List(Board.cellCount)..fillRange(0, Board.cellCount, -1);
  final _clearColours = Int8List(Board.cellCount);
  final _placeT = Float32List(Board.cellCount);
  final _clearT = Float32List(Board.cellCount);
  final _ghost = Uint8List(Board.cellCount);
  final _imminent = Uint8List(Board.cellCount);

  int _placing = 0;
  int _clearing = 0;
  int _ghostColour = 0;
  double _shakeT = 0;
  double _shakeAmp = 0;

  final _wellPaint = Paint();
  final _wellEdge = Paint()..style = PaintingStyle.stroke;
  final _wellInner = Paint();
  final Vector2 _home = Vector2.zero();

  set painter(TilePainter value) {
    _painter = value;
    _syncPaints();
  }

  @override
  Future<void> onLoad() async {
    _home.setFrom(position);
    size = Vector2(geom.well.width, geom.well.height);
    _syncPaints();
  }

  void _syncPaints() {
    _wellPaint.color = _painter.palette.well;
    _wellEdge
      ..color = _painter.palette.hairline
      ..strokeWidth = 1;
    _wellInner.color = _painter.palette.lightGround
        ? const Color(0x1A000000)
        : const Color(0xE6000000);
  }

  bool get isAnimating => _placing > 0 || _clearing > 0 || _shakeT > 0;

  /// Replace the board with no animation (a new game, or a resume).
  void reset(Board board) {
    for (var i = 0; i < Board.cellCount; i++) {
      _colours[i] = board.cellAt(i ~/ Board.size, i % Board.size) ?? -1;
      _placeT[i] = 0;
      _clearT[i] = 0;
    }
    _placing = 0;
    _clearing = 0;
    clearHover();
    _shakeT = 0;
    position.setFrom(_home);
  }

  /// Take the board from `result.state` while keeping cleared cells on screen
  /// for their animation.
  void syncColours(Board board) {
    for (var i = 0; i < Board.cellCount; i++) {
      _colours[i] = board.cellAt(i ~/ Board.size, i % Board.size) ?? -1;
    }
  }

  void animatePlace(List<Cell> cells) {
    for (final c in cells) {
      final i = c.row * Board.size + c.col;
      if (_placeT[i] <= 0) _placing++;
      _placeT[i] = placeDuration;
    }
  }

  /// Staggered 15 ms per cell outward from `origin` (design 9.3).
  void animateClear(List<Cell> cells, Board before, Offset origin) {
    for (final c in cells) {
      final i = c.row * Board.size + c.col;
      final centre = geom.cellCentre(c.row, c.col);
      final rank = (centre - origin).distance / geom.pitch;
      _clearColours[i] = before.cellAt(c.row, c.col) ?? 0;
      if (_clearT[i] == 0) _clearing++;
      _clearT[i] = -rank * clearStagger - 1e-6;
    }
  }

  void shake(int lines) {
    if (lines < 2) return;
    _shakeAmp = 2.0 * lines * geom.s;
    _shakeT = shakeDuration;
  }

  void setHover(List<Cell> cells, int colourIndex, List<int> rows, List<int> cols) {
    _ghost.fillRange(0, Board.cellCount, 0);
    _imminent.fillRange(0, Board.cellCount, 0);
    _ghostColour = colourIndex;
    for (final c in cells) {
      _ghost[c.row * Board.size + c.col] = 1;
    }
    for (final r in rows) {
      for (var c = 0; c < Board.size; c++) {
        _imminent[r * Board.size + c] = 1;
      }
    }
    for (final c in cols) {
      for (var r = 0; r < Board.size; r++) {
        _imminent[r * Board.size + c] = 1;
      }
    }
  }

  void clearHover() {
    _ghost.fillRange(0, Board.cellCount, 0);
    _imminent.fillRange(0, Board.cellCount, 0);
  }

  @override
  void update(double dt) {
    if (_placing > 0) {
      for (var i = 0; i < Board.cellCount; i++) {
        if (_placeT[i] > 0) {
          _placeT[i] -= dt;
          if (_placeT[i] <= 0) {
            _placeT[i] = 0;
            _placing--;
          }
        }
      }
    }
    if (_clearing > 0) {
      for (var i = 0; i < Board.cellCount; i++) {
        final t = _clearT[i];
        if (t != 0) {
          final next = t + dt;
          if (next >= clearFlash + clearFade) {
            _clearT[i] = 0;
            _clearing--;
          } else {
            _clearT[i] = next == 0 ? 1e-6 : next;
          }
        }
      }
    }
    if (_shakeT > 0) {
      _shakeT -= dt;
      if (_shakeT <= 0) {
        _shakeT = 0;
        position.setFrom(_home);
      } else {
        final p = _shakeT / shakeDuration;
        position.setValues(
          _home.x + math.sin(p * math.pi * 6) * _shakeAmp * p,
          _home.y,
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, geom.well.width, geom.well.height),
      geom.wellRadius,
    );
    canvas.drawRRect(r, _wellPaint);
    canvas.drawRRect(r.deflate(0.5), _wellEdge);

    final ox = geom.gridOrigin.dx - geom.well.left;
    final oy = geom.gridOrigin.dy - geom.well.top;
    final radius = geom.cellRadius;

    for (var i = 0; i < Board.cellCount; i++) {
      final row = i ~/ Board.size, col = i % Board.size;
      final rect = Rect.fromLTWH(
        ox + col * geom.pitch,
        oy + row * geom.pitch,
        geom.cell,
        geom.cell,
      );
      final clearT = _clearT[i];
      if (clearT != 0) {
        _renderClearing(canvas, rect, radius, i, clearT);
      } else if (_colours[i] >= 0) {
        _renderFilled(canvas, rect, radius, i);
      } else {
        _painter.empty(canvas, rect, radius);
        if (_ghost[i] == 1) _painter.ghost(canvas, rect, radius, _ghostColour);
      }
      if (_imminent[i] == 1) _painter.imminent(canvas, rect, radius);
    }
  }

  void _renderFilled(Canvas canvas, Rect rect, double radius, int i) {
    final t = _placeT[i];
    if (t <= 0) {
      _painter.filled(canvas, rect, radius, _colours[i]);
      return;
    }
    final scale = 1.0 + 0.1 * (t / placeDuration);
    _painter.filled(
      canvas,
      Rect.fromCenter(
        center: rect.center,
        width: rect.width * scale,
        height: rect.height * scale,
      ),
      radius * scale,
      _colours[i],
    );
  }

  void _renderClearing(Canvas canvas, Rect rect, double radius, int i, double t) {
    if (t < 0) {
      _painter.filled(canvas, rect, radius, _clearColours[i]);
      return;
    }
    if (t < clearFlash) {
      _painter.filled(canvas, rect, radius, _clearColours[i]);
      _painter.flash(canvas, rect, radius, 1.0);
      return;
    }
    final p = ((t - clearFlash) / clearFade).clamp(0.0, 1.0);
    final scale = 1.0 - 0.45 * p;
    _painter.flash(
      canvas,
      Rect.fromCenter(
        center: rect.center,
        width: rect.width * scale,
        height: rect.height * scale,
      ),
      radius * scale,
      1.0 - p,
    );
  }
}
