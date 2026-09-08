# Contract: monetisation (`services/ads.dart`, `ad_ids.dart`, `purchases.dart`, `app_shop.dart`, `ui/screens/{shop,settings}_screen.dart`, `config.dart`)

As built in phase 4. The controller already owns the policy (design 8.2), the
rewarded flows and the `PurchaseSink`/`AdSink` transitions; the services in this
file only run the SDKs and never touch the profile.

## 1. Ad ids (`services/ad_ids.dart`)

| build | rewarded | interstitial | app id (manifest) |
| --- | --- | --- | --- |
| debug | `…/5224354917` (Google test) | `…/1033173712` (Google test) | `…~3347511713` (Google sample) |
| release | `releaseRewardedUnitId` | `releaseInterstitialUnitId` | `releaseAppId` |

One rewarded unit serves all four placements of design 8.1; `showRewarded`
takes the placement only for the analytics dimension the controller emits.

`adIdsConfigured` is `kDebugMode || none of the three release ids is
'REPLACE_ME'`. When it is false `AdMobAdsService.start` returns before the
consent flow, nothing is ever loaded, `isRewardedReady`/`isInterstitialReady`
stay false and every `show` is a no-op — a store build shipped with
placeholders is ad-free rather than crashed or serving test ads to players.

## 2. Consent and initialisation (design 8.4)

`start(sink)` never throws; every failure logs and leaves the service in the
"no ads" state. The flow, once per launch, inside `MobileAdsPlatform.prepare`:

1. `ConsentInformation.instance.requestConsentInfoUpdate` (30 s timeout on the
   listener). This must run before anything else: `canRequestAds()` returns
   false until it has run at least once, even where consent is not required.
2. `ConsentForm.loadAndShowConsentFormIfRequired`, awaited on its dismissal
   listener (5 min timeout).
3. If `canRequestAds()` is false, stop. No `MobileAds.initialize`, no loads.
4. `MobileAds.instance.initialize()`, then
   `RequestConfiguration(maxAdContentRating: MaxAdContentRating.t)`. Not tagged
   child-directed: the target audience is 18+.
5. Preload one rewarded and one interstitial.

`privacyOptionsRequired` is a cached bool read once after the flow
(`getPrivacyOptionsRequirementStatus() == required`) because the `AdsService`
getter is synchronous; `showPrivacyOptions()` shows
`ConsentForm.showPrivacyOptionsForm` and re-reads it afterwards.

**Debug-only geography override.** `--dart-define=SETTLE_FORCE_EEA=true` passes
`ConsentDebugSettings(debugGeography: debugGeographyEea)`, optionally with
`--dart-define=SETTLE_CONSENT_TEST_DEVICE=<hash from logcat>`. Off by default
and inert outside `kDebugMode`. `ConsentInformation.reset()` is never called.

## 3. Ad lifecycle

`AdPlatform` is the seam (`prepare`, `load`, `privacyOptionsRequired`,
`showPrivacyOptions`); `LoadedAd.show(AdCallbacks)` carries `onShown`,
`onClosed`, `onFailedToShow` and `onEarnedReward`. Unit tests drive the whole
state machine through a fake platform, so no test touches a platform channel.

- One ad of each kind is cached. `_keepLoaded` refuses to start a second load
  for a kind already loaded or loading.
- A load failure retries for ever with `backoffFor(attempt)` = 1, 2, 4, 8, 16,
  32, 60, 60 … seconds (`AdMobAdsService.minBackoff`/`maxBackoff`).
- The cached reference is cleared at **show** time, not at dismissal: an ad
  object may only be shown once, and a second `show` would silently become
  `onAdFailedToShowFullScreenContent`.
- After a show (successful or failed) the ad is disposed and the next one is
  loaded immediately.
- `showRewarded` resolves `true` only from `onUserEarnedReward`. Dismissal never
  grants. With no ad loaded it resolves `false` without a sink transition.
- Sink transitions come from the full-screen callbacks:
  `onAdShowedFullScreenContent` → `onRewardedShown`/`onInterstitialShown`,
  `onAdDismissedFullScreenContent` → `onRewardedClosed`/`onInterstitialClosed`.
  A **failed show raises neither**, so design 8.2's counters and timestamps
  never move for an ad that did not run.
- The service decides nothing about *when* to show. `AppController.playAgain`
  runs `InterstitialPolicy.shouldShow`; no ad is requested on launch or
  mid-game, and there are no app-open or banner ads.

## 4. Purchases (design 8.3)

`BillingGateway` wraps `in_app_purchase` (`purchaseStream`, `isAvailable`,
`queryProducts`, `buyConsumable`, `buyNonConsumable`, `consume`, `complete`,
`restore`); `PlayBillingGateway` is the real one and a scripted gateway drives
the stream handler in tests.

`start(sink)` subscribes to `purchaseStream` **once, for the process** (the
subscription is never cancelled) and then calls `restore()`. Purchases that
resolve while no screen is open, or in a previous session, still land.

`products()` queries the five ids of `Products.all` and returns them in
catalogue order with the store's localised `price`. It returns an empty list —
never throws — when the store is unavailable, when the query errors or when
every id is unfetched; each reason is logged, and unfetched ids are logged by
name. The shop renders `S.shopUnavailable` for an empty list.

`buy(id)` uses `buyConsumable(autoConsume: false)` for the three coin packs and
`buyNonConsumable` for `remove_ads` and `theme_pack_all`. `autoConsume` is
process-local in the plugin, so owning the consume explicitly is the only way
the coins are durably written before the item becomes repurchasable.

