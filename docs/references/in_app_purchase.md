<!-- Retrieved 2026-09-08 | in_app_purchase 3.3.0 / in_app_purchase_android 0.5.3 -->

## Sources
- https://pub.dev/packages/in_app_purchase
- https://pub.dev/packages/in_app_purchase/changelog
- https://pub.dev/api/packages/in_app_purchase (version/publish metadata)
- https://pub.dev/documentation/in_app_purchase/latest/in_app_purchase/InAppPurchase-class.html
- https://pub.dev/documentation/in_app_purchase/latest/in_app_purchase/InAppPurchase/buyConsumable.html
- https://pub.dev/packages/in_app_purchase_android
- https://pub.dev/packages/in_app_purchase_android/changelog
- https://pub.dev/api/packages/in_app_purchase_android
- https://pub.dev/documentation/in_app_purchase_android/latest/in_app_purchase_android/InAppPurchaseAndroidPlatformAddition-class.html
- https://pub.dev/documentation/in_app_purchase_android/latest/in_app_purchase_android/GooglePlayPurchaseParam-class.html
- https://pub.dev/documentation/in_app_purchase_platform_interface/latest/in_app_purchase_platform_interface/ProductDetails-class.html
- https://pub.dev/documentation/in_app_purchase_platform_interface/latest/in_app_purchase_platform_interface/ProductDetailsResponse-class.html
- https://pub.dev/documentation/in_app_purchase_platform_interface/latest/in_app_purchase_platform_interface/PurchaseDetails-class.html
- https://pub.dev/documentation/in_app_purchase_platform_interface/latest/in_app_purchase_platform_interface/PurchaseVerificationData-class.html
- https://pub.dev/documentation/in_app_purchase_platform_interface/latest/in_app_purchase_platform_interface/PurchaseStatus.html
- https://raw.githubusercontent.com/flutter/packages/main/packages/in_app_purchase/in_app_purchase/README.md
- https://raw.githubusercontent.com/flutter/packages/main/packages/in_app_purchase/in_app_purchase_android/android/build.gradle.kts
- https://raw.githubusercontent.com/flutter/packages/main/packages/in_app_purchase/in_app_purchase_android/android/src/main/AndroidManifest.xml
- https://raw.githubusercontent.com/flutter/packages/main/packages/in_app_purchase/in_app_purchase_android/lib/src/in_app_purchase_android_platform.dart
- https://raw.githubusercontent.com/flutter/packages/main/packages/in_app_purchase/in_app_purchase_android/lib/src/types/google_play_purchase_details.dart
- https://raw.githubusercontent.com/flutter/packages/main/packages/in_app_purchase/in_app_purchase_android/lib/src/billing_client_wrappers/billing_client_wrapper.dart
- https://developer.android.com/google/play/billing/integrate
- https://developer.android.com/google/play/billing/compatibility
- https://developer.android.com/google/play/billing/deprecation-faq
- https://developer.android.com/google/play/billing/test
- https://support.google.com/googleplay/android-developer/answer/1153481
- https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/get
- https://docs.flutter.dev/resources/in-app-purchases-overview (cookbook path `/cookbook/plugins/in-app-purchases` is 404; overview page only links the codelab)

## Versions / constraints
- `in_app_purchase` **3.3.0**, published **2026-06-03**. `environment: {sdk: ^3.10.0, flutter: '>=3.38.0'}`.
  - deps: `in_app_purchase_android ^0.5.0`, `in_app_purchase_storekit ^0.4.0`, `in_app_purchase_platform_interface ^1.4.0`.
- `in_app_purchase_android` **0.5.3**, published **2026-08-28**. `environment: {sdk: ^3.12.0, flutter: '>=3.44.0'}`.
  - **Resolving 0.5.1+ forces Flutter >= 3.44 / Dart >= 3.12** even though `in_app_purchase` 3.3.0 itself only needs 3.38.
- Platform support table (plugin README): Android **SDK 24+**, iOS 13.0+, macOS 10.15+. Plugin gradle sets `minSdk = 21`; the README/Flutter floor of 24 is the practical number.
- Bundled billing lib: `implementation("com.android.billingclient:billing:8.0.0")` — Play Billing Library **8.0.0** (raised from 7.1.1 in `in_app_purchase_android` 0.5.0).

```yaml
dependencies:
  in_app_purchase: ^3.3.0
  in_app_purchase_android: ^0.5.3  # only needed to import GooglePlayPurchaseParam / platform addition
```

