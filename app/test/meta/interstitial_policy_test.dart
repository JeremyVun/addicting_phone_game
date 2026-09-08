import 'package:flutter_test/flutter_test.dart';
import 'package:settle/meta/economy.dart';
import 'package:settle/meta/interstitial_policy.dart';
import 'package:settle/meta/player_profile.dart';

final now = DateTime(2026, 5, 4, 12);
int msAgo(int ms) => now.millisecondsSinceEpoch - ms;

PlayerProfile eligible({
  int gamesCompleted = 3,
  int gamesSinceInterstitial = 2,
  int lastInterstitialClosedAt = 0,
  int lastRewardedClosedAt = 0,
}) => PlayerProfile(
  gamesCompleted: gamesCompleted,
  gamesSinceInterstitial: gamesSinceInterstitial,
  lastInterstitialClosedAt: lastInterstitialClosedAt,
  lastRewardedClosedAt: lastRewardedClosedAt,
);

bool show({
  PlayerProfile? profile,
  bool adFree = false,
  int gameDurationMs = 30000,
  bool loaded = true,
  DateTime? at,
}) => InterstitialPolicy.shouldShow(
  profile: profile ?? eligible(),
  adFree: adFree,
  gameDurationMs: gameDurationMs,
  loaded: loaded,
  now: at ?? now,
);

void main() {
  test('all seven conditions met shows', () {
    expect(show(), isTrue);
  });

  test('condition 1: not ad-free', () {
    expect(show(adFree: true), isFalse);
  });

  test('condition 2: lifetime completed games >= 3', () {
    expect(show(profile: eligible(gamesCompleted: 2)), isFalse);
    expect(show(profile: eligible(gamesCompleted: 3)), isTrue);
  });

  test('condition 3: games since the last interstitial >= 2', () {
    expect(show(profile: eligible(gamesSinceInterstitial: 1)), isFalse);
    expect(show(profile: eligible(gamesSinceInterstitial: 2)), isTrue);
  });

  test('condition 4: 90 s since the last interstitial closed', () {
    expect(
      show(profile: eligible(lastInterstitialClosedAt: msAgo(89999))),
      isFalse,
    );
    expect(
      show(profile: eligible(lastInterstitialClosedAt: msAgo(90000))),
      isTrue,
    );
  });

  test('condition 5: 45 s since the last rewarded closed', () {
    expect(show(profile: eligible(lastRewardedClosedAt: msAgo(44999))), isFalse);
    expect(show(profile: eligible(lastRewardedClosedAt: msAgo(45000))), isTrue);
  });

  test('condition 6: the game lasted >= 30 s', () {
    expect(show(gameDurationMs: 29999), isFalse);
    expect(show(gameDurationMs: 30000), isTrue);
  });

  test('condition 7: an interstitial is loaded', () {
    expect(show(loaded: false), isFalse);
  });

  test('a zero stamp means never, so the cooldown is satisfied', () {
    expect(show(profile: eligible(lastInterstitialClosedAt: 0)), isTrue);
  });

  test('a clock moved back counts as not elapsed', () {
    final future = now.add(const Duration(hours: 1)).millisecondsSinceEpoch;
    expect(show(profile: eligible(lastInterstitialClosedAt: future)), isFalse);
    expect(show(profile: eligible(lastRewardedClosedAt: future)), isFalse);
  });

  test('reconcileClock resets a stamp more than 24 h ahead', () {
    final ahead = now.add(const Duration(hours: 25)).millisecondsSinceEpoch;
    final near = now.add(const Duration(hours: 23)).millisecondsSinceEpoch;
    final reset = InterstitialPolicy.reconcileClock(
      eligible(lastInterstitialClosedAt: ahead, lastRewardedClosedAt: near),
      now,
    );
    expect(reset.lastInterstitialClosedAt, now.millisecondsSinceEpoch);
    expect(reset.lastRewardedClosedAt, near, reason: 'under 24 h is left alone');

    final untouched = eligible(lastInterstitialClosedAt: msAgo(100000));
    expect(InterstitialPolicy.reconcileClock(untouched, now), untouched);
    expect(InterstitialPolicy.reconcileClock(eligible(), now), eligible());
  });

  test('shown resets the counter, closed re-stamps the time', () {
    final shown = InterstitialPolicy.afterInterstitialShown(eligible(), now);
    expect(shown.gamesSinceInterstitial, 0);
    expect(shown.lastInterstitialClosedAt, now.millisecondsSinceEpoch);

    final later = now.add(const Duration(seconds: 20));
    final closed = InterstitialPolicy.afterInterstitialClosed(shown, later);
    expect(closed.lastInterstitialClosedAt, later.millisecondsSinceEpoch);
    expect(closed.gamesSinceInterstitial, 0);
    expect(
      show(profile: closed, at: later.add(const Duration(seconds: 89))),
      isFalse,
    );
  });

  test('rewarded shown then closed both stamp the rewarded time', () {
    final shown = InterstitialPolicy.afterRewardedShown(eligible(), now);
    expect(shown.lastRewardedClosedAt, now.millisecondsSinceEpoch);
    final later = now.add(const Duration(seconds: 30));
    final closed = InterstitialPolicy.afterRewardedClosed(shown, later);
    expect(closed.lastRewardedClosedAt, later.millisecondsSinceEpoch);
    expect(closed.gamesSinceInterstitial, eligible().gamesSinceInterstitial);
  });

  test('afterGameCompleted counts one game', () {
    expect(
      InterstitialPolicy.afterGameCompleted(eligible()).gamesSinceInterstitial,
      3,
    );
  });

  test('the thresholds are the design 8.2 numbers', () {
    expect(Economy.interstitialMinLifetimeGames, 3);
    expect(Economy.interstitialMinGamesSince, 2);
    expect(Economy.interstitialCooldownMs, 90000);
    expect(Economy.rewardedCooldownMs, 45000);
    expect(Economy.interstitialMinGameDurationMs, 30000);
  });
}
