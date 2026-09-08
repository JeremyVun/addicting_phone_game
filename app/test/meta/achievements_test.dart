import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/achievements.dart';
import 'package:settle/meta/game_summary.dart';
import 'package:settle/meta/levels.dart';
import 'package:settle/meta/player_profile.dart';
import 'package:settle/meta/progression.dart';

final now = DateTime(2026, 5, 4, 12);

GameSummary game({
  String id = 'g1',
  int score = 0,
  int maxCombo = 0,
  int boardClearedCount = 0,
}) => GameSummary(
  mode: GameMode.classic,
  gameId: id,
  score: score,
  placements: 30,
  durationMs: 60000,
  maxCombo: maxCombo,
  boardClearedCount: boardClearedCount,
);

/// (id, coins, a profile before the game, the game that should unlock it).
final cases = <(String, int, PlayerProfile, GameSummary)>[
  ('first_clear', 10, PlayerProfile(), game(maxCombo: 1)),
  ('combo_3', 25, PlayerProfile(), game(maxCombo: 3)),
  ('combo_5', 50, PlayerProfile(), game(maxCombo: 5)),
  ('combo_8', 100, PlayerProfile(), game(maxCombo: 8)),
  ('score_1k', 25, PlayerProfile(), game(score: 1000)),
  ('score_2500', 50, PlayerProfile(), game(score: 2500)),
  ('score_5k', 100, PlayerProfile(), game(score: 5000)),
  ('score_10k', 200, PlayerProfile(), game(score: 10000)),
  ('score_25k', 400, PlayerProfile(), game(score: 25000)),
  ('board_clear', 100, PlayerProfile(), game(boardClearedCount: 1)),
  ('games_10', 25, PlayerProfile(gamesCompleted: 9), game()),
  ('games_100', 150, PlayerProfile(gamesCompleted: 99), game()),
  ('streak_3', 50, PlayerProfile(streak: 2, lastCompletedOrdinal: 9), game()),
  ('streak_7', 150, PlayerProfile(streak: 6, lastCompletedOrdinal: 9), game()),
  ('streak_30', 500, PlayerProfile(streak: 29, lastCompletedOrdinal: 9), game()),
  ('level_10', 200, PlayerProfile(xp: Levels.xpForLevel(10) - 1), game(score: 10)),
];

void main() {
  test('sixteen achievements with the design 7.7 ids, names and coins', () {
    expect(Achievements.all.length, 16);
    expect(Achievements.all.map((a) => a.id).toSet().length, 16);
    expect(Achievements.byId('combo_8').name, 'Combo master');
    expect(Achievements.byId('combo_8').description, 'Reach a combo of 8.');
    expect(Achievements.byId('first_clear').description, 'Clear your first line.');
    expect(Achievements.byId('board_clear').name, 'Clear grid');
    expect(
      Achievements.byId('board_clear').description,
      'Clear every block from the grid.',
    );
    expect(Achievements.byId('games_100').name, 'Hundred games');
    expect(Achievements.byId('score_2500').name, '2,500 points');
    expect(Achievements.byId('streak_30').coins, 500);
    expect(
      Achievements.all.map((a) => a.coins).reduce((a, b) => a + b),
      2135,
    );
  });

  for (final (id, coins, before, summary) in cases) {
    test('$id unlocks exactly once and pays $coins', () {
      final daily = id.startsWith('streak_')
          ? GameSummary(
              mode: GameMode.daily,
              gameId: summary.gameId,
              score: summary.score,
              placements: summary.placements,
              durationMs: summary.durationMs,
              maxCombo: summary.maxCombo,
              boardClearedCount: summary.boardClearedCount,
              dayOrdinal: 10,
            )
          : summary;

      final unlockedIds = Achievements.check(
        before,
        Progression.finish(before, daily, now).profile,
        daily,
      );
      expect(unlockedIds, contains(id));

      final first = Progression.finish(before, daily, now);
      expect(first.result!.newAchievements, contains(id));
      expect(first.profile.achievements, contains(id));

      final second = Progression.finish(
        first.profile,
        GameSummary(
          mode: daily.mode,
          gameId: 'second',
          score: daily.score,
          placements: daily.placements,
          durationMs: daily.durationMs,
          maxCombo: daily.maxCombo,
          boardClearedCount: daily.boardClearedCount,
          dayOrdinal: daily.dayOrdinal,
        ),
        now,
      );
      expect(Achievements.byId(id).coins, coins);
      expect(second.result!.newAchievements, isNot(contains(id)));
      expect(second.profile.achievements, first.profile.achievements);
    });
  }

  test('each threshold is exact: one short does not unlock', () {
    const combos = [('combo_3', 2), ('combo_5', 4), ('combo_8', 7)];
    for (final (id, combo) in combos) {
      final out = Progression.finish(PlayerProfile(), game(id: id, maxCombo: combo), now);
      expect(out.result!.newAchievements, isNot(contains(id)), reason: 'combo $combo');
    }
    const scores = [
      ('score_1k', 999),
      ('score_2500', 2499),
      ('score_5k', 4999),
      ('score_10k', 9999),
      ('score_25k', 24999),
    ];
    for (final (id, score) in scores) {
      final out = Progression.finish(PlayerProfile(), game(id: id, score: score), now);
      expect(out.result!.newAchievements, isNot(contains(id)), reason: 'score $score');
    }
    expect(
      Progression.finish(PlayerProfile(gamesCompleted: 8), game(), now)
          .result!
          .newAchievements,
      isEmpty,
    );
    expect(
      Progression.finish(PlayerProfile(), game(boardClearedCount: 0), now)
          .result!
          .newAchievements,
      isNot(contains('board_clear')),
    );
  });

  test('a game that misses every condition unlocks nothing', () {
    final out = Progression.finish(PlayerProfile(), game(score: 999), now);
    expect(out.result!.newAchievements, isEmpty);
  });

  test('one game can unlock several', () {
    final out = Progression.finish(
      PlayerProfile(),
      game(score: 26000, maxCombo: 9, boardClearedCount: 2),
      now,
    );
    expect(out.result!.newAchievements, [
      'first_clear',
      'combo_3',
      'combo_5',
      'combo_8',
      'score_1k',
      'score_2500',
      'score_5k',
      'score_10k',
      'score_25k',
      'board_clear',
    ]);
  });

  test('coinsFor sums the table', () {
    expect(Achievements.coinsFor(['first_clear', 'combo_8']), 110);
  });
}
