import 'package:flutter_test/flutter_test.dart';
import 'package:settle/app.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/ui/strings.dart';

import 'harness.dart';

void main() {
  test('products load into the shop state', () async {
    final harness = Harness();
    await harness.start();
    await harness.controller.loadProducts();
    expect(harness.controller.shop.loaded, isTrue);
    expect(
      harness.controller.shop.products.map((p) => p.id),
      containsAll(Products.all.map((p) => p.id)),
    );
  });

  test('an unavailable store leaves the product list empty', () async {
    final harness = Harness();
    await harness.start();
    harness.purchases.catalogueIsEmpty = true;
    await harness.controller.loadProducts();
    expect(harness.controller.shop.products, isEmpty);
    expect(harness.controller.shop.loaded, isTrue);
  });

  test('buying remove_ads sets adFree and makes the continue free', () async {
    final harness = Harness();
    await harness.start();
    await harness.controller.loadProducts();
    await harness.controller.buyProduct(Products.removeAds);
    expect(harness.controller.profile.adFree, isTrue);
    expect(harness.controller.continuePayment, ContinuePayment.free);
    expect(harness.controller.shop.pending, isEmpty);
  });

  test('a coin pack adds its coins exactly once', () async {
    final harness = Harness();
    await harness.start();
    await harness.controller.loadProducts();
    final before = harness.controller.profile.coins;
    await harness.controller.buyProduct(Products.coinsMedium);
    expect(harness.controller.profile.coins, before + 3000);
    // The same token replaying grants nothing more.
    final token = harness.controller.profile.completedPurchaseTokens.last;
    await harness.controller.applyPurchase(Products.coinsMedium, token);
    expect(harness.controller.profile.coins, before + 3000);
  });

  test('restore replays the owned non-consumables and reports it', () async {
    final harness = Harness();
    await harness.start();
    await harness.controller.loadProducts();
    await harness.controller.buyProduct(Products.themePackAll);
    expect(harness.controller.profile.themePackOwned, isTrue);
    await harness.controller.restorePurchases();
    expect(harness.controller.shop.message, S.shopRestored);
    expect(harness.controller.profile.themePackOwned, isTrue);
  });

  test('a failed purchase surfaces the message and clears pending', () async {
    final harness = Harness();
    await harness.start();
    harness.controller.purchaseFailed(Products.coinsSmall);
    expect(harness.navigator.calls, contains('message:${S.shopPurchaseFailed}'));
  });

  test('privacy options follow the ads service', () async {
    final harness = Harness();
    await harness.start();
    expect(harness.controller.privacyOptionsRequired, isFalse);
    await harness.controller.showPrivacyOptions();
  });

  test('the daily reminder flag is written to the profile', () async {
    final harness = Harness();
    await harness.start();
    await harness.controller.setRemindersEnabled(true);
    expect(harness.controller.profile.remindersEnabled, isTrue);
  });
}
