import 'package:collection/collection.dart';
import 'achievements.dart';
import 'calendar.dart';
import 'economy.dart';
import 'game_summary.dart';
import 'interstitial_policy.dart';
import 'levels.dart';
import 'player_profile.dart';
import 'streaks.dart';

const _deepEquals = DeepCollectionEquality();

/// Design 6.1's `LastGameResult`, persisted in the `AppData` envelope.
class LastGameResult {
  LastGameResult({
    required this.gameId,
    required this.mode,
    required this.score,
    required this.baseCoins,
    required this.bonusCoins,
    required this.xp,
    List<int> levelUps = const [],
    List<String> newAchievements = const [],
    required this.streakAfter,
    required this.elapsedMs,
    this.dayOrdinal,
    this.doubled = false,
  }) : levelUps = List.unmodifiable(levelUps),
       newAchievements = List.unmodifiable(newAchievements);

  static const int version = 1;

  final String gameId;
  final GameMode mode;
  final int score;

  /// The game's own coins (7.1), which is exactly what Double coins adds again.
  final int baseCoins;

  /// First game of the day, level-up and achievement coins from this finish.
  final int bonusCoins;
  final int xp;
  final List<int> levelUps;
  final List<String> newAchievements;
  final int streakAfter;
  final int elapsedMs;

  /// Set for daily games only (3).
  final int? dayOrdinal;
  final bool doubled;

  int get totalCoins => baseCoins + bonusCoins;

  LastGameResult copyWith({bool? doubled}) => LastGameResult(
    gameId: gameId,
    mode: mode,
    score: score,
    baseCoins: baseCoins,
    bonusCoins: bonusCoins,
    xp: xp,
    levelUps: levelUps,
    newAchievements: newAchievements,
    streakAfter: streakAfter,
    elapsedMs: elapsedMs,
    dayOrdinal: dayOrdinal,
    doubled: doubled ?? this.doubled,
  );

  Map<String, dynamic> toJson() => {
    'v': version,
    'gameId': gameId,
    'mode': mode.name,
    'score': score,
    'baseCoins': baseCoins,
    'bonusCoins': bonusCoins,
    'xp': xp,
    'levelUps': levelUps,
    'newAchievements': newAchievements,
    'streakAfter': streakAfter,
    'elapsedMs': elapsedMs,
    'dayOrdinal': dayOrdinal,
    'doubled': doubled,
  };

  static LastGameResult fromJson(Map<String, dynamic> json) => LastGameResult(
    gameId: json['gameId'] as String,
    mode: GameMode.values.byName(json['mode'] as String),
    score: json['score'] as int,
    baseCoins: json['baseCoins'] as int,
    bonusCoins: json['bonusCoins'] as int,
    xp: json['xp'] as int,
    levelUps: [for (final l in json['levelUps'] as List) (l as num).toInt()],
    newAchievements: [
      for (final id in json['newAchievements'] as List) id as String,
    ],
    streakAfter: json['streakAfter'] as int,
    elapsedMs: json['elapsedMs'] as int,
    dayOrdinal: json['dayOrdinal'] as int?,
    doubled: json['doubled'] as bool? ?? false,
  );

  List<Object?> get _props => [
    gameId,
    mode,
    score,
    baseCoins,
    bonusCoins,
    xp,
    levelUps,
    newAchievements,
    streakAfter,
    elapsedMs,
    dayOrdinal,
    doubled,
  ];

  @override
  bool operator ==(Object other) =>
      other is LastGameResult && _deepEquals.equals(_props, other._props);

  @override
  int get hashCode => _deepEquals.hash(_props);

  @override
  String toString() =>
      'LastGameResult($gameId, score $score, coins $totalCoins)';
}

class FinishOutcome {
  const FinishOutcome({
    required this.profile,
    required this.result,
    required this.alreadyApplied,
  });

  final PlayerProfile profile;

  /// Null only when `alreadyApplied` is true: the stored result stands.
  final LastGameResult? result;
  final bool alreadyApplied;
}

