// Runnable dev entry for the play screen, with no app shell:
//   flutter run -t lib/dev/play_harness.dart -d emulator-5554
// The dot at the bottom left opens a menu that sets each exemplar scenario.
import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/game.dart';
import '../core/game_state.dart';
import '../core/piece.dart';
import '../services/audio.dart';
import '../services/haptics.dart';
import '../ui/play/play_host.dart';
import '../ui/play/play_screen.dart';
import '../ui/theme/palettes.dart';
import '../ui/theme/typography.dart';

void main() => runApp(const HarnessApp());

enum Scenario {
  empty('empty'),
  mid('mid'),
  clearMoment('clear'),
  danger('danger'),
  weights('type');

  const Scenario(this.label);

  final String label;
}

const _boards = {
  Scenario.mid: '..3..1...53..17..53.417...2.4...6.22447.6644..70.6...0..55.0.0..',
  Scenario.clearMoment:
      '....71...53..1...53.415.123456706.2244..66..1370...5.0..55...4..',
  Scenario.danger:
      '4433.1.7445.311.4453..112.53.76666.3446.6644337..651005555.00055',
};

const _sets = {
  Scenario.empty: ['o2:0', 'l3:0', 'i3:0'],
  Scenario.mid: ['l4:0', 'i2:0', 't4:0'],
  Scenario.clearMoment: ['t4:0', 'l3:0', null],
  Scenario.danger: [null, 'o3:0', null],
};

class HarnessHost extends ChangeNotifier implements PlayHost {
  HarnessHost() {
    load(Scenario.empty);
  }

  static const fakeBest = 12460;
  static const fakeCoins = 1240;

  late GameState _state;
  Scenario scenario = Scenario.empty;
  ThemePalette _palette = ThemePalette.obsidian;
  int _serial = 0;
  bool gameOverShown = false;

  @override
  GameState get state => _state;

  @override
  int get bestScore => scenario == Scenario.empty ? 0 : fakeBest;

  @override
  int get coins => fakeCoins;

  @override
  bool get rewardedRerollAvailable => scenario != Scenario.danger;

  @override
  int get rerollCoinPrice => 50;

  @override
  bool get soundOn => true;

  @override
  bool get hapticsOn => true;

  @override
  bool get showFirstGameHints => scenario == Scenario.empty;

  @override
  ThemePalette get palette => _palette;

  set palette(ThemePalette value) {
    _palette = value;
    notifyListeners();
  }

  void load(Scenario s) {
    scenario = s;
    gameOverShown = false;
    final fresh = Game.newGame(
      mode: GameMode.classic,
      seed: 7,
      restricted: s == Scenario.empty,
      startedAtMs: ++_serial,
    );
    final grid = _boards[s];
    final ids = _sets[s];
    _state = fresh.copyWith(
      board: grid == null ? Board.empty() : Board.fromJson(grid),
      set: ids == null
          ? fresh.set
          : List.unmodifiable([for (final id in ids) id == null ? null : Piece.byId[id]]),
      score: s == Scenario.empty ? 0 : 4820,
      comboCount: s == Scenario.clearMoment ? 3 : 0,
      maxCombo: s == Scenario.empty ? 0 : 3,
      placements: s == Scenario.empty ? 0 : 40,
    );
    notifyListeners();
  }

  void newGame() {
    load(Scenario.empty);
  }

  @override
  PlacementResult place(int slot, int row, int col) {
    final result = Game.place(_state, slot, row, col);
    _state = result.state;
    return result;
  }

  @override
  void requestReroll() {
    if (_state.rerollsUsed >= 3) return;
    _state = Game.reroll(_state);
    notifyListeners();
  }

  @override
  void requestPause() {
    debugPrint('harness: pause requested');
  }

  @override
  void onGameOver() {
    gameOverShown = true;
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 1400), newGame);
  }
}

class HarnessApp extends StatefulWidget {
  const HarnessApp({super.key});

  @override
  State<HarnessApp> createState() => _HarnessAppState();
}

class _HarnessAppState extends State<HarnessApp> {
  final _host = HarnessHost();
  final _audio = FlameAudioService();
  final _haptics = PlatformHapticsService();
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _host.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final p = _host.palette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: p.ground,
        body: Stack(
          children: [
            if (_host.scenario == Scenario.weights)
              _WeightSpecimen(palette: p)
            else
              PlayScreen(host: _host, audio: _audio, haptics: _haptics),
            if (_host.gameOverShown)
              IgnorePointer(
                child: Center(
                  child: Text(
                    'GAME OVER',
                    style: manrope(size: 22, weight: 800, color: p.ink, letterSpacing: 4),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _menuOpen = !_menuOpen),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Center(
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: p.faint.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_menuOpen) _menu(p),
          ],
        ),
      ),
    );
  }

  Widget _menu(ThemePalette p) => Positioned(
        left: 8,
        bottom: 40,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.well,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (final s in Scenario.values)
                    _chip(p, s.label, () {
                      _host.load(s);
                      setState(() => _menuOpen = false);
                    }),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 250,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final theme in ThemePalette.all)
                      _chip(p, theme.name, () {
                        _host.palette = theme;
                        setState(() => _menuOpen = false);
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _chip(ThemePalette p, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: p.hairline),
          ),
          child: Text(label, style: manrope(size: 11, weight: 700, color: p.muted)),
        ),
      );
}

/// Proof on device that the variable font's `wght` axis is actually moving.
class _WeightSpecimen extends StatelessWidget {
  const _WeightSpecimen({required this.palette});

  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in [300, 400, 500, 700, 800])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Settle 4,820 $w',
                  style: manrope(size: 30, weight: w, color: palette.ink),
                ),
              ),
          ],
        ),
      );
}
