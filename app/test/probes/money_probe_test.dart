import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/core/game_state.dart' as core;
import 'package:settle/meta/meta.dart';
import 'package:settle/services/ads.dart';

import '../app/harness.dart';
import 'support.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);

  Future<ProbeApp> atGameOver({
    OneShotAds? ads,
    int coins = 0,
    bool adFree = false,
  }) async {
    final app = ProbeApp(ads: ads ?? OneShotAds(), now: now);
    await app.start();
    await app.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: coins, adFree: adFree)),
    );
    await app.controller.startClassic();
    await playToGameOver(app.controller);
    expect(app.controller.state.status, core.GameStatus.over);
    return app;
  }

  test('a continue paid by a rewarded ad is never also charged in coins', () async {
    final ads = OneShotAds();
    final app = await atGameOver(ads: ads, coins: 400);

    expect(app.controller.continuePayment, ContinuePayment.rewarded);
    await app.controller.continueGame();

    expect(ads.shows, [RewardedPlacement.continueGame]);
    expect(app.controller.state.continuesUsed, 1);
    expect(app.controller.profile.coins, 400,
        reason: 'the reward paid for the continue');
  });

  test('coins never go negative when a rewarded continue is granted', () async {
    final app = await atGameOver(coins: 0);

    await app.controller.continueGame();

    expect(app.controller.profile.coins, greaterThanOrEqualTo(0));
  });

  test('two unawaited coin rerolls spend one price', () async {
    final app = ProbeApp(now: now);
    await app.start();
    await app.controller.startClassic();
    await setCoins(app.controller, Economy.rerollCost);

    final first = app.controller.rerollWithCoins();
    final second = app.controller.rerollWithCoins();
    await Future.wait([first, second]);

    expect(app.controller.profile.coins, greaterThanOrEqualTo(0));
    expect(app.controller.state.rerollsUsed, 1,
        reason: 'only one reroll was affordable');
  });

  test('two unawaited coin continues charge once', () async {
    final ads = OneShotAds()..rewardedReady = false;
    final app = await atGameOver(ads: ads, coins: 400);

    final first = app.controller.continueGame();
    final second = app.controller.continueGame();
    await Future.wait([first, second]);

    expect(app.controller.state.continuesUsed, 1);
    expect(app.controller.profile.coins, 250);
  });

  test('a dismissed rewarded ad grants nothing anywhere', () async {
    final ads = OneShotAds(grantsReward: false, reloads: true);
    final app = ProbeApp(ads: ads, now: now);
    await app.start();
    await app.controller.startClassic();
    await setCoins(app.controller, 1000);

    await app.controller.rerollWithAd();
    expect(app.controller.state.rerollsUsed, 0);
    expect(app.controller.profile.coins, 1000);

    await playToGameOver(app.controller);
    await app.controller.continueGame();
    expect(app.controller.state.continuesUsed, 0);
    expect(app.controller.profile.coins, 1000);

    await app.controller.endGame();
    final earned = app.controller.profile.coins;
    await app.controller.doubleCoins();
    expect(app.controller.profile.coins, earned);
    expect(app.controller.lastResult!.doubled, isFalse);
  });

  test('double coins cannot be applied twice, even concurrently', () async {
    final ads = OneShotAds(reloads: true);
    final app = ProbeApp(ads: ads, now: now);
    await app.start();
    await app.controller.startClassic();
    await playToGameOver(app.controller);
    await app.controller.endGame();
    final before = app.controller.profile.coins;
    final base = app.controller.lastResult!.baseCoins;

    await Future.wait([app.controller.doubleCoins(), app.controller.doubleCoins()]);

    expect(app.controller.profile.coins, before + base);
    expect(app.controller.lastResult!.doubled, isTrue);
  });

  test('reroll refuses at the cap without charging', () async {
    final ads = OneShotAds(reloads: true);
    final app = ProbeApp(ads: ads, now: now);
    await app.start();
    await app.controller.startClassic();
    await setCoins(app.controller, 1000);

    for (var i = 0; i < 3; i++) {
      await app.controller.rerollWithCoins();
    }
    expect(app.controller.state.rerollsUsed, 3);
    final coins = app.controller.profile.coins;

    await app.controller.rerollWithCoins();
    await app.controller.rerollWithAd();

    expect(app.controller.state.rerollsUsed, 3);
    expect(app.controller.profile.coins, coins);
    expect(ads.shows, isEmpty, reason: 'a refused reroll never shows an ad');
  });

  test('the free ad-free continue is once per game, not once per app', () async {
    final ads = OneShotAds(reloads: true);
    final app = ProbeApp(ads: ads, now: now);
    await app.start();
    await app.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(adFree: true)),
    );

    for (var game = 0; game < 2; game++) {
      await app.controller.startClassic();
      await playToGameOver(app.controller);
      expect(app.controller.continueAvailable, isTrue);
      await app.controller.continueGame();
      expect(app.controller.state.continuesUsed, 1);
      await playToGameOver(app.controller);
      expect(app.controller.continueAvailable, isFalse,
          reason: 'a second continue in the same game is refused');
      await app.controller.endGame();
    }
    expect(app.controller.profile.coins, greaterThanOrEqualTo(0));
  });

  test('a long spend sequence never drives coins negative', () async {
    final ads = OneShotAds()..rewardedReady = false;
    final app = ProbeApp(ads: ads, now: now);
    await app.start();
    await setCoins(app.controller, 200);

    await app.controller.buyStreakFreeze();
    await app.controller.buyTheme(11);
    await app.controller.startClassic();
    for (var i = 0; i < 4; i++) {
      await app.controller.rerollWithCoins();
    }
    await playToGameOver(app.controller);
    await app.controller.continueGame();
    await app.controller.endGame();

    expect(app.controller.profile.coins, greaterThanOrEqualTo(0));
  });
}
