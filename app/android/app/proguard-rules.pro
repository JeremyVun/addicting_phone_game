# google_mobile_ads and in_app_purchase need no app-side rules: the Play Services Ads and
# Play Billing AARs ship their own consumer rules. Verified by a release build with this file
# empty -- R8 emitted no build/app/outputs/mapping/release/missing_rules.txt.

# Flutter's embedding references Play Core deferred-components classes that are absent unless
# the app uses deferred components. Not triggered on Flutter 3.47, but the break is version
# sensitive and tracked upstream: flutter/flutter#165646, #139462.
-dontwarn com.google.android.play.core.**
