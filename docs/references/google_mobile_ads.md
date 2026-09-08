<!-- Retrieved 2026-09-08 | google_mobile_ads 9.1.0 -->

## Sources
- https://pub.dev/packages/google_mobile_ads
- https://pub.dev/api/packages/google_mobile_ads (pubspec metadata)
- https://pub.dev/api/archives/google_mobile_ads-9.1.0.tar.gz (signatures below read from this source tarball; authoritative)
- https://pub.dev/packages/google_mobile_ads/changelog
- https://pub.dev/documentation/google_mobile_ads/latest/
- https://developers.google.com/admob/flutter/quick-start
- https://developers.google.com/admob/flutter/rewarded
- https://developers.google.com/admob/flutter/banner
- https://developers.google.com/admob/flutter/app-open
- https://developers.google.com/admob/flutter/privacy
- https://developers.google.com/admob/android/test-ads
- https://developers.google.com/admob/android/quick-start
- https://support.google.com/admob/answer/6201362 (disallowed interstitial implementations)
- https://support.google.com/googleplay/android-developer/answer/9893335 (Families policy)
- https://support.google.com/googleplay/android-developer/answer/6048248 (advertising ID)
- https://developer.android.com/about/versions/13/behavior-changes-13

## Version + constraints

- Latest `9.1.0`, published `2026-08-11T21:00:29Z`. `sdk: ">=3.10.0 <4.0.0"`, `flutter: ">=3.38.1"`.
- Transitive: `webview_flutter ^4.10.0`, `webview_flutter_android ^4.10.9`, `webview_flutter_wkwebview ^3.23.4`, `meta ^1.16.0`.
- Plugin `android/build.gradle` pins: `play-services-ads:25.4.0`, `user-messaging-platform:4.0.0`, `constraintlayout:2.2.1`, `lifecycle-process:2.10.0`; `compileSdk 36`, `minSdk 24`, `agp_version = '8.13.1'`.
- `--dart-define=USE_NEXT_GEN_SDK=true` swaps to `ads-mobile-sdk:1.3.1`. Do not use for a first game.

```yaml
dependencies:
  google_mobile_ads: ^9.1.0
```

## 9.x vs 8.x

- 9.1.0: preloading APIs (`RewardedAdPreloader` etc.), `AdManagerBannerAd` recycling, `ConsentRequestParameters.consentSyncId`, `RequestConfiguration.ageRestrictedTreatment`, null-safe returns, GMA Android 25.4.0 / iOS 13.7.0. 9.0.0: GMA Android 25.3.0 / iOS 13.3.0, UMP Android 4.0.0 / iOS 3.1.0.
- 8.0.0 was the breaking release, not 9.x: min Flutter 3.38.1, Dart 3.10.0, Swift Package Manager, `isCollapsible`, UISceneDelegate, **deprecated `getCurrentOrientationAnchoredAdaptiveBannerAdSize()` / `getAnchoredAdaptiveBannerAdSize()`**, removed `orientation` param on AppOpenAd.

## Android project setup

`android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<!-- Sample AdMob app ID: ca-app-pub-3940256099942544~3347511713 -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
```

Omitting it: the app **crashes on startup** with a "Missing application ID" fatal exception thrown by the Ads SDK's ContentProvider initializer. It is not a soft failure and it is not deferred to first ad load. Note the app ID uses `~`, ad unit IDs use `/`.

`android/app/build.gradle`: `compileSdk 36`, `defaultConfig { minSdk 24 }`.

Google's Android quick-start says minSdk 23 / compileSdk 35 for the raw SDK; the plugin module is the binding constraint at minSdk 24 / compileSdk 36. Use AGP >= 8.13.x with the matching Gradle wrapper. `UNVERIFIED`: no minimum AGP/Kotlin floor is documented upstream, only the AGP the plugin is built with. The plugin manifest already contributes `android.permission.INTERNET`.

## Initialization

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

