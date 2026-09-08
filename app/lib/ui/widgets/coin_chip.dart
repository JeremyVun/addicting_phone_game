import 'package:flutter/material.dart';

import '../theme/palettes.dart';
import '../theme/typography.dart';
import 'format.dart';

class CoinChip extends StatelessWidget {
  const CoinChip({
    super.key,
    required this.coins,
    required this.palette,
    this.size = 17,
    this.accented = false,
    this.prefix = '',
  });

  final int coins;
  final ThemePalette palette;
  final double size;
  final bool accented;
  final String prefix;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.adjust,
        size: size,
        color: accented ? palette.accent : palette.muted,
      ),
      SizedBox(width: size * 0.4),
      Text(
        '$prefix${formatCount(coins)}',
        style: manrope(
          size: size,
          weight: 800,
          color: palette.ink,
          letterSpacing: -0.2,
        ),
      ),
    ],
  );
}
