import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:settle/meta/meta.dart';
import 'package:settle/services/analytics.dart';
import 'package:settle/services/purchases.dart';

PurchaseDetails update(
  String productId,
  PurchaseStatus status, {
  String token = 'token-1',
  bool pendingComplete = true,
}) => PurchaseDetails(
  purchaseID: null,
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: '{}',
    serverVerificationData: token,
    source: 'google_play',
  ),
  transactionDate: null,
  status: status,
)..pendingCompletePurchase = pendingComplete;

class ScriptedGateway implements BillingGateway {
  ScriptedGateway({this.available = true, this.products = const []});

  bool available;
  List<ProductDetails> products;
  List<String> notFound = const [];
  String? queryError;
  bool consumeSucceeds = true;
  bool completeSucceeds = true;

  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<String> calls = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductQuery> queryProducts(Set<String> ids) async {
    calls.add('query:${ids.length}');
    return ProductQuery(
      products: products,
      notFound: notFound,
      error: queryError,
    );
  }

  @override
  Future<void> buyConsumable(ProductDetails product) async =>
      calls.add('buyConsumable:${product.id}');

  @override
  Future<void> buyNonConsumable(ProductDetails product) async =>
      calls.add('buyNonConsumable:${product.id}');

  @override
  Future<bool> consume(PurchaseDetails purchase) async {
    calls.add('consume:${purchase.productID}');
    return consumeSucceeds;
  }

  @override
  Future<bool> complete(PurchaseDetails purchase) async {
    calls.add('complete:${purchase.productID}');
    return completeSucceeds;
  }

  @override
  Future<void> restore() async => calls.add('restore');
}

class RecordingSink implements PurchaseSink {
  final List<String> calls = [];

  @override
  Future<void> applyPurchase(String productId, String purchaseToken) async =>
      calls.add('grant:$productId:$purchaseToken');

  @override
  Future<void> purchaseCompleted(String purchaseToken) async =>
      calls.add('completed:$purchaseToken');

  @override
  void purchasePending(String productId) => calls.add('pending:$productId');

  @override
  void purchaseFailed(String productId) => calls.add('failed:$productId');
}

ProductDetails detailsFor(String id, String price) => ProductDetails(
  id: id,
  title: id,
  description: id,
  price: price,
  rawPrice: 1,
  currencyCode: 'USD',
);