WidgetsFlutterBinding.ensureInitialized();
final InitializationStatus status = await MobileAds.instance.initialize();
for (final MapEntry<String, AdapterStatus> e in status.adapterStatuses.entries) {
  debugPrint('${e.key}: ${e.value.state} ${e.value.description} ${e.value.latency}');
}
```

- `Future<InitializationStatus> initialize()` — "finishes after Google Mobile Ads Flutter Plugin initializes, or after 30 seconds", whichever is first.
- `adapterStatuses` is `Map<String, AdapterStatus>` keyed by adapter class name; `AdapterStatus(state, description, latency)` with `AdapterInitializationState` (`notReady`, `ready`), `String description`, `double latency` seconds (`0` if unfinished). With no mediation the map holds only the Google adapter — do not gate UI on every adapter being `ready`.
- Call `initialize()` once per process.

## UMP consent

Exports: `ConsentInformation`, `ConsentForm`, `ConsentRequestParameters`, `ConsentDebugSettings`, `DebugGeography`, `ConsentStatus`, `PrivacyOptionsRequirementStatus`, `FormError`.

```dart
void ConsentInformation.instance.requestConsentInfoUpdate(
  ConsentRequestParameters params,
  OnConsentInfoUpdateSuccessListener successListener,   // void Function()
  OnConsentInfoUpdateFailureListener failureListener,   // void Function(FormError error)
);
Future<bool> isConsentFormAvailable();
Future<ConsentStatus> getConsentStatus();
Future<bool> canRequestAds();
Future<PrivacyOptionsRequirementStatus> getPrivacyOptionsRequirementStatus();
Future<void> reset();   // testing only

// OnConsentFormDismissedListener = void Function(FormError?)
static Future<void> ConsentForm.loadAndShowConsentFormIfRequired(OnConsentFormDismissedListener l);
static Future<void> ConsentForm.showPrivacyOptionsForm(OnConsentFormDismissedListener l);
static void ConsentForm.loadConsentForm(
  OnConsentFormLoadSuccessListener s,    // void Function(ConsentForm)
  OnConsentFormLoadFailureListener f);   // void Function(FormError)
void show(OnConsentFormDismissedListener l);   // on a loaded ConsentForm
Future<void> dispose();

ConsentRequestParameters({bool? tagForUnderAgeOfConsent,
                          ConsentDebugSettings? consentDebugSettings,
                          String? consentSyncId});
ConsentDebugSettings({DebugGeography? debugGeography, List<String>? testIdentifiers});

enum ConsentStatus { notRequired, obtained, required, unknown }
enum PrivacyOptionsRequirementStatus { notRequired, required, unknown }
enum DebugGeography { debugGeographyDisabled, debugGeographyEea,
  @Deprecated('Use DebugGeography.debugGeographyOther') debugGeographyNotEea,
  debugGeographyRegulatedUsState, debugGeographyOther }
```

Working flow (run once per app launch, before requesting ads):

```dart
class AdsBootstrap {
  static bool _started = false;
  static void gatherConsentThenInit() {
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async => ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) async {
        if (e != null) debugPrint('consent form: ${e.errorCode} ${e.message}');
        await _initIfAllowed();
      }),
      (FormError e) async {
        debugPrint('consent update: ${e.errorCode} ${e.message}');
        await _initIfAllowed(); // cached consent may still permit ads
      },
    );
    // Fires in parallel: consent may already be cached from a prior session.
    _initIfAllowed();
  }

  static Future<void> _initIfAllowed() async {
    if (_started) return;
    if (!await ConsentInformation.instance.canRequestAds()) return;
    _started = true;
    await MobileAds.instance.initialize();
  }
}
```

Ordering (documented): request the consent info update on **every** app launch and only request ads once `canRequestAds()` is true; it returns `false` until `requestConsentInfoUpdate()` has been called at least once. Initialize the Mobile Ads SDK once, either after the form flow completes *or* immediately if consent is already cached — hence the guarded dual entry above. `initialize()` before consent is not documented as forbidden; ad *requests* before `canRequestAds()` are.

Privacy options entry point (settings menu; required in some regions) and testing:

```dart
Future<bool> isPrivacyOptionsRequired() async =>
    await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
ConsentForm.showPrivacyOptionsForm((FormError? e) {
  if (e != null) debugPrint('${e.errorCode}: ${e.message}');
});

