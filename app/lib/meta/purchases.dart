import 'economy.dart';
import 'player_profile.dart';
import 'themes.dart';

/// Design 8.3 step 2 and 3, as pure state. The idempotency key is the Play
/// purchase token (`verificationData.serverVerificationData`), never
/// `purchaseID`. A token is pending from the grant until the plugin confirms
/// the consume or acknowledge, so a crash in between cannot grant twice.
class Purchases {
  const Purchases._();

  static bool alreadyGranted(PlayerProfile profile, String purchaseToken) =>
      profile.pendingPurchaseTokens.contains(purchaseToken) ||
      profile.completedPurchaseTokens.contains(purchaseToken);

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
    return profile.copyWith(
      coins: profile.coins + product.coins,
      adFree: profile.adFree || product.grantsAdFree,
      themePackOwned: profile.themePackOwned || product.grantsThemePack,
      unlockedThemes: product.grantsThemePack
          ? {for (final theme in Themes.all) theme.slot}
          : profile.unlockedThemes,
      pendingPurchaseTokens: {...profile.pendingPurchaseTokens, purchaseToken},
    );
  }

  static PlayerProfile markPurchaseCompleted(
    PlayerProfile profile,
    String purchaseToken,
  ) {
    if (purchaseToken.isEmpty ||
        profile.completedPurchaseTokens.contains(purchaseToken)) {
      return profile;
    }
    final completed = [...profile.completedPurchaseTokens, purchaseToken];
    return profile.copyWith(
      pendingPurchaseTokens: {...profile.pendingPurchaseTokens}
        ..remove(purchaseToken),
      completedPurchaseTokens: completed.length > Economy.completedTokensCap
          ? completed.sublist(completed.length - Economy.completedTokensCap)
          : completed,
    );
  }
}
