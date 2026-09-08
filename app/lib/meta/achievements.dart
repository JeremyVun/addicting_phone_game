import 'game_summary.dart';
import 'player_profile.dart';

class Achievement {
  const Achievement(this.id, this.name, this.description, this.coins);

  final String id;
  final String name;
  final String description;
  final int coins;
}

/// Design 7.7.
class Achievements {
  const Achievements._();

  static const List<Achievement> all = [
    Achievement('first_clear', 'First clear', 'Clear your first line.', 10),
    Achievement('combo_3', 'Combo starter', 'Reach a combo of 3.', 25),
    Achievement('combo_5', 'Combo builder', 'Reach a combo of 5.', 50),
    Achievement('combo_8', 'Combo master', 'Reach a combo of 8.', 100),
    Achievement('score_1k', '1,000 points', 'Score 1,000 points in one game.', 25),
    Achievement('score_2500', '2,500 points', 'Score 2,500 points in one game.', 50),
    Achievement('score_5k', '5,000 points', 'Score 5,000 points in one game.', 100),
    Achievement('score_10k', '10,000 points', 'Score 10,000 points in one game.', 200),
    Achievement('score_25k', '25,000 points', 'Score 25,000 points in one game.', 400),
    Achievement('board_clear', 'Clear grid', 'Clear every block from the grid.', 100),
    Achievement('games_10', 'Ten games', 'Finish 10 games.', 25),
    Achievement('games_100', 'Hundred games', 'Finish 100 games.', 150),
    Achievement('streak_3', 'Three-day streak', 'Keep a daily streak for 3 days.', 50),
    Achievement('streak_7', 'Seven-day streak', 'Keep a daily streak for 7 days.', 150),
    Achievement('streak_30', 'Thirty-day streak', 'Keep a daily streak for 30 days.', 500),
    Achievement('level_10', 'Level 10', 'Reach level 10.', 200),
  ];

  static Achievement byId(String id) => all.firstWhere((a) => a.id == id);

  static int coinsFor(Iterable<String> ids) =>
      ids.fold(0, (sum, id) => sum + byId(id).coins);

  static List<String> check(
    PlayerProfile before,
    PlayerProfile after,
    GameSummary summary,
  ) => [
    for (final achievement in all)
      if (!before.achievements.contains(achievement.id) &&
          _isMet(achievement.id, after, summary))
        achievement.id,
  ];

  static bool _isMet(String id, PlayerProfile after, GameSummary summary) =>
      switch (id) {
        'first_clear' => summary.clearedALine,
        'combo_3' => summary.maxCombo >= 3,
        'combo_5' => summary.maxCombo >= 5,
        'combo_8' => summary.maxCombo >= 8,
        'score_1k' => summary.score >= 1000,
        'score_2500' => summary.score >= 2500,
        'score_5k' => summary.score >= 5000,
        'score_10k' => summary.score >= 10000,
        'score_25k' => summary.score >= 25000,
        'board_clear' => summary.boardClearedCount >= 1,
        'games_10' => after.gamesCompleted >= 10,
        'games_100' => after.gamesCompleted >= 100,
        'streak_3' => after.streak >= 3,
        'streak_7' => after.streak >= 7,
        'streak_30' => after.streak >= 30,
        'level_10' => after.level >= 10,
        _ => false,
      };
}