void main() {
  late ScriptedGateway gateway;
  late RecordingSink sink;
  late RecordingAnalytics analytics;
  late PlayPurchaseService service;

  setUp(() {
    gateway = ScriptedGateway();
    sink = RecordingSink();
    analytics = RecordingAnalytics();
    service = PlayPurchaseService(gateway: gateway, analytics: analytics)
      ..start(sink);
  });

  tearDown(() => gateway.controller.close());

  test('start subscribes once and restores', () async {
    await pumpEventQueue();
    expect(gateway.calls, ['restore']);
    expect(gateway.controller.hasListener, isTrue);
  });

  test('pending only marks the item pending', () async {
    await service.handleUpdates([update(Products.coinsSmall, PurchaseStatus.pending)]);
    expect(sink.calls, ['pending:${Products.coinsSmall}']);
    expect(gateway.calls, ['restore']);
  });

  test('a consumable is granted, consumed and then completed', () async {
    await service.handleUpdates([
      update(Products.coinsMedium, PurchaseStatus.purchased, token: 'tok-a'),
    ]);
    expect(sink.calls, [
      'grant:${Products.coinsMedium}:tok-a',
      'completed:tok-a',
    ]);
    expect(gateway.calls, [
      'restore',
      'consume:${Products.coinsMedium}',
      'complete:${Products.coinsMedium}',
    ]);
    expect(analytics.named('purchase_completed').single.dims, {
      'product': Products.coinsMedium,
    });
  });

  test('a non-consumable is granted and acknowledged, not consumed', () async {
    await service.handleUpdates([
      update(Products.removeAds, PurchaseStatus.purchased, token: 'tok-b'),
    ]);
    expect(sink.calls, ['grant:${Products.removeAds}:tok-b', 'completed:tok-b']);
    expect(gateway.calls, ['restore', 'complete:${Products.removeAds}']);
  });

  test('restored does not count as a fresh purchase in analytics', () async {
    await service.handleUpdates([
      update(Products.themePackAll, PurchaseStatus.restored, token: 'tok-c'),
    ]);
    expect(sink.calls, ['grant:${Products.themePackAll}:tok-c', 'completed:tok-c']);
    expect(analytics.named('purchase_completed'), isEmpty);
  });

  test('an empty product id is completed and otherwise ignored', () async {
    await service.handleUpdates([
      update('', PurchaseStatus.canceled, token: ''),
    ]);
    expect(sink.calls, isEmpty);
    expect(gateway.calls, ['restore', 'complete:']);
  });

  test('an empty token grants nothing but still completes', () async {
    await service.handleUpdates([
      update(Products.coinsSmall, PurchaseStatus.purchased, token: ''),
    ]);
    expect(sink.calls, isEmpty);
    expect(gateway.calls, ['restore', 'complete:${Products.coinsSmall}']);
  });

  test('a crash replay re-grants nothing new but finishes the transaction', () async {
    for (var i = 0; i < 2; i++) {
      await service.handleUpdates([
        update(Products.coinsLarge, PurchaseStatus.purchased, token: 'dup'),
      ]);
    }
    // The sink is idempotent per token; the service always finishes the deal.
    expect(sink.calls, [
      'grant:${Products.coinsLarge}:dup',
      'completed:dup',
      'grant:${Products.coinsLarge}:dup',
      'completed:dup',
    ]);
    expect(
      gateway.calls.where((c) => c.startsWith('consume')).length,
      2,
    );
  });

  test('a failed consume leaves the token pending, not completed', () async {
    gateway.consumeSucceeds = false;
    await service.handleUpdates([
      update(Products.coinsSmall, PurchaseStatus.purchased, token: 'tok-d'),
    ]);
    expect(sink.calls, ['grant:${Products.coinsSmall}:tok-d']);
  });

  test('error completes the transaction and reports the failure', () async {
    await service.handleUpdates([
      update(Products.removeAds, PurchaseStatus.error),
    ]);
    expect(sink.calls, ['failed:${Products.removeAds}']);
    expect(gateway.calls, ['restore', 'complete:${Products.removeAds}']);
  });

  test('canceled without a pending completion completes nothing', () async {
    await service.handleUpdates([
      update(
        Products.removeAds,
        PurchaseStatus.canceled,
        pendingComplete: false,
      ),
    ]);
    expect(sink.calls, ['failed:${Products.removeAds}']);
    expect(gateway.calls, ['restore']);
  });

  test('stream updates are handled in order through the subscription', () async {
    gateway.controller.add([
      update(Products.removeAds, PurchaseStatus.pending),
      update(Products.removeAds, PurchaseStatus.purchased, token: 'tok-e'),
    ]);
    await pumpEventQueue();
    expect(sink.calls, [
      'pending:${Products.removeAds}',
      'grant:${Products.removeAds}:tok-e',
      'completed:tok-e',
    ]);
  });

  test('products come back in catalogue order with store prices', () async {
    gateway.products = [
      detailsFor(Products.themePackAll, r'$2.99'),
      detailsFor(Products.removeAds, r'$3.99'),
    ];
    final products = await service.products();
    expect(products.map((p) => p.id), [
      Products.removeAds,
      Products.themePackAll,
    ]);
    expect(products.first.price, r'$3.99');
  });

  test('an unavailable store yields an empty list, not a throw', () async {
    gateway.available = false;
    expect(await service.products(), isEmpty);
  });

  test('every id unfetched yields an empty list', () async {
    gateway.notFound = [for (final p in Products.all) p.id];
    expect(await service.products(), isEmpty);
  });

  test('buy picks the consumable path for coin packs only', () async {
    gateway.products = [
      detailsFor(Products.coinsSmall, r'$0.99'),
      detailsFor(Products.removeAds, r'$3.99'),
    ];
    await service.products();
    await service.buy(Products.coinsSmall);
    await service.buy(Products.removeAds);
    expect(gateway.calls.sublist(gateway.calls.length - 2), [
      'buyConsumable:${Products.coinsSmall}',
      'buyNonConsumable:${Products.removeAds}',
    ]);
  });

  test('buying an unfetched product fails without touching the store', () async {
    await service.buy(Products.coinsLarge);
    expect(sink.calls, ['failed:${Products.coinsLarge}']);
  });
}
