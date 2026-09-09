import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../meta/economy.dart';
import 'analytics.dart';

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;

  /// The store's localised price string, shown verbatim.
  final String price;
}

abstract class PurchaseService {
  void start(PurchaseSink sink);
  Future<List<StoreProduct>> products();
  Future<void> buy(String productId);
  Future<void> restore();
}

abstract class PurchaseSink {
  Future<void> applyPurchase(String productId, String purchaseToken);
  Future<void> purchaseCompleted(String purchaseToken);
  void purchasePending(String productId);
  void purchaseFailed(String productId);
}

class FakePurchaseService implements PurchaseService {
  FakePurchaseService({this.delay = const Duration(milliseconds: 300)});

  static const Map<String, String> catalogue = {
    'remove_ads': r'$3.99',
    'coins_small': r'$0.99',
    'coins_medium': r'$4.99',
    'coins_large': r'$9.99',
    'theme_pack_all': r'$2.99',
  };

  final Duration delay;
  final List<String> bought = [];

  /// Lets a test or an emulator drive exercise the "store unreachable" state.
  bool catalogueIsEmpty = false;
  PurchaseSink? _sink;
  int _tokenCounter = 0;

  @override
  void start(PurchaseSink sink) => _sink = sink;

  @override
  Future<List<StoreProduct>> products() async => catalogueIsEmpty
      ? const []
      : [
          for (final entry in catalogue.entries)
            StoreProduct(id: entry.key, title: entry.key, price: entry.value),
        ];

  @override
  Future<void> buy(String productId) async {
    bought.add(productId);
    _sink?.purchasePending(productId);
    await Future<void>.delayed(delay);
    final token = 'fake-$productId-${++_tokenCounter}';
    await _sink?.applyPurchase(productId, token);
    await _sink?.purchaseCompleted(token);
  }

  @override
  Future<void> restore() async {
    for (final productId in bought.toSet()) {
      final token = 'fake-$productId-restore';
      await _sink?.applyPurchase(productId, token);
      await _sink?.purchaseCompleted(token);
    }
  }
}

class ProductQuery {
  const ProductQuery({
    required this.products,
    required this.notFound,
    this.error,
  });

  final List<ProductDetails> products;
  final List<String> notFound;
  final String? error;
}

/// Everything `PlayPurchaseService` needs from `in_app_purchase`, so the design
/// 8.3 stream handling can be driven by a scripted gateway in unit tests.
abstract class BillingGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductQuery> queryProducts(Set<String> ids);
  Future<void> buyConsumable(ProductDetails product);
  Future<void> buyNonConsumable(ProductDetails product);
  Future<bool> consume(PurchaseDetails purchase);
  Future<bool> complete(PurchaseDetails purchase);
  Future<void> restore();
}

class PlayPurchaseService implements PurchaseService {
  PlayPurchaseService({
    BillingGateway? gateway,
    this.analytics = const NoopAnalytics(),
  }) : _gateway = gateway ?? PlayBillingGateway();

  final BillingGateway _gateway;
  final AnalyticsService analytics;
  final Map<String, ProductDetails> _details = {};

  PurchaseSink? _sink;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void start(PurchaseSink sink) {
    _sink = sink;
    _subscription ??= _gateway.purchaseStream.listen(
      handleUpdates,
      onError: (Object error, StackTrace stack) =>
          _log('purchase stream', error, stack),
    );
    unawaited(restore());
  }

  @override
  Future<List<StoreProduct>> products() async {
    try {
      if (!await _gateway.isAvailable()) {
        _log('store unavailable');
        return const [];
      }
      final query = await _gateway.queryProducts({
        for (final product in Products.all) product.id,
      });
      if (query.error != null) _log('query products: ${query.error}');
      if (query.notFound.isNotEmpty) {
        _log('products not found in Play: ${query.notFound.join(", ")}');
      }
      if (query.products.isEmpty) return const [];
      _details
        ..clear()
        ..addEntries(query.products.map((p) => MapEntry(p.id, p)));
      return [
        for (final product in Products.all)
          if (_details[product.id] case final details?)
            StoreProduct(
              id: details.id,
              title: details.title,
              price: details.price,
            ),
      ];
    } catch (error, stack) {
      _log('query products threw', error, stack);
      return const [];
    }
  }

  @override
  Future<void> buy(String productId) async {
    final product = Products.byId(productId);
    final details = _details[productId];
    if (product == null || details == null) {
      _log('cannot buy unknown or unfetched product $productId');
      _sink?.purchaseFailed(productId);
      return;
    }
    try {
      if (product.kind == ProductKind.consumable) {
        await _gateway.buyConsumable(details);
      } else {
        await _gateway.buyNonConsumable(details);
      }
    } catch (error, stack) {
      _log('buy $productId threw', error, stack);
      _sink?.purchaseFailed(productId);
    }
  }

