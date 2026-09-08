import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/piece.dart';
import 'play_geometry.dart';
import 'tile_painter.dart';

/// Three bare slots on the ground: no dock, no cards (`styles.md`).
class TrayComponent extends PositionComponent {
  TrayComponent({required this.geom, required TilePainter painter})
      : _painter = painter,
        super(position: Vector2.zero());

  static const refillDuration = 0.22;
  static const noFitOpacity = 0.45;

  final PlayGeometry geom;
  TilePainter _painter;

  final _pieces = List<Piece?>.filled(3, null);
  final _fits = List<bool>.filled(3, true);
  final _refill = List<double>.filled(3, 0);
  int _hidden = -1;
  int _refilling = 0;

  set painter(TilePainter value) => _painter = value;

  Piece? pieceAt(int slot) => _pieces[slot];

  bool get isAnimating => _refilling > 0;

  void setSlots(List<Piece?> pieces, List<bool> fits, {bool animateNew = false}) {
    for (var i = 0; i < 3; i++) {
      final changed = _pieces[i]?.id != pieces[i]?.id;
      _pieces[i] = pieces[i];
      _fits[i] = fits[i];
      if (animateNew && changed && pieces[i] != null) {
        if (_refill[i] <= 0) _refilling++;
        _refill[i] = refillDuration;
      }
    }
  }

  void hide(int slot) => _hidden = slot;

  void showAll() => _hidden = -1;

  @override
  void update(double dt) {
    if (_refilling == 0) return;
    for (var i = 0; i < 3; i++) {
      if (_refill[i] > 0) {
        _refill[i] -= dt;
        if (_refill[i] <= 0) {
          _refill[i] = 0;
          _refilling--;
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (var slot = 0; slot < 3; slot++) {
      final area = geom.traySlot(slot);
      final piece = _pieces[slot];
      if (piece == null || slot == _hidden) {
        canvas.drawCircle(area.center, 4 * geom.s, _painter.dotPaint);
        continue;
      }
      final t = _refill[slot];
      final p = t <= 0 ? 1.0 : 1.0 - t / refillDuration;
      final opacity = (_fits[slot] ? 1.0 : noFitOpacity) * p;
      final rise = (1 - p) * 6 * geom.s;
      drawPiece(
        canvas,
        _painter,
        piece,
        area.center.translate(0, rise),
        geom.trayCell,
        geom.trayGap,
        geom.trayCellRadius,
        opacity: opacity,
      );
    }
  }
}

/// Draws a piece centred on `centre` at the given cell size. Shared by the
/// tray and the held piece so both stay the same object.
void drawPiece(
  Canvas canvas,
  TilePainter painter,
  Piece piece,
  Offset centre,
  double cell,
  double gap,
  double radius, {
  double opacity = 1.0,
  bool rim = false,
}) {
  final w = piece.width * cell + (piece.width - 1) * gap;
  final h = piece.height * cell + (piece.height - 1) * gap;
  final left = centre.dx - w / 2;
  final top = centre.dy - h / 2;
  for (final c in piece.cells) {
    painter.filled(
      canvas,
      Rect.fromLTWH(
        left + c.col * (cell + gap),
        top + c.row * (cell + gap),
        cell,
        cell,
      ),
      radius,
      piece.colourIndex,
      opacity: opacity,
      rim: rim,
    );
  }
}
