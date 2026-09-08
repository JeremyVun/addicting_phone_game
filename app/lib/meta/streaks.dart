import 'dart:math' as math;

import 'calendar.dart';
import 'economy.dart';
import 'player_profile.dart';

/// Design 7.5.
class Streaks {
  const Streaks._();

  static PlayerProfile onDailyCompleted(PlayerProfile profile, int ordinal) {
    final last = profile.lastCompletedOrdinal;
    if (last == ordinal) return profile;
    final anchor = _anchor(profile);
    final streak = anchor == ordinal - 1 ? profile.streak + 1 : 1;
    return profile.copyWith(streak: streak, lastCompletedOrdinal: ordinal);
  }

  /// A day covered by a freeze counts as completed for the streak's purposes.
  static int? _anchor(PlayerProfile profile) {
    final last = profile.lastCompletedOrdinal;
    if (last == null) return profile.streakReconciledOrdinal;
    return math.max(last, profile.streakReconciledOrdinal ?? last);
  }

  /// Freezes cover a gap only when they cover all of it; a wider gap resets the
  /// streak and leaves the freezes for the next one.
  static PlayerProfile reconcile(PlayerProfile profile, DateTime now) {
    if (profile.lastCompletedOrdinal == null) return profile;
    final today = Calendar.dayOrdinal(now);
    final missed = today - _anchor(profile)! - 1;
    if (missed <= 0) return profile;
    final covered = profile.streak > 0 && missed <= profile.freezesHeld;
    return profile.copyWith(
      streak: covered ? profile.streak : 0,
      freezesHeld: covered ? profile.freezesHeld - missed : profile.freezesHeld,
      streakReconciledOrdinal: today - 1,
    );
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
