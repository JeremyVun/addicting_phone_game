import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum PlayIcon { pause, reroll, play, coin }

class PlayIconPainter extends CustomPainter {
  const PlayIconPainter(this.icon, this.colour);

  final PlayIcon icon;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final fill = Paint()..color = colour;
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * u
      ..strokeCap = StrokeCap.round;
    switch (icon) {
      case PlayIcon.pause:
        for (final x in const [8.0, 14.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x * u, 6 * u, 2.4 * u, 12 * u),
              Radius.circular(1.2 * u),
            ),
            fill,
          );
        }
      case PlayIcon.play:
        canvas.drawPath(
          Path()
            ..moveTo(8 * u, 5.5 * u)
            ..lineTo(8 * u, 18.5 * u)
            ..lineTo(19 * u, 12 * u)
            ..close(),
          fill,
        );
      case PlayIcon.reroll:
        canvas.drawArc(
          Rect.fromCircle(center: Offset(12 * u, 12 * u), radius: 7 * u),
          -math.pi * 0.62,
          math.pi * 1.55,
          false,
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(15.4 * u, 1.6 * u)
            ..lineTo(19.2 * u, 5.4 * u)
            ..lineTo(14.2 * u, 7.4 * u)
            ..close(),
          fill,
        );
      case PlayIcon.coin:
        canvas.drawCircle(Offset(12 * u, 12 * u), 8 * u, stroke..strokeWidth = 2 * u);
        canvas.drawCircle(Offset(12 * u, 12 * u), 3 * u, fill);
    }
  }

  @override
  bool shouldRepaint(PlayIconPainter old) =>
      old.icon != icon || old.colour != colour;
}

class PlayIconBox extends StatelessWidget {
  const PlayIconBox(this.icon, {required this.size, required this.colour, super.key});

  final PlayIcon icon;
  final double size;
  final Color colour;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: PlayIconPainter(icon, colour)),
      );
}
