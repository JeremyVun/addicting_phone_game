import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/calendar.dart';
import 'package:settle/meta/game_summary.dart';
import 'package:settle/meta/levels.dart';
import 'package:settle/meta/player_profile.dart';
import 'package:settle/meta/progression.dart';

final now = DateTime(2026, 5, 4, 12);
final tomorrow = DateTime(2026, 5, 5, 9);

GameSummary game({
  String id = 'g1',
  GameMode mode = GameMode.classic,
  int score = 0,
  int maxCombo = 0,
  int boardClearedCount = 0,
  int placements = 30,
  int durationMs = 60000,
  bool continued = false,
  int? dayOrdinal,
}) => GameSummary(
  mode: mode,
  gameId: id,
  score: score,
  placements: placements,
  durationMs: durationMs,
  maxCombo: maxCombo,
  boardClearedCount: boardClearedCount,
  continued: continued,
  dayOrdinal: dayOrdinal,
);

void main() {
  group('coins', () {
    test('a blank first game of the day pays 5 + 25', () {
      final out = Progression.finish(PlayerProfile(), game(), now);
      expect(out.profile.coins, 30);
      expect(out.result!.baseCoins, 5, reason: 'the bonus is not doublable');
      expect(out.result!.bonusCoins, 25);
      expect(out.result!.totalCoins, 30);
      expect(out.result!.elapsedMs, 60000);
      expect(out.result!.dayOrdinal, isNull);
    });

    test('the bonus applies once per local day', () {
      var p = Progression.finish(PlayerProfile(), game(id: 'a'), now).profile;
      expect(p.coins, 30);
      p = Progression.finish(p, game(id: 'b'), now.add(const Duration(hours: 5))).profile;
      expect(p.coins, 35);
      p = Progression.finish(p, game(id: 'c'), tomorrow).profile;
      expect(p.coins, 65);
      expect(p.lastFirstGameOfDayOrdinal, Calendar.dayOrdinal(tomorrow));
    });

    test('coins follow the 7.1 formula', () {
      for (final (score, coins) in [(0, 5), (249, 5), (250, 5), (300, 6), (10000, 200), (99999, 200)]) {
        final out = Progression.finish(PlayerProfile(), game(score: score), now);
        expect(out.result!.baseCoins, coins, reason: 'score $score');
      }
    });
  });

  group('xp and levels', () {
    test('xp is score ~/ 10 and level-ups pay 50 x level', () {
      final out = Progression.finish(PlayerProfile(), game(score: 1500), now);
      expect(out.result!.xp, 150);
      expect(out.profile.xp, 150);
      expect(out.result!.levelUps, [2]);
      // 30 game coins + 25 first of day + 100 level 2 + 25 score_1k.
      expect(out.profile.coins, 180);
      expect(out.result!.baseCoins, 30);
      expect(out.result!.bonusCoins, 150);
      expect(out.result!.totalCoins, 180);
      expect(out.profile.level, 2);
    });

    test('several levels in one game each pay', () {
      final out = Progression.finish(
        PlayerProfile(xp: Levels.xpForLevel(4) - 1),
        game(score: 10000),
        now,
      );
      expect(out.result!.levelUps, [4, 5]);
      expect(out.profile.level, 5);
      expect(out.result!.xp, 1000);
    });

    test('no level-up when the threshold is not crossed', () {
      final out = Progression.finish(PlayerProfile(), game(score: 1490), now);
      expect(out.result!.levelUps, isEmpty);
    });
  });

  test('skill updates on classic only (7.6)', () {
    final classic = Progression.finish(PlayerProfile(), game(score: 3000), now);
    expect(classic.profile.skill, closeTo(0.8 * 0.35 + 0.2 * 0.5, 1e-12));

    final daily = Progression.finish(
      PlayerProfile(),
      game(mode: GameMode.daily, score: 3000, dayOrdinal: 100),
      now,
    );
    expect(daily.profile.skill, 0.35);

    final capped = Progression.finish(PlayerProfile(), game(score: 99999), now);
    expect(capped.profile.skill, closeTo(0.8 * 0.35 + 0.2, 1e-12));
  });

  test('bests and gamesCompleted', () {
    var p = Progression.finish(PlayerProfile(), game(id: 'a', score: 900), now).profile;
    expect(p.bestClassic, 900);
    expect(p.gamesCompleted, 1);
    p = Progression.finish(p, game(id: 'b', score: 400), now).profile;
    expect(p.bestClassic, 900);
    expect(p.gamesCompleted, 2);
    expect(p.bestDaily, 0);
  });

  group('daily', () {
    test('records the day best, attempts and streak', () {
      const ordinal = 123;
      var p = Progression.finish(
        PlayerProfile(),
        game(id: 'd1', mode: GameMode.daily, score: 800, dayOrdinal: ordinal),
        now,
      ).profile;
      expect(p.dailyBest[ordinal], 800);
      expect(p.dailyAttempts[ordinal], 1);
      expect(p.bestDaily, 800);
      expect(p.streak, 1);

      final second = Progression.finish(
        p,
        game(id: 'd2', mode: GameMode.daily, score: 500, dayOrdinal: ordinal),
        now,
      );
      p = second.profile;
      expect(p.dailyBest[ordinal], 800, reason: 'best of the attempts');
      expect(p.dailyAttempts[ordinal], 2);
      expect(p.streak, 1, reason: 'a second attempt does not extend the streak');
      expect(second.result!.streakAfter, 1);
      expect(second.result!.dayOrdinal, ordinal);
      expect(second.result!.mode, GameMode.daily);
    });

    test('consecutive days build the streak', () {
      var p = PlayerProfile();
      for (var d = 0; d < 3; d++) {
        p = Progression.finish(
          p,
          game(id: 'd$d', mode: GameMode.daily, score: 100, dayOrdinal: 200 + d),
          now.add(Duration(days: d)),
        ).profile;
      }
      expect(p.streak, 3);
      expect(p.achievements, contains('streak_3'));
    });
  });

  group('idempotency', () {
    test('the same game id is applied once', () {
      final first = Progression.finish(PlayerProfile(), game(score: 5000), now);
      expect(first.alreadyApplied, isFalse);
      final again = Progression.finish(first.profile, game(score: 5000), now);
      expect(again.alreadyApplied, isTrue);
      expect(again.result, isNull);
      expect(again.profile, first.profile);
    });

    test('a different game id is applied', () {
      final first = Progression.finish(PlayerProfile(), game(id: 'a'), now);
      final second = Progression.finish(first.profile, game(id: 'b'), now);
      expect(second.alreadyApplied, isFalse);
      expect(second.profile.gamesCompleted, 2);
      expect(second.profile.lastFinishedGameId, 'b');
    });
  });

  group('doubleCoins', () {
    test('adds the game coins again, once', () {
      final out = Progression.finish(PlayerProfile(), game(score: 3000), now);
      expect(out.result!.baseCoins, 60);
      expect(out.result!.doubled, isFalse);
      final coinsBefore = out.profile.coins;

      final first = Progression.doubleCoins(out.profile, out.result!);
      expect(first.profile.coins, coinsBefore + 60);
      expect(first.result.doubled, isTrue);

      final second = Progression.doubleCoins(first.profile, first.result);
      expect(second.profile.coins, first.profile.coins);
      expect(second.result, first.result);
    });

    test('does not double the first-game-of-day bonus', () {
      final out = Progression.finish(PlayerProfile(), game(score: 250), now);
      expect(out.profile.coins, 30);
      final doubled = Progression.doubleCoins(out.profile, out.result!);
      expect(doubled.profile.coins, 35);
    });
  });

  test('finish counts the game for the interstitial policy', () {
    final out = Progression.finish(PlayerProfile(), game(), now);
    expect(out.profile.gamesCompleted, 1);
    expect(out.profile.gamesSinceInterstitial, 1);
  });
}
