import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/game.dart' as core;
import 'package:settle/core/game_state.dart' as core;
import 'package:settle/meta/meta.dart';
import 'package:settle/services/storage.dart';

void main() {
  test('a full AppData round trips through storage', () async {
    final game = core.Game.newGame(
      mode: core.GameMode.daily,
      seed: 240,
      startedAtMs: 1748000000000,
      dayOrdinal: 240,
    );
    final data = AppData(
      profile: PlayerProfile.initial(
        analyticsUnitId: 'unit-1',
        now: DateTime(2026, 5, 1),
      ).copyWith(
        coins: 1240,
        xp: 6285,
        gamesCompleted: 42,
        bestClassic: 12460,
        unlockedThemes: {1, 2, 3},
        selectedTheme: 3,
        achievements: {'combo_3', 'score_1k'},
        dailyBest: {240: 1500},
        dailyAttempts: {240: 1},
        pendingPurchaseTokens: {'tok-a'},
        completedPurchaseTokens: ['tok-b'],
        lastFinishedGameId: 'seed-1:2',
      ),
      savedGame: game,
      lastResult: LastGameResult(
        gameId: 'seed-1:2',
        mode: GameMode.daily,
        score: 4820,
        baseCoins: 96,
        bonusCoins: 175,
        xp: 482,
        levelUps: const [4, 5],
        newAchievements: const ['score_2500'],
        streakAfter: 12,
        elapsedMs: 214000,
        dayOrdinal: 240,
      ),
    );

    final storage = MemoryStorage();
    await storage.save(data);
    final loaded = await storage.load();

    expect(loaded!.profile, data.profile);
    expect(loaded.savedGame, data.savedGame);
    expect(loaded.lastResult, data.lastResult);
  });

  test('empty storage loads null', () async {
    expect(await MemoryStorage().load(), isNull);
  });
}
