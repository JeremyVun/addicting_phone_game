# Settle v1 — build plan

Phases along the module seams in `design.md` section 11. Each phase names
its owned files, the contract at its seams, its verify gate and its done
marker. Verification waves are separate from code waves. All agents are
Opus 5. Every brief carries the owner's comment rule verbatim.

Worktrees live under `/private/tmp/settle-<phase>` and are cut from the
named base branch; verify the base with the landmark file named in the
phase. The stack lands as sequenced merges into `main`.

## Phase 0 — skeleton (done on main by the orchestrator, 2026-09-08)

Flutter project in `app/` with every dependency pinned, AdMob test app id
in the manifest, core library desugaring on, minSdk 24, `tools/check.sh`,
docs skeleton, `docs/references/` (plugin notes), this design. Landmark:
`app/pubspec.yaml` names `settle` and lists `flame`.

## Phase 1 — core engine and simulator

Owns: `app/lib/core/**`, `app/test/core/**`, `app/bin/sim.dart`,
`docs/contracts/core-engine.md`.

Builds design sections 2, 3 (seed rule only), 4, 5, 6 (the state changes,
not the payment), and the sim in 5.6. Pure Dart: no `package:flutter`
import anywhere under `core/`.

Seam contract (recorded in `docs/contracts/core-engine.md` by this phase):
- `Piece` catalogue with stable ids (`family:rotation`), cells as offsets,
  `cells.length`, `colourIndex`.
- `Board` immutable 8x8 value with `canPlace(piece, row, col)`,
  `place(...)`, `fullLines()`, `clear(lines)`, `fill` (0..1), `isEmpty`,
  `anyPlacement(piece)`, `placements(piece)`.
- `Director.generateSet(board, rng, pressure, {restricted})` per 5.4;
  `pressure(setsGenerated, skill)` per 5.2.
- `GameState` immutable; `GameReducer` with `place(slot, row, col)`,
  `continueGame()`, `reroll()`, returning a `PlacementResult` (lines
  cleared, points, comboCount, boardCleared, gameOver, newSet) so the UI can
  animate from the result without recomputing. Every rule number from
  design 2.4 lives in `scoring.dart` as a named constant.
- `toJson` / `fromJson` on `GameState` and `Rng`.
- Sim: `dart run bin/sim.dart --bot random|greedy --games 2000 --skill 0.5`
  prints median/p10/p90 placements and score, plus the assist-rate figures
  in 5.6.

Verify gate: `tools/check.sh` green; invariant tests from design 5.4 and
4; sim numbers inside the 5.6 bands (paste the table into the report and
into the contract). Done marker: `- [x] phase 1` below with the sim table.

## Phase 2a — visual comps (design-comps skill, parallel with phase 1)

Owns nothing in the repo until the verdict. Produces a /tmp workshop with
3–5 HTML comps of the Play screen and the Home screen, a contact sheet, and
OPTIONS.md. The orchestrator records the verdict and the exemplar image in
`docs/styles.md` and `assets/exemplar/`. Frozen: design 9.5. Frames:
1080x2400 at 3x (the emulator) and 720x1520 at 2x (a low-end phone).
Schemes: dark only in v1.

Done marker: `- [x] phase 2a` with the exemplar path.

## Phase 2b — play screen (Flame) and app shell

Split 2026-09-08 into 2b-play (Flame play screen, palettes, typography,
audio, haptics, `tools/emu.sh`, a dev harness entry point; started from
main right after phase 1 merged) and 2b-shell (AppController with the
mutation queue, storage envelope, bootstrap and service interfaces with
fakes, Home, game over and pause sheets; started after phase 3a merged).
The seam between them is `app/lib/ui/play/play_host.dart` (`PlayHost`),
owned by 2b-play and implemented by 2b-shell in `AppController`.

Base: phase 1 branch. Owns: `app/lib/ui/**` except shop, themes, settings,
achievements screens; `app/lib/app.dart`, `app/lib/main.dart`,
`app/lib/bootstrap.dart` (created here with fakes, owned by phase 4 after),
`app/lib/services/ads.dart`, `purchases.dart`, `analytics.dart` (created
here as interfaces + sinks + fakes per design section 11, owned by phase 4
after), `app/lib/services/audio.dart`, `haptics.dart`, `storage.dart` (the
single `AppData` envelope of design section 4), `clock.dart`;
`app/test/ui/**`; `tools/emu.sh`; `tools/sfx/gen_sfx.py` and the generated
`app/assets/sfx/*.wav`; `docs/contracts/visual.md`.

Builds design 9.1 (Home, Play, Game over sheet in their non-monetised form),
9.2, 9.3, 9.4, 10 (except the notification prompt), and the save/resume in
4. Uses the phase 1 reducer only; never reimplements a rule. Themes come
from a `ThemePalette` table in `ui/theme/palettes.dart` with the twelve
slots from design 7.3 (colours chosen by the agent to the exemplar; names
placeholder until the Codex pass). Rewarded and coin buttons are present
but wired to a `MonetisationHooks` interface with a no-op default so phase
4 can plug in without touching UI files.

`tools/emu.sh`: `install`, `launch`, `shot <name>` (adb screencap to
/tmp/settle-shots/), `tap x y`, `swipe x1 y1 x2 y2 [ms]`, `logcat`. This is
the on-device instrument every later phase inherits.

Verify gate: `tools/check.sh` green; a widget test that drives one
placement and one clear through the Flame game with a fixed seed; on the
emulator, one full game played by hand via `emu.sh` with screenshots of
home, mid-game, a clear, a combo banner, game over; frame time under 16 ms
during a clear (`flutter run --profile` timeline or DevTools). Done marker:
`- [x] phase 2b` with the screenshot paths.

## Phase 3a — meta package (pure Dart, parallel with phases 1 and 2b)