  @override
  Future<void> restore() async {
    try {
      await _gateway.restore();
    } catch (error, stack) {
      _log('restore threw', error, stack);
    }
  }

  @visibleForTesting
  Future<void> handleUpdates(List<PurchaseDetails> updates) async {
    for (final update in updates) {
      await _handle(update);
    }
  }

  Future<void> _handle(PurchaseDetails update) async {
    if (update.status == PurchaseStatus.pending) {
      _sink?.purchasePending(update.productID);
      return;
    }
    // A user cancel arrives as a synthetic update with everything blank.
    if (update.productID.isEmpty) {
      await _complete(update);
      return;
    }
    switch (update.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _deliver(update);
      case PurchaseStatus.error:
      case PurchaseStatus.canceled:
        _log('purchase ${update.productID}: ${update.status.name} '
            '${update.error?.message ?? ""}');
        _sink?.purchaseFailed(update.productID);
        await _complete(update);
      case PurchaseStatus.pending:
        break;
    }
  }

  Future<void> _deliver(PurchaseDetails update) async {
    final token = update.verificationData.serverVerificationData;
    if (token.isEmpty) {
      _log('empty purchase token for ${update.productID}; ignored');
      await _complete(update);
      return;
    }
    final sink = _sink;
    if (sink == null) return;
    // Idempotent per token: a crash-replay re-grants nothing but still finishes
    // the transaction below.
    await sink.applyPurchase(update.productID, token);
    final consumable =
        Products.byId(update.productID)?.kind == ProductKind.consumable;
    final finished = consumable
        ? await _consume(update)
        : await _complete(update);
    if (consumable) await _complete(update);
    if (!finished) return;
    await sink.purchaseCompleted(token);
    if (update.status == PurchaseStatus.purchased) {
      analytics.count('purchase_completed', {'product': update.productID});
      final product = Products.byId(update.productID);
      if (product != null) {
        analytics.countN('revenue_usd_micros', product.usdMicros, {
          'source': 'iap',
          'product': update.productID,
        });
      }
    }
  }

  Future<bool> _consume(PurchaseDetails update) async {
    try {
      return await _gateway.consume(update);
    } catch (error, stack) {
      _log('consume ${update.productID} threw', error, stack);
      return false;
    }
  }

  Future<bool> _complete(PurchaseDetails update) async {
    if (!update.pendingCompletePurchase) return false;
    try {
      return await _gateway.complete(update);
    } catch (error, stack) {
      _log('completePurchase ${update.productID} threw', error, stack);
      return false;
    }
  }
}

void _log(String what, [Object? error, StackTrace? stack]) {
  if (error == null) {
    debugPrint('purchases: $what');
    return;
  }
  debugPrint('purchases: $what: $error');
  if (kDebugMode && stack != null) debugPrintStack(stackTrace: stack);
}

class PlayBillingGateway implements BillingGateway {
  final InAppPurchase _plugin = InAppPurchase.instance;

  InAppPurchaseAndroidPlatformAddition get _android =>
      InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _plugin.purchaseStream;

  @override
  Future<bool> isAvailable() => _plugin.isAvailable();

  @override
  Future<ProductQuery> queryProducts(Set<String> ids) async {
    final response = await _plugin.queryProductDetails(ids);
    return ProductQuery(
      products: response.productDetails,
      notFound: response.notFoundIDs,
      error: response.error?.message,
    );
  }

  /// `autoConsume: false`: the coins are written through the sink before the
  /// item becomes repurchasable (the plugin's auto-consume is process-local).
  @override
  Future<void> buyConsumable(ProductDetails product) => _plugin.buyConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
    autoConsume: false,
  );

  @override
  Future<void> buyNonConsumable(ProductDetails product) => _plugin
      .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));

  @override
  Future<bool> consume(PurchaseDetails purchase) async {
    final result = await _android.consumePurchase(purchase);
    if (result.responseCode != BillingResponse.ok) {
      _log('consume ${purchase.productID}: ${result.responseCode.name}');
      return false;
    }
    return true;
  }

  /// On Android this only acknowledges; it never consumes.
  @override
  Future<bool> complete(PurchaseDetails purchase) async {
    await _plugin.completePurchase(purchase);
    return true;
  }

  @override
  Future<void> restore() => _plugin.restorePurchases();
}
