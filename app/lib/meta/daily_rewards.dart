import 'calendar.dart';
import 'economy.dart';
import 'player_profile.dart';

/// Design 7.4, with the day-1 suppression from design 10.
class DailyRewards {
  const DailyRewards._();

  static bool claimable(PlayerProfile profile, DateTime now) {
    final today = Calendar.dayOrdinal(now);
    return today > Calendar.dayOrdinal(profile.createdAt) &&
        today != profile.lastRewardClaimOrdinal &&
        today != profile.rewardDismissedOrdinal;
  }

  static int nextCycleDay(PlayerProfile profile, DateTime now) =>
      profile.lastRewardClaimOrdinal == Calendar.dayOrdinal(now) - 1
      ? profile.rewardCycleDay
      : 1;

  static int nextReward(PlayerProfile profile, DateTime now) =>
      Economy.dailyRewardForCycleDay(nextCycleDay(profile, now));

  static PlayerProfile claim(PlayerProfile profile, DateTime now) {
    if (!claimable(profile, now)) return profile;
    final today = Calendar.dayOrdinal(now);
    final cycleDay = nextCycleDay(profile, now);
    return profile.copyWith(
      coins: profile.coins + Economy.dailyRewardForCycleDay(cycleDay),
      rewardCycleDay: cycleDay % Economy.dailyRewardCycleLength + 1,
      lastRewardClaimOrdinal: today,
    );
  }

  static PlayerProfile dismiss(PlayerProfile profile, DateTime now) =>
      profile.copyWith(rewardDismissedOrdinal: Calendar.dayOrdinal(now));
}