/// Design 6.1 and 7.
class Progression {
  const Progression._();

  static FinishOutcome finish(
    PlayerProfile profile,
    GameSummary summary,
    DateTime now,
  ) {
    if (profile.lastFinishedGameId == summary.gameId) {
      return FinishOutcome(
        profile: profile,
        result: null,
        alreadyApplied: true,
      );
    }

    final gameCoins = Economy.coinsForScore(summary.score);
    final todayOrdinal = Calendar.dayOrdinal(now);
    final isFirstOfDay = profile.lastFirstGameOfDayOrdinal != todayOrdinal;
    final gainedXp = summary.score ~/ Economy.xpScoreDivisor;
    final newXp = profile.xp + gainedXp;
    final levelUps = [
      for (var level = profile.level + 1; level <= Levels.levelFor(newXp); level++)
        level,
    ];
    final levelCoins = levelUps.fold(0, (sum, l) => sum + Levels.levelUpReward(l));

    final firstOfDayCoins = isFirstOfDay ? Economy.firstGameOfDayBonus : 0;

    var next = profile.copyWith(
      coins: profile.coins + gameCoins + levelCoins + firstOfDayCoins,
      xp: newXp,
      gamesCompleted: profile.gamesCompleted + 1,
      classicGamesCompleted: summary.mode == GameMode.classic
          ? profile.classicGamesCompleted + 1
          : profile.classicGamesCompleted,
      lastFirstGameOfDayOrdinal: isFirstOfDay
          ? todayOrdinal
          : profile.lastFirstGameOfDayOrdinal,
      lastFinishedGameId: summary.gameId,
    );

    final dailyOrdinal = summary.dayOrdinal ?? todayOrdinal;

    if (summary.mode == GameMode.classic) {
      next = next.copyWith(
        bestClassic: summary.score > profile.bestClassic
            ? summary.score
            : profile.bestClassic,
        skill:
            Economy.skillRetain * profile.skill +
            Economy.skillLearn *
                (summary.score / Economy.skillScoreCap).clamp(0.0, 1.0),
      );
    } else {
      final ordinal = dailyOrdinal;
      final previousBest = profile.dailyBest[ordinal] ?? 0;
      next = next.copyWith(
        bestDaily: summary.score > profile.bestDaily
            ? summary.score
            : profile.bestDaily,
        dailyBest: {
          ...profile.dailyBest,
          ordinal: summary.score > previousBest ? summary.score : previousBest,
        },
        dailyAttempts: {
          ...profile.dailyAttempts,
          ordinal: (profile.dailyAttempts[ordinal] ?? 0) + 1,
        },
      );
      next = Streaks.onDailyCompleted(next, ordinal);
    }

    final unlocked = Achievements.check(profile, next, summary);
    final achievementCoins = Achievements.coinsFor(unlocked);
    next = next.copyWith(
      coins: next.coins + achievementCoins,
      achievements: {...profile.achievements, ...unlocked},
    );
    next = InterstitialPolicy.afterGameCompleted(next);

    return FinishOutcome(
      profile: next,
      alreadyApplied: false,
      result: LastGameResult(
        gameId: summary.gameId,
        mode: summary.mode,
        score: summary.score,
        baseCoins: gameCoins,
        bonusCoins: firstOfDayCoins + levelCoins + achievementCoins,
        xp: gainedXp,
        levelUps: levelUps,
        newAchievements: unlocked,
        streakAfter: next.streak,
        elapsedMs: summary.durationMs,
        dayOrdinal: summary.isDaily ? dailyOrdinal : null,
      ),
    );
  }

  static ({PlayerProfile profile, LastGameResult result}) doubleCoins(
    PlayerProfile profile,
    LastGameResult lastResult,
  ) {
    if (lastResult.doubled) {
      return (profile: profile, result: lastResult);
    }
    return (
      profile: profile.copyWith(coins: profile.coins + lastResult.baseCoins),
      result: lastResult.copyWith(doubled: true),
    );
  }
}
