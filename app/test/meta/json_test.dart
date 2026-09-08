import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/game_summary.dart';
import 'package:settle/meta/player_profile.dart';
import 'package:settle/meta/progression.dart';

/// Every field away from its default, so a dropped field cannot round trip.
final loaded = PlayerProfile(
  coins: 4321,
  xp: 9876,
  gamesCompleted: 57,
  bestClassic: 12345,
  bestDaily: 6789,
  skill: 0.7123,
  unlockedThemes: {1, 5, 11},
  selectedTheme: 5,
  achievements: {'first_clear', 'score_5k'},
  rewardCycleDay: 4,
  lastRewardClaimOrdinal: 240,
  rewardDismissedOrdinal: 239,
  streak: 12,
  lastCompletedOrdinal: 240,
  streakReconciledOrdinal: 239,
  freezesHeld: 2,
  dailyBest: {238: 900, 239: 1200, 240: 1500},
  dailyAttempts: {238: 1, 239: 2, 240: 1},
  dailySecondAttemptUsed: 239,
  lastFirstGameOfDayOrdinal: 240,
  adFree: true,
  themePackOwned: true,
  pendingPurchaseTokens: {'token-c'},
  completedPurchaseTokens: ['token-a', 'token-b'],
  lastFinishedGameId: 'seed-42:1748000000000',
  gamesSinceInterstitial: 3,
  lastInterstitialClosedAt: 1748000111222,
  lastRewardedClosedAt: 1748000333444,
  soundEnabled: false,
  hapticsEnabled: false,
  remindersEnabled: true,
  reminderPermissionAsked: true,
  analyticsUnitId: '5f1b1b7c-0d1e-4a2b-8c3d-9e0f1a2b3c4d',
  createdAtMs: 1747000000000,
);

void main() {
  test('PlayerProfile round trips through JSON with every field set', () {
    final decoded = PlayerProfile.fromJson(
      jsonDecode(jsonEncode(loaded.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, loaded);
    expect(decoded.hashCode, loaded.hashCode);
    expect(decoded.toJson(), loaded.toJson());
    expect(decoded.dailyBest[239], 1200);
    expect(decoded.unlockedThemes, {1, 5, 11});
    expect(loaded.toJson()['v'], PlayerProfile.version);
  });

  test('equality is deep, not identity', () {
    expect(
      loaded.copyWith(dailyBest: {...loaded.dailyBest}),
      loaded,
    );
    expect(loaded.copyWith(coins: 4322), isNot(loaded));
    expect(loaded.copyWith(dailyBest: const {1: 1}), isNot(loaded));
    expect(loaded.copyWith(achievements: const {}), isNot(loaded));
  });

  test('an empty object decodes to the defaults', () {
    final blank = PlayerProfile.fromJson(const {});
    expect(blank, PlayerProfile());
    expect(blank.unlockedThemes, {PlayerProfile.defaultThemeSlot});
    expect(blank.skill, 0.35);
    expect(blank.lastCompletedOrdinal, isNull);
    expect(blank.rewardCycleDay, 1);
  });

  test('collections on a profile are unmodifiable', () {
    expect(() => loaded.dailyBest[1] = 1, throwsUnsupportedError);
    expect(() => loaded.achievements.add('x'), throwsUnsupportedError);
    expect(() => loaded.completedPurchaseTokens.add('x'), throwsUnsupportedError);
    expect(() => loaded.pendingPurchaseTokens.add('x'), throwsUnsupportedError);
  });

  test('LastGameResult round trips', () {
    final result = LastGameResult(
      gameId: 'seed-7:1748000000000',
      mode: GameMode.daily,
      score: 4820,
      baseCoins: 96,
      bonusCoins: 175,
      xp: 482,
      levelUps: [4, 5],
      newAchievements: ['score_2500', 'combo_5'],
      streakAfter: 12,
      elapsedMs: 214000,
      dayOrdinal: 240,
      doubled: true,
    );
    final decoded = LastGameResult.fromJson(
      jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, result);
    expect(decoded.totalCoins, 271);
    expect(result.toJson()['v'], LastGameResult.version);
  });

  test('GameSummary round trips', () {
    const summary = GameSummary(
      mode: GameMode.daily,
      gameId: 'g',
      score: 10,
      placements: 4,
      durationMs: 5000,
      maxCombo: 2,
      boardClearedCount: 1,
      continued: true,
      dayOrdinal: 300,
    );
    expect(
      GameSummary.fromJson(
        jsonDecode(jsonEncode(summary.toJson())) as Map<String, dynamic>,
      ),
      summary,
    );
  });
}
