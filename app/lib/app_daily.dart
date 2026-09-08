part of 'app.dart';

/// What the Home daily card shows and what a tap on it does.
enum DailyCardState { notPlayed, inProgress, done }

// Daily mode, streak, reward calendar and theme flows (phase 3b).
extension DailyFlows on AppController {
  int get today => dayOrdinalOf(services.clock.now());

  int get dailyAttemptsToday => profile.dailyAttempts[today] ?? 0;

  int get dailyBestToday => profile.dailyBest[today] ?? 0;

  int get _dailyAttemptsAllowed =>
      profile.dailySecondAttemptUsed == today ? 2 : 1;

  bool get canStartDaily => dailyAttemptsToday < _dailyAttemptsAllowed;

  /// Design 6.1: offered only on the day it was earned for, and only once.
  bool get secondDailyAttemptOffered =>
      profile.dailySecondAttemptUsed != today && dailyAttemptsToday > 0;

  core.GameState? get _savedDailyToday {
    final saved = _data.savedGame;
    return saved != null &&
            saved.mode == core.GameMode.daily &&
            saved.dayOrdinal == today
        ? saved
        : null;
  }

  DailyCardState get dailyCardState {
    if (_savedDailyToday != null) return DailyCardState.inProgress;
    return dailyAttemptsToday > 0
        ? DailyCardState.done
        : DailyCardState.notPlayed;
  }

  core.GameState _newDailyGame(int ordinal) => core.Game.newGame(
    mode: core.GameMode.daily,
    seed: dailySeedFor(ordinal),
    startedAtMs: services.clock.now().millisecondsSinceEpoch,
    dayOrdinal: ordinal,
  );

  Future<void> startDaily() async {
    if (_savedDailyToday != null) return resumeDaily();
    if (!canStartDaily) return;
    final ordinal = today;
    await mutate(
      (d) => AppData(
        profile: d.profile,
        savedGame: _newDailyGame(ordinal),
        lastResult: null,
      ),
    );
    _markResumed(_data.savedGame!);
    services.analytics.count('game_started', {'mode': 'daily'});
    navigator.goPlay();
  }

  Future<void> resumeDaily() async {
    final saved = _savedDailyToday;
    if (saved == null) return;
    _markResumed(saved);
    navigator.goPlay();
    if (saved.status == core.GameStatus.over) navigator.showGameOver();
  }

  /// Design 6.1: the flag and the new board land in one envelope write, so a
  /// kill between them cannot grant a free third attempt.
  Future<void> startSecondDailyAttempt() async {
    if (!secondDailyAttemptOffered) return;
    if (!await _watchRewarded(RewardedPlacement.dailySecondAttempt)) return;
    final ordinal = today;
    await mutate(
      (d) => AppData(
        profile: d.profile.copyWith(dailySecondAttemptUsed: ordinal),
        savedGame: _newDailyGame(ordinal),
        lastResult: null,
      ),
    );
    _markResumed(_data.savedGame!);
    services.analytics.count('game_started', {'mode': 'daily'});
    navigator.dismissSheet();
    navigator.goPlay();
  }

  // ---- streak (design 7.5) ----

  bool get canBuyStreakFreeze => Streaks.canBuyFreeze(profile);

  Future<void> buyStreakFreeze() async {
    if (!canBuyStreakFreeze) return;
    await mutate((d) => d.copyWith(profile: Streaks.buyFreeze(d.profile)));
  }

  // ---- daily reward calendar (design 7.4) ----

  bool get dailyRewardClaimable =>
      DailyRewards.claimable(profile, services.clock.now());

  int get dailyRewardCycleDay =>
      DailyRewards.nextCycleDay(profile, services.clock.now());

  int get dailyRewardAmount =>
      DailyRewards.nextReward(profile, services.clock.now());

  Future<void> claimDailyReward() async {
    final now = services.clock.now();
    await mutate((d) => d.copyWith(profile: DailyRewards.claim(d.profile, now)));
  }

  Future<void> dismissDailyReward() async {
    final now = services.clock.now();
    await mutate(
      (d) => d.copyWith(profile: DailyRewards.dismiss(d.profile, now)),
    );
  }

  // ---- themes (design 7.3) ----

  Future<void> buyTheme(int slot) async {
    if (!Themes.canBuy(profile, slot)) return;
    await mutate((d) => d.copyWith(profile: Themes.buy(d.profile, slot)));
    await selectTheme(slot);
  }

  // ---- reminder (design 10) ----

  bool get remindersEnabled => profile.remindersEnabled;

  /// Design 10: asked once, after the second finished game, and never again.
  bool get reminderPromptDue =>
      _reminderPromptArmed &&
      !profile.reminderPermissionAsked &&
      profile.gamesCompleted == Economy.reminderPromptAfterGames;

  Future<void> enableRemindersFromPrompt() async {
    final granted = await services.notifications.requestPermission();
    services.analytics.count('notification_permission', {'granted': '$granted'});
    _reminderPromptArmed = false;
    await mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(
          reminderPermissionAsked: true,
          remindersEnabled: granted,
        ),
      ),
    );
  }

  Future<void> declineReminderPrompt() async {
    _reminderPromptArmed = false;
    await mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(reminderPermissionAsked: true),
      ),
    );
  }

  Future<void> setRemindersEnabled(bool on) async {
    await mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(remindersEnabled: on)),
    );
    if (on) {
      await scheduleReminderIfEnabled();
    } else {
      await cancelReminder();
    }
  }

  Future<void> scheduleReminderIfEnabled() async {
    if (!profile.remindersEnabled) return;
    await services.notifications.scheduleReminder(
      Reminders.nextReminderTime(services.clock.now()),
    );
  }

  Future<void> cancelReminder() => services.notifications.cancelReminder();

  // ---- raised by `finishGame` ----

  void _afterFinish(LastGameResult? result) {
    _reminderPromptArmed = true;
    if (result == null) return;
    if (result.mode == GameMode.daily) {
      services.analytics.count('daily_completed', {
        'streak': Buckets.streak(result.streakAfter),
      });
    }
    for (final level in result.levelUps) {
      services.analytics.count('level_reached', {'level': Buckets.level(level)});
    }
  }
}
