# Settle v1 — design

Settle is a one-thumb block puzzle for Android. Three block shapes are offered
at a time; the player drags each onto an 8x8 grid. Full rows and columns
clear. Consecutive clears build a combo. The game ends when no offered shape
fits. Around that core sit a daily puzzle with a streak, coins, a player
level that unlocks colour themes, and monetisation through rewarded video,
capped interstitials and a small in-app-purchase catalogue.

Why this game: the block-fit genre has the highest download and retention
numbers in casual mobile (Block Blast, Woodoku). The mechanic is legible in
three seconds, plays in portrait with one thumb, is deterministic and fully
testable headless, and its retention lever (the piece generator) is code we
own. Novelty is spent on feel, the director and the meta loop, not on the
core rule set.

Status: designed 2026-09-08 by the orchestrating session under the owner's
standing brief ("make the most addictive Android game, monetise it legally,
don't stop until it's done"). Decisions marked *orchestrator* were taken
without an owner ruling and are the first things to revisit if the owner
disagrees. Nothing here blocks the build.

## 1. Goals and how they are measured

| Goal | Target | Instrument |
| --- | --- | --- |
| Instant legibility | first placement within 10 s of first launch, no tutorial modal | emulator drive test; FTUE hint |
| Session shape | median classic game 2–6 min; restart to new board < 300 ms | sim bots (section 5.6) + on-device timing |
| Never unfair at spawn | a freshly generated set always has a placeable piece while the board is under 70% full | `core` invariant test |
| Retention loops | daily puzzle, streak with freeze, daily reward calendar, level unlocks, achievements, reminder notification | present and verified on device |
| Revenue | 4 rewarded placements, capped interstitials, 5 IAP products, consent-gated | fake and real ad paths verified on emulator with Google test IDs |
| Store-ready | signed AAB, icon, splash, listing copy, privacy policy text, data-safety notes | `tools/release.sh` output + docs |

Live metrics (D1, ARPDAU) need real users and are outside this build; the
analytics events in section 12 exist so they can be measured after launch.

## 2. Core rules

### 2.1 Grid
8 rows x 8 columns, 64 cells. A cell is empty or holds a colour index
(0–7). Colour is cosmetic: it never affects placement, clearing or score.

### 2.2 Pieces
A piece is a set of (row, col) offsets with its bounding box anchored at
(0,0). The catalogue, with base weight per family, split evenly across the
family's rotations:

| family | cells | rotations | base weight |
| --- | --- | --- | --- |
| dot | 1 | 1 | 4 |
| i2 | 2 (line) | 2 | 8 |
| i3 | 3 (line) | 2 | 8 |
| i4 | 4 (line) | 2 | 6 |
| i5 | 5 (line) | 2 | 4 |
| o2 | 4 (2x2) | 1 | 8 |
| o3 | 9 (3x3) | 1 | 4 |
| r23 | 6 (2x3) | 2 | 5 |
| l3 | 3 (corner) | 4 | 8 |
| l4 | 4 (L) + mirrored (J) | 8 | 8 |
| l5 | 5 (3-arm corner) | 4 | 6 |
| t4 | 4 (T) | 4 | 8 |
| s4 | 4 (S) | 2 | 3 |
| z4 | 4 (Z) | 2 | 3 |

Total base weight 83. Each piece carries one colour index chosen uniformly
at generation; a family always maps to the same colour index within one
theme so the player learns shapes by colour (dot 0, i2/i3 1, i4/i5 2, o2 3,
o3/r23 4, l3/l4 5, l5 6, t4/s4/z4 7).

### 2.3 Turn structure
- A **set** is three pieces shown in a tray under the grid. All three must be
  placed before the next set is generated. Placement order is free.
- A placement is legal when every cell of the piece lands on an empty cell
  inside the grid. The piece is dropped by drag; the drop target is the grid
  cell under the piece's anchor after snapping (section 9.2).
- After a placement, every full row and every full column clears at once.
  A cell belonging to both a full row and a full column clears once.
- **Game over**: after any placement, if none of the remaining pieces of the
  current set fits anywhere. Checked after clearing. If the set is exhausted,
  the next set is generated first and the check runs on it (generation
  guarantees a fit while the board is under 70% full, section 5.4).

### 2.4 Scoring
For one placement with a piece of `k` cells that clears `n` lines (rows +
columns counted together):

```
placement   = k
clear(n)    = 10 * n * (n + 1) / 2         # 0,10,30,60,100,150,210,...
multiplier  = min(comboCount, 8)            # comboCount after this placement
boardClear  = 300 if the grid is empty after clearing else 0
points      = placement + clear(n) * multiplier + boardClear
```

Combo: `comboCount` increments on every placement that clears at least one
line. A placement that clears nothing increments `missCount`; when
`missCount` reaches 2, `comboCount` and `missCount` both reset to 0. A
clearing placement resets `missCount` to 0. So one non-clearing placement
between clears keeps the combo alive (the one-move grace). The HUD shows the
combo banner whenever `comboCount >= 2`.

Best score per mode is persisted. Score, not level, is the number the
player chases inside a game.

## 3. Modes

**Classic**: endless, high-score. Director uses the player's skill estimate.

**Daily**: one board per calendar day (local date). Seed = number of days
since 2026-01-01 in the device's local date. The director runs with skill
fixed at 0.5 and no per-player adaptation, so every player gets the same
piece sequence for the same placements. One attempt per day; a second
attempt is available once through the `dailySecondAttempt` rewarded
placement. The best of the attempts is the day's result. Completing an
attempt (reaching game over, with or without a continue) counts the day for
the streak. A daily game in progress is saved and resumed like a classic one;
a saved daily from a previous date is discarded on launch and does not count.

## 4. Determinism, saving and resuming

All randomness in `core` comes from one PCG32-style generator (`Rng`)
seeded per game. `GameState` (grid, current set with which slots are used,
score, comboCount, missCount, setsGenerated, continuesUsed, rerollsUsed,
mode, seed, rng state, startedAt, elapsed) serialises to JSON and back with
no loss; `serialize(deserialize(x)) == x` is a test. The app saves after
every placement and on background; on launch it resumes a saved game of the
same date (daily) or any date (classic). A resumed game cannot be replayed
to a different outcome: the rng state is part of the save.

## 5. The director (piece generation)

The director decides which three pieces appear. It is the addictiveness
lever: it keeps a beginner alive long enough to learn, keeps a good player
in flow, and manufactures the occasional tight spot that makes a clear feel
earned. It is pure Dart in `core/director.dart`.

### 5.1 Inputs
`board`, `rng`, `pressure p in [0,1]`, `firstGameEver` flag.

### 5.2 Pressure
```
base(sets)   = min(0.85, 0.15 + 0.70 * setsGenerated / 40)
skillAdj     = 0.30 * (skill - 0.5)         # skill in [0,1], 0.5 for daily
p            = clamp(base + skillAdj, 0, 1)
```
`skill` is the persisted per-player estimate (section 7.6). A game of 40
sets is 120 placements, around 5 minutes at a relaxed pace; base pressure
reaches its ceiling there.

### 5.3 Sampling a piece
Each piece's weight is `familyWeight / rotations * (cells / 4) ^ (2p - 1)`.
At `p = 0.5` the exponent is 0 and the bag is the base table; at `p = 0`
small pieces are favoured; at `p = 1` large ones. Sampling is weighted
random over the whole catalogue.

### 5.4 Generating a set (in this order)
1. Draw three pieces by 5.3.
2. **Mercy**: if board fill >= 70% and `rng.next() < 0.70 - 0.40 * p`,
   replace the largest piece with a uniformly random piece of at most 3
   cells (dot, i2, i3, l3).
3. **Assist**: if `rng.next() < 0.45 * (1 - p)`, draw up to 12 candidate
   pieces by 5.3 and take the first that has a placement completing at least
   one line; if one exists, it replaces a random slot.
4. **Fit guarantee**: if no piece in the set fits the board, discard the set
   and retry from step 1. After 10 failed tries, retry with `p = 0`. After
   30 failed tries, keep the last set (the board is effectively dead and game
   over follows).
5. Colour each piece by family (2.2).

Invariant (tested): when fill < 70% a returned set always has a fitting
piece. Empirically, 30 retries make an unfit set at fill < 70% impossible
in practice; the test asserts it over 10,000 random boards.

### 5.5 First game ever
For the first three sets of a brand-new profile the catalogue is restricted
to {dot, i2, i3, o2, l3, l4, t4} and `p = 0`. No modal tutorial. A single
hint line under the tray ("Drag a block onto the grid") shows until the
first placement, and a second ("Fill a row or column to clear it") shows
until the first clear. Both lines are final Codex copy (2026-09-08).

### 5.6 Tuning gates (simulation)
`app/bin/sim.dart` plays headless games with bots and prints length and
score distributions. The build must satisfy, at skill 0.5, over 2,000 games
per bot:

| bot | median placements | purpose |
| --- | --- | --- |
| random legal placement | 20–45 | a beginner survives 1–2 minutes |
| greedy 1-ply (max lines cleared, then max empty cells) | 90–220 | a competent player reaches 4–8 minutes |

Also: fraction of sets that contain a line-completing piece >= 35% when
`p <= 0.3`, and <= 25% when `p >= 0.8`. If the numbers fall outside these
bands, tune the constants in 5.2–5.4 and record the change here.

## 6. Continue and reroll

- **Continue** (`continueGame` placement): offered once per game on the game
  over sheet. Clears the three rows with the most filled cells (ties:
  topmost), then generates a fresh set with `p = 0`, and play resumes with
  the same score and combo. Paid by one rewarded ad, or by 150 coins. Ad-free
  buyers get it free once per game.
- **Reroll** (`reroll` placement): from the tray during play, replaces the
  remaining unplaced pieces of the current set with a fresh set generated at
  the current pressure. Paid by one rewarded ad or 50 coins. At most 3
  rerolls per game in total.

## 7. Meta progression

### 7.1 Coins
- Per game: `max(5, min(200, score ~/ 50))`.
- First completed game of the local day: +25.
- `doubleCoins` rewarded placement at game over doubles the game's coins
  (before the daily +25).
- Level-ups, achievements and the daily reward calendar also grant coins.
- Spend: continue 150, reroll 50, streak freeze 200, themes (7.3).

### 7.2 XP and level
`xp += score ~/ 10` per completed game. Cumulative XP needed to be at level
`L` (L >= 2): `round(150 * (L - 1) ^ 1.7)`. L2 150, L3 487, L5 1,590,
L10 6,300, L20 22,300, L30 46,000. A level-up shows on the game over sheet
with its reward: 50 coins x new level, plus the theme it unlocks if any. No
level cap.

### 7.3 Themes
Twelve colour themes. Each theme defines: background, grid, empty cell,
eight block colours, text on dark, accent. The default is unlocked.
Unlock table:

| theme slot | unlock |
| --- | --- |
| 1 | default |
| 2 | level 2 |
| 3 | level 4 |
| 4 | level 6 |
| 5 | level 9 |
| 6 | level 12 |
| 7 | level 16 |
| 8 | level 20 |
| 9 | level 25 |
| 10 | level 30 |
| 11 | 1,500 coins |
| 12 | 3,000 coins |

The `theme_pack_all` purchase unlocks all twelve. Theme names (Codex,
2026-09-08), in slot order: Obsidian (default), Dawn, Meadow, Coral,
Glacier, Desert, Storm, Lavender, Ember, Plum, Pearl, Lagoon.

### 7.4 Daily reward calendar
On the first launch of each local day a small sheet offers the day's coins:
day 1–7 of the cycle = 25, 50, 75, 100, 150, 200, 400. The cycle advances on
consecutive days and restarts at day 1 after a missed day. One claim per
day; claiming is a button, never automatic.

### 7.5 Streak and streak freeze
The daily streak is the number of consecutive local days with a completed
daily attempt. A missed day resets it to 0 unless a streak freeze is held,
in which case one freeze is consumed and the streak is kept. Freezes cost
200 coins, at most 2 held. The home screen shows the streak and whether a
freeze is held.

### 7.6 Skill estimate
`skill` in [0,1], persisted. After each completed classic game:
`skill = 0.8 * skill + 0.2 * clamp(score / 6000, 0, 1)`. Starts at 0.35.
6,000 is the score a competent player reaches in a good game under this
scoring; revisit after sim data and record here.

### 7.7 Achievements
Sixteen, each granting coins once. Checked at game over and on the relevant
events. Names and descriptions by Codex (2026-09-08); the coin reward is in
brackets:

| id | name | description | coins |
| --- | --- | --- | --- |
| `first_clear` | First clear | Clear your first line. | 10 |
| `combo_3` | Combo starter | Reach a combo of 3. | 25 |
| `combo_5` | Combo builder | Reach a combo of 5. | 50 |
| `combo_8` | Combo master | Reach a combo of 8. | 100 |
| `score_1k` | 1,000 points | Score 1,000 points in one game. | 25 |
| `score_2500` | 2,500 points | Score 2,500 points in one game. | 50 |
| `score_5k` | 5,000 points | Score 5,000 points in one game. | 100 |
| `score_10k` | 10,000 points | Score 10,000 points in one game. | 200 |
| `score_25k` | 25,000 points | Score 25,000 points in one game. | 400 |
| `board_clear` | Clear grid | Clear every block from the grid. | 100 |
| `games_10` | Ten games | Finish 10 games. | 25 |
| `games_100` | Hundred games | Finish 100 games. | 150 |
| `streak_3` | Three-day streak | Keep a daily streak for 3 days. | 50 |
| `streak_7` | Seven-day streak | Keep a daily streak for 7 days. | 150 |
| `streak_30` | Thirty-day streak | Keep a daily streak for 30 days. | 500 |
| `level_10` | Level 10 | Reach level 10. | 200 |

## 8. Monetisation

Everything is opt-in or capped, discloses what the player gets, and follows
Google Play's ads and monetisation policies (see `docs/references/`).

### 8.1 Rewarded placements
| placement | when | reward |
| --- | --- | --- |
| `continueGame` | game over sheet, once per game | continue (section 6) |
| `reroll` | tray button during play, max 3 per game | new pieces (section 6) |
| `doubleCoins` | game over sheet, once per game | this game's coins x2 |
| `dailySecondAttempt` | daily result, once per day | one more daily attempt |

A rewarded button always shows the reward and a play icon; if no rewarded ad
is loaded the button shows the coin price instead (continue, reroll) or is
hidden (double coins, second attempt). The reward is granted only from the
`onUserEarnedReward` callback.

### 8.2 Interstitial policy
Shown when the player taps "Play again" on the game over sheet, and only if
all hold: not ad-free; lifetime completed games >= 3; completed games since
the last interstitial >= 2; at least 90 s since the last interstitial
closed; at least 45 s since the last rewarded ad closed; the game just
finished lasted >= 30 s; an interstitial is loaded. The next interstitial is
preloaded after each show. Never on launch, never mid-game, no app-open ads
in v1.

### 8.3 Products
| product id | type | grants |
| --- | --- | --- |
| `remove_ads` | non-consumable | no interstitials, free continue once per game |
| `coins_small` | consumable | 500 coins |
| `coins_medium` | consumable | 3,000 coins |
| `coins_large` | consumable | 8,000 coins |
| `theme_pack_all` | non-consumable | all twelve themes |

Prices are set in Play Console (suggested USD 3.99 / 0.99 / 4.99 / 9.99 /
2.99) and displayed from the store's localised price. Purchases are
acknowledged or consumed through the plugin; non-consumables are restored on
launch and through a "Restore purchases" button in Settings. No server-side
receipt validation in v1; the risk is accepted and recorded.

### 8.4 Consent
On launch the app requests consent info (UMP). If a form is required it is
shown before any ad loads. `MobileAds.initialize` runs only when
`canRequestAds` is true. Settings shows "Privacy options" when the SDK
reports that requirement. Ad requests set the content rating to `T` at most
and are not tagged child-directed (the target audience is 18+; the Play
listing declares it so).

### 8.5 Fakes
`AdsService` and `PurchaseService` are interfaces. The real ones wrap
`google_mobile_ads` and `in_app_purchase`. The fakes grant instantly and are
used by tests and, via a debug flag, on the emulator. In debug builds the
real ads service uses Google's test unit ids.

## 9. Screens and feel

### 9.1 Screens
- **Home**: top bar (coins, level with progress ring, settings), streak
  chip, big Play button, Daily card (today's status, streak, attempt left),
  Themes and Shop entries, achievements entry.
- **Play** (Flame `GameWidget` with Flutter overlays): HUD (score, best,
  combo banner), 8x8 grid, tray with three pieces, reroll button, pause.
- **Game over sheet**: score, best (with "New best" state), coins earned,
  level progress, Continue (rewarded/coins), Double coins (rewarded), Play
  again, Home.
- **Daily result**: today's score, streak, share button (text card), second
  attempt (rewarded) if unused.
- **Shop**: Remove Ads, three coin packs, theme pack; Restore purchases.
- **Themes**: grid of twelve swatches with lock state and unlock condition.
- **Settings**: sound, haptics, reminder notification, privacy options,
  restore purchases, version, privacy policy link.
- **Achievements**: list with progress and claimed state.

Navigation is a `Navigator` stack; Play is full-screen; sheets are modal
bottom sheets. Back from Play pauses.

### 9.2 Drag and drop
A tray piece is picked up on touch-down. While dragging it renders at full
grid scale, offset 64 px above the finger so the thumb never hides it. The
target cell is the grid cell under the piece's top-left cell after rounding;
a ghost of the piece shows on the grid in the piece colour at 40% opacity
when the placement is legal, and cells that would complete a line are
highlighted at 70%. Release with a legal target places the piece; release
elsewhere flies the piece back to the tray in 200 ms.

### 9.3 Timings
| moment | animation |
| --- | --- |
| pick up | scale 1.0 to 1.15 over 120 ms, ease-out |
| place | cells scale 1.1 to 1.0 over 120 ms |
| clear | 80 ms white flash, then 180 ms shrink+fade staggered 15 ms per cell outward from the placed piece; 8 particles per cell |
| score popup | floats 40 px up over 500 ms at the clear centroid |
| shake | for n >= 2 lines: amplitude 2 px x n, 150 ms |
| combo banner | scales in 200 ms, holds 700 ms |
| game over | 500 ms hold, cells dim to 40%, sheet slides up 250 ms |
| restart | new board visible within 300 ms of tapping Play again |

### 9.4 Haptics and audio
Place: selection click. Clear one line: light impact. Two or more lines:
medium impact. Combo >= 3: heavy impact. Game over: heavy impact twice,
120 ms apart. All haptics off when the setting is off.

Sounds (generated procedurally by `tools/sfx/gen_sfx.py`, WAV, 44.1 kHz):
place, clear (pitch rises one semitone per combo step up to 8), combo
stinger at combo 3/5/8, board clear, game over, button, coin, level up. No
music in v1. Played through `flame_audio` `AudioPool`s preloaded at Play
screen start.

### 9.5 Visual direction
Decided by a design-comps round before the Play screen is built (build plan
phase 2a). Frozen inputs to the comps: 8x8 grid, three-piece tray under the
grid, HUD above, dark default theme, blocks read as solid rounded tiles,
type is one bundled OFL font. The comp verdict and exemplar image live in
`docs/styles.md` and `assets/exemplar/`.

## 10. First-session flow

Launch -> splash (native, < 1 s) -> consent form if required -> home. First
Play tap goes straight into a classic game with the first-game catalogue
(5.5). No account, no name, no permissions asked. The reminder notification
permission is requested only after the second completed game, from a sheet
that explains it ("Get a reminder when the daily puzzle is ready"), with a
"Not now" that never re-asks. The daily reward sheet is not shown on day 1.

Reminder: one local notification at 19:00 local time on any day the player
has not opened the app, scheduled inexactly. Cancelled on open,
re-scheduled on background. Text (Codex, 2026-09-08): title "Daily puzzle
ready", body "Today's puzzle is ready to play."

## 11. Technical shape

Flutter 3.41 / Dart 3.11, Android only in v1 (minSdk 24, targetSdk from the
Flutter template, currently 36). Packages: flame 1.38, flame_audio 2.12,
google_mobile_ads 9.1, in_app_purchase 3.3, shared_preferences 2.5,
flutter_local_notifications 22.3, timezone 0.11, flutter_timezone,
package_info_plus, url_launcher, share_plus.

```
app/lib/
  core/        pure Dart, no Flutter import: board, piece catalogue, rng,
               director, scoring, game state + reducer, serialisation
  meta/        pure Dart: profile, economy numbers, levels, themes table,
               daily/streak logic, achievements, daily reward calendar
  services/    Flutter adapters behind interfaces: storage, ads, purchases,
               analytics, notifications, audio, haptics, clock
  ui/          screens, Flame play game, overlays, theme palettes, typography
  app.dart     AppController (ChangeNotifier) owning profile, game, services
  main.dart
app/bin/sim.dart   headless bot simulation (section 5.6)
app/test/          unit tests per module; widget tests for sheets
tools/             check.sh, emu.sh (install/launch/screenshot/tap), release.sh
```

State management is one `AppController` exposed with `ListenableBuilder`;
no additional state library. `core` and `meta` never import Flutter, so they
run in plain `dart test` and in the simulator.

Contracts written as the build lands: `docs/contracts/core-engine.md`,
`economy.md`, `monetisation.md`, `analytics.md`, `visual.md`.

## 12. Analytics

Shared analytics service (`analytics-stack` skill). Project key `settle`.
No-op when the endpoint is unset. Unit id is a random UUID generated on first
launch and stored locally; no PII.

| event | dims |
| --- | --- |
| `session_started` | `first: true/false` |
| `game_started` | `mode` |
| `game_ended` | `mode`, `score: 0-499/500-1999/2000-4999/5000-9999/10000+`, `placements: <20/20-59/60-119/120+`, `continued` |
| `rewarded_completed` | `placement` |
| `rewarded_unavailable` | `placement` |
| `interstitial_shown` | |
| `purchase_completed` | `product` |
| `daily_completed` | `streak: 1/2-6/7-29/30+` |
| `level_reached` | `level: 2-4/5-9/10-19/20+` |
| `notification_permission` | `granted` |
| `theme_selected` | `theme` |

## 13. Copy and names

All player-facing strings live in one Dart file `ui/strings.dart` and are
drafted by Codex (`gpt-5.6-sol`) under the `user-facing-copy` skill, never
by the build agents. The build agents wire keys and use placeholder English
until the Codex pass lands. The store listing (title, short and long
description), privacy policy and notification text are drafted the same way
and kept in `docs/store/`.

Name: **Settle**, store title "Settle - Block Puzzle", package
`com.perch.settle`. *Orchestrator* decision 2026-09-08 from a Codex
shortlist; the package name becomes permanent at first Play upload, so the
owner must confirm it before then.

## 14. Store and compliance

- Release signing with an upload keystore generated by `tools/release.sh`
  into a path outside the repo (`~/.settle/upload.jks`), never committed.
- `flutter build appbundle --release`, R8 enabled with the plugin keep rules.
- Icon and feature graphic generated with Codex image generation; splash via
  `flutter_native_splash`.
- Play Console needs from the owner: developer account, AdMob account and
  real unit ids, the five products, the privacy policy hosted at a URL,
  data-safety answers (from `docs/store/data-safety.md`), content rating
  questionnaire, target audience 18+, ads declaration yes.

## 15. Decisions and rejected alternatives

- 2026-09-08 *orchestrator*: engine Flutter + Flame. Rejected: native
  Kotlin (slower iteration, no first-party plugins advantage), Godot (not
  installed, ads plugins third-party), web-in-WebView (worse input latency
  and ad integration).
- 2026-09-08 *orchestrator*: 8x8 rows+columns, not 9x9 with 3x3 boxes.
  Fewer cells means shorter, tenser games and bigger thumb targets.
- 2026-09-08 *orchestrator*: colour has no gameplay meaning. Colour-matching
  rules add a second thing to read and cost legibility.
- 2026-09-08 *orchestrator*: no loot boxes or random-reward purchases.
  Avoids gambling-disclosure obligations and rating complications; all
  purchases grant a stated amount.
- 2026-09-08 *orchestrator*: one daily attempt plus one rewarded second
  attempt. Unlimited attempts would let players memorise the sequence.
- 2026-09-08 *orchestrator*: combo one-move grace. A strict reset makes
  combos rare for average players; the grace keeps the banner on screen
  often enough to be the thing players chase.
- 2026-09-08 *orchestrator*: no banner ads. They cost grid space and feel.
- 2026-09-08 *orchestrator*: no leaderboard server in v1. Play Games
  leaderboards are v1.1 once the owner has a Play Console app id.
- 2026-09-08 *orchestrator*: no music. Genre norm; sound effects carry feel.
