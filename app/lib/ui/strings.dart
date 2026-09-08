// Every player-facing string. Drafted by Codex (gpt-5.6-sol) on 2026-09-08 under the
// user-facing-copy rules; edit here only, never inline in widgets.
abstract final class S {
  static const String homePlay = 'Play';
  static const String homeDailyTitle = 'Daily';
  static const String homeDailyNotPlayed = 'Not played today';
  static String homeDailyDone(Object score) => 'Today’s score: $score';
  static const String homeDailySecondAttemptAvailable =
      'One more try is available';
  static const String homeStreakLabel = 'Day streak';
  static const String homeThemes = 'Themes';
  static const String homeShop = 'Shop';
  static const String homeAchievements = 'Achievements';
  static const String homeSettings = 'Settings';
  static const String playScore = 'Score';
  static const String playBest = 'Best';
  static String playCombo(Object n) => 'Combo x$n';
  static const String playReroll = 'Reroll';
  static const String playHintDrag = 'Drag a block onto the grid';
  static const String playHintClear = 'Fill a row or column to clear it';
  static const String pauseTitle = 'Paused';
  static const String pauseResume = 'Resume';
  static const String pauseHome = 'Home';
  static const String pauseSound = 'Sound';
  static const String pauseHaptics = 'Haptics';
  static const String overNoRoomTitle = 'No room';
  static const String overContinue = 'Continue';
  static const String overContinueSub =
      'Clears the three fullest rows and gives you new blocks.';
  static const String overWatchAd = 'Watch an ad';
  static String overUseCoins(Object coins) => 'Use $coins coins';
  static const String overFree = 'Free';
  static const String overEndGame = 'End game';
  static const String overTitle = 'Game over';
  static const String overNewBest = 'New best';
  static const String overCoinsEarned = 'Coins';
  static String overLevel(Object level) => 'Level $level';
  static String overLevelUp(Object level) => 'You reached level $level.';
  static String overNewTheme(Object name) =>
      'The $name theme is now available.';
  static String overAchievement(Object name, Object coins) =>
      'You completed $name. +$coins coins';
  static const String overDoubleCoins = 'Double coins';
  static const String overPlayAgain = 'Play again';
  static const String overHome = 'Home';
  static const String dailyTitle = 'Daily puzzle';
  static String dailyDay(Object day) => 'Puzzle $day';
  static const String dailyBestToday = 'Best today';
  static const String dailyShare = 'Share';
  static const String dailySecondAttempt = 'Try again';
  static const String dailySecondAttemptSub =
      'You can try once more today. Your better score counts.';
  static String dailyShareText(Object day, Object score, Object streak) =>
      'Settle · Puzzle $day · $score points · $streak-day streak';
  static const String rewardTitle = 'Daily reward';
  static String rewardDay(Object n) => 'Day $n of 7';
  static const String rewardClaim = 'Claim';
  static const String rewardNotNow = 'Not now';
  static const String streakTitle = 'Day streak';
  static String streakFreezes(Object n) => '$n of 2 freezes';
  static const String streakFreezeExplain =
      'A freeze keeps your streak if you miss one day.';
  static String streakBuyFreeze(Object coins) => 'Buy for $coins coins';
  static const String streakNotEnough = 'Not enough coins';
  static const String streakGetCoins = 'Get coins';
  static const String rerollTitle = 'New blocks';
  static const String rerollSub = 'Replaces the blocks you have not placed.';
  static const String rerollWatchAd = 'Watch an ad';
  static String rerollUseCoins(Object coins) => 'Use $coins coins';
  static const String rerollLimit = 'No rerolls left this game';
  static const String adUnavailable =
      'No ad is available right now. Try again later.';
  static const String shopTitle = 'Shop';
  static const String shopRemoveAds = 'Remove ads';
  static const String shopRemoveAdsSub =
      'No interstitial ads and one free continue every game';
  static const String shopCoinsSmall = '500 coins';
  static const String shopCoinsMedium = '3,000 coins';
  static const String shopCoinsLarge = '8,000 coins';
  static const String shopAllThemes = 'All themes';
  static const String shopAllThemesSub = 'Every colour theme, now and later';
  static const String shopPurchased = 'Purchased';
  static const String shopPending = 'Pending';
  static const String shopUnavailable =
      'The store can’t be reached right now. Try again later.';
  static const String shopRestore = 'Restore purchases';
  static const String shopRestored = 'Your purchases were restored.';
  static const String shopPurchaseFailed =
      'The purchase didn’t go through. You weren’t charged.';
  static const String themesTitle = 'Themes';
  static const String themesSelected = 'Selected';
  static String themesLevelLock(Object level) => 'Level $level';
  static String themesCoinLock(Object coins) => '$coins coins';
  static const String themesGet = 'Select';
  static String themesBuy(Object coins) => 'Buy for $coins coins';
  static const String settingsTitle = 'Settings';
  static const String settingsSound = 'Sound';
  static const String settingsHaptics = 'Haptics';
  static const String settingsReminder = 'Daily reminder';
  static const String settingsPrivacyOptions = 'Privacy options';
  static const String settingsRestore = 'Restore purchases';
  static const String settingsPrivacyPolicy = 'Privacy policy';
  static String settingsVersion(Object n) => 'Version $n';
  static const String achievementsTitle = 'Achievements';
  static const String achievementsDone = 'Done';
  static String achievementsReward(Object coins) => '+$coins coins';
  static const String notifyPromptTitle = 'Daily reminder';
  static const String notifyPromptBody =
      'Get a reminder when the daily puzzle is ready.';
  static const String notifyAllow = 'Allow';
  static const String notifyNotNow = 'Not now';
  static const String commonOk = 'OK';
  static const String commonCancel = 'Cancel';
  static const String commonClose = 'Close';
  static String levelLabel(Object level) => 'Level $level';
}
