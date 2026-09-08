import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';

/// Replaced screen by screen in the meta-screens phase.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.palette,
  });

  final String title;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: palette.ground,
    appBar: AppBar(
      backgroundColor: palette.ground,
      foregroundColor: palette.ink,
      elevation: 0,
      title: Text(title, style: manrope(size: 18, weight: 800, color: palette.ink)),
    ),
    body: Center(
      child: Text(
        S.comingSoon,
        style: manrope(size: 15, weight: 600, color: palette.muted),
      ),
    ),
  );
}
