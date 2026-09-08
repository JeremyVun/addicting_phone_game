import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/services/purchases.dart';
import 'package:settle/services/storage.dart';

import '../services/purchase_stream_test.dart' show ScriptedGateway, update;
import 'support.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);

  late ScriptedGateway gateway;
  late ProbeApp app;
  late PlayPurchaseService service;

  Future<void> boot() async {
    gateway = ScriptedGateway();
    app = ProbeApp(now: now);
    await app.start();
    service = PlayPurchaseService(gateway: gateway, analytics: app.analytics)
      ..start(app.controller);
  }

  tearDown(() => gateway.controller.close());

  test('a crash-replayed token grants once, however often it is replayed',
      () async {
    await boot();
    for (var i = 0; i < 5; i++) {
      await service.handleUpdates([
        update(Products.coinsSmall, PurchaseStatus.purchased, token: 'dup'),
      ]);
      await app.controller.idle;
    }
    expect(app.controller.profile.coins, 500);
    expect(app.controller.profile.completedPurchaseTokens, ['dup']);
    expect(app.controller.profile.pendingPurchaseTokens, isEmpty);
  });

  test('a token whose consume never succeeds is granted once and stays pending',
      () async {
    await boot();
    gateway.consumeSucceeds = false;
    for (var i = 0; i < 4; i++) {
      await service.handleUpdates([
        update(Products.coinsLarge, PurchaseStatus.purchased, token: 'stuck'),
      ]);
      await app.controller.idle;
    }
    expect(app.controller.profile.coins, 8000);
    expect(app.controller.profile.pendingPurchaseTokens, {'stuck'});
    expect(app.controller.profile.completedPurchaseTokens, isEmpty);
  });

  test('the 200-token cap never re-grants a still-pending purchase', () async {
    await boot();
    gateway.consumeSucceeds = false;
    await service.handleUpdates([
      update(Products.coinsMedium, PurchaseStatus.purchased, token: 'pending-1'),
    ]);
    await app.controller.idle;
    gateway.consumeSucceeds = true;
    for (var i = 0; i < 250; i++) {
      await service.handleUpdates([
        update(Products.removeAds, PurchaseStatus.restored, token: 'filler-$i'),
      ]);
      await app.controller.idle;
    }
    expect(app.controller.profile.completedPurchaseTokens, hasLength(200));
    expect(app.controller.profile.pendingPurchaseTokens, {'pending-1'});
    final coins = app.controller.profile.coins;

    await service.handleUpdates([
      update(Products.coinsMedium, PurchaseStatus.purchased, token: 'pending-1'),
    ]);
    await app.controller.idle;
    expect(app.controller.profile.coins, coins);
  });

  test('an empty token or an empty product id grants nothing', () async {
    await boot();
    await service.handleUpdates([
      update(Products.coinsLarge, PurchaseStatus.purchased, token: ''),
      update('', PurchaseStatus.purchased, token: 'orphan'),
      update('not_a_product', PurchaseStatus.purchased, token: 'unknown'),
    ]);
    await app.controller.idle;
    expect(app.controller.profile.coins, 0);
    expect(app.controller.profile.adFree, isFalse);
    expect(app.controller.profile.pendingPurchaseTokens, isEmpty);
    expect(app.controller.profile.completedPurchaseTokens,
        isNot(contains('orphan')));
  });

  test('a restored non-consumable survives a relaunch without granting twice',
      () async {
    await boot();
    await service.handleUpdates([
      update(Products.themePackAll, PurchaseStatus.purchased, token: 'pack'),
    ]);
    await app.controller.idle;
    expect(app.controller.profile.themePackOwned, isTrue);
    expect(app.controller.profile.unlockedThemes, hasLength(Themes.count));

    final saved = (app.storage as MemoryStorage).writes.last;
    final relaunch = ProbeApp(storage: MemoryStorage(saved), now: now);
    await relaunch.start();
    final restoreService =
        PlayPurchaseService(gateway: gateway, analytics: relaunch.analytics)
          ..start(relaunch.controller);
    await restoreService.handleUpdates([
      update(Products.themePackAll, PurchaseStatus.restored, token: 'pack'),
    ]);
    await relaunch.controller.idle;
    expect(relaunch.controller.profile.completedPurchaseTokens, ['pack']);
    expect(relaunch.controller.profile.coins, 0);
  });
}
