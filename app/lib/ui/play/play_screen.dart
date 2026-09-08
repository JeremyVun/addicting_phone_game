import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../../core/game_state.dart';
import '../../services/audio.dart';
import '../../services/haptics.dart';
import '../theme/typography.dart';
import 'play_geometry.dart';
import 'play_host.dart';
import 'play_icons.dart';
import 'play_strings.dart';
import 'settle_play_game.dart';

/// Thousands separators without pulling in `intl` for one string.
String formatScore(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

class PlayScreen extends StatefulWidget {
  const PlayScreen({
    required this.host,
    this.audio = const NoopAudioService(),
    this.haptics = const NoopHapticsService(),
    super.key,
  });

  final PlayHost host;
  final AudioService audio;
  final HapticsService haptics;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  SettlePlayGame? _game;

  @override
  void initState() {
    super.initState();
    widget.host.addListener(_onHostChanged);
    widget.audio.preload();
  }

  @override
  void dispose() {
    widget.host.removeListener(_onHostChanged);
    super.dispose();
  }

  void _onHostChanged() {
    _game?.syncFromHost();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 120 || constraints.maxHeight < 200) {
          return ColoredBox(color: widget.host.palette.ground);
        }
        final geom = PlayGeometry.of(
          constraints.biggest,
          safeTop: media.padding.top,
          safeBottom: media.padding.bottom,
        );
        final game = _game ??= SettlePlayGame(
          host: widget.host,
          audio: widget.audio,
          haptics: widget.haptics,
          geometry: geom,
        );
        game.applyGeometry(geom);
        return ValueListenableBuilder<double>(
          valueListenable: game.dim,
          builder: (context, dim, child) => _Dimmed(amount: dim, child: child!),
          // A loose Stack would collapse to its smallest child and leave the
          // GameWidget with no size at all.
          child: SizedBox.fromSize(
            size: geom.size,
            child: Stack(
              children: [
                Positioned.fill(child: GameWidget(game: game)),
                _Hud(host: widget.host, game: game, geom: geom),
                _Band(host: widget.host, geom: geom),
                Positioned.fromRect(
                  rect: geom.pauseButton,
                  child: _TapTarget(
                    key: const ValueKey('pause'),
                    onTap: widget.host.requestPause,
                    semantics: PlayStrings.pauseSemantics,
                    child: Center(
                      child: PlayIconBox(
                        PlayIcon.pause,
                        size: 20 * geom.s,
                        colour: widget.host.palette.faint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Game over dims the HUD, the well and the tray to brightness 40% and
/// saturation 65% (`styles.md`), behind whatever sheet the host puts up.
class _Dimmed extends StatelessWidget {
  const _Dimmed({required this.amount, required this.child});

  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return child;
    final sat = 1.0 - 0.35 * amount;
    final bri = 1.0 - 0.60 * amount;
    double m(double base, double delta) => (base + delta * sat) * bri;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        m(0.213, 0.787), m(0.715, -0.715), m(0.072, -0.072), 0, 0, //
        m(0.213, -0.213), m(0.715, 0.285), m(0.072, -0.072), 0, 0, //
        m(0.213, -0.213), m(0.715, -0.715), m(0.072, 0.928), 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
      child: child,
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.host, required this.game, required this.geom});

  final PlayHost host;
  final SettlePlayGame game;
  final PlayGeometry geom;

  @override
  Widget build(BuildContext context) {
    final p = host.palette;
    final showBest = host.bestScore > 0;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: geom.pad,
            top: geom.hudTop,
            child: Text(
              PlayStrings.score,
              style: PlayType.label(geom.s, p.faint),
            ),
          ),
          Positioned(
            left: geom.pad,
            top: geom.scoreTop,
            child: ValueListenableBuilder<int>(
              valueListenable: game.displayScore,
              builder: (context, value, _) => Text(
                formatScore(value),
                style: PlayType.score(geom.s, p.ink),
              ),
            ),
          ),
          if (showBest)
            Positioned(
              right: geom.pad,
              top: geom.hudTop,
              child: Text(
                PlayStrings.best,
                style: PlayType.label(geom.s, p.faint),
              ),
            ),
          if (showBest)
            // Bottom-aligned in the score numeral's own box, so Best answers
            // the score on its baseline whatever the font metrics do.
            Positioned(
              right: geom.pad,
              top: geom.scoreTop,
              height: 33.1 * geom.s,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  formatScore(host.bestScore),
                  style: PlayType.best(geom.s, p.muted),
                ),
              ),
            ),
          Positioned(
            left: geom.pad,
            top: geom.ruleY,
            width: geom.well.width,
            height: 1,
            child: ColoredBox(color: p.hairline),
          ),
          Positioned.fromRect(
            rect: geom.gutter,
            child: Align(
              alignment: Alignment.centerRight,
              child: ValueListenableBuilder<int>(
                valueListenable: game.combo,
                builder: (context, count, _) => _ComboBanner(
                  count: count,
                  style: PlayType.combo(geom.s, p.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scales in over 200 ms and then holds for as long as the combo stands
/// (design 9.3 and 2.4).
class _ComboBanner extends StatefulWidget {
  const _ComboBanner({required this.count, required this.style});

  final int count;
  final TextStyle style;

  @override
  State<_ComboBanner> createState() => _ComboBannerState();
}

class _ComboBannerState extends State<_ComboBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.count >= 2 ? 1 : 0,
  );

  @override
  void didUpdateWidget(_ComboBanner old) {
    super.didUpdateWidget(old);
    if (widget.count < 2) {
      _controller.reverse();
    } else if (widget.count != old.count) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(
          _controller.value.clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: _controller.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
        );
      },
      child: Text(
        PlayStrings.combo(widget.count < 2 ? 2 : widget.count),
        style: widget.style,
      ),
    );
  }
}

/// Fixed height so the board never moves when the hint disappears
/// (`styles.md`): the reroll pill right, the first-game hint centred.
class _Band extends StatelessWidget {
  const _Band({required this.host, required this.geom});

  final PlayHost host;
  final PlayGeometry geom;

  String? get _hint {
    if (!host.showFirstGameHints) return null;
    final state = host.state;
    if (state.placements == 0) return PlayStrings.hintFirstPlacement;
    if (state.maxCombo == 0) return PlayStrings.hintFirstClear;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = host.palette;
    final hint = _hint;
    final canReroll =
        host.state.status == GameStatus.playing &&
        host.state.rerollsUsed < 3 &&
        host.state.set.any((piece) => piece != null);
    return Positioned.fromRect(
      rect: geom.band,
      child: Stack(
        children: [
          if (hint != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Text(hint, style: PlayType.hint(geom.s, p.faint)),
                ),
              ),
            ),
          if (canReroll)
            Align(
              alignment: Alignment.centerRight,
              child: _RerollPill(host: host, geom: geom),
            ),
        ],
      ),
    );
  }
}

class _RerollPill extends StatelessWidget {
  const _RerollPill({required this.host, required this.geom});

  final PlayHost host;
  final PlayGeometry geom;

  @override
  Widget build(BuildContext context) {
    final p = host.palette;
    final s = geom.s;
    final rewarded = host.rewardedRerollAvailable;
    return _TapTarget(
      key: const ValueKey('reroll'),
      onTap: host.requestReroll,
      semantics: PlayStrings.rerollSemantics,
      child: Container(
        height: 28 * s,
        padding: EdgeInsets.symmetric(horizontal: 10 * s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: p.hairline, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayIconBox(PlayIcon.reroll, size: 14 * s, colour: p.muted),
            SizedBox(width: 6 * s),
            if (rewarded)
              PlayIconBox(PlayIcon.play, size: 12 * s, colour: p.accent)
            else ...[
              PlayIconBox(PlayIcon.coin, size: 12 * s, colour: p.accent),
              SizedBox(width: 4 * s),
              Text(
                PlayStrings.rerollPrice(host.rerollCoinPrice),
                style: PlayType.pill(s, p.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TapTarget extends StatelessWidget {
  const _TapTarget({
    required this.onTap,
    required this.semantics,
    required this.child,
    super.key,
  });

  final VoidCallback onTap;
  final String semantics;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
}