final params = ConsentRequestParameters(consentDebugSettings: ConsentDebugSettings(
  debugGeography: DebugGeography.debugGeographyEea,
  testIdentifiers: ['TEST-DEVICE-HASHED-ID'],
));
await ConsentInformation.instance.reset(); // clears consent state; testing only
```

The hashed device ID is printed in logcat by UMP on first debug run. `reset()` must not ship.

## Test ad unit IDs (Android, verbatim)

```dart
const appOpen              = 'ca-app-pub-3940256099942544/9257395921';
const anchoredAdaptive     = 'ca-app-pub-3940256099942544/9214589741'; // same ID for inline adaptive
const fixedBanner          = 'ca-app-pub-3940256099942544/6300978111';
const interstitial         = 'ca-app-pub-3940256099942544/1033173712';
const rewarded             = 'ca-app-pub-3940256099942544/5224354917';
const rewardedInterstitial = 'ca-app-pub-3940256099942544/5354046379';
const nativeAdvanced       = 'ca-app-pub-3940256099942544/2247696110';
const nativeVideo          = 'ca-app-pub-3940256099942544/1044960115';
const sampleAppId          = 'ca-app-pub-3940256099942544~3347511713';   // note the '~'
```

## Test devices + request configuration

```dart
MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
  testDeviceIds: <String>['33BE2250B43518CCDA7DE426D04EE231'],
  maxAdContentRating: MaxAdContentRating.g,
  ageRestrictedTreatment: AgeRestrictedTreatment.unspecified,
));

RequestConfiguration({
  String? maxAdContentRating,
  @Deprecated('Use ageRestrictedTreatment instead.') int? tagForChildDirectedTreatment,
  @Deprecated('Use ageRestrictedTreatment instead.') int? tagForUnderAgeOfConsent,
  List<String>? testDeviceIds,
  AgeRestrictedTreatment? ageRestrictedTreatment,
});
Future<RequestConfiguration> MobileAds.instance.getRequestConfiguration();
Future<void> MobileAds.instance.updateRequestConfiguration(RequestConfiguration c);

class MaxAdContentRating {   // String values, not an enum
  static final String unspecified = '', g = 'G', pg = 'PG', t = 'T', ma = 'MA';
}
// both @Deprecated('Use AgeRestrictedTreatment instead.'), int values:
class TagForChildDirectedTreatment { static final int yes = 1, no = 0, unspecified = -1; }
class TagForUnderAgeOfConsent      { static final int yes = 1, no = 0, unspecified = -1; }
enum AgeRestrictedTreatment { unspecified, child, teen }   // preferred in 9.1.0
```

The test device ID is printed in logcat on the first ad request ("Use RequestConfiguration.Builder.setTestDeviceIds(...)"). Real ad units + registered test device is the only safe way to exercise production units.

```dart
const AdRequest({List<String>? keywords, String? contentUrl,
  List<String>? neighboringContentUrls, bool? nonPersonalizedAds,
  int? httpTimeoutMillis, Map<String, String>? extras,
  List<MediationExtras>? mediationExtras,
  @Deprecated('Use mediationExtras instead.') String? mediationExtrasIdentifier});
```

`nonPersonalizedAds` is not a substitute for UMP; UMP drives it via the consent string.

## RewardedAd

```dart
static Future<void> RewardedAd.load({required String adUnitId, required AdRequest request,
                                     required RewardedAdLoadCallback rewardedAdLoadCallback});
Future<void> show({required OnUserEarnedRewardCallback onUserEarnedReward});
Future<void> setServerSideOptions(ServerSideVerificationOptions options); // {userId, customData}
FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;

