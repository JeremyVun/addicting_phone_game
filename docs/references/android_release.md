<!-- Retrieved 2026-09-08 | Flutter 3.47.2 | target API 36 -->

## Sources

- https://docs.flutter.dev/deployment/android (documents Flutter 3.47.2, updated 2026-08-26)
- https://docs.flutter.dev/deployment/obfuscate
- https://docs.flutter.dev/deployment/flavors
- https://docs.flutter.dev/release/breaking-changes/flutter-gradle-plugin-apply
- https://github.com/flutter/flutter/blob/master/examples/hello_world/android/settings.gradle.kts
- https://github.com/flutter/flutter/blob/master/examples/hello_world/android/app/build.gradle.kts
- https://developer.android.com/google/play/requirements/target-sdk
- https://pub.dev/packages/flutter_launcher_icons , /flutter_native_splash , /google_mobile_ads , /in_app_purchase , /flame
- https://developers.google.com/admob/flutter/quick-start , /admob/android/quick-start , /admob/flutter/targeting
- https://support.google.com/googleplay/android-developer/answer/7384423 (Play App Signing)
- https://support.google.com/googleplay/android-developer/answer/10787469 (Data safety)
- https://support.google.com/googleplay/android-developer/answer/9859455 (content ratings)
- https://support.google.com/googleplay/android-developer/answer/9893335 (Families / target audience)
- https://support.google.com/googleplay/android-developer/answer/9857753 (Ads policy)
- https://support.google.com/googleplay/android-developer/answer/9858738 (Payments / Play Billing)
- https://support.google.com/googleplay/android-developer/answer/9877032 (Real-Money Gambling)
- https://support.google.com/googleplay/android-developer/answer/9866151 (store listing assets)
- https://support.google.com/googleplay/android-developer/answer/14151465 (closed testing requirement)
- https://github.com/flutter/flutter/issues/165646 , /issues/139462 (Play Core R8 missing classes), /issues/177141 (minSdk overwrite)

## Gradle template (Kotlin DSL)

Declarative `plugins {}` DSL: supported since Flutter 3.16, recommended since 3.19, emitted by `flutter create`. `.kts` is the default template. The legacy imperative loader (`apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"`) is deprecated — never reintroduce it.

### android/settings.gradle.kts

Verbatim, `flutter/flutter@master examples/hello_world` (its extra `buildscript { dependencyLocking }` block is SDK-repo-specific, omitted here):

```kotlin
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
```

- Settings-level id is `dev.flutter.flutter-plugin-loader`; module-level id is `dev.flutter.flutter-gradle-plugin`. Not interchangeable.
- AGP/Kotlin pins above are what master emits; your local SDK may differ — read the generated file.

