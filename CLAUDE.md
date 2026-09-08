# Settle (addicting_phone_game)

One-thumb block puzzle for Android in Flutter + Flame. Orientation:
[docs/project.md](docs/project.md). Design in flight:
[docs/backlog/v1/design.md](docs/backlog/v1/design.md) and its
[build_plan.md](docs/backlog/v1/build_plan.md). Plugin notes for builders:
[docs/references/README.md](docs/references/README.md).

## Structure

```
app/lib/core      pure Dart game rules (board, pieces, director, scoring, state)
app/lib/meta      pure Dart economy (profile, levels, themes, daily, achievements)
app/lib/services  plugin adapters behind interfaces, with fakes
app/lib/ui        screens, Flame play screen, palettes, strings.dart
app/bin/sim.dart  headless bot simulation for tuning the director
app/test          unit + widget tests
docs/contracts    as-built rules, one file per seam
tools             check.sh (analyze+test), emu.sh (emulator drive), release.sh
```

## Run

```sh
tools/check.sh                        # flutter analyze + flutter test
cd app && flutter run -d emulator-5554
cd app && dart run bin/sim.dart --bot greedy --games 2000
tools/emu.sh shot <name>              # screenshot the emulator to /tmp/settle-shots/
```

## Rules

- `core/` and `meta/` never import Flutter. Rule numbers live in named
  constants in those packages, nowhere else.
- Player-facing text only in `app/lib/ui/strings.dart`, drafted by Codex.
- Ads and purchases only through the `AdsService` / `PurchaseService`
  interfaces; tests and the emulator use the fakes.
- Never commit `key.properties`, `*.jks`, or real AdMob unit ids. The upload key
  lives in `~/.settle/` (PKCS12); `tools/release.sh` reads it from there.
- `emulator-5554` is shared by every session; never install over another
  agent's build (same applicationId). Boot your own AVD on another port for
  device checks, and build before booting: two emulators plus Gradle
  overload this machine.
