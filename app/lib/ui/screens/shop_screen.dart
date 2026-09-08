import 'package:flutter/material.dart';

import '../../app.dart';
import '../../meta/meta.dart';
import '../../services/purchases.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';
import '../widgets/buttons.dart';
import '../widgets/coin_chip.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.shop]),
      builder: (context, _) {
        final palette = controller.palette;
        final shop = controller.shop;
        return Scaffold(
          backgroundColor: palette.ground,
          appBar: AppBar(
            backgroundColor: palette.ground,
            foregroundColor: palette.ink,
            elevation: 0,
            title: Text(
              S.shopTitle,
              style: manrope(size: 18, weight: 800, color: palette.ink),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Center(
                  child: CoinChip(
                    coins: controller.profile.coins,
                    palette: palette,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: shop.products.isEmpty
                        ? _Empty(loading: shop.loading, palette: palette)
                        : ListView(
                            children: [
                              for (final product in shop.products)
                                _ProductRow(
                                  controller: controller,
                                  product: product,
                                ),
                            ],
                          ),
                  ),
                  if (shop.message case final message?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: manrope(
                          size: 13,
                          weight: 600,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  SecondaryButton(
                    label: S.shopRestore,
                    palette: palette,
                    onPressed: controller.restorePurchases,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.loading, required this.palette});

  final bool loading;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Center(
    child: loading
        ? CircularProgressIndicator(color: palette.accent, strokeWidth: 2)
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              S.shopUnavailable,
              textAlign: TextAlign.center,
              style: manrope(size: 15, weight: 600, color: palette.muted),
            ),
          ),
  );
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.controller, required this.product});

  final AppController controller;
  final StoreProduct product;

  static const Map<String, (String, String?)> _labels = {
    Products.removeAds: (S.shopRemoveAds, S.shopRemoveAdsSub),
    Products.coinsSmall: (S.shopCoinsSmall, null),
    Products.coinsMedium: (S.shopCoinsMedium, null),
    Products.coinsLarge: (S.shopCoinsLarge, null),
    Products.themePackAll: (S.shopAllThemes, S.shopAllThemesSub),
  };

  bool get _owned => switch (product.id) {
    Products.removeAds => controller.profile.adFree,
    Products.themePackAll => controller.profile.themePackOwned,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    final pending = controller.shop.pending.contains(product.id);
    final (title, subtitle) = _labels[product.id] ?? (product.title, null);
    final trailing = _owned
        ? S.shopPurchased
        : pending
        ? S.shopPending
        : product.price;
    return Semantics(
      button: !_owned && !pending,
      child: InkWell(
        onTap: _owned || pending
            ? null
            : () => controller.buyProduct(product.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: manrope(size: 16, weight: 800, color: palette.ink),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: manrope(
                          size: 12,
                          weight: 600,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                trailing,
                style: manrope(
                  size: 15,
                  weight: 800,
                  color: _owned || pending ? palette.muted : palette.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
