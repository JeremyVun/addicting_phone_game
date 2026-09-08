import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/coin_chip.dart';
import '../widgets/level_ring.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    final profile = controller.profile;
    return Scaffold(
      backgroundColor: palette.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CoinChip(coins: profile.coins, palette: palette, size: 18),
                  const SizedBox(width: 14),
                  LevelRing(
                    level: profile.level,
                    progress: profile.levelProgress,
                    palette: palette,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/settings'),
                    icon: Icon(Icons.settings_outlined, color: palette.muted),
                    tooltip: S.homeSettings,
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                S.appName.toUpperCase(),
                style: manrope(
                  size: 19,
                  weight: 800,
                  color: palette.ink,
                  letterSpacing: 19 * 0.42,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = math.min(
                      math.min(constraints.maxWidth, constraints.maxHeight),
                      240.0,
                    );
                    return Center(
                      child: SizedBox.square(
                        dimension: side,
                        child: CustomPaint(painter: _MotifPainter(palette)),
                      ),
                    );
                  },
                ),
              ),
              PrimaryButton(
                label: S.homePlay,
                height: 64,
                palette: palette,
                onPressed: controller.startClassic,
              ),
              const SizedBox(height: 12),
              _DailyCard(controller: controller),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _LinkButton(
                      label: S.homeThemes,
                      palette: palette,
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/themes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LinkButton(
                      label: S.homeShop,
                      palette: palette,
                      onPressed: () => Navigator.of(context).pushNamed('/shop'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AppTextButton(
                label: S.homeAchievements,
                palette: palette,
                onPressed: () =>
                    Navigator.of(context).pushNamed('/achievements'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.homeDailyTitle,
                  style: manrope(size: 18, weight: 800, color: palette.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  S.homeDailyNotPlayed,
                  style: manrope(size: 12, weight: 600, color: palette.muted),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${controller.profile.streak}',
                style: manrope(
                  size: 30,
                  weight: 800,
                  color: palette.ink,
                  letterSpacing: -0.9,
                  height: 1.05,
                ),
              ),
              Text(
                S.homeStreakLabel.toUpperCase(),
                style: manrope(
                  size: 10,
                  weight: 700,
                  color: palette.muted,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Icon(Icons.play_arrow_rounded, size: 18, color: palette.accent),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  final String label;
  final ThemePalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: palette.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      child: Text(
        label.toUpperCase(),
        style: manrope(
          size: 13,
          weight: 700,
          color: palette.muted,
          letterSpacing: 2.0,
        ),
      ),
    ),
  );
}

/// A still life of the board, not a game: fixed cells, fixed colour indices.
class _MotifPainter extends CustomPainter {
  const _MotifPainter(this.palette);

  static const List<List<int>> _cells = [
    [1, 2, 3],
    [1, 5, 1],
    [2, 1, 5],
    [2, 2, 3],
    [2, 5, 1],
    [2, 6, 7],
    [3, 1, 5],
    [3, 2, 3],
    [3, 4, 4],
    [3, 5, 1],
    [3, 6, 7],
    [4, 2, 2],
    [4, 4, 4],
    [5, 1, 6],
    [5, 3, 2],
  ];

  final ThemePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    const wellPadding = 7.0;
    final well = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    canvas.drawRRect(well, Paint()..color = palette.well);
    canvas.drawRRect(
      well,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.hairline,
    );
    final cell = (size.width - wellPadding * 2 - gap * 7) / 8;
    final filled = {for (final c in _cells) (c[0], c[1]): c[2]};
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            wellPadding + col * (cell + gap),
            wellPadding + row * (cell + gap),
            cell,
            cell,
          ),
          const Radius.circular(5),
        );
        final colourIndex = filled[(row, col)];
        canvas.drawRRect(
          rect,
          Paint()
            ..color = colourIndex == null
                ? palette.empty
                : palette.block(colourIndex),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MotifPainter old) => old.palette != palette;
}
