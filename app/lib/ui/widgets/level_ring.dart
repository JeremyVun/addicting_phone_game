import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palettes.dart';
import '../theme/typography.dart';

class LevelRing extends StatelessWidget {
  const LevelRing({
    super.key,
    required this.level,
    required this.progress,
    required this.palette,
    this.diameter = 38,
  });

  final int level;
  final double progress;
  final ThemePalette palette;
  final double diameter;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: diameter,
    height: diameter,
    child: CustomPaint(
      painter: _RingPainter(progress, palette),
      child: Center(
        child: Text(
          '$level',
          style: manrope(
            size: diameter * 0.37,
            weight: 800,
            color: palette.ink,
            letterSpacing: -0.2,
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress, this.palette);

  final double progress;
  final ThemePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final rect = Offset.zero & size;
    final inset = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = palette.hairline;
    canvas.drawArc(inset, 0, math.pi * 2, false, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = palette.accent;
    canvas.drawArc(inset, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.palette != palette;
}
