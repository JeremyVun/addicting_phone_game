import 'package:flutter/painting.dart';

/// Manrope is bundled as one variable TTF, so `fontWeight` alone picks the
/// single named instance the engine registered; `fontVariations` is what
/// actually moves the `wght` axis.
TextStyle manrope({
  required double size,
  required int weight,
  Color? color,
  double letterSpacing = 0,
  double? height,
  List<Shadow>? shadows,
}) =>
    TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );

/// The one type ladder of `styles.md`, at 360 CSS px; `s` scales it by width.
abstract final class PlayType {
  static TextStyle label(double s, Color color) =>
      manrope(size: 11 * s, weight: 700, color: color, letterSpacing: 1.76 * s);

  static TextStyle score(double s, Color color) => manrope(
        size: 36 * s,
        weight: 800,
        color: color,
        letterSpacing: -0.72 * s,
        height: 0.92,
      );

  static TextStyle best(double s, Color color) => manrope(
        size: 15 * s,
        weight: 700,
        color: color,
        letterSpacing: -0.15 * s,
        height: 1.0,
      );

  static TextStyle combo(double s, Color color) =>
      manrope(size: 15 * s, weight: 800, color: color, letterSpacing: 0.15 * s);

  static TextStyle popup(double s) => manrope(
        size: 34 * s,
        weight: 800,
        color: const Color(0xFFFFFFFF),
        letterSpacing: -0.68 * s,
        shadows: [
          Shadow(color: const Color(0xD9000000), blurRadius: 10 * s, offset: Offset(0, 2 * s)),
          const Shadow(color: Color(0xE6000000), blurRadius: 2),
        ],
      );

  static TextStyle hint(double s, Color color) =>
      manrope(size: 12 * s, weight: 500, color: color, letterSpacing: 0.06 * s);

  static TextStyle pill(double s, Color color) =>
      manrope(size: 12 * s, weight: 800, color: color, letterSpacing: 0.06 * s);
}