typedef OnUserEarnedRewardCallback = void Function(AdWithoutView ad, RewardItem reward);
class RewardItem { RewardItem(this.amount, this.type); final num amount; final String type; }
class RewardedAdLoadCallback extends FullScreenAdLoadCallback<RewardedAd> {
  const FullScreenAdLoadCallback({
    required GenericAdEventCallback<T> onAdLoaded,           // void Function(T ad)
    required FullScreenAdLoadErrorCallback onAdFailedToLoad, // void Function(LoadAdError)
  });   // subclasses: InterstitialAdLoadCallback, AppOpenAdLoadCallback,
}       // RewardedInterstitialAdLoadCallback, AdManagerInterstitialAdLoadCallback
class FullScreenContentCallback<T extends Ad> {   // GenericAdEventCallback<T> = void Function(T)
  const FullScreenContentCallback({
    GenericAdEventCallback<T>? onAdShowedFullScreenContent, onAdImpression,
    onAdWillDismissFullScreenContent /* iOS only */, onAdDismissedFullScreenContent, onAdClicked,
    void Function(T ad, AdError error)? onAdFailedToShowFullScreenContent,
  });
}
```

Dispose + preload-next pattern (the shape to copy for a game):

```dart
class RewardedAdManager {
  static const _adUnitId = 'ca-app-pub-3940256099942544/5224354917';
  RewardedAd? _ad;
  bool _loading = false;
  int _retry = 0;
  bool get isReady => _ad != null;

  void load() {
    if (_ad != null || _loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) { _loading = false; _retry = 0; _ad = ad; },
        onAdFailedToLoad: (LoadAdError error) {
          _loading = false;
          _ad = null;
          _retry++;
          Future.delayed(Duration(seconds: 1 << _retry.clamp(0, 6)), load);
        },
      ),
    );
  }

  void show({required void Function(RewardItem) onReward,
             required VoidCallback onUnavailable}) {
    final ad = _ad;
    if (ad == null) { onUnavailable(); return; }
    _ad = null;   // an ad object may only be shown once
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (_) => pauseGameAndAudio(),
      onAdImpression: (_) {}, onAdClicked: (_) {},
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose(); resumeGameAndAudio(); load();  // preload next immediately
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose(); resumeGameAndAudio(); load(); onUnavailable();
      },
    );
    ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) => onReward(reward));
  }
}
```

"A RewardedAd can only be shown once. Subsequent calls to show will trigger `onAdFailedToShowFullScreenContent`." Grant the reward from `onUserEarnedReward` (fires *before* dismissal), never from `onAdDismissedFullScreenContent`, which also fires when the user skipped early.

## InterstitialAd

```dart
static Future<void> InterstitialAd.load({required String adUnitId, required AdRequest request,
  required InterstitialAdLoadCallback adLoadCallback});  // adLoadCallback, NOT rewardedAdLoadCallback
Future<void> show();
FullScreenContentCallback<InterstitialAd>? fullScreenContentCallback;
```

Same dispose-then-reload discipline; same one-show-per-object rule. Set `fullScreenContentCallback` before `show()`.

## AppOpenAd

```dart
static Future<void> AppOpenAd.load({required String adUnitId, required AdRequest request,
                                    required AppOpenAdLoadCallback adLoadCallback});
Future<void> show();
FullScreenContentCallback<AppOpenAd>? fullScreenContentCallback;
```

Expiry: "Ad references in the app open beta will time out after four hours." Track load time; reload past that.

```dart
DateTime? _loadTime;
static const Duration maxCacheDuration = Duration(hours: 4);
bool get _isExpired =>
    _loadTime == null || DateTime.now().difference(_loadTime!) > maxCacheDuration;


AppStateEventNotifier.startListening();   // and stopListening() on teardown
AppStateEventNotifier.appStateStream.listen((AppState state) {  // AppState.{foreground,background}
  if (state == AppState.foreground) appOpenAdManager.showIfAvailable();
});
```

Cold start: the ad usually will not be loaded in time for the first frame. Documented guidance: show a loading screen during startup and show the ad *from that loading screen only*, never after the user reaches the game; load assets off the main thread so the ad can display without blocking. Do not show an app open ad over live gameplay, and defer the first one until the user has opened the app several times. The `orientation` parameter was removed in 8.0.0 — do not pass it.

## Adaptive banners

Current (8.0.0+) API:

```dart
static Future<AnchoredAdaptiveBannerAdSize?> AdSize.getLargeAnchoredAdaptiveBannerAdSize(int width);
static Future<AnchoredAdaptiveBannerAdSize?>
    AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(Orientation o, int width);