Stream handling, per update:

| status | what happens |
| --- | --- |
| `pending` | `sink.purchasePending(productID)`; nothing else, never a grant |
| empty `productID` | the user-cancel artefact: `completePurchase` if pending, then ignored |
| `purchased` / `restored` | deliver (below) |
| `error` / `canceled` | logged, `sink.purchaseFailed(productID)`, `completePurchase` if pending |

Deliver:

1. Key on `verificationData.serverVerificationData` (the Play purchase token),
   never `purchaseID` — Android derives that from a nullable order id. An empty
   token is logged, grants nothing, and is still completed.
2. `await sink.applyPurchase(productId, token)`. `Purchases.grant` is idempotent
   per token, so a crash-replay of an already-granted purchase grants nothing.
3. Consumables: `InAppPurchaseAndroidPlatformAddition.consumePurchase`.
   Non-consumables: `completePurchase` (on Android this only acknowledges).
4. Design 8.3 step 4 is applied literally: after a consumable is consumed,
   `completePurchase` still runs while `pendingCompletePurchase` is true. It is
   a no-op on an already-acknowledged purchase and a logged, harmless failure on
   a consumed one; it guarantees no path leaves an unacknowledged purchase to be
   refunded by Play after three days.
5. Only when step 3 succeeded: `await sink.purchaseCompleted(token)`, which
   moves the token from `pendingPurchaseTokens` to `completedPurchaseTokens`. A
   purchase whose consume keeps failing therefore stays granted and stays
   deduplicated for ever.
6. `purchase_completed {product}` is emitted here for `purchased` only, not for
   `restored`.

There is no server-side receipt validation in v1 (design 8.3); the risk is
accepted. `restore()` cannot bring back consumed coin packs — Play stops
returning them — so "Restore purchases" only recovers `remove_ads` and
`theme_pack_all` plus any unconsumed pack.

## 5. Shop flows (`app_shop.dart`)

`extension ShopFlows on AppController` holds `loadProducts`, `buyProduct`,
`restorePurchases`, `privacyOptionsRequired`, `showPrivacyOptions` and (until
integration removes the duplicate) `setRemindersEnabled`. An extension cannot
carry fields, so the view state is a separate `ShopState extends ChangeNotifier`
held in an `Expando` keyed by controller: `products`, `loading`, `loaded`,
`pending` and one transient `message`. The shop screen listens to
`Listenable.merge([controller, controller.shop])`.

`buyProduct` marks the id pending, calls the service, awaits `controller.idle`
and clears it. **Known gap:** the controller's `purchasePending` sink method is
an empty body in `app.dart` (phase 2b), so Play's slow-card `pending` state
cannot reach the shop yet. `ShopState.markPending`/`clearPending` are public for
exactly that one-line follow-up when `app.dart` is next opened.

## 6. Wiring (`services/wiring_monetisation.dart`)

Release, profile and debug builds all get `AdMobAdsService` (debug uses the test
unit ids) and `PlayPurchaseService`. `--dart-define=SETTLE_FAKE_SERVICES=true`
selects `FakeAdsService`/`FakePurchaseService`, and only in `kDebugMode`, for
emulator drives. `FakePurchaseService.catalogueIsEmpty` reproduces the store
outage on the emulator.

## 7. What the owner must fill in before a store build

1. `app/lib/services/ad_ids.dart`: `releaseAppId`, `releaseRewardedUnitId`,
   `releaseInterstitialUnitId` from AdMob. Until then a release build ships
   with ads disabled by design.
2. `app/android/app/src/main/AndroidManifest.xml`:
   `com.google.android.gms.ads.APPLICATION_ID` currently holds Google's sample
   id. It must match `releaseAppId` — a missing or malformed value crashes the
   process at start, before any Dart runs, and an ad **unit** id pasted there
   crashes it too (app ids use `~`, unit ids use `/`).
3. `app/lib/config.dart`: `kPrivacyPolicyUrl`, currently
   `https://REPLACE_ME/settle/privacy`.
4. Play Console: the five product ids of design 8.3 as **managed products**,
   Active, with a build of the same `applicationId` uploaded to a track.
   Product ids can never be changed or reused.
5. `--dart-define=SETTLE_ANALYTICS_URL=… --dart-define=SETTLE_ANALYTICS_KEY=…`
   on the release build (see `docs/contracts/analytics.md`); without the URL
   analytics is a no-op.
6. Data safety: Advertising ID collected and shared for advertising; ads
   declaration yes; target audience 18+.

## 8. Failure modes

| failure | behaviour |
| --- | --- |
| release ad ids are placeholders | no consent flow, no loads, no ads, no crash |
| consent update or form fails | logged; `canRequestAds` decides; usually no ads this launch |
| `canRequestAds` false | SDK never initialised, nothing loaded |
| ad load fails | retried for ever with capped backoff; the buttons fall back to the coin price or hide (design 8.1) |
| ad fails to show | no reward, no policy transition, ad disposed, next one loaded |
| store unavailable / ids unfetched | empty product list, `S.shopUnavailable`, Restore still offered |
| buy on an unfetched product | `sink.purchaseFailed`, `S.shopPurchaseFailed` |
| grant succeeds, consume fails | token stays in `pendingPurchaseTokens`; the next launch's restore replays it, skips the grant and retries the consume |
| crash between grant and consume | same replay path; step 2 skips, step 3 finishes |
| user cancels | synthetic empty-`productID` update; completed if pending, otherwise ignored |
| analytics endpoint down | events dropped, nothing blocks or throws |
