# Going live on Google Play

The owner's step list, in order. Everything here is a Play Console or AdMob
action; the build side is `tools/release.sh`.

## Two deadlines that are already past

Both bit on **2026-08-31**, with the extension window closing **2026-11-01**.
A first release today has to satisfy them from day one:

- **Target API level.** New apps must target Android 16 (API 36).
  The build already ships `targetSdkVersion 36` — verified in the merged
  manifest, not assumed.
- **Play Billing 8.** New apps and updates must use Billing Library 8+.
  `in_app_purchase 3.3.0` pulls `in_app_purchase_android` 0.5.x, which bundles
  `com.android.billingclient:billing:8.0.0`. Do not downgrade the plugin.

## 1. Account and identity

1. Create the Google Play Console developer account and finish identity
   verification (name, address, phone, email). Publishing is blocked until it
   clears.
2. If this is a **personal** account created after 2023-11-13, production access
   also requires a closed test with 12 testers opted in continuously for 14
   days. Start that clock early — it gates the production launch, not the
   internal one.

## 2. Confirm the package name before the first upload

The application id is **`com.perch.settle`**. Play locks it forever on first
upload: it cannot be renamed, and it cannot be reused on another listing even
after unpublishing. Confirm it reads correctly now, because there is no
second chance.

## 3. Upload key

```sh
tools/release.sh keystore     # creates ~/.settle/upload.jks + key.properties
tools/release.sh fingerprint  # prints SHA-1 / SHA-256 again
```

Back up the whole `~/.settle/` directory off this machine immediately. The
script refuses to overwrite an existing keystore. Nothing in `~/.settle` is
in the repo, and `*.jks` / `key.properties` are gitignored.

## 4. Play App Signing

Opt in when creating the app, and upload the upload-key certificate. Google
then holds the real app signing key and re-signs every download.

Anything that authenticates by certificate fingerprint must have **both** the
upload key and Google's app signing key registered, or it works on your device
and fails for every real user. Not needed for v1 (no Google Sign-In, Play Games
or Firebase), but note it before adding any of them.

## 5. AdMob

1. Create the AdMob account and link it to the Play listing.
2. Put the real app id in `app/android/app/src/main/AndroidManifest.xml` as the
   `com.google.android.gms.ads.APPLICATION_ID` meta-data, replacing Google's
   sample id. `tools/release.sh apk|bundle` refuses to build while the sample id
   is present, because shipping test ads is a policy violation.
   App ids use `~`; ad unit ids use `/`. Pasting a unit id here crashes at
   startup.
3. Create the four ad unit ids (rewarded and interstitial). Once phase 4 lands
   they belong in **`app/lib/services/ad_ids.dart`** — a file that does not
   exist yet. Keep the real ids out of git.

## 6. In-app products

Create all five under Monetize > Products, with these exact ids and types
(design section 8.3), then **activate** them — a created-but-inactive product
returns an empty product list:

| product id | type | suggested USD |
| --- | --- | --- |
| `remove_ads` | non-consumable | 3.99 |
| `coins_small` | consumable | 0.99 |
| `coins_medium` | consumable | 4.99 |
| `coins_large` | consumable | 9.99 |
| `theme_pack_all` | non-consumable | 2.99 |

Product ids are permanent and cannot be reused after deletion. Add licensed
testers under Setup > License testing.

## 7. App content declarations

1. **Privacy policy.** Host `docs/store/privacy-policy.md` (drafted separately)
   at a public URL reachable without login, and enter it under App content.
   Mandatory: AdMob collects an advertising id, so "we collect nothing" is
   false.
2. **Data safety.** Fill from `docs/store/data-safety.md`. The build ships
   `com.google.android.gms.permission.AD_ID` (merged in by the Ads SDK, not
   added by hand) and `com.android.vending.BILLING` (merged in by the Billing
   AAR), so the declaration must at minimum cover the advertising id.
3. **Content rating.** Complete the IARC questionnaire, declaring in-app
   purchases and ads. Unrated apps may be removed.
4. **Target audience: 18+.** Any under-13 band pulls the app into the Families
   programme, which restricts ad SDKs, bans interest-based ads and materially
   lowers revenue. A wrong answer counts as misrepresentation.
5. **Ads declaration: yes, contains ads.**

## 8. Store listing

- Text from `docs/store/listing.md`.
- Icon: `assets/store/icon-1024.png` (Play wants 512x512 32-bit PNG with alpha,
  max 1024 KB — resize on upload).
- Feature graphic: `assets/store/feature-1024x500.png` (24-bit PNG, no alpha).
- Screenshots from `tools/emu.sh shot` (being built separately). Minimum 2 to
  publish, 4+ at 1080px minimum for promotion eligibility. They must show the
  real puzzle — misleading screenshots are a common takedown cause.

## 9. Release

1. **Internal testing track first.** Up to 100 testers, no review wait. This is
   the only way to verify in-app purchases and real ad fill: a sideloaded APK
   returns an empty product list and serves no real ads.
2. Upload the AAB from `tools/release.sh bundle`.
3. Upload `app/build/app/outputs/mapping/release/mapping.txt` as the
   deobfuscation file, or Android Vitals crashes are unreadable.
4. Then production, once closed testing (step 1.2) is satisfied if it applies.

`versionCode` must strictly increase and Play permanently rejects one it has
already seen, including from a deleted draft. Bump with
`tools/release.sh version <x.y.z> <code>`.

## After every store build

- `tools/release.sh bundle` obfuscates Dart code and writes the symbol
  files to `app/build/symbols/<version>/`. Archive that folder with the
  uploaded bundle; without it, crash stack traces from production cannot
  be read.
- The upload keystore is PKCS12 (converted 2026-09-08 before first use).