Base: main. Owns: `app/lib/meta/**`, `app/test/meta/**`,
`docs/contracts/economy.md`. No import of `core/`; the app hands meta a
`GameSummary` value built from the game state.

Builds design 7 (all), 3 (day ordinal, daily bookkeeping), 6.1 (the pure
`finish` and `doubleCoins` computations with the game-id idempotency of
section 4), 8.1–8.3 (costs, product table, idempotent `grant`, the
interstitial policy state and the pure `shouldShow` decision of 8.2), 10
(the reminder time rule) and 12 (bucket functions). Everything takes
`DateTime now` explicitly.

Verify gate: `tools/check.sh` green; a unit test for every number in
design 7, 8.1–8.3 and 10 (level thresholds, coin formula bounds,
streak/freeze transitions across day boundaries, reward cycle restart,
each interstitial condition individually, DST-safe ordinal). Done marker:
`- [x] phase 3a`.

## Phase 3b — meta screens and daily mode wiring

Base: phase 2b branch with phase 3a merged. Owns:
`app/lib/ui/screens/themes_screen.dart`, `achievements_screen.dart`,
`daily_result_sheet.dart`, `daily_reward_sheet.dart`,
`streak_sheet.dart`, the home screen's streak/level/daily widgets,
`app/lib/services/notifications.dart` with its wiring in
`app/lib/bootstrap.dart` and the manifest receivers it needs (phase 3b
owns both files until it lands; phase 4 owns them after), and the
`AppController` methods that call meta (`finishGame`, `doubleCoins`,
`claimDailyReward`, `reconcileOnLaunch`, `buyStreakFreeze`, daily game
start and second attempt).

Builds the screens of design 9.1 for meta, daily mode end to end (3, 6.1
daily result), the notification prompt and reminder (10), and the
level-up/coin lines on the game over sheet.

Verify gate: `tools/check.sh` green; emulator screenshots of the daily
card, daily result, themes screen, achievements screen, daily reward
sheet, a level-up on the game over sheet; a fresh install shows no reward
sheet on day 1 and the reminder permission sheet only after the second
completed game. Done marker: `- [x] phase 3b`.

## Phase 4 — monetisation and consent

Base: phase 3b branch. Owns: `app/lib/bootstrap.dart`,
`app/lib/services/ads.dart`, `purchases.dart`, `analytics.dart`,
`monetisation.dart` (the `MonetisationHooks` implementation and the
interstitial policy), `app/lib/ui/screens/shop_screen.dart`,
`settings_screen.dart`, `app/test/services/**`, Android manifest/gradle
changes the plugins need, `docs/contracts/monetisation.md`,
`docs/contracts/analytics.md`.

Builds design 8 (all), 12, and the settings screen from 9.1.

Verify gate: `tools/check.sh` green; unit tests for the interstitial policy
(every condition in 8.2 individually), reward-only-on-callback, product id
table; on the emulator with Google test unit ids: consent flow (use the
debug geography EEA setting to force the form), a rewarded ad granting a
continue, an interstitial after the third game, shop listing the five
products (queryProductDetails will fail without Play Console products; the
screen must show the "not available" state cleanly and the fake path must
be screenshotted). Done marker: `- [x] phase 4`.

## Phase 5 — copy, art, sound polish

Base: phase 4 branch. Owns: `app/lib/ui/strings.dart`, `docs/store/**`,
`app/assets/icon/**`, `assets/**`, `flutter_launcher_icons` and
`flutter_native_splash` config in `pubspec.yaml`.

The orchestrator shells out to Codex for every string (strings file, theme
names, achievement names, notification text, store listing, privacy
policy). Codex image generation produces the icon and feature graphic. An
Opus agent wires them and fixes any layout the real copy breaks.

Verify gate: every string in the app comes from `strings.dart`; no banned
filler words (grep list from the `user-facing-copy` skill); icon renders on
the emulator launcher; splash shows. Done marker: `- [x] phase 5`.

## Phase 6 — release build and verification wave

Base: phase 5 branch. Owns: `tools/release.sh`, `android/app/proguard-rules.pro`,
signing wiring in `build.gradle.kts`, `docs/store/checklist.md`,
`docs/project.md`, `CLAUDE.md`, `docs/roadmap.md`.

Verify gate: `flutter build appbundle --release` succeeds with the upload
keystore; the release APK installs and runs on the emulator; a scripted
`emu.sh` drive plays three games, watches a test rewarded ad, sees one
interstitial; a fresh-install run exercises first-game catalogue and both
hints; profile timeline shows no frame over 16 ms in a 60 s session. Done
marker: `- [x] phase 6`.

## Phase 7 — adversarial review and fix wave

An Opus xhigh reviewer attacks the invariants in design 2.3, 2.4, 5.4, 4,
7.5 and 8.2 in its own worktree, commits probe tests as soon as they
compile, and reports contract contradictions. A fix agent inherits the
probes as its acceptance suite. Done marker: `- [x] phase 7`.

## Done markers

- [x] phase 0
- [x] phase 1 — 66 tests; offset 1.6; greedy 32/56/89 placements (score 222/502/916), smart 119/215/400 (1325/2967/5677), random 11/17/26 ungated; dots 10.0% at p=0.5; assist rate(A) 0.789 vs rate(B) 0.775
- [x] phase 2a — exemplar `assets/exemplar/play-mid-drag.png` (+4 frames), verdict in `docs/styles.md`
- [ ] phase 2b
- [ ] phase 3a
- [ ] phase 3b
- [ ] phase 4
- [ ] phase 5
- [ ] phase 6 — tooling done 2026-09-08 (`tools/release.sh`, signing, R8, icon, splash, `docs/store/checklist.md`); the verification wave remains
- [ ] phase 7
