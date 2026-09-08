import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/board.dart';
import 'package:settle/core/game.dart';
import 'package:settle/core/game_state.dart';
import 'package:settle/core/piece.dart';
import 'package:settle/ui/play/play_geometry.dart';
import 'package:settle/ui/play/play_host.dart';
import 'package:settle/ui/play/play_screen.dart';
import 'package:settle/ui/play/settle_play_game.dart';
import 'package:settle/ui/theme/palettes.dart';

const _frame = Size(360, 800);

class FakeHost extends ChangeNotifier implements PlayHost {
  FakeHost({GameState? initial, this.hints = false})
      : _state = initial ??
            Game.newGame(mode: GameMode.classic, seed: 1, startedAtMs: 1);

  GameState _state;
  final bool hints;
  final calls = <(int, int, int)>[];
  int rerolls = 0;
  int pauses = 0;
  int gameOvers = 0;
  ThemePalette _palette = ThemePalette.obsidian;

  void swap(GameState next) {
    _state = next;
    notifyListeners();
  }

  set palette(ThemePalette value) {
    _palette = value;
    notifyListeners();
  }

  @override
  GameState get state => _state;

  @override
  int get bestScore => 12460;

  @override
  int get coins => 1240;

  @override
  bool get rewardedRerollAvailable => false;

  @override
  int get rerollCoinPrice => 50;

  @override
  bool get soundOn => true;

  @override
  bool get hapticsOn => true;

  @override
  bool get showFirstGameHints => hints;

  @override
  ThemePalette get palette => _palette;

  @override
  PlacementResult place(int slot, int row, int col) {
    calls.add((slot, row, col));
    final result = Game.place(_state, slot, row, col);
    _state = result.state;
    return result;
  }

  @override
  void requestReroll() => rerolls++;

  @override
  void requestPause() => pauses++;

  @override
  void onGameOver() => gameOvers++;
}

Future<PlayGeometry> pumpPlay(WidgetTester tester, FakeHost host) async {
  tester.view.physicalSize = _frame;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: _frame),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PlayScreen(host: host),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  return PlayGeometry.of(_frame);
}

SettlePlayGame gameOf(WidgetTester tester) => tester
    .widget<GameWidget<SettlePlayGame>>(find.byType(GameWidget<SettlePlayGame>))
    .game!;

/// A drag the Flame gesture recogniser sees as a real drag: several moves.
Future<void> dragPiece(
  WidgetTester tester,
  Offset from,
  Offset to, {
  int steps = 8,
}) async {
  final gesture = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 16));
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 16));
}

/// Where the finger must be for the piece's top-left cell to land on (row, col).
Offset fingerFor(PlayGeometry geom, Piece piece, int row, int col) {
  final lead = geom.cellCentre(row, col);
  final centre = Offset(
    lead.dx + (piece.width - 1) * (geom.cell + geom.gap) / 2,
    lead.dy + (piece.height - 1) * (geom.cell + geom.gap) / 2,
  );
  return centre.translate(0, 64 * geom.s);
}

GameState scripted(List<String?> ids, {String? board}) {
  final fresh = Game.newGame(mode: GameMode.classic, seed: 1, startedAtMs: 1);
  return fresh.copyWith(
    board: board == null ? Board.empty() : Board.fromJson(board),
    set: List.unmodifiable([for (final id in ids) id == null ? null : Piece.byId[id]]),
  );
}

