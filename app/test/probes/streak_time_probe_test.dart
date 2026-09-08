import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/services/storage.dart';

import '../app/harness.dart';
import 'support.dart';

Future<void> playDaily(ProbeApp app) async {
  await app.controller.startDaily();
  await playToGameOver(app.controller);
  await app.controller.finishGame();
  await app.controller.goHome();
}

Future<ProbeApp> relaunch(ProbeApp app, DateTime now) async {
  final next = ProbeApp(
    storage: MemoryStorage((app.storage as MemoryStorage).writes.last),
    ads: OneShotAds(reloads: true),
    now: now,
  );
  await next.start();
  return next;
}

void main() {
  final day1 = DateTime(2026, 9, 8, 12);

  test('reconciling twice on the same day charges the gap once', () async {
    var app = ProbeApp(ads: OneShotAds(reloads: true), now: day1);
    await app.start();
    await app.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: 400)),
    );
    await playDaily(app);
    await app.controller.buyStreakFreeze();
    await app.controller.buyStreakFreeze();
    expect(app.controller.profile.freezesHeld, 2);
    expect(app.controller.profile.streak, 1);

    final gapDay = day1.add(const Duration(days: 2));
    app = await relaunch(app, gapDay);
    expect(app.controller.profile.freezesHeld, 1, reason: 'one day covered');
    expect(app.controller.profile.streak, 1);

    app = await relaunch(app, gapDay);
    expect(app.controller.profile.freezesHeld, 1, reason: 'charged once');
    expect(app.controller.profile.streak, 1);

    await playDaily(app);
    expect(app.controller.profile.streak, 2);
  });

  for (var gap = 1; gap <= 4; gap++) {
    for (var freezes = 0; freezes <= 2; freezes++) {
      test('a $gap-day gap with $freezes freezes follows 7.5', () async {
        var app = ProbeApp(ads: OneShotAds(reloads: true), now: day1);
        await app.start();
        await app.controller.mutate(
          (d) => d.copyWith(
            profile: d.profile.copyWith(coins: Economy.freezeCost * freezes),
          ),
        );
        await playDaily(app);
        for (var i = 0; i < freezes; i++) {
          await app.controller.buyStreakFreeze();
        }

        app = await relaunch(app, day1.add(Duration(days: gap + 1)));
        final covered = gap <= freezes;
        expect(app.controller.profile.streak, covered ? 1 : 0);
        expect(app.controller.profile.freezesHeld,
            covered ? freezes - gap : freezes);
        expect(app.controller.profile.coins, greaterThanOrEqualTo(0));

        await playDaily(app);
        expect(app.controller.profile.streak, covered ? 2 : 1);
      });
    }
  }

  test('a daily run across a DST boundary keeps counting days', () async {
    // US: 2026-11-01 is a 25-hour day; the streak reads calendar days only.
    var app = ProbeApp(ads: OneShotAds(reloads: true), now: DateTime(2026, 10, 31, 20));
    await app.start();
    await playDaily(app);
    app = await relaunch(app, DateTime(2026, 11, 1, 20));
    await playDaily(app);
    app = await relaunch(app, DateTime(2026, 11, 2, 20));
    await playDaily(app);
    expect(app.controller.profile.streak, 3);
  });

  test('a device clock moved backwards never destroys a streak', () async {
    var app = ProbeApp(ads: OneShotAds(reloads: true), now: day1);
    await app.start();
    await playDaily(app);
    app = await relaunch(app, day1.add(const Duration(days: 1)));
    await playDaily(app);
    expect(app.controller.profile.streak, 2);

    app = await relaunch(app, day1.subtract(const Duration(days: 3)));
    expect(app.controller.profile.streak, 2, reason: 'a rollback is not a gap');
    await playDaily(app);
    expect(app.controller.profile.streak, greaterThanOrEqualTo(2),
        reason: 'a stale clock must not reset a live streak');
  });

  test('two unawaited reward claims pay one day', () async {
    final app = ProbeApp(now: day1);
    await app.start();
    final later = ProbeApp(
      storage: MemoryStorage((app.storage as MemoryStorage).writes.last),
      now: day1.add(const Duration(days: 1)),
    );
    await later.start();
    expect(later.controller.dailyRewardClaimable, isTrue);
    final amount = later.controller.dailyRewardAmount;

    await Future.wait([
      later.controller.claimDailyReward(),
      later.controller.claimDailyReward(),
    ]);

    expect(later.controller.profile.coins, amount);
    expect(later.controller.dailyRewardClaimable, isFalse);
  });

  test('the reward cycle restarts at day 1 after a missed day', () async {
    var app = ProbeApp(now: day1);
    await app.start();
    var day = day1;
    final paid = <int>[];
    for (final step in [1, 1, 1, 3]) {
      day = day.add(Duration(days: step));
      app = await relaunch(app, day);
      final before = app.controller.profile.coins;
      await app.controller.claimDailyReward();
      paid.add(app.controller.profile.coins - before);
    }
    expect(paid, [25, 50, 75, 25]);
  });

  test('a clock moved back more than a day frees the interstitial cooldown',
      () async {
    var app = ProbeApp(ads: OneShotAds(reloads: true), now: day1);
    await app.start();
    await app.controller.mutate(
      (d) => d.copyWith(
        profile: d.profile.copyWith(
          gamesCompleted: 10,
          gamesSinceInterstitial: 5,
          lastInterstitialClosedAt: day1.millisecondsSinceEpoch,
          lastRewardedClosedAt: day1.millisecondsSinceEpoch,
        ),
      ),
    );

    final back = day1.subtract(const Duration(hours: 25));
    app = await relaunch(app, back);
    expect(
      InterstitialPolicy.shouldShow(
        profile: app.controller.profile,
        adFree: false,
        gameDurationMs: Economy.interstitialMinGameDurationMs,
        loaded: true,
        now: back.add(const Duration(minutes: 5)),
      ),
      isTrue,
      reason: 'reconcileClock repaired the stamps on launch',
    );
  });

  test('the interstitial cooldown is exact at each boundary', () async {
    final profile = PlayerProfile(
      gamesCompleted: Economy.interstitialMinLifetimeGames,
      gamesSinceInterstitial: Economy.interstitialMinGamesSince,
      lastInterstitialClosedAt: 1000000,
      lastRewardedClosedAt: 1000000,
    );
    bool show(int afterMs, int durationMs) => InterstitialPolicy.shouldShow(
      profile: profile,
      adFree: false,
      gameDurationMs: durationMs,
      loaded: true,
      now: DateTime.fromMillisecondsSinceEpoch(1000000 + afterMs),
    );
    expect(show(Economy.interstitialCooldownMs,
        Economy.interstitialMinGameDurationMs), isTrue);
    expect(show(Economy.interstitialCooldownMs - 1,
        Economy.interstitialMinGameDurationMs), isFalse);
    expect(show(Economy.interstitialCooldownMs,
        Economy.interstitialMinGameDurationMs - 1), isFalse);
  });
}
