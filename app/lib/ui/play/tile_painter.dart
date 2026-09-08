import 'dart:ui';

import '../theme/palettes.dart';

/// Every tile in the game is drawn through here, so the `styles.md` tile-state
/// invariants exist in exactly one place. All `Paint`s are built once per
/// palette; nothing here allocates per frame.
class TilePainter {
  TilePainter(this.palette) {
    _empty.color = palette.empty;
    _emptyInset.color = const Color(0x59000000);
    final lit = palette.lightGround;
    _highlight.color = lit ? const Color(0x66FFFFFF) : const Color(0x6BFFFFFF);
    _shade.color = lit ? const Color(0x33000000) : const Color(0x4D000000);
    for (var i = 0; i < 8; i++) {
      _fills[i] = Paint()..color = palette.blocks[i];
      _ghostFills[i] = Paint()
        ..color = Color.lerp(const Color(0xFF000000), palette.blocks[i], 0.18)!;
      _ghostRings[i] = Paint()
        ..color = palette.blocks[i]
        ..style = PaintingStyle.stroke;
      _rings[i] = Paint()
        ..color = palette.blocks[i]
        ..style = PaintingStyle.stroke;
    }
    _imminent
      ..color = const Color(0x94FFFFFF)
      ..style = PaintingStyle.stroke;
    _glow
      ..color = const Color(0x1FFFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    _flash.color = const Color(0xE6FFFFFF);
    _rim
      ..color = const Color(0x6BFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _dot.color = palette.hairline;
    _shadow
      ..color = const Color(0xD9000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  }

  final ThemePalette palette;

  final _empty = Paint();
  final _emptyInset = Paint();
  final _highlight = Paint();
  final _shade = Paint();
  final _flash = Paint();
  final _imminent = Paint();
  final _glow = Paint();
  final _rim = Paint();
  final _dot = Paint();
  final _shadow = Paint();
  final _fills = List<Paint>.filled(8, Paint());
  final _ghostFills = List<Paint>.filled(8, Paint());
  final _ghostRings = List<Paint>.filled(8, Paint());
  final _rings = List<Paint>.filled(8, Paint());
  final _alpha = Paint();

  Paint get dotPaint => _dot;
  Paint get shadowPaint => _shadow;

  void empty(Canvas canvas, Rect r, double radius) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(rr, _empty);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(r.left, r.top, r.width, radius * 0.22 + 1),
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      ),
      _emptyInset,
    );
  }

  /// Filled: colour fill, 2 px inset top highlight, 2.5 px inset bottom shade.
  void filled(
    Canvas canvas,
    Rect r,
    double radius,
    int colourIndex, {
    double opacity = 1.0,
    bool rim = false,
  }) {
    final scale = radius / 5.0;
    final top = 2.0 * scale, bottom = 2.5 * scale;
    if (opacity >= 1.0) {
      _drawTile(canvas, r, radius, _fills[colourIndex], top, bottom, rim);
      return;
    }
    canvas.saveLayer(r.inflate(radius), _alpha..color = Color.fromRGBO(0, 0, 0, opacity));
    _drawTile(canvas, r, radius, _fills[colourIndex], top, bottom, rim);
    canvas.restore();
  }

  void _drawTile(
    Canvas canvas,
    Rect r,
    double radius,
    Paint fill,
    double top,
    double bottom,
    bool rim,
  ) {
    final rad = Radius.circular(radius);
    canvas.drawRRect(RRect.fromRectAndRadius(r, rad), fill);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(r.left, r.top, r.width, top),
        topLeft: rad,
        topRight: rad,
      ),
      _highlight,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(r.left, r.bottom - bottom, r.width, bottom),
        bottomLeft: rad,
        bottomRight: rad,
      ),
      _shade,
    );
    if (rim) {
      _rim.strokeWidth = 1.5 * radius / 5.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(_rim.strokeWidth / 2), rad),
        _rim,
      );
    }
  }

  /// Ghost: never a dimmed fill. 18% of the piece colour over black, plus a
  /// 2.5 px inset ring in the full colour.
  void ghost(Canvas canvas, Rect r, double radius, int colourIndex) {
    final rad = Radius.circular(radius);
    canvas.drawRRect(RRect.fromRectAndRadius(r, rad), _ghostFills[colourIndex]);
    final w = 2.5 * radius / 5.0;
    _ghostRings[colourIndex].strokeWidth = w;
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(w / 2), rad),
      _ghostRings[colourIndex],
    );
  }

  /// Line-imminent: a 2 px white inset ring and a soft glow on every cell of a
  /// row or column the ghost would complete.
  void imminent(Canvas canvas, Rect r, double radius) {
    final rad = Radius.circular(radius);
    final w = 2.0 * radius / 5.0;
    canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(w / 2), rad), _glow);
    _imminent.strokeWidth = w;
    canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(w / 2), rad), _imminent);
  }

  void flash(Canvas canvas, Rect r, double radius, double opacity) {
    _flash.color = Color.fromRGBO(255, 255, 255, 0.9 * opacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      _flash,
    );
  }

  Color blockColour(int index) => palette.blocks[index];
}
