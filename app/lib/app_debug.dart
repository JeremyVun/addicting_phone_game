part of 'app.dart';

/// TEMPORARY emulator-drive hooks (phase 3b). Removed before the final commit.
extension DebugDrive on AppController {
  Future<void> debugSeedPlayedDaily() async {
    final ordinal = today;
    await mutate(
      (d) => AppData(
        profile: d.profile.copyWith(
          coins: 1240,
          xp: Levels.xpForLevel(7) + 200,
          gamesCompleted: 9,
          streak: 12,
          freezesHeld: 1,
          lastCompletedOrdinal: ordinal,
          dailyBest: {ordinal: 3300},
          dailyAttempts: {ordinal: 1},
          bestClassic: 12460,
          achievements: {'first_clear', 'combo_3', 'score_1k', 'games_10'},
        ),
        lastResult: null,
      ),
    );
  }

  Future<void> debugShowDailyResult() async {
    await debugSeedPlayedDaily();
    final ordinal = today;
    await mutate(
      (d) => d.copyWith(
        lastResult: LastGameResult(
          gameId: 'debug',
          mode: GameMode.daily,
          score: 3300,
          baseCoins: 66,
          bonusCoins: 25,
          xp: 330,
          streakAfter: 12,
          elapsedMs: 214000,
          dayOrdinal: ordinal,
        ),
      ),
    );
    navigator.showGameOver();
  }

  Future<void> debugArmRewardSheet() async {
    await mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(
          createdAtMs: services.clock
              .now()
              .subtract(const Duration(days: 5))
              .millisecondsSinceEpoch,
          rewardCycleDay: 3,
          lastRewardClaimOrdinal: today - 1,
        ),
      ),
    );
  }

  Future<void> debugArmNotificationPrompt() async {
    _reminderPromptArmed = true;
    await mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(
          gamesCompleted: Economy.reminderPromptAfterGames,
          reminderPermissionAsked: false,
        ),
      ),
    );
  }

  Future<void> debugScheduleReminderSoon() async {
    await services.notifications.requestPermission();
    await services.notifications.scheduleReminder(
      services.clock.now().add(const Duration(minutes: 2)),
    );
    navigator.showMessage('Reminder in 2 minutes');
  }
}
