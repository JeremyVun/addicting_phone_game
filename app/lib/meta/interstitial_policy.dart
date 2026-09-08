import 'economy.dart';
import 'player_profile.dart';

/// Design 8.2.
class InterstitialPolicy {
  const InterstitialPolicy._();

  static bool shouldShow({
    required PlayerProfile profile,
    required bool adFree,
    required int gameDurationMs,
    required bool loaded,
    required DateTime now,
  }) {
    if (adFree) return false;
    if (!loaded) return false;
    if (profile.gamesCompleted < Economy.interstitialMinLifetimeGames) {
      return false;
    }
    if (profile.gamesSinceInterstitial < Economy.interstitialMinGamesSince) {
      return false;
    }
    if (gameDurationMs < Economy.interstitialMinGameDurationMs) return false;
    final nowMs = now.millisecondsSinceEpoch;
    return elapsedAtLeast(
          profile.lastInterstitialClosedAt,
          nowMs,
          Economy.interstitialCooldownMs,
        ) &&
        elapsedAtLeast(
          profile.lastRewardedClosedAt,
          nowMs,
          Economy.rewardedCooldownMs,
        );
  }

  static bool elapsedAtLeast(int storedMs, int nowMs, int thresholdMs) {
    if (storedMs == 0) return true;
    final delta = nowMs - storedMs;
    return delta >= 0 && delta >= thresholdMs;
  }

  /// A stored stamp more than 24 h in the future can only be a clock move, and
  /// would otherwise block interstitials forever.
  static PlayerProfile reconcileClock(PlayerProfile profile, DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    final interstitial = _resetIfRolledBack(
      profile.lastInterstitialClosedAt,
      nowMs,
    );
    final rewarded = _resetIfRolledBack(profile.lastRewardedClosedAt, nowMs);
    if (interstitial == profile.lastInterstitialClosedAt &&
        rewarded == profile.lastRewardedClosedAt) {
      return profile;
    }
    return profile.copyWith(
      lastInterstitialClosedAt: interstitial,
      lastRewardedClosedAt: rewarded,
    );
  }

  static int _resetIfRolledBack(int storedMs, int nowMs) =>
      storedMs != 0 && storedMs - nowMs > Economy.clockRollbackResetMs
      ? nowMs
      : storedMs;

  static PlayerProfile afterInterstitialShown(
    PlayerProfile profile,
    DateTime now,
  ) => profile.copyWith(
    lastInterstitialClosedAt: now.millisecondsSinceEpoch,
    gamesSinceInterstitial: 0,
  );

  static PlayerProfile afterInterstitialClosed(
    PlayerProfile profile,
    DateTime now,
  ) => profile.copyWith(lastInterstitialClosedAt: now.millisecondsSinceEpoch);

  static PlayerProfile afterRewardedShown(PlayerProfile profile, DateTime now) =>
      profile.copyWith(lastRewardedClosedAt: now.millisecondsSinceEpoch);

  static PlayerProfile afterRewardedClosed(
    PlayerProfile profile,
    DateTime now,
  ) => profile.copyWith(lastRewardedClosedAt: now.millisecondsSinceEpoch);

  static PlayerProfile afterGameCompleted(PlayerProfile profile) =>
      profile.copyWith(
        gamesSinceInterstitial: profile.gamesSinceInterstitial + 1,
      );
}
