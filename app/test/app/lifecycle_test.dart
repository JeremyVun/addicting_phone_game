import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/day_ordinal.dart';
import 'package:settle/core/game.dart' as core;
import 'package:settle/core/game_state.dart' as core;
import 'package:settle/meta/meta.dart';
import 'package:settle/services/storage.dart';

import 'harness.dart';

String _saved(AppData data) => jsonEncode(data.toJson());

AppData _dataWith({core.GameState? game, LastGameResult? result, PlayerProfile? profile}) =>
    AppData(
      profile:
          profile ??
          PlayerProfile.initial(
            analyticsUnitId: 'unit',
            now: DateTime(2026, 1, 1),
          ),
      savedGame: game,
      lastResult: result,
    );

void main() {
  final now = DateTime(2026, 9, 8, 12);
  final today = dayOrdinalOf(now);

  test('start on empty storage creates a profile and persists it', () async {
    final harness = Harness(now: now);
    await harness.start();

    expect(harness.controller.profile.analyticsUnitId, isNotEmpty);
    expect(harness.controller.profile.createdAtMs, now.millisecondsSinceEpoch);
    expect(harness.storage.writes, hasLength(1));
    expect(harness.analytics.named('session_started').single.dims, {'first': 'true'});
  });

  test('start resumes a saved classic game from any day', () async {
    final game = core.Game.newGame(
      mode: core.GameMode.classic,
      seed: 99,
      startedAtMs: 1,
    );
    final harness = Harness(saved: _saved(_dataWith(game: game)), now: now);
    await harness.start();

    expect(harness.controller.currentGame!.id, game.id);
    harness.controller.resumeFromLaunch();
    expect(harness.navigator.calls, ['goPlay']);
    expect(harness.analytics.named('session_started').single.dims, {'first': 'false'});
  });

  test('start discards a saved daily from yesterday', () async {
    final game = core.Game.newGame(
      mode: core.GameMode.daily,
      seed: today - 1,
      startedAtMs: 1,
      dayOrdinal: today - 1,
    );
    final harness = Harness(saved: _saved(_dataWith(game: game)), now: now);
    await harness.start();

    expect(harness.controller.currentGame, isNull);
  });

  test('start keeps a saved daily from today', () async {
    final game = core.Game.newGame(
      mode: core.GameMode.daily,
      seed: today,
      startedAtMs: 1,
      dayOrdinal: today,
    );
    final harness = Harness(saved: _saved(_dataWith(game: game)), now: now);
    await harness.start();

    expect(harness.controller.currentGame!.dayOrdinal, today);
  });

  test('a pending lastResult reopens the game over sheet on launch', () async {
    final harness = Harness(
      saved: _saved(
        _dataWith(
          result: LastGameResult(
            gameId: 'seed-1:2',
            mode: GameMode.classic,
            score: 900,
            baseCoins: 18,
            bonusCoins: 0,
            xp: 90,
            levelUps: const [],
            newAchievements: const [],
            streakAfter: 0,
            elapsedMs: 60000,
          ),
        ),
      ),
      now: now,
    );
    await harness.start();
    harness.controller.resumeFromLaunch();

    expect(harness.navigator.calls, ['showGameOver']);
  });

  test('a saved game already over resumes to the continue offer', () async {
    var game = core.Game.newGame(
      mode: core.GameMode.classic,
      seed: 7,
      startedAtMs: 1,
    );
    game = core.GameState.fromJson({
      ...game.toJson(),
      'status': core.GameStatus.over.name,
    });
    final harness = Harness(saved: _saved(_dataWith(game: game)), now: now);
    await harness.start();
    harness.controller.resumeFromLaunch();

    expect(harness.navigator.calls, ['goPlay', 'showGameOver']);
    expect(harness.controller.continueAvailable, isTrue);
  });

  test('startClassic restricts the first game only and persists it', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();

    final game = harness.controller.currentGame!;
    expect(game.restricted, isTrue);
    expect(game.mode, core.GameMode.classic);
    expect(harness.navigator.calls, contains('goPlay'));
    expect(harness.analytics.named('game_started').single.dims, {'mode': 'classic'});

    final reloaded = await harness.storage.load();
    expect(reloaded!.savedGame!.id, game.id);
  });

  test('place persists the new state', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();
    final before = harness.controller.state;
    final piece = before.set.firstWhere((p) => p != null)!;
    final slot = before.set.indexOf(piece);

    harness.controller.place(slot, 0, 0);
    await harness.controller.idle;

    expect(harness.controller.state.set[slot], isNull);
    final reloaded = await harness.storage.load();
    expect(reloaded!.savedGame!.board.filledCount, piece.size);
  });

  test('setSound and setHaptics persist', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.setSound(false);
    await harness.controller.setHaptics(false);

    final reloaded = await harness.storage.load();
    expect(reloaded!.profile.soundEnabled, isFalse);
    expect(reloaded.profile.hapticsEnabled, isFalse);
  });

  test('selectTheme goes through Themes.select and reports the theme', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(xp: 10000)),
    );
    await harness.controller.selectTheme(3);

    expect(harness.controller.profile.selectedTheme, 3);
    expect(harness.controller.palette.id, 'meadow');
    expect(harness.analytics.named('theme_selected').single.dims, {'theme': 'Meadow'});
  });
}
