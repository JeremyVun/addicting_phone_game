import 'calendar.dart';
import 'economy.dart';
import 'player_profile.dart';

/// Design 7.5.
class Streaks {
  const Streaks._();

  static PlayerProfile onDailyCompleted(PlayerProfile profile, int ordinal) {
    final last = profile.lastDailyCompletedOrdinal;
    if (last == ordinal) return profile;
    final streak = last == ordinal - 1 ? profile.streak + 1 : 1;
    return profile.copyWith(
      streak: streak,
      lastDailyCompletedOrdinal: ordinal,
    );
  }

  /// Freezes cover a gap only when they cover all of it; a gap wider than the
  /// held freezes resets the streak and leaves the freezes untouched.
  static PlayerProfile reconcile(PlayerProfile profile, DateTime now) {
    final last = profile.lastDailyCompletedOrdinal;
    if (last == PlayerProfile.never) return profile;
    final today = Calendar.dayOrdinal(now);
    final missed = today - last - 1;
    if (missed <= 0 || profile.streak == 0) return profile;
    if (profile.freezesHeld >= missed) {
      return profile.copyWith(
        freezesHeld: profile.freezesHeld - missed,
        lastDailyCompletedOrdinal: today - 1,
      );
    }
    return profile.copyWith(streak: 0);
  }

  static bool canBuyFreeze(PlayerProfile profile) =>
      profile.freezesHeld < Economy.maxFreezesHeld &&
      profile.coins >= Economy.freezeCost;

  static PlayerProfile buyFreeze(PlayerProfile profile) => canBuyFreeze(profile)
      ? profile.copyWith(
          coins: profile.coins - Economy.freezeCost,
          freezesHeld: profile.freezesHeld + 1,
        )
      : profile;
}