### android/app/build.gradle.kts

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.addicting_phone_game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlin {
        jvmToolchain(17)
    }

    defaultConfig {
        applicationId = "com.example.addicting_phone_game"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
```

- Upstream `hello_world` uses `JavaVersion.VERSION_1_8` and no `jvmToolchain` block (it has no Kotlin sources, hence no `kotlin-android`). Exact Java level emitted by current `flutter create` is `UNVERIFIED` — read the generated file.
- `flutter { source = "../.." }` points the plugin at the Dart project root; removing it breaks the build. Prefer the `flutter.*` accessors over hardcoded SDK levels.

### namespace vs applicationId

- `namespace` — Java/Kotlin package for generated `R`/`BuildConfig`. Compile-time only, freely changeable.
- `applicationId` — the app's identity on device and on Play. **Play locks it forever on first upload**: unrenameable, and unreusable on another listing even after unpublishing. `com.example.*` is rejected outright.
- Both default to the same string from `flutter create --org`, which is why they get conflated.
- Flavor `applicationIdSuffix` changes applicationId, not namespace — so the flavor naming scheme is equally permanent. Decide both before the first upload.

### SDK floors

| Source | Requirement |
|---|---|
| Flutter 3.35+ | `flutter.minSdkVersion` = 24 (Android 7); builds fail below 24 |
| Google Mobile Ads Android SDK 25.4.0 | minSdk 23, **compileSdk 35+** |
| google_mobile_ads 9.1.0 (Flutter plugin) | requires Flutter 3.38.1+ |
| in_app_purchase 3.3.0 | Android SDK 24+ |
| flame 1.38.2 | no stated Android floor |

Net: `minSdk = 24`, `compileSdk = flutter.compileSdkVersion` (already >= 35 on Flutter 3.47).

## Play target API level policy

Verbatim, developer.android.com/google/play/requirements/target-sdk:

> "Starting August 31 2026: New apps and app updates must target Android 16 (API level 36) or higher to be submitted to Google Play; except for Wear OS and Android Automotive OS apps, which must target Android 15 (API level 35) or higher, and Android TV and Android XR apps, which must target Android 14 (API level 34) or higher."

> "Existing apps must target Android 15 (API level 35) or higher to remain available to new users on devices running Android OS higher than your app's target API level."

> "If you need more time to update your app, you'll be able to request an extension to November 1, 2026."

Deadline **2026-08-31**; extension window closes **2026-11-01**. Both are already past as of 2026-09-08 — a new game must ship `targetSdk = 36`. `flutter.targetSdkVersion` on 3.47 satisfies this; confirm against the merged manifest rather than assuming.

## Signing

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
        -storetype JKS -keysize 2048 -validity 10000 -alias upload
```

`android/key.properties` (`storeFile` is absolute, or relative to `android/`; on Windows use `/` or `\\`):

```properties
storePassword=<password-from-previous-step>
keyPassword=<password-from-previous-step>
keyAlias=upload
storeFile=<keystore-file-location>
```

Load it in `android/app/build.gradle.kts` — the imports must sit above `plugins {}`:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

`android/.gitignore` — docs only say "Keep the `key.properties` file private; don't check it into public source control", the keystore globs are the standard addition:

```
key.properties
**/*.keystore
**/*.jks
```

## Play App Signing

> "Android uses two signing keys: _upload_ and _app signing_. Developers upload an `.aab` or `.apk` file signed with an _upload key_ to the Play Store. The end-users download the `.apk` file signed with an _app signing key_." — docs.flutter.dev

> "Because Google signs the final APK, you must register the Google-held app signing key fingerprint with your API providers, not just your local upload key." — Play Console Help

- Upload key: yours, RSA 2048+, replaceable via support if lost. App signing key: Google's, RSA 4096, permanent.
- Fingerprints: Play Console > Protected with Play > Play Store distribution > Play app signing > App signing key; copy SHA-1/SHA-256.
- Anything authenticating by certificate fingerprint — Google Sign-In, Play Games Services, Firebase Auth, Maps — fails for Play users if only the upload key is registered (`ApiException: 10`, `DEVELOPER_ERROR`). Register **both** fingerprints.

## R8 / keep rules

R8 shrinking is on by default for Flutter release builds (`--no-shrink` disables it). Explicit form:

```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
        signingConfig = signingConfigs.getByName("release")
    }
}
```

`android/app/proguard-rules.pro`:

```proguard
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core: referenced by Flutter's deferred-components embedding even when unused
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }

# Google Mobile Ads / AdMob
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keepclassmembers class * extends com.google.android.gms.ads.mediation.** { *; }

# Play Billing / in_app_purchase
-keep class com.android.billingclient.api.** { *; }
-keep class com.android.vending.billing.** { *; }
-dontwarn com.android.billingclient.**
```

- Play Services Ads and Play Billing ship consumer ProGuard rules inside their AARs; the ads/billing keeps above are defensive. `UNVERIFIED` that they are strictly required at current versions — no first-party doc mandates them.
- The Play Core failures are real and tracked upstream (flutter/flutter#165646, #139462): `Missing class com.google.android.play.core.splitcompat.SplitCompatApplication` and `com.google.android.play.core.tasks.OnFailureListener` referenced from `PlayStoreDeferredComponentManager`, in apps that never use deferred components.
- The authoritative fix list is generated for you at `build/app/outputs/mapping/release/missing_rules.txt` — paste it into `proguard-rules.pro`.

## Obfuscation and symbols

```bash
flutter build appbundle --obfuscate --split-debug-info=build/symbols/
flutter symbolize -i <stack-trace-file> -d <obfuscated-symbols-file>
flutter build appbundle --obfuscate --split-debug-info=build/symbols/ \
   --extra-gen-snapshot-options=--save-obfuscation-map=build/symbols/map.json
```

- Emits `app.<platform>-<architecture>.symbols` (e.g. `app.android-arm64.symbols`). Windows x64 emits a PDB, which `flutter symbolize` cannot read — use WinDbg.
- Archive the symbols directory per released build-number, off-machine. Without it a crash report is unreadable forever.
- `runtimeType.toString()` compared against a literal breaks under obfuscation; enum names are currently not obfuscated.
- R8's Java mapping is separate: upload `build/app/outputs/mapping/release/mapping.txt` to Play Console (App bundle explorer > version > Downloads > deobfuscation file) so Android Vitals can read native/Java frames. Dart frames still need `flutter symbolize`.

## Build commands

```bash
flutter build appbundle                      # release AAB, the Play upload artifact
flutter build apk --split-per-abi            # sideload/testing only, not for Play
flutter build appbundle --flavor production
flutter build appbundle --build-name=1.0.1 --build-number=2
```

Outputs: `build/app/outputs/bundle/release/app-release.aab`, and `build/app/outputs/apk/release/app-{armeabi-v7a,arm64-v8a,x86_64}-release.apk`. Play requires an AAB for new apps; `--release` is already the default for `build`. An APK is only for sideloading to testers, and neither IAP nor real ad fill works from one (see Gotchas).

## Versioning and flavors

`pubspec.yaml` `version: 1.0.0+1` — left of `+` is `versionName`, right is `versionCode`; the template wires them through `flutter.versionName` / `flutter.versionCode`. Override per build with `--build-name=` / `--build-number=` (CI: `--build-number=$CI_BUILD_ID`). `versionCode` must strictly increase; Play permanently rejects one it has already seen, including from a deleted draft release.

```kotlin
android {
    flavorDimensions += "default"
    productFlavors {
        create("staging") { dimension = "default"; applicationIdSuffix = ".staging" }
        create("production") { dimension = "default"; applicationIdSuffix = ".production" }
    }
}
```

`flutter build appbundle --flavor staging`. A `production` flavor with `.production` suffix locks `com.you.game.production` on Play, not `com.you.game`.

## Icons — flutter_launcher_icons 0.14.4

```yaml
dev_dependencies:
  flutter_launcher_icons: "^0.14.4"

flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icon/icon.png"
  min_sdk_android: 24
  adaptive_icon_background: "#101014"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
  adaptive_icon_monochrome: "assets/icon/icon_monochrome.png"
  remove_alpha_ios: true
```

```bash
flutter pub get
dart run flutter_launcher_icons
```

- `adaptive_icon_background` takes a colour string or an image asset path. `adaptive_icon_monochrome` drives Android 13+ themed icons; without it the launcher renders a washed-out auto fallback.
- Adaptive foreground: design at 432x432 with the logo inside the centre ~264x264 — the outer ~18% of each edge is masked away.
- The Play **listing** icon is separate and not generated: 512x512, 32-bit PNG with alpha, max 1024 KB, uploaded in Play Console.

## Splash — flutter_native_splash 2.4.8

```yaml
flutter_native_splash:
  color: "#101014"
  image: assets/splash/logo.png
  android_gravity: center
  fullscreen: true
  android_12:
    color: "#101014"
    image: assets/splash/logo_android12.png
    icon_background_color: "#101014"
    branding: assets/splash/branding.png
```

```bash
dart run flutter_native_splash:create
dart run flutter_native_splash:create --path=path/to/file.yaml
dart run flutter_native_splash:remove
```

- On Android 12+ the splash is the **system** splash screen: window background + centre icon + optional icon background. Background images are unsupported there, only the `android_12` keys — pre-12 art simply will not appear on modern devices.
- Package notes the splash "may not appear when you launch the app from Android Studio on API 31"; launch from the launcher icon instead. It also does not show on notification launches (intended Android 12 behaviour).

## Testing tracks and release

- **Internal testing**: up to 100 testers, near-instant, no review wait. Fastest route to a Play-signed, Play-distributed build — use it for all IAP and ad-fill verification.
- **Closed testing requirement**, verbatim: applies to "personal developer accounts created after November 13, 2023", which must run a closed test with "a minimum of 12 testers who have been opted in continuously for at least 14 days" before applying for production access on the Play Console Dashboard. Organisation accounts, and accounts created on or before 2023-11-13, are exempt.
- Community sources report Google now also checks that testers genuinely used the app, and that all 12 must overlap in one continuous window (a drop-out resets the counter). `UNVERIFIED` — not stated in the first-party help page.
- The Data safety form is required for every track except internal testing.

## Gotchas

- **applicationId is permanent.** Ship `com.example.*` or the wrong flavor suffix once and that identity is burned across all of Play.
- **Registering only the upload key's SHA-1** makes Google Sign-In / Play Games Services fail for real users while working perfectly on your device, because Google re-signs with its own key. Surfaces only after going live. Register the app signing key fingerprint too.
- **IAP and real ads require a Play-distributed build.** `in_app_purchase` returns empty product lists on a sideloaded APK and AdMob serves test/no-fill. Verify on the internal testing track with licensed tester accounts, never via `flutter run --release`.
- R8 fails on `com.google.android.play.core.*` classes referenced by Flutter's deferred-components embedding even in apps that never use them. Fix from `missing_rules.txt`.
- A missing `com.google.android.gms.ads.APPLICATION_ID` `<meta-data>` crashes at startup with "Missing application ID" — release-only if the tag was never absent in debug.
- No `mapping.txt` upload means unreadable Android Vitals crashes; no archived `--split-debug-info` symbols means permanently unreadable Dart stack traces.
- `flutter.minSdkVersion` (24 since Flutter 3.35) can silently overwrite an explicit `minSdk` (flutter/flutter#177141).
- Declaring any under-13 band in target audience irreversibly changes which ad SDKs you may use, and a wrong answer counts as misrepresentation, which is suspension-grade.
- `flutter clean` wipes generated splash/icon resources; re-run both generators in CI before release builds.

## Play Console checklist

- [ ] Developer identity verification complete (name, address, D-U-N-S for orgs, phone/email) — publishing is blocked until it clears.
- [ ] Privacy policy URL live and reachable without login, entered under App content. Mandatory here: AdMob collects an advertising ID, so "we collect nothing" is false.
- [ ] **Data safety form** submitted. For AdMob + IAP expect to declare:
  - [ ] Device or other IDs — advertising ID (collected, shared, for advertising/marketing)
  - [ ] Location — approximate location (AdMob geo-targeting), unless disabled
  - [ ] App activity — app interactions (analytics / ad measurement)
  - [ ] Financial info — purchase history, if you read it
  - [ ] Third-party SDK collection is yours to declare: the form covers "data collected and handled through any third-party libraries or SDKs used in their apps"
  - [ ] Encryption-in-transit and data-deletion answers
- [ ] **Content rating (IARC) questionnaire** completed, declaring in-app purchases and ads. Unrated apps "may be removed from Google Play".
- [ ] **Ads declaration**: "contains ads" under App content > Ads — drives the store badge.
- [ ] **Target audience and content** age bands chosen. Any under-13 band enters the Families programme; 13+ avoids that whole compliance surface for a general puzzle game.
- [ ] App access (no login required, or test credentials), plus news/COVID/data-deletion N/A answers.
- [ ] Store listing assets: icon 512x512 32-bit PNG with alpha (max 1024 KB); feature graphic 1024x500 JPEG or 24-bit PNG with no alpha; screenshots min 2 to publish, 4+ at 1080px min for promotion eligibility, 16:9 landscape (min 1920x1080) or 9:16 portrait (min 1080x1920), min side 320px, max 3840px, longest side <= 2x shortest, up to 8 per device type; descriptions free of misleading claims or fake badges.
- [ ] Play App Signing enrolled; app signing SHA-1 + SHA-256 added to Firebase / Cloud OAuth clients alongside the upload key.
- [ ] `mapping.txt` uploaded; `--split-debug-info` symbols archived off-machine.
- [ ] IAP products created and **activated** (Monetize > Products > In-app products); licensed testers added under Setup > License testing.
- [ ] AdMob app linked to the listing; `app-ads.txt` published if running mediation.
- [ ] Closed testing 12-testers / 14-days completed and production access approved (personal accounts created after 2023-11-13).

## Play policy for a puzzle game with rewarded ads + coin packs

### Ads policy

> "Ads may only be displayed inside of the app serving them and must not interfere with other apps, ads, or the operation of the device."

> "Full screen interstitial ads of all formats (video, GIF, static, etc.) that show unexpectedly, typically when the user has chosen to do something else, are not allowed."

> "Full screen video interstitial ads that appear before an app's loading screen (splash screen) are not allowed."

> "Full screen interstitial ads of all formats that are not closeable after 15 seconds are not allowed."

> "This policy does not apply to rewarded ads which are explicitly opted-in by users (for example, an ad that developers explicitly offer a user to watch in exchange for unlocking a specific game feature or a piece of content)."

> "Ads must not simulate or impersonate the user interface of any app feature, such as notifications or warning elements of an operating system. It must be clear to the user which app is serving each ad."

Implementation rules that follow:

- Rewarded ads are user-initiated only — a button tap. Never auto-play on level start, level fail, or app resume.
- State the reward before the ad ("Watch an ad for 50 coins") and grant it on the SDK reward callback, not on ad close.
- No interstitial on launch/splash or mid-gameplay. Between-level boundaries with a visible transition are the safe placement.
- Close button reachable and functional within 15s: not under a notch, not offscreen, not covered by a decoy X.
- The listing must not misrepresent gameplay — screenshots and promo video must show the actual puzzle, not a different minigame. One of the most common puzzle-game takedown causes.

### Payments

> "Play-distributed apps requiring or accepting payment for access to in-app features or services, including any app functionality, digital content or goods (collectively 'in-app purchases'), must use Google Play's billing system for those transactions unless Section 3, 8, or 9 applies."

Enumerated digital goods include "virtual currencies, extra lives, additional playtime, add-on items, characters, and avatars" — coin packs are squarely in scope. Use `in_app_purchase` over Play Billing; no web checkout and no Stripe/PayPal for coins (alternative billing exists only in specific countries under Sections 8-9).

### Randomised rewards / loot boxes

Payments policy (May 2019 update): apps offering mechanisms to receive randomized virtual items from a purchase, including loot boxes, must clearly disclose the odds of receiving those items in advance of, and in close and timely proximity to, the purchase.

- Show per-item probabilities on the purchase screen itself, not buried in settings.
- Deterministic "N coins for $X" packs do not trigger this; a mystery chest bought with those coins does. `UNVERIFIED` whether a chest purchasable only with earned soft currency is in scope — treat it as in scope.

### Real-money gambling exclusion

> "we don't allow content or services that enable or facilitate users' ability to wager, stake, or participate using real money (including in-app items purchased with money) to obtain a prize of real world monetary value."

Coins must have no cash-out path and no real-world value: no gift cards, crypto, or player-to-player transfers for money.

### Families / under-13 consequences

If the target-audience declaration includes any under-13 band: "Only use Google Play Families Self-Certified Ads SDKs to display ads to those users", and ads "must not involve interest-based advertising ... or remarketing". Apps targeting only children "must not transmit advertising identifiers (AAID), SIM serial numbers, MAC addresses, IMEI, or IMSI", and "should not request AD_ID permission when targeting Android API 33 or higher". google_mobile_ads merges that permission in, so remove it explicitly:

```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID"
    tools:node="remove" />
```

```dart
final RequestConfiguration requestConfiguration = RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes);
    MobileAds.instance.updateRequestConfiguration(requestConfiguration);
```

```dart
final RequestConfiguration requestConfiguration = RequestConfiguration(
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes);
    MobileAds.instance.updateRequestConfiguration(requestConfiguration);
```

Both tags disable interest-based ads and remarketing, materially lowering eCPM; a 13+ target audience avoids all of the above. "Failure to satisfy these requirements may result in app removal or suspension", and "Misrepresentation of any information about your app in the Play Console ... may result in removal or suspension of your app."
