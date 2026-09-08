import 'package:flutter_test/flutter_test.dart';
import 'package:settle/core/game_state.dart' as core;
import 'package:settle/services/ads.dart';

import 'harness.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);

  test('game over offers a continue, and End game finishes exactly once', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();
    await playToGameOver(harness.controller);

    expect(harness.controller.state.status, core.GameStatus.over);
    expect(harness.controller.continueAvailable, isTrue);
    expect(harness.controller.lastResult, isNull, reason: 'no progression yet');

    await harness.controller.endGame();
    final afterFirst = harness.controller.profile;
    expect(afterFirst.gamesCompleted, 1);
    expect(harness.controller.currentGame, isNull);
    expect(harness.controller.lastResult, isNotNull);

    await harness.controller.endGame();
    expect(harness.controller.profile.coins, afterFirst.coins);
    expect(harness.controller.profile.gamesCompleted, 1);
    expect(harness.analytics.named('game_ended'), hasLength(1));
  });

  test('continue with coins deducts 150 and resumes play', () async {
    final harness = Harness(now: now);
    harness.ads.rewardedReady = false;
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: 400)),
    );
    await harness.controller.startClassic();
    await playToGameOver(harness.controller);

    expect(harness.controller.continuePriceLabel, 'Use 150 coins');
    await harness.controller.continueGame();

    expect(harness.controller.profile.coins, 250);
    expect(harness.controller.state.continuesUsed, 1);
    expect(harness.controller.continueAvailable, isFalse);
  });

  test('a rewarded continue never also charges the coins', () async {
    final harness = Harness(now: now);
    harness.ads.consumesOnShow = true;
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: 400)),
    );
    await harness.controller.startClassic();
    await playToGameOver(harness.controller);

    expect(harness.controller.continuePriceLabel, 'Watch an ad');
    await harness.controller.continueGame();

    expect(harness.controller.profile.coins, 400);
    expect(harness.controller.state.continuesUsed, 1);
  });

  test('continue is free for an ad-free buyer', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(adFree: true, coins: 400)),
    );
    await harness.controller.startClassic();
    await playToGameOver(harness.controller);

    expect(harness.controller.continuePriceLabel, 'Free');
    await harness.controller.continueGame();
    expect(harness.controller.profile.coins, 400);
    expect(harness.controller.state.continuesUsed, 1);
  });

  test('double coins pays the base coins once, from the reward only', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();
    await playToGameOver(harness.controller);
    await harness.controller.endGame();

    final result = harness.controller.lastResult!;
    final before = harness.controller.profile.coins;

    harness.ads.grantsReward = false;
    await harness.controller.doubleCoins();
    expect(harness.controller.profile.coins, before);
    expect(harness.analytics.named('rewarded_unavailable'), hasLength(1));

    harness.ads.grantsReward = true;
    await harness.controller.doubleCoins();
    expect(harness.controller.profile.coins, before + result.baseCoins);
    expect(harness.controller.lastResult!.doubled, isTrue);

    await harness.controller.doubleCoins();
    expect(harness.controller.profile.coins, before + result.baseCoins);
    expect(
      harness.analytics
          .named('rewarded_completed')
          .where((e) => e.dims['placement'] == 'doubleCoins'),
      hasLength(1),
    );
  });

  test('the play host keeps the finished board after finishGame', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();
    await playToGameOver(harness.controller);
    final finished = harness.controller.state;

    await harness.controller.endGame();

    expect(harness.controller.currentGame, isNull);
    expect(harness.controller.state.id, finished.id);
    expect(harness.controller.state.board, finished.board);
  });

  test('goHome clears the pending result', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();
    await playToGameOver(harness.controller);
    await harness.controller.endGame();
    expect(harness.controller.lastResult, isNotNull);

    await harness.controller.goHome();

    expect(harness.controller.lastResult, isNull);
    expect((await harness.storage.load())!.lastResult, isNull);
    expect(harness.navigator.calls, containsAllInOrder(['dismissSheet', 'goHome']));
  });

  test('playAgain shows an interstitial only when every 8.2 condition holds', () async {
    Future<Harness> ready({
      required int gamesCompleted,
      required int gamesSinceInterstitial,
      required Duration gameLength,
      bool interstitialLoaded = true,
      bool adFree = false,
    }) async {
      final harness = Harness(now: now);
      harness.ads.interstitialReady = interstitialLoaded;
      await harness.start();
      await harness.controller.mutate(
        (d) => d.copyWith(
          profile: d.profile.copyWith(
            gamesCompleted: gamesCompleted,
            gamesSinceInterstitial: gamesSinceInterstitial,
            adFree: adFree,
          ),
        ),
      );
      await harness.controller.startClassic();
      harness.clock.advance(gameLength);
      final state = harness.controller.state;
      final slot = state.set.indexWhere((p) => p != null);
      harness.controller.place(slot, 0, 0);
      await harness.controller.idle;
      await harness.controller.endGame();
      return harness;
    }

    final short = await ready(
      gamesCompleted: 5,
      gamesSinceInterstitial: 5,
      gameLength: const Duration(seconds: 20),
    );
    await short.controller.playAgain();
    expect(short.ads.interstitialShows, 0);

    final tooFew = await ready(
      gamesCompleted: 1,
      gamesSinceInterstitial: 5,
      gameLength: const Duration(seconds: 60),
    );
    await tooFew.controller.playAgain();
    expect(tooFew.ads.interstitialShows, 0);

    final notLoaded = await ready(
      gamesCompleted: 5,
      gamesSinceInterstitial: 5,
      gameLength: const Duration(seconds: 60),
      interstitialLoaded: false,
    );
    await notLoaded.controller.playAgain();
    expect(notLoaded.ads.interstitialShows, 0);

    final bought = await ready(
      gamesCompleted: 5,
      gamesSinceInterstitial: 5,
      gameLength: const Duration(seconds: 60),
      adFree: true,
    );
    await bought.controller.playAgain();
    expect(bought.ads.interstitialShows, 0);

    final shows = await ready(
      gamesCompleted: 5,
      gamesSinceInterstitial: 5,
      gameLength: const Duration(seconds: 60),
    );
    await shows.controller.playAgain();
    await shows.controller.idle;

    expect(shows.ads.interstitialShows, 1);
    expect(shows.analytics.named('interstitial_shown'), hasLength(1));
    expect(shows.controller.profile.gamesSinceInterstitial, 0);
    expect(
      shows.controller.profile.lastInterstitialClosedAt,
      shows.clock.now().millisecondsSinceEpoch,
    );
    expect(shows.controller.lastResult, isNull);
    expect(shows.controller.currentGame, isNotNull);
    expect((await shows.storage.load())!.profile.gamesSinceInterstitial, 0);

    final failed = await ready(
      gamesCompleted: 5,
      gamesSinceInterstitial: 5,
      gameLength: const Duration(seconds: 60),
    );
    failed.ads.showFails = true;
    await failed.controller.playAgain();
    await failed.controller.idle;
    expect(failed.analytics.named('interstitial_shown'), isEmpty);
    expect(failed.controller.profile.gamesSinceInterstitial, 6);
    expect(failed.controller.profile.lastInterstitialClosedAt, 0);
  });

  test('a rewarded show stamps the rewarded cooldown through the sink', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();
    await harness.controller.rerollWithAd();
    await harness.controller.idle;

    expect(harness.ads.rewardedShows, [RewardedPlacement.reroll]);
    expect(
      harness.controller.profile.lastRewardedClosedAt,
      harness.clock.now().millisecondsSinceEpoch,
    );
  });
}
