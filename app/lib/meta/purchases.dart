import 'economy.dart';
import 'player_profile.dart';
import 'themes.dart';

/// Design 8.3 step 2: the pure grant, idempotent on the Play purchase token
/// (`verificationData.serverVerificationData`), never on `purchaseID`.
class Purchases {
  const Purchases._();

  static bool alreadyGranted(PlayerProfile profile, String purchaseToken) =>
      profile.grantedPurchaseTokens.contains(purchaseToken);

  /// An empty token cannot identify a purchase, so it grants nothing.
  static PlayerProfile grant(
    PlayerProfile profile,
    String productId,
    String purchaseToken,
  ) {
    final product = Products.byId(productId);
    if (product == null ||
        purchaseToken.isEmpty ||
        alreadyGranted(profile, purchaseToken)) {
      return profile;
    }
    final granted = [...profile.grantedPurchaseTokens, purchaseToken];
    return profile.copyWith(
      coins: profile.coins + product.coins,
      adFree: profile.adFree || product.grantsAdFree,
      themePackOwned: profile.themePackOwned || product.grantsThemePack,
      unlockedThemes: product.grantsThemePack
          ? {for (final theme in Themes.all) theme.slot}
          : profile.unlockedThemes,
      grantedPurchaseTokens: granted.length > Economy.grantedPurchaseTokensCap
          ? granted.sublist(granted.length - Economy.grantedPurchaseTokensCap)
          : granted,
    );
  }
}