void main() {
  testWidgets('the play screen builds and shows the score', (tester) async {
    final host = FakeHost();
    await pumpPlay(tester, host);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('BEST'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('12,460'), findsOneWidget);
  });

  testWidgets('the first-game hints follow the state', (tester) async {
    final host = FakeHost(hints: true);
    await pumpPlay(tester, host);
    expect(find.text('Drag a block onto the grid'), findsOneWidget);
    host.swap(host.state.copyWith(placements: 1));
    await tester.pump();
    expect(find.text('Fill a row or column to clear it'), findsOneWidget);
    host.swap(host.state.copyWith(maxCombo: 1));
    await tester.pump();
    expect(find.text('Drag a block onto the grid'), findsNothing);
    expect(find.text('Fill a row or column to clear it'), findsNothing);
  });

  testWidgets('a new state id shows its board within 300 ms', (tester) async {
    final host = FakeHost();
    await pumpPlay(tester, host);
    final fresh = Game.newGame(mode: GameMode.classic, seed: 9, startedAtMs: 2)
        .copyWith(board: Board.fromJson('${'0' * 8}${'.' * 56}'), score: 4820);
    host.swap(fresh);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('4,820'), findsOneWidget);
  });

  testWidgets('the reroll pill and pause icon reach the host', (tester) async {
    final host = FakeHost();
    await pumpPlay(tester, host);
    await tester.tap(find.byKey(const ValueKey('reroll')));
    await tester.tap(find.byKey(const ValueKey('pause')));
    await tester.pump();
    expect(host.rerolls, 1);
    expect(host.pauses, 1);
  });

  testWidgets('a legal drag places through the host and redraws the grid',
      (tester) async {
    final host = FakeHost(initial: scripted(['i3:0', 'o2:0', 'l3:0']));
    final geom = await pumpPlay(tester, host);
    final piece = Piece.byId['i3:0']!;
    await dragPiece(
      tester,
      geom.traySlot(0).center,
      fingerFor(geom, piece, 2, 3),
    );
    expect(host.calls, [(0, 2, 3)]);
    expect(host.state.board.cellAt(2, 3), piece.colourIndex);
    expect(host.state.set[0], isNull);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a drag that completes a row clears it and scores the clear',
      (tester) async {
    final host = FakeHost(
      initial: scripted(
        ['i3:0', 'o2:0', 'l3:0'],
        board: '${'.' * 24}11111...${'.' * 32}',
      ),
    );
    final geom = await pumpPlay(tester, host);
    await dragPiece(
      tester,
      geom.traySlot(0).center,
      fingerFor(geom, Piece.byId['i3:0']!, 3, 5),
    );
    expect(host.calls, [(0, 3, 5)]);
    for (var c = 0; c < Board.size; c++) {
      expect(host.state.board.cellAt(3, c), isNull);
    }
    // 3 placed + clear(1) * multiplier 1 + the 300 board clear
    expect(host.state.score, 313);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('313'), findsOneWidget);
  });

  testWidgets('an illegal drop flies back and calls nothing', (tester) async {
    final host = FakeHost(
      initial: scripted(['i3:0', 'o2:0', 'l3:0'], board: '${'2' * 8}${'.' * 56}'),
    );
    final geom = await pumpPlay(tester, host);
    final before = host.state;
    await dragPiece(
      tester,
      geom.traySlot(0).center,
      fingerFor(geom, Piece.byId['i3:0']!, 0, 0),
    );
    expect(host.calls, isEmpty);
    expect(host.state, same(before));
    await tester.pump(const Duration(milliseconds: 400));
    expect(gameOf(tester).tray.pieceAt(0)?.id, 'i3:0');
  });

  testWidgets('the tray refills after the third placement', (tester) async {
    final host = FakeHost(initial: scripted(['i3:0', 'i3:0', 'i3:0']));
    final geom = await pumpPlay(tester, host);
    final piece = Piece.byId['i3:0']!;
    for (var slot = 0; slot < 3; slot++) {
      expect(host.state.set.where((p) => p != null).length, 3 - slot);
      await dragPiece(
        tester,
        geom.traySlot(slot).center,
        fingerFor(geom, piece, slot, 0),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(host.calls.length, 3);
    expect(host.state.set.every((p) => p != null), isTrue);
    expect(host.state.setsGenerated, 2);
    await tester.pump(const Duration(milliseconds: 400));
    for (var slot = 0; slot < 3; slot++) {
      expect(gameOf(tester).tray.pieceAt(slot), isNotNull);
    }
  });

  test('scores are grouped in threes', () {
    expect(formatScore(0), '0');
    expect(formatScore(4820), '4,820');
    expect(formatScore(1284600), '1,284,600');
  });
}
