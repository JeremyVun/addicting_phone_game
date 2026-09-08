<!-- Retrieved 2026-09-08 | index of upstream-grounded package reference notes -->
Reference notes for building this Android Flutter game. Each file leads with its retrieval date, exact package versions and the source URLs it was written from; signatures are copied from upstream, not paraphrased.

- `flame.md` — flame 1.38.2: FlameGame lifecycle, components, camera/viewport, tap+drag events, effects, particles, overlays, coordinate spaces, flame_test.
- `google_mobile_ads.md` — google_mobile_ads 9.1.0: init, UMP consent, rewarded/interstitial/app-open/adaptive banner, test IDs, manifest APPLICATION_ID, ad policy.
- `in_app_purchase.md` — in_app_purchase 3.3.0 / in_app_purchase_android 0.5.3: purchase stream, consumables, acknowledgement, Billing 8 deadline, Play Console product setup.
- `notifications_and_storage.md` — flutter_local_notifications 22.3.0, shared_preferences 2.5.5, path_provider 2.1.6, games_services 5.3.0: scheduling, exact-alarm policy, save files, leaderboards.
- `audio_haptics.md` — flame_audio 2.12.2, audioplayers 6.8.1, flutter_soloud 5.0.2, vibration 3.2.1: SFX pools, bgm, audio focus, HapticFeedback.
- `android_release.md` — Flutter 3.47.2 / target API 36: Kotlin DSL gradle, signing, R8 rules, appbundle, icons/splash, Play Console checklist and monetisation policy.

Read the file for the package you are touching before writing code against it; several widely-copied StackOverflow patterns are documented here as wrong for these versions.
