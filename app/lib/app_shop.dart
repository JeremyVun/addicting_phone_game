part of 'app.dart';

/// The shop screen's own view state. It is not part of the persisted envelope,
/// so it lives beside the controller rather than in it.
class ShopState extends ChangeNotifier {
  List<StoreProduct> products = const [];
  bool loading = false;
  bool loaded = false;
  String? message;
  final Set<String> pending = {};

  void startLoading() {
    loading = true;
    notifyListeners();
  }

  void finishLoading(List<StoreProduct> fetched) {
    products = fetched;
    loading = false;
    loaded = true;
    notifyListeners();
  }

  void markPending(String productId) {
    pending.add(productId);
    notifyListeners();
  }

  void clearPending(String productId) {
    if (pending.remove(productId)) notifyListeners();
  }

  void showMessage(String? text) {
    message = text;
    notifyListeners();
  }
}

final Expando<ShopState> _shopStates = Expando<ShopState>();

extension ShopFlows on AppController {
  ShopState get shop => _shopStates[this] ??= ShopState();

  bool get privacyOptionsRequired => services.ads.privacyOptionsRequired;

  Future<void> showPrivacyOptions() => services.ads.showPrivacyOptions();

  Future<void> loadProducts() async {
    final state = shop;
    if (state.loading) return;
    state.startLoading();
    state.finishLoading(await services.purchases.products());
  }

  Future<void> buyProduct(String productId) async {
    final state = shop
      ..showMessage(null)
      ..markPending(productId);
    await services.purchases.buy(productId);
    await idle;
    state.clearPending(productId);
  }

  Future<void> restorePurchases() async {
    await services.purchases.restore();
    await idle;
    shop.showMessage(S.shopRestored);
  }
}
