import 'dart:async';

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
  PurchaseSink? _sink;
  int _tokenCounter = 0;

  @override
  void start(PurchaseSink sink) => _sink = sink;

  @override
  Future<List<StoreProduct>> products() async => [
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