static InlineAdaptiveSize AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(int width);
static InlineAdaptiveSize AdSize.getPortraitInlineAdaptiveBannerAdSize(int width);
static InlineAdaptiveSize AdSize.getLandscapeInlineAdaptiveBannerAdSize(int width);
static InlineAdaptiveSize AdSize.getInlineAdaptiveBannerAdSize(int width, int maxHeight);
```

Deprecated in 8.0.0 (still present in 9.1.0, warns): `getAnchoredAdaptiveBannerAdSize(Orientation, int)` → `getLargeAnchoredAdaptiveBannerAdSizeWithOrientation`; `getCurrentOrientationAnchoredAdaptiveBannerAdSize(int)` → `getLargeAnchoredAdaptiveBannerAdSize`. Also deprecated: `AdSize.smartBanner*`, `SmartBannerAdSize`.

Fixed sizes: `AdSize.banner` 320x50, `largeBanner` 320x100, `mediumRectangle` 300x250, `fullBanner` 468x60, `leaderboard` 728x90, `fluid`.

```dart
Future<void> _loadBanner(BuildContext context) async {
  final int width = MediaQuery.of(context).size.width.truncate();
  final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
  if (size == null) return;   // no valid height for this device/window
  final banner = BannerAd(
    adUnitId: 'ca-app-pub-3940256099942544/9214589741',
    size: size, request: const AdRequest(),
    listener: BannerAdListener(   // also onAdOpened/onAdClosed/onAdImpression/onAdClicked/onPaidEvent
      onAdLoaded: (Ad ad) => setState(() => _banner = ad as BannerAd),
      onAdFailedToLoad: (Ad ad, LoadAdError error) => ad.dispose(),
    ),
  );
  await banner.load();
}

