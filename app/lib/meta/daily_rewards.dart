import 'calendar.dart';
import 'economy.dart';
import 'player_profile.dart';

/// Design 7.4, with the day-1 suppression from design 10.
class DailyRewards {
  const DailyRewards._();

  static int nextCycleDay(PlayerProfile profile, DateTime now) {
    final today = Calendar.dayOrdinal(now);
    final consecutive = profile.dailyRewardLastClaimOrdinal == today - 1;
    if (!consecutive) return 1;
    return profile.dailyRewardCycleDay % Economy.dailyRewardCycleLength + 1;
  }

  static int nextReward(PlayerProfile profile, DateTime now) =>
      Economy.dailyRewardForCycleDay(nextCycleDay(profile, now));

  static bool claimable(PlayerProfile profile, DateTime now) {
    final today = Calendar.dayOrdinal(now);
    if (today == Calendar.dayOrdinal(profile.createdAt)) return false;
    return profile.dailyRewardLastClaimOrdinal != today;
  }

  static PlayerProfile claim(PlayerProfile profile, DateTime now) {
    if (!claimable(profile, now)) return profile;
    final cycleDay = nextCycleDay(profile, now);
    return profile.copyWith(
      coins: profile.coins + Economy.dailyRewardForCycleDay(cycleDay),
      dailyRewardCycleDay: cycleDay,
      dailyRewardLastClaimOrdinal: Calendar.dayOrdinal(now),
    );
  }
}
