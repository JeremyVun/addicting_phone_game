# Settle (addicting_phone_game)

One-thumb block puzzle for Android in Flutter + Flame. Orientation:
[docs/project.md](docs/project.md); next work: [docs/roadmap.md](docs/roadmap.md);
visual authority: [docs/styles.md](docs/styles.md); as-built law, one file
per seam: `docs/contracts/` (core-engine, economy, app-shell, meta-screens,
monetisation, analytics, visual, copy). Plugin notes for builders:
[docs/references/README.md](docs/references/README.md). Store to-dos:
[docs/store/checklist.md](docs/store/checklist.md). Contracts cite "design N.N":
that is the v1 design doc, kept only in git history
(`git show d9dc5a9:docs/backlog/v1/design.md`).

## Structure

```
app/lib/core      pure Dart rules: board, pieces, director, scoring, game state
app/lib/meta      pure Dart economy: profile, levels, themes, daily, streak, achievements, policies
app/lib/services  plugin adapters behind interfaces with fakes (storage, ads, purchases, analytics, notifications, audio, haptics)
app/lib/ui        shell (app.dart routes, screens, widgets), Flame play screen (ui/play), palettes, strings.dart
app/lib/app.dart  AppController: envelope, mutation queue, PlayHost; app_daily.dart / app_shop.dart are its part files
app/lib/dev       play_harness.dart: the play screen alone with scripted boards
app/bin/sim.dart  headless bots and the director calibration sweep
app/test          unit, widget and probes/ (adversarial regressions)
tools             check.sh, emu.sh (emulator drive/screenshots), release.sh (keystore, apk, bundle), sfx/, icon/
assets            exemplar frames, store art and screenshots
```

## Run

```sh
tools/check.sh                                   # flutter analyze + flutter test (387 tests)
cd app && flutter run -d emulator-5554           # the app; add --dart-define=SETTLE_FAKE_SERVICES=true for fake ads/purchases
cd app && flutter run -t lib/dev/play_harness.dart -d emulator-5554
cd app && dart run bin/sim.dart --bot greedy --games 2000   # or --sweep
tools/emu.sh install|launch|shot <name>|drag x1 y1 x2 y2    # see its header
tools/release.sh keystore|apk|bundle [--allow-test-ads]     # signed builds; refuses sample ad ids
tools/analytics_dashboard.sh                     # install the settle dashboard layout (Authelia login prompted)
```

## Rules

- `core/` and `meta/` never import Flutter; rule numbers live there as named constants only.
- Every state change goes through `AppController.mutate`; spends are re-checked inside the mutation; never `unawaited(mutate(...))`, use `mutateInBackground`.
- Player-facing text only in `strings.dart`, drafted by Codex (`docs/contracts/copy.md`).
- Ads and purchases only through `AdsService` / `PurchaseService`; tests and emulator drives use the fakes.
- Never commit `key.properties`, `*.jks`, or real AdMob unit ids. The upload key lives in `~/.settle/` (PKCS12).
- `emulator-5554` is shared by every session; never install over another agent's build (same applicationId). Boot your own AVD on another port for device checks, and build before booting: two emulators plus Gradle overload this machine.