// Render only after onAdLoaded, inside explicit constraints:
SizedBox(
  width: _banner!.size.width.toDouble(),
  height: _banner!.size.height.toDouble(),
  child: AdWidget(ad: _banner!),
)
```

Anchored adaptive height is never >15% of current-orientation screen height, never <50px, and is stable per width/device. Inline adaptive returns height 0 until loaded — read the real size with `BannerAd.getPlatformAdSize()` afterwards and resize the container. Dispose after the `AdWidget` leaves the tree or in `onAdFailedToLoad`. On rotation, dispose and re-request at the new width. On iOS the widget must have specified width and height or the ad may not display.

## Preloading APIs (9.1.0)

```dart
class PreloadConfiguration { final String adUnitId; final AdRequest request; final int bufferSize; }
class PreloadCallback {   // onAdPreloaded(preloadId, ResponseInfo), onAdsExhausted(preloadId),
}                         // onAdFailedToPreload(preloadId, AdError)
abstract class RewardedAdPreloader {  // same shape: InterstitialAdPreloader, AppOpenAdPreloader
  static Future<void> start({required String preloadId,
      required PreloadConfiguration preloadConfiguration, required PreloadCallback callback});
  static Future<RewardedAd?> pollAd(String preloadId);   // removes + returns, or null
  static Future<bool> isAdAvailable(String preloadId);
  static Future<int> getNumAdsAvailable(String preloadId);
  static Future<void> destroy(String preloadId);   static Future<void> destroyAll();
  static Future<PreloadConfiguration?> getConfiguration(String preloadId);
  static Future<Map<String, PreloadConfiguration>> getConfigurations();
}
```

Polled ads still show once and still need `dispose()`.

## Game lifecycle best practice

- Consent flow at launch, `initialize()` once behind `canRequestAds()`, then warm one rewarded and one interstitial.
- Reload in `onAdDismissedFullScreenContent`, and after failure with exponential backoff — never a tight retry loop; no-fill spam gets an app throttled.
- Pause clock/physics/audio in `onAdShowedFullScreenContent`; resume in **both** `onAdDismissedFullScreenContent` and `onAdFailedToShowFullScreenContent`, or a show-failure freezes the game.
- Never `await` an ad load on a level-transition critical path; gate the watch-ad button on `isReady`.
- Dispose each ad exactly once; its callbacks must not `setState` after the widget is gone.

## Gotchas

1. **Missing `com.google.android.gms.ads.APPLICATION_ID` crashes at process start**, before any Dart runs. App ID uses `~`; ad unit IDs use `/`. Pasting an ad unit ID into the manifest also crashes.
2. **An ad object can be shown once.** Reusing it triggers `onAdFailedToShowFullScreenContent`, not an exception. Null out your cached reference at `show()` time, not at dismissal.
3. **`canRequestAds()` returns `false` until `requestConsentInfoUpdate()` has been called at least once**, even where consent is not required. Gating ad loads on it without ever calling the update means zero ads forever.
4. `getCurrentOrientationAnchoredAdaptiveBannerAdSize` / `getAnchoredAdaptiveBannerAdSize` are deprecated as of 8.0.0; most tutorials and training data still use them. Use `getLargeAnchoredAdaptiveBannerAdSize`.
5. `RequestConfiguration.tagForChildDirectedTreatment` / `tagForUnderAgeOfConsent` are deprecated in favour of `AgeRestrictedTreatment` and are `int?` (`1`/`0`/`-1`), not `bool`. `ConsentRequestParameters.tagForUnderAgeOfConsent` *is* `bool?` — same name, different type.
6. `MaxAdContentRating` members are `static final String`, not an enum; `unspecified` is `''`.
7. `AdWidget` must sit inside explicit width/height constraints and only be built after `onAdLoaded`. Inline adaptive reports height 0 until loaded.
8. Shipping `ConsentInformation.instance.reset()` wipes consent every launch — form spam and policy trouble.
9. `initialize()` resolves after 30s even if the SDK never came up; do not treat the await returning as "ads are ready".
10. `AppOpenAd` references expire after 4 hours; a stale ad shows nothing and burns the slot.
11. The Flutter 3.38.1 / Dart 3.10.0 floor comes from 8.0.0 — an older Flutter pin silently resolves to google_mobile_ads 7.x with a different API surface.

## Policy

**Rewarded ads.** Rewarded must always be an opt-in experience. You must present an explicit choice to view the ad in exchange for a stated reward before the ad loads/shows; the publisher owns that opt-in screen and owns delivering the reward. State what the reward is ("Watch a video for 1 extra life"), never auto-play a rewarded ad, never make it the only way to continue in a way that reads as forced. Rewarded interstitial is different: it needs an intro screen announcing the reward with a chance to opt out, but no opt-in.

**Interstitials.** "Do not place interstitial ads on app load and when exiting apps as interstitials should only be placed in between pages" — use an app open ad for launch instead. No more than one interstitial per two user actions. Only at natural breaks (level end, stage transition). Pre-load so carrier latency doesn't fire an ad at an unexpected moment. Ads must not interfere with navigating or interacting with core content.

**Accidental clicks.** No ads adjacent to or overlapping buttons, none where a tap is expected, none that shift layout under the user's finger, no encouraging clicks. Keep a clear gap between game controls and any banner.

**App open ads.** Only on launch/foreground transitions, from a loading screen, never over live gameplay, never as a second full-screen ad stacked with an interstitial. Defer the first one until the user has some positive history with the app.

**Families / kids.** If the app targets children under 13 (or the Play Families programme): only Google Play Families Self-Certified Ads SDKs; no interest-based advertising or remarketing; **no interstitial monetization or advertising displayed immediately upon app launch**; ads interfering with gameplay must be closeable within 5 seconds; no multiple ad placements on one page; no full-screen ads without a clear dismissal; ads clearly distinguishable from app content. Set `ageRestrictedTreatment: AgeRestrictedTreatment.child` and `maxAdContentRating: MaxAdContentRating.g`.

**Data safety / advertising ID.** Declare in the Play Console Data safety form that the app collects and shares an Advertising ID (and device identifiers) for advertising, and check the "Advertising ID" box in the app content declaration. Apps targeting Android 13+ that use the advertising ID must declare:

```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
```

play-services-ads 20.4.0+ (this plugin pins 25.4.0) declares this in its library manifest, so it is merged into your app automatically and you do **not** need to add it by hand. Do not add `tools:node="remove"` for it unless you intend to serve non-personalized ads only — without the permission the ad ID is replaced with a string of zeroes. Verify it in the merged manifest before release, and make sure the Play Console declaration matches what actually ships.

**Test ads.** Always use the demo ad unit IDs or a registered test device during development. Requesting live ads on your own device against your own units is invalid traffic and can get the AdMob account suspended. Swap demo IDs for real ones before release.