## Play Billing minimum-version deadline (2026)
- Verbatim, https://developer.android.com/google/play/billing/compatibility and https://developer.android.com/google/play/billing/deprecation-faq:
  > "By Aug 31, 2026, all new apps and updates to existing apps must use Billing Library version 8 or later. If you need more time to update your app, you can request an extension until Nov 1, 2026."
- Deprecation table (https://developer.android.com/google/play/billing/deprecation-faq), "new app and update deadline" / "extension deadline" per version:
  - v5 — Aug 31, 2024 / Nov 1, 2024
  - v6 — Aug 31, 2025 / Nov 1, 2025
  - v7 — **Aug 31, 2026** / Nov 1, 2026
  - v8 — Aug 31, 2027 / Nov 1, 2027
  - v9 — Aug 31, 2028 / Nov 1, 2028
- "All versions of the Google Play Billing Library have a two-year deprecation cycle."
- Practical: `in_app_purchase_android` >= 0.5.0 bundles v8.0.0 and is compliant past Aug 31, 2026. Anything still on `in_app_purchase_android` 0.4.x (billing 7.1.1) will be **rejected for new uploads after Aug 31, 2026**.

## Core API (verbatim signatures)
```dart
static InAppPurchase get instance;
Future<bool> isAvailable();
Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
Future<bool> buyConsumable({required PurchaseParam purchaseParam, bool autoConsume = true});
Future<void> completePurchase(PurchaseDetails purchase);
Future<void> restorePurchases({String? applicationUserName});
Future<String> countryCode();
static T getPlatformAddition<T extends InAppPurchasePlatformAddition?>();
Stream<List<PurchaseDetails>> get purchaseStream;
```

```dart
ProductDetailsResponse({
  required List<ProductDetails> productDetails,
  required List<String> notFoundIDs,
  IAPError? error,
});

ProductDetails({
  required String id,
  required String title,
  required String description,
  required String price,        // formatted, e.g. "$0.99"
  required double rawPrice,     // 2.45 for $2.45
  required String currencyCode, // e.g. "AUD"
  String currencySymbol = '',
});

PurchaseDetails({
  String? purchaseID,
  required String productID,
  required PurchaseVerificationData verificationData,
  required String? transactionDate,
  required PurchaseStatus status,
});
// mutable: status, error (IAPError?), pendingCompletePurchase (bool)

PurchaseVerificationData({
  required String localVerificationData,
  required String serverVerificationData,
  required String source,
});

enum PurchaseStatus { pending, purchased, error, restored, canceled }
```

- `queryProductDetails` returns unknown IDs in `notFoundIDs` — always check it; a typo'd or not-yet-active Play product silently lands there rather than throwing.
- On Android `ProductDetails` is actually `GooglePlayProductDetails`; `PurchaseDetails` is `GooglePlayPurchaseDetails` (exposes `.billingClientPurchase` → `PurchaseWrapper` with `originalJson`, `purchaseToken`, `isAcknowledged`, `orderId`, `products`).

## PurchaseParam / GooglePlayPurchaseParam
```dart
PurchaseParam({required ProductDetails productDetails, String? applicationUserName});

GooglePlayPurchaseParam({
  required ProductDetails productDetails,
  String? applicationUserName,
  ChangeSubscriptionParam? changeSubscriptionParam,
  String? offerToken,
  String? obfuscatedProfileId,
});
```
- `applicationUserName` is passed straight to `launchBillingFlow(accountId: ...)` — it becomes Play's **obfuscatedAccountId**. Play docs: send a hash, never a raw email/user id; verify it server-side before granting.
- `obfuscatedProfileId` added in `in_app_purchase_android` **0.5.2**.
- `changeSubscriptionParam` is Android-only sub upgrade/downgrade; passed to `buyNonConsumable`, not `buyConsumable`:
```dart
PurchaseParam purchaseParam = GooglePlayPurchaseParam(
    productDetails: productDetails,
    changeSubscriptionParam: ChangeSubscriptionParam(
        oldPurchaseDetails: oldPurchaseDetails,
        replacementMode: ReplacementMode.withTimeProration));
InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
```
- Coin packs are consumables → `buyConsumable`; there is no `changeSubscriptionParam` concern.

## buyConsumable vs buyNonConsumable, and what autoConsume really does
- Doc comment: "`autoConsume` is provided as a utility and will instruct the plugin to automatically consume the product after a succesful purchase. `autoConsume` is `true` by default." Also: "Calling this method for non consumable items will cause unwanted behaviors!"
- Android implementation (`in_app_purchase_android_platform.dart`) — the whole of it:
```dart
Future<bool> buyConsumable({required PurchaseParam purchaseParam, bool autoConsume = true}) {
  if (autoConsume) {
    _productIdsToConsume.add(purchaseParam.productDetails.id);
  }
  return buyNonConsumable(purchaseParam: purchaseParam);
}
```
  `_productIdsToConsume` is an **in-memory Set on the platform object**. On a purchase update with `status == purchased` whose `productID` is in that set, `_maybeAutoConsumePurchase` calls `InAppPurchaseAndroidPlatformAddition.consumePurchase`; on non-OK it rewrites the item to `PurchaseStatus.error` with code `consume_purchase_failed`.
- Consuming implicitly acknowledges on Play, so autoConsume covers the 3-day window **only if the consume actually runs in that process**.
- Set `autoConsume: false` when you want to grant coins *before* the item becomes repurchasable — i.e. write coins to your durable store (or get a server ack) and only then call `InAppPurchaseAndroidPlatformAddition.consumePurchase(purchaseDetails)` yourself. With `autoConsume: true` the plugin consumes before your handler has necessarily persisted anything; a crash between consume and your write loses the coins with no way to re-query the purchase (Play stops returning consumed consumables).
- `completePurchase` on Android does **not** consume; source:
```dart
Future<BillingResultWrapper> completePurchase(PurchaseDetails purchase) async {
  final googlePurchase = purchase as GooglePlayPurchaseDetails;
  if (googlePurchase.billingClientPurchase.isAcknowledged) {
    return const BillingResultWrapper(responseCode: BillingResponse.ok);
  }
  return billingClientManager.runWithClient((BillingClient client) =>
      client.acknowledgePurchase(purchase.verificationData.serverVerificationData));
}
```
  So `completePurchase` == `acknowledgePurchase(purchaseToken)`. Acknowledging a consumable stops the refund clock but leaves it **unrepurchasable** until consumed.

## purchaseStream — subscribe, handle, complete
Plugin README, verbatim:
```dart
class _MyAppState extends State<MyApp> {
  StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  void initState() {
    final Stream purchaseUpdated =
        InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // handle error here.
    });
    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
```
```dart
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.status == PurchaseStatus.pending) {
      _showPendingUI();
    } else {
      if (purchaseDetails.status == PurchaseStatus.error) {
        _handleError(purchaseDetails.error!);
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        bool valid = await _verifyPurchase(purchaseDetails);
        if (valid) {
          _deliverProduct(purchaseDetails);
        } else {
          _handleInvalidPurchase(purchaseDetails);
        }
      }
      if (purchaseDetails.pendingCompletePurchase) {
        await InAppPurchase.instance
            .completePurchase(purchaseDetails);
      }
    }
  });
}
```
- `PurchaseStatus.canceled` falls into the `else` branch above and is silently ignored except for the `pendingCompletePurchase` check — add an explicit arm to dismiss your spinner.
- README warning, verbatim: "Failure to call `InAppPurchase.completePurchase` and get a successful response within 3 days of the purchase will result in a refund on Android."
- `pendingCompletePurchase` is set in the `GooglePlayPurchaseDetails` constructor as `!billingClientPurchase.isAcknowledged`, so it is `true` for already-delivered-but-unacked purchases surfaced on restore/relaunch too.
- Subscribe **as early as possible** ("to be able to catch all purchase updates, including the ones from the previous app session"). If the listener lives in a screen widget, purchases that resolve while the screen is closed are missed until next launch. Prefer an app-lifetime service, not `initState` of a store page.
- Android status mapping (`pigeon_converters.dart`): `PurchaseStateWrapper.purchased → purchased`, `.pending → pending`, `.unspecified_state → error`. `PurchaseStatus.canceled` is produced only when the billing result is `BillingResponse.userCanceled`.

## restorePurchases()
```dart
await InAppPurchase.instance.restorePurchases();
```
- Android implementation queries `queryPurchases(ProductType.inapp)` + `queryPurchases(ProductType.subs)`, forces every result to `PurchaseStatus.restored`, and pushes them onto `purchaseStream`. Throws `InAppPurchaseException` (code `restore_failed`) if either query returns non-OK.
- **Duplicate delivery**: restored purchases arrive on the same stream as fresh ones and can arrive repeatedly (every call, every relaunch for unconsumed items). Grant idempotently, keyed on `purchaseID`/`purchaseToken` in durable storage.
- README: "Google Play considers consumable products to no longer be owned once they're marked as consumed and fails to return them here. For restoring these across devices you'll need to persist them on your own server and query that as well." → **coin balances are not restorable via IAP**; they must live on your own account/server, or restore is a no-op for the customer.

## Android-only surface
```dart
final addition = InAppPurchase.instance
    .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
```
Verified members of `InAppPurchaseAndroidPlatformAddition`:
```dart
Future<BillingResultWrapper> consumePurchase(PurchaseDetails purchase);
Future<QueryPurchaseDetailsResponse> queryPastPurchases({String? applicationUserName});
Future<bool> isFeatureSupported(BillingClientFeature feature);
Future<void> setBillingChoice(BillingChoiceMode billingChoiceMode);
Future<BillingResultWrapper> isAlternativeBillingOnlyAvailable();
Future<AlternativeBillingOnlyReportingDetailsWrapper> createAlternativeBillingOnlyReportingDetails();
Future<BillingResultWrapper> showAlternativeBillingOnlyInformationDialog();
Future<InAppMessageResultWrapper> showInAppMessages();   // added 0.5.1
Future<String> getCountryCode();
late final Stream<GooglePlayUserChoiceDetails> userChoiceDetailsStream;
```
- `enum BillingChoiceMode { playBillingOnly, alternativeBillingOnly, userChoiceBilling }` — `setBillingChoice` must be called **before** any purchase attempt; default is `playBillingOnly`. Irrelevant for a normal coin-pack game.
- `enum BillingClientFeature { alternativeBillingOnly, billingConfig, externalOffer, inAppMessaging, priceChangeConfirmation, productDetails, subscriptions, ... }`.
- Removed in 0.5.0 (breaking): `queryPurchaseHistory` / `queryPurchaseHistoryAsync` — use `queryPurchases`. 0.5.0 also added `subResponseCode` on `BillingResultWrapper`, `oneTimePurchaseOfferDetailsList`, and `unfetchedProductList`.
- `enum BillingResponse { serviceTimeout, featureNotSupported, serviceDisconnected, ok, userCanceled, serviceUnavailable, billingUnavailable, ... }`.

### Acknowledgement vs consumption (Play semantics)
- Play docs, verbatim: acknowledgement "must be done within three days so that the purchase isn't automatically refunded and entitlement revoked"; "purchases are refunded after 3 days if your app has not processed the purchase."
- Consumables → `consumeAsync` (implicitly acknowledges, re-enables repurchase). Non-consumables/subs → `acknowledgePurchase`.
- Server-side equivalents Google now recommends: `Purchases.products:consume`, `Purchases.products:acknowledge`.

### Pending purchases
- Billing 8 requires `enablePendingPurchases(PendingPurchasesParams...)` at `BillingClient` build time; the plugin does this internally — you get `PurchaseStatus.pending` items on the stream.
- Play docs: **do not acknowledge or grant on PENDING.** "The three-day acknowledgement window begins only when the purchase state transitions from 'PENDING' to 'PURCHASED'." Transition arrives via `queryPurchasesAsync` on next connect (i.e. next `restorePurchases()`/app launch), not necessarily as a live stream event.
- Test with license-tester instruments "Slow test card, approves after a few minutes" and "Slow test card, declines after a few minutes"; verify no grant on decline after a restart.

## Play Console setup
- Product IDs (https://support.google.com/googleplay/android-developer/answer/1153481): "must start with a number or lowercase letter"; may contain numbers `0-9`, lowercase letters `a-z`, underscores `_`, periods `.`. Must be unique for the app. "You can't change or reuse a product ID after the product has been created" — this includes after deletion. `android.test` and any ID prefixed `android.test` are reserved.
  - Pick a scheme you can live with forever, e.g. `coins_500`, `coins_1200`, `coins_3000`. UNVERIFIED: max ID length.
- Managed products (one-time) vs subscriptions are separate Console sections; coin packs are **managed products**, consumable in code. Prices are per-country, entered in local currency or via a pricing template.
- Products only resolve in `queryProductDetails` once the product is **Active** and a build containing the matching `applicationId` + signing has been uploaded to a track; otherwise the IDs land in `notFoundIDs`.
- Testing:
  - License testers (Play Console → Setup → License testing) get test payment instruments and, per Play docs, "bypass this check" that "ordinarily block[s]" billing "for apps that aren't signed and uploaded to Google Play" — so a sideloaded debug build with the right `applicationId` can transact.
  - Test-track releases work too but need publish + a few hours propagation; non-license-testers on a test track are charged for real.
  - **License-tester purchases auto-refund after 3 minutes if unacknowledged** (not 3 days) — your ack path breaks loudly in testing, which is the good case.
  - Draft/internal-track apps have spend limits; move to closed/open/production for higher limits.
  - Play Billing Lab app (`com.google.android.apps.play.billingtestcompanion`) for country/offer/state testing.

## Verification
- Android `PurchaseVerificationData` values (`google_play_purchase_details.dart`):
  - `localVerificationData` = `purchase.originalJson`
  - `serverVerificationData` = `purchase.purchaseToken`
  - `source` = `'google_play'` (constant `kIAPSource`)
- Local/serverless verification is spoofable: on a rooted device or with a patched APK, both the billing responses and any client-side signature check are attacker-controlled — the check runs inside the process being attacked. Billing 3+ removed the public signature-verification key path anyway; `originalJson` alone proves nothing.
- Real answer: send `purchaseToken` + `productId` + your `applicationUserName` hash to your backend and call
  `GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}`
  (scope `https://www.googleapis.com/auth/androidpublisher`, service account with Play Console access). Check `purchaseState` (0 = purchased, 1 = canceled), `consumptionState` (0 = unconsumed, 1 = consumed), `acknowledgementState` (0/1), and `obfuscatedExternalAccountId` matches the user. Then acknowledge/consume server-side and credit coins on the server.
- Risk profile for a small game with no accounts and no server: client-side-only granting means a determined user can mint coins locally. If coins are purely single-player and never traded or leaderboarded, the loss is bounded to revenue from users who would not have paid anyway. It becomes unacceptable the moment coins buy anything competitive or transferable. Middle ground: verify server-side but keep the server stateless (verify → return signed grant), no full account system.
- Real Play Voided Purchases / refund handling also needs a server (`purchases.voidedpurchases`). UNVERIFIED here — not fetched.

## Manifest / gradle / R8
- The plugin's own `android/src/main/AndroidManifest.xml` is empty (no `<uses-permission>`). The **Play Billing Library AAR declares `com.android.vending.BILLING` itself** and manifest-merger pulls it into your APK, so you do **not** add it to `android/app/src/main/AndroidManifest.xml`. (Sourced from the plugin manifest + community reports of the AAR manifest; not restated in the current Play integrate doc — treat the "AAR declares it" mechanism as UNVERIFIED against a first-party page, but the observed net effect is that no app-side declaration is needed.)
- Plugin `android/build.gradle.kts`: `minSdk = 21`, `compileSdk = flutter.compileSdkVersion`, `namespace = "io.flutter.plugins.inapppurchase"`, `implementation("com.android.billingclient:billing:8.0.0")`. Set your app `minSdk` to at least 24 to match the plugin's declared support.
- Plugin README, verbatim: "It is not necessary to depend on `com.android.billingclient:billing` in your own app's `android/app/build.gradle` file. If you choose to do so know that conflicts might occur."
- No ProGuard/R8 rules file ships with `in_app_purchase_android` (no `proguard-rules.pro` in its `android/`); the billing AAR ships its own consumer rules. No app-side keep rules are documented as required.
- Billing needs a real device/emulator with Play Store; `isAvailable()` returns `false` on an emulator image without Google APIs.

## Gotchas
- **autoConsume is process-local.** `_productIdsToConsume` is an in-memory Set. Kill the app between `buyConsumable` and the purchase update (or let the purchase land as PENDING and resolve later) and the plugin will not auto-consume on the next launch — the item comes back as `purchased`/`restored`, `pendingCompletePurchase` acknowledges it, and it is then acked-but-unconsumed: **unrepurchasable forever** until you call `consumePurchase` explicitly. Always call `consumePurchase` yourself for any `purchased`/`restored` consumable you see at startup, or run with `autoConsume: false` and own the whole path.
- **Cancel emits a synthetic empty PurchaseDetails.** On `BillingResponse.userCanceled` with an empty purchase list the Android platform constructs `PurchaseDetails(purchaseID: '', productID: '', status: canceled, ...)` with empty verification data. Any handler that does `_products[purchaseDetails.productID]!` or logs `purchaseID` non-null crashes/misreports on every user cancel.
- **Aug 31, 2026 is a hard upload gate.** Billing Library 8+ required for new apps *and updates* (extension to Nov 1, 2026). That means `in_app_purchase_android >= 0.5.0`, which drags the Flutter floor to 3.44/Dart 3.12 via 0.5.1+. Pin and upgrade the toolchain before the deadline, not at submission time. (https://developer.android.com/google/play/billing/compatibility)
- Missing `completePurchase` refunds the purchase after 3 days on Android (3 *minutes* for license testers) and silently revokes entitlement — always run the `if (purchaseDetails.pendingCompletePurchase)` branch on *every* status including `error` and `canceled`.
- `restorePurchases()` cannot restore consumed coin packs. If the design promises "restore purchases", it can only mean unconsumed/pending items unless balances live on your server.
- Product IDs are permanent and unreusable after deletion — a bad naming scheme is unfixable without new SKUs.
