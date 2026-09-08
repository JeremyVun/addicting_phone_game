import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/coin_chip.dart';
import '../widgets/format.dart';
import '../widgets/level_ring.dart';
import 'daily_result_sheet.dart';
import 'daily_reward_sheet.dart';
import 'notification_prompt_sheet.dart';
import 'streak_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _sheetUp = false;

  AppController get controller => widget.controller;

  /// Design 7.4 and 10: both sheets belong to Home and are offered again on
  /// every return until the player answers them, so they are not dismissible.
  void _offerPendingSheets() {
    if (_sheetUp || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final Widget? sheet = controller.reminderPromptDue
        ? NotificationPromptSheet(controller: controller)
        : controller.dailyRewardClaimable
        ? DailyRewardSheet(controller: controller)
        : null;
    if (sheet == null) return;
    _sheetUp = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0x00000000),
      builder: (_) => sheet,
    ).whenComplete(() => _sheetUp = false);
  }

  void _openDailyResult() {
    final pending = controller.lastResult;
    final result =
        pending != null && pending.dayOrdinal == controller.today ? pending : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000),
      builder: (_) => DailyResultSheet(controller: controller, result: result),
    );
  }

  void _openStreakSheet() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => StreakSheet(controller: controller),
  );

  void _tapDailyCard() {
    switch (controller.dailyCardState) {
      case DailyCardState.notPlayed:
        controller.startDaily();
      case DailyCardState.inProgress:
        controller.resumeDaily();
      case DailyCardState.done:
        _openDailyResult();
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerPendingSheets());
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
              const SizedBox(height: 30),
              Text(
                S.appName.toUpperCase(),
                style: manrope(
                  size: 19,
                  weight: 800,
                  color: palette.ink,
                  letterSpacing: 19 * 0.42,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = math.min(
                      math.min(constraints.maxWidth, constraints.maxHeight),
                      240.0,
                    );
                    return Align(
                      alignment: Alignment.topCenter,
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
              _DailyCard(
                controller: controller,
                onTap: _tapDailyCard,
                onStreakTap: _openStreakSheet,
              ),
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
  const _DailyCard({
    required this.controller,
    required this.onTap,
    required this.onStreakTap,
  });

  final AppController controller;
  final VoidCallback onTap;
  final VoidCallback onStreakTap;

  String get _status => switch (controller.dailyCardState) {
    DailyCardState.notPlayed => S.homeDailyNotPlayed,
    DailyCardState.inProgress => S.homeDailyInProgress,
    DailyCardState.done => S.homeDailyDone(
      formatCount(controller.dailyBestToday),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    return Material(
      color: const Color(0x00000000),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                      _status,
                      style: manrope(
                        size: 12,
                        weight: 600,
                        color: palette.muted,
                      ),
                    ),
                    if (controller.secondDailyAttemptOffered) ...[
                      const SizedBox(height: 2),
                      Text(
                        S.homeDailySecondAttemptAvailable,
                        style: manrope(
                          size: 12,
                          weight: 700,
                          color: palette.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onStreakTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (controller.profile.freezesHeld > 0) ...[
                            Icon(
                              Icons.ac_unit,
                              size: 15,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 5),
                          ],
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
                        ],
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
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.play_arrow_rounded, size: 18, color: palette.accent),
            ],
          ),
        ),
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
