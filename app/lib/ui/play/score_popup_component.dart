import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../theme/typography.dart';
import 'play_strings.dart';

/// "+180" at the clear centroid: weight and size, no box (`styles.md`).
class ScorePopupComponent extends PositionComponent {
  ScorePopupComponent({
    required int points,
    required Offset at,
    required double scale,
    required Rect bounds,
  })  : _at = at,
        _rise = 40.0 * scale,
        super(priority: 30) {
    _painter = TextPainter(
      text: TextSpan(text: PlayStrings.points(points), style: PlayType.popup(scale)),
      textDirection: TextDirection.ltr,
    )..layout();
    final half = Offset(_painter.width / 2, _painter.height / 2);
    _at = Offset(
      _at.dx.clamp(bounds.left + half.dx, bounds.right - half.dx),
      _at.dy.clamp(bounds.top + half.dy + _rise, bounds.bottom - half.dy),
    );
  }

  static const duration = 0.5;

  late final TextPainter _painter;
  Offset _at;
  final double _rise;
  double _t = 0;
  final _fade = Paint();

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / duration).clamp(0.0, 1.0);
    final opacity = (p < 0.6 ? 1.0 : 1.0 - (p - 0.6) / 0.4).clamp(0.0, 1.0);
    final at = Offset(
      _at.dx - _painter.width / 2,
      _at.dy - _painter.height / 2 - _rise * p,
    );
    if (opacity >= 1.0) {
      _painter.paint(canvas, at);
      return;
    }
    canvas.saveLayer(
      Rect.fromLTWH(at.dx, at.dy, _painter.width, _painter.height).inflate(_rise),
      _fade..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    _painter.paint(canvas, at);
    canvas.restore();
  }
}
