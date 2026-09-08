import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

import '../../core/piece.dart';
import 'play_geometry.dart';
import 'tile_painter.dart';
import 'tray_component.dart';

/// The piece under the finger: grid scale, 64 px above the touch, a drop
/// shadow and a light rim on every cell (`styles.md` "held").
class HeldPieceComponent extends PositionComponent {
  HeldPieceComponent({
    required this.geom,
    required TilePainter painter,
    required this.piece,
    required Offset from,
  })  : _painter = painter,
        _cell = geom.trayCell,
        _gap = geom.trayGap,
        _radius = geom.trayCellRadius,
        _centre = from,
        super(priority: 40);

  /// Design 9.3 pick-up is 120 ms ease-out; the growth from tray scale to grid
  /// scale is what carries it, since `styles.md` pins the held piece at 1.0.
  static const pickUpDuration = 0.12;
  static const flyBackDuration = 0.20;
  static const liftPx = 64.0;

  final PlayGeometry geom;
  final Piece piece;
  TilePainter _painter;

  double _cell;
  double _gap;
  double _radius;
  Offset _centre;
  double _pickUp = 0;
  double _flyBack = 0;
  Offset _flyFrom = Offset.zero;
  Offset _flyTo = Offset.zero;
  VoidCallback? _onLanded;

  set painter(TilePainter value) => _painter = value;

  bool get isFlyingBack => _flyBack > 0;

  /// The centre of the piece's top-left cell, which is what picks the anchor.
  Offset get leadCellCentre => Offset(
        _centre.dx - (piece.width - 1) * (_cell + _gap) / 2,
        _centre.dy - (piece.height - 1) * (_cell + _gap) / 2,
      );

  void follow(Offset pointer) {
    _centre = pointer.translate(0, -liftPx * geom.s);
  }

  void flyBackTo(Offset target, VoidCallback onLanded) {
    _flyBack = flyBackDuration;
    _flyFrom = _centre;
    _flyTo = target;
    _onLanded = onLanded;
  }

  @override
  Future<void> onLoad() async {
    _pickUp = pickUpDuration;
  }

  @override
  void update(double dt) {
    if (_flyBack > 0) {
      _flyBack -= dt;
      final p = Curves.easeOutCubic
          .transform((1 - _flyBack / flyBackDuration).clamp(0.0, 1.0));
      _centre = Offset.lerp(_flyFrom, _flyTo, p)!;
      _cell = lerpDouble(geom.cell, geom.trayCell, p)!;
      _gap = lerpDouble(geom.gap, geom.trayGap, p)!;
      _radius = lerpDouble(geom.cellRadius, geom.trayCellRadius, p)!;
      if (_flyBack <= 0) {
        _onLanded?.call();
        removeFromParent();
      }
      return;
    }
    if (_pickUp > 0) {
      _pickUp -= dt;
      final p = Curves.easeOut
          .transform((1 - _pickUp / pickUpDuration).clamp(0.0, 1.0));
      _cell = lerpDouble(geom.trayCell, geom.cell, p)!;
      _gap = lerpDouble(geom.trayGap, geom.gap, p)!;
      _radius = lerpDouble(geom.trayCellRadius, geom.cellRadius, p)!;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = piece.width * _cell + (piece.width - 1) * _gap;
    final h = piece.height * _cell + (piece.height - 1) * _gap;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: _centre.translate(0, 6 * geom.s),
          width: w,
          height: h,
        ).deflate(_cell * 0.12),
        Radius.circular(_radius),
      ),
      _painter.shadowPaint,
    );
    drawPiece(canvas, _painter, piece, _centre, _cell, _gap, _radius, rim: true);
  }
}
