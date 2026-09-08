import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);

  test('reroll with coins deducts 50 and replaces the unplayed slots', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.mutate(
      (d) => d.copyWith(profile: d.profile.copyWith(coins: 100)),
    );
    await harness.controller.startClassic();
    final before = harness.controller.state.set;

    await harness.controller.rerollWithCoins();

    expect(harness.controller.profile.coins, 50);
    expect(harness.controller.state.rerollsUsed, 1);
    expect(harness.controller.state.setsGenerated, 1);
    expect(harness.controller.state.set, isNot(before));
  });

  test('reroll with coins refuses when the balance is short', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();

    await harness.controller.rerollWithCoins();

    expect(harness.controller.state.rerollsUsed, 0);
  });

  test('reroll by ad rerolls only from the reward callback', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();

    harness.ads.grantsReward = false;
    await harness.controller.rerollWithAd();
    expect(harness.controller.state.rerollsUsed, 0);
    expect(harness.analytics.named('rewarded_unavailable'), hasLength(1));

    harness.ads.grantsReward = true;
    await harness.controller.rerollWithAd();
    expect(harness.controller.state.rerollsUsed, 1);
    expect(harness.analytics.named('rewarded_completed'), hasLength(1));
  });

  test('reroll refuses at the three-per-game cap', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();
    for (var i = 0; i < 3; i++) {
      await harness.controller.rerollWithAd();
    }
    expect(harness.controller.state.rerollsUsed, 3);
    expect(harness.controller.canReroll, isFalse);

    await harness.controller.rerollWithAd();
    expect(harness.controller.state.rerollsUsed, 3);
  });

  test('requestReroll and requestPause open their sheets', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.controller.startClassic();

    harness.controller.requestReroll();
    harness.controller.requestPause();

    expect(harness.navigator.calls, containsAllInOrder(['showReroll', 'showPause']));
  });

  test('the same purchase token grants once and completes both times', () async {
    final harness = Harness(now: now);
    await harness.start();

    await harness.controller.applyPurchase('coins_small', 'tok-1');
    await harness.controller.purchaseCompleted('tok-1');
    await harness.controller.applyPurchase('coins_small', 'tok-1');
    await harness.controller.purchaseCompleted('tok-1');

    expect(harness.controller.profile.coins, 500);
    expect(harness.controller.profile.pendingPurchaseTokens, isEmpty);
    expect(harness.controller.profile.completedPurchaseTokens, ['tok-1']);
  });

  test('the fake store drives the sink end to end', () async {
    final harness = Harness(now: now);
    await harness.start();
    await harness.purchases.buy('remove_ads');
    await harness.controller.idle;

    expect(harness.controller.profile.adFree, isTrue);
    expect(harness.controller.profile.completedPurchaseTokens, [
      'fake-remove_ads-1',
    ]);
  });
}
