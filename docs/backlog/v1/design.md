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

Total base weight 83. Each piece's colour index is fixed by family and
consumes no randomness, so the player learns shapes by colour: dot 0,
i2/i3 1, i4/i5 2, o2 3, o3/r23 4, l3/l4 5, l5 6, t4/s4/z4 7.

### 2.3 Turn structure
- A **set** is three pieces shown in a tray under the grid. All three must be
  placed before the next set is generated. Placement order is free.
- A placement is legal when every cell of the piece lands on an empty cell
  inside the grid. The piece is dropped by drag; the drop target is the grid
  cell under the piece's anchor after snapping (section 9.2).
- After a placement, every full row and every full column clears at once.
  A cell belonging to both a full row and a full column clears once.
- **Game over**: after any placement, and after any reroll, if none of the
  remaining pieces of the current set fits anywhere. Checked after clearing. If the set is exhausted,
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

**Daily**: one board per calendar day (local date). Seed = the day
ordinal. The **day ordinal** of a local date is
`DateTime.utc(y, m, d).difference(DateTime.utc(2026, 1, 1)).inDays` where
`y, m, d` come from the device's local `DateTime.now()`; it is DST-proof and
is the only calendar arithmetic used anywhere (seeds, streaks, reward
calendar, saved-daily validation, first-game-of-day). The director runs with skill
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
mode, seed, rng state, status `playing | over`, dayOrdinal for daily, the
director configuration snapshot `skill` and `restricted` (section 5.5,
fixed for the life of the game), the running facts `placements`,
`maxCombo` and `boardClears` that achievements and analytics need after
the game, startedAt, elapsed) serialises to JSON and back with
no loss; `serialize(deserialize(x)) == x` is a test.

All persistent app state lives in one JSON envelope, `AppData {v, profile,
savedGame?, lastResult?}`, stored under a single `shared_preferences`
string key and always written whole, so a write is all-or-nothing and no
two keys can disagree after a crash. Every mutation of `AppData`, from
any source (UI actions, reducer results, rewarded callbacks, the purchase
stream, lifecycle events, `finishGame()`), runs through one serialised
queue owned by `AppController`: `mutate(AppData Function(AppData))`
applies the function to the latest committed state, writes the envelope,
and completes only after the write succeeds; the next queued mutation
starts from the committed result. Two callbacks can therefore never
derive from the same stale state. The UI acknowledges a change, and a
payment is consumed, only after the mutation's future completes;
backgrounding enqueues a plain write. Every game carries an `id`
(`"$seed-$startedAtMs"`); `finishGame()` is a no-op when
`profile.lastFinishedGameId` already equals the game's id.

Classic seed: the app (not `core`) draws a uniformly random non-negative
32-bit int from `Random.secure()` when the game starts. The daily seed is
the day ordinal (section 3). The seed alone reproduces a game given the
same moves; `startedAtMs` in the id only makes ids unique. On launch the app resumes a saved game whose
day ordinal matches today (daily) or any (classic). A resumed game cannot
be replayed to a different outcome: the rng state is part of the save.

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

`setsGenerated` is the number of normal sets already returned. It starts
at 0, every generation rule (pressure, the 5.5 restriction) is evaluated
with its current value, and it increments after a normal set is returned.
So the first three sets of a first game (values 0, 1, 2) are restricted
and the fourth (value 3) is not. Rerolls and continues never change it.

### 5.3 Sampling a piece
Each piece's weight is `familyWeight / rotations * (cells / 4) ^ (2p - 1.6)`.
The offset 1.6 (not the 1.0 that would make `p = 0.5` the neutral base
table) was ruled on 2026-09-08 from the calibration sweep in 5.6: with
1.0 a competent player's game was too short and with 2.6 the bag was 28%
single dots and a strong player never died. At 1.6 and `p = 0.5` the
draw shares by piece size are 1 cell 10%, 2–3 cells 34%, 4 cells 39%,
5–6 cells 14%, 9 cells 3%. Sampling is weighted random over the whole
catalogue.

### 5.4 Generating a set (in this order)
`generateSet(board, rng, p, count)` returns `count` pieces (3 for a normal
set; 1–3 for a reroll, see section 6). Every rule below applies to the
`count` pieces being generated.
1. Draw `count` pieces by 5.3.
2. **Mercy**: if board fill >= 70% and `rng.next() < 0.70 - 0.40 * p`,
   replace the largest piece with a uniformly random piece of at most 3
   cells (dot, i2, i3, l3).
3. **Assist**: if `rng.next() < 0.45 * (1 - p)`, draw up to 12 candidate
   pieces by 5.3 and take the first that has a placement completing at least
   one line; if one exists, it replaces a random slot.
4. **Fit guarantee**: if no piece in the set fits the board, discard the set
   and retry from step 1. Tries 11–30 run with `p = 0`. After 30 failed
   tries: if fill < 70%, replace slot 0 with `dot` (which fits any empty
   cell) and return; otherwise return the last set as drawn (the board is
   dead and game over follows).
5. Colour each piece by family (2.2).

Invariant (tested over 10,000 random boards at every fill from 0 to 69%):
when fill < 70% a returned set always has a fitting piece. At fill >= 70%
an unfit set is possible by design; the mercy step and the 30 retries make
it rare.

### 5.5 First game ever
A classic game started while the profile has no completed **classic**
game (`profile.classicGamesCompleted == 0`; daily games do not count,
ruled 2026-09-09) is created with `restricted = true`. The two hint lines
follow the same rule. In a restricted game, while `setsGenerated < 3`
the catalogue is limited to {dot, i2, i3, o2, l3, l4, t4} and `p = 0`.
Daily games are never restricted and always use `skill = 0.5`, so the
daily sequence is identical for every player. Nothing else is persisted
for onboarding: an abandoned first game resumes under the same rule, and
the rule ends for good once one game has been completed. No modal tutorial. A single
hint line under the tray ("Drag a block onto the grid") shows until the
first placement, and a second ("Fill a row or column to clear it") shows
until the first clear. Both lines are final Codex copy (2026-09-08).

### 5.6 Tuning gates (simulation)
`app/bin/sim.dart` plays headless games with bots and prints length and
score distributions; `--sweep` runs the size-bias offsets side by side.
The build must satisfy, at skill 0.5 and seed 1:

| bot | median placements | purpose |
| --- | --- | --- |
| random legal placement | reported, not gated | it never prefers a clear, so it cannot discriminate the constant (ruling 2026-09-08) |
| greedy 1-ply (max lines cleared, then max empty cells), 2,000 games | 40–90 | a weak player reaches 2–4 minutes |
| smart (2–3 ply over the set with a board-quality heuristic), 200 games | 150–260 | a strong player reaches 8–12 minutes and still dies |

Also: the share of single-cell pieces drawn at `p = 0.5` is at most 15%.

Assist gate, measured on the greedy bot's 2,000 games at skill 0.5, over
every set returned by 5.4 (the simulator never rerolls or continues), using
the board at generation time. Only sets generated with fill in [30%, 70%)
count. Bucket A: `p <= 0.3`; bucket B: `p >= 0.8`. A set counts as
"assisted" when at least one of its pieces has a placement completing a
line. Required: `rate(A) >= 0.35` and `rate(A) >= rate(B) + 0.08`. Print
both rates and both denominators. If the numbers fall outside these bands,
tune the constants in 5.2–5.4 and record the change here.

## 6. Continue and reroll

- **Continue** (`continueGame` placement): offered once per game on the game
  over sheet (section 6.1). Removes every block in the three rows with the
  most filled cells (ties: topmost); this is a demolition of occupied
  cells, not a line clear: it awards no points, does not touch the combo,
  and the result lists only the cells that held a block (ruled
  2026-09-09). It then discards the current set, generates a fresh
  three-piece set with `p = 0`, and play resumes with the same score,
  combo and `setsGenerated`. Paid by one rewarded ad, or by 150 coins.
  Ad-free buyers get it free once per game.
- **Reroll** (`reroll` placement): from the tray during play, replaces the
  remaining unplaced slots of the current set. The director generates
  `count = remaining` pieces by 5.4 at the current pressure (so the fit
  guarantee applies to exactly the pieces the player receives), and they
  fill the unplaced slots in slot order. `setsGenerated` does not advance.
  Paid by one rewarded ad or 50 coins. At most 3 rerolls per game in total.

### 6.1 Game over, in two states
A game reaching game over is saved with `status = over` before anything is
shown. The game over sheet then has two states:

1. **Continue offer** (only if `continuesUsed == 0`): score and best so far,
   the Continue button (rewarded, 150 coins, or free for ad-free buyers)
   and an "End game" link. No progression is awarded in this state. Killing
   the app here resumes to this state.
2. **Final**: reached by "End game", or directly when a continue is not
   available. `AppController.finishGame()` runs once: it computes score →
   best, coins (7.1), XP and level (7.2), achievements (7.7), daily
   completion (3), writes the profile and deletes the saved game in one
   awaited storage write, and stores a `LastGameResult {gameId, mode,
   score, baseCoins, bonusCoins, totalCoins, xp, levelUps,
   newAchievements, streakAfter, elapsedMs, dayOrdinal?, doubled: false}`
   (`elapsedMs` feeds the interstitial policy after a relaunch;
   `dayOrdinal` is set for daily results and the second attempt is
   offered only while it equals today's ordinal) where `baseCoins` is the
   7.1 per-game amount, `bonusCoins` everything else awarded at this
   finish (first-game-of-day, level-ups, achievements) and `totalCoins`
   their sum. The sheet then shows the result, Double coins (rewarded,
   only while `doubled == false`; on reward it adds `baseCoins` again,
   sets `doubled = true`, and persists), Play again and Home.

   `lastResult` is pending until dismissed: it stays in the envelope, the
   app reopens the matching result sheet on launch if it is present, and
   it is cleared in the same mutation that handles Play again, Home, or
   the start of a second daily attempt. The first-game-of-day +25 is added in `finishGame()` and is not
   doubled.

   In daily mode the final state is the **Daily result** sheet instead:
   today's score and today's best (they differ only on a second attempt),
   the streak with today's increment, coins earned, Double coins (as
   above), Share (a text card, section 9.1), Second attempt (rewarded,
   shown only while `profile.dailySecondAttemptUsed != dayOrdinal`; on
   reward one mutation sets the flag and stores the new daily game as
   `savedGame` in the same envelope write, then the app navigates to
   Play), and Home. There is no Play again in daily. `finishGame()`
   records `profile.dailyBest[dayOrdinal]`, `dailyAttempts[dayOrdinal]`
   and the streak update (7.5) in the same envelope write.

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
`L` (L >= 2): `round(150 * (L - 1) ^ 1.7)`, the formula being
authoritative: L2 150, L3 487, L5 1,583, L10 6,285, L20 22,386,
L30 45,938. A level-up shows on the game over sheet
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
day 1–7 of the cycle = 25, 50, 75, 100, 150, 200, 400. The profile holds
`rewardCycleDay` (1–7), `lastRewardClaimOrdinal` and
`rewardDismissedOrdinal`. The sheet is offered when today's ordinal is
after the profile's creation day, differs from `lastRewardClaimOrdinal`
and differs from `rewardDismissedOrdinal`; it is offered again on every
return to Home that day until claimed or dismissed once ("Not now" sets
`rewardDismissedOrdinal = today`). The cycle advances only on a successful
claim: if `lastRewardClaimOrdinal == today - 1` the claim pays
`rewardCycleDay` and then advances it (wrapping 7 to 1); otherwise the
claim pays day 1 and sets `rewardCycleDay = 2`. The first offer after
install is therefore always day 1. One claim per day; claiming is a
button, never automatic.

### 7.5 Streak and streak freeze
The daily streak is the number of consecutive local days with a completed
daily attempt. The profile holds `lastCompletedOrdinal` (null until the
first completed daily, always factual) and `streakReconciledOrdinal`
(the ordinal through which reconciliation has been applied, null
initially). On launch and before recording a completion, the app
reconciles for `today`: if `lastCompletedOrdinal` is null, nothing.
Otherwise `from = max(lastCompletedOrdinal, streakReconciledOrdinal ??
lastCompletedOrdinal)` and `missed = today - from - 1`. If `missed <= 0`
(completed today or yesterday) nothing changes. If `0 < missed <=
freezesHeld`, `missed` freezes are consumed and the streak is kept. If
`missed > freezesHeld`, the streak resets to 0 and no freeze is consumed.
A streak of 0 is never defended: freezes are consumed only while `streak >
0`. In both of the last two cases `streakReconciledOrdinal = today - 1`,
so a gap is charged exactly once and a later launch on the same day is a
no-op. A device clock moved backwards never destroys a streak (ruled
2026-09-09): a daily cannot be started for an ordinal below
`lastCompletedOrdinal`, and a completion whose ordinal is below it
leaves the streak, the anchor and the reconciliation marker unchanged. Completing today's daily compares against the same anchor
(`max(lastCompletedOrdinal, streakReconciledOrdinal)`), sets
`lastCompletedOrdinal = today` and increments the streak (from 0 after a
reset). Freezes cost
200 coins, at most 2 held. The home screen shows the streak and whether a
freeze is held; tapping the streak chip opens the **Streak sheet**: the
current streak, freezes held (0–2), and a "Buy a freeze" button showing
the price. The button is disabled with the player's coin balance shown
beside it when coins are under 200 or two freezes are already held, with
a link to the Shop in the first case. Buying runs
`AppController.buyStreakFreeze()` as one mutation (deduct and add).

### 7.6 Skill estimate
`skill` in [0,1], persisted. After each completed classic game:
`skill = 0.8 * skill + 0.2 * clamp(score / 4000, 0, 1)`. Starts at 0.35.
4,000 sits between the greedy bot's median score (about 500) and the
smart bot's (about 3,000) at offset 1.6, so a competent human lands near
0.5–0.75 (ruled 2026-09-08 from the sweep).

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

Policy state is persisted in the profile: `gamesCompleted`,
`gamesSinceInterstitial`, `lastInterstitialClosedAt` and
`lastRewardedClosedAt` (epoch milliseconds, 0 when never). Transitions:
`gamesCompleted` and `gamesSinceInterstitial` increment inside
`finishGame()`; `gamesSinceInterstitial` resets to 0 and
`lastInterstitialClosedAt` is set to `now` when the ad reports it was
shown (`onAdShowedFullScreenContent`), and `lastInterstitialClosedAt` is
set again on dismissal; a failed load or failed show changes nothing and
the next load is retried with backoff; the same two-step rule applies to
`lastRewardedClosedAt`. Process death during an ad therefore still counts
it as shown. Elapsed time is `now - stored`; a negative value (clock moved
back) counts as not elapsed, and if it is more negative than 24 h the
stored value is reset to `now`. The counters survive restarts, so the caps
cannot be reset by relaunching.

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
acknowledged or consumed through the plugin under the protocol below;
non-consumables are restored on launch and through a "Restore purchases"
button in Settings. No server-side receipt validation in v1; the risk is
accepted and recorded.

Purchase protocol (`PurchaseService`):
1. The `purchaseStream` listener is subscribed once, at app start, before
   any screen, and lives for the process.
2. Coin packs are bought with `autoConsume: false`. The idempotency key
   of an update is the Play purchase token,
   `verificationData.serverVerificationData` (never `purchaseID`, which
   Android derives from a nullable order id). An update in state
   `purchased` or `restored` with an empty token is logged and ignored.
   Otherwise: if the token is in `profile.pendingPurchaseTokens` or
   `profile.completedPurchaseTokens`, skip the grant and go straight to
   step 3; else grant (coins added, or the non-consumable flag set), add
   the token to `pendingPurchaseTokens` (unbounded; it only ever holds
   purchases whose consume or acknowledge has not yet succeeded), and
   await the mutation. When step 3 succeeds the token moves to
   `completedPurchaseTokens` (the last 200 kept). A purchase whose
   consumption keeps failing therefore stays deduplicated for ever.
3. Then, whether or not the grant was new: consumables are consumed
   (`InAppPurchaseAndroidPlatformAddition.consumePurchase`) and
   non-consumables acknowledged (`completePurchase`, when
   `pendingCompletePurchase` is true). A crash between grant and consume
   replays at the next launch as a `purchased` update whose id is already
   granted; step 2 skips the grant and step 3 finishes the transaction.
4. `pending` shows the shop item in a pending state; `error` and `canceled`
   dismiss it with a short message. Independently of status, after every
   non-pending update whose `pendingCompletePurchase` is true,
   `completePurchase` is called (this is the plugin's own contract; an
   unacknowledged purchase is refunded by Play within three days). On
   launch `restorePurchases()` runs after the listener is attached.

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
  combo in the gutter, pause icon top right), 8x8 grid in its well, a
  fixed-height band holding the reroll pill (right) and the first-game
  hint (centre), tray with three pieces. Pause opens a sheet with Resume,
  Home, sound and haptics.
- **Game over sheet**: the two states of 6.1. Continue offer: score, best,
  Continue (rewarded/coins/free), End game. Final: score, best (with "New
  best" state), coins earned, level progress, Double coins (rewarded), Play
  again, Home.
- **Daily result**: the daily final state of 6.1 (score, best, streak,
  coins, Double coins, Share, Second attempt, Home). The share card is
  plain text: the game name, the day number, the score and the streak.
- **Shop**: Remove Ads, three coin packs, theme pack; Restore purchases.
- **Themes**: grid of twelve swatches with lock state and unlock condition.
- **Settings**: sound, haptics, reminder notification, privacy options,
  restore purchases, version, privacy policy link.
- **Achievements**: list with progress and claimed state.

Navigation is a `Navigator` stack; Play is full-screen; sheets are modal
bottom sheets. Back from Play pauses.

### 9.2 Drag and drop
A tray piece is picked up on touch-down. While dragging it renders at full
grid scale, offset 64 px above the finger so the thumb never hides it,
with the "held" treatment of `styles.md` (drop shadow and light rim). The
target cell is the grid cell under the piece's top-left cell after
rounding; when the placement is legal the target cells show the ghost
treatment (18% fill plus a full-colour ring) and every cell of any line
the placement would complete shows the line-imminent ring. Release with a
legal target places the piece; release elsewhere flies the piece back to
the tray in 200 ms.

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
Ruled 2026-09-08 from the round-1 comps: concept "Well" with the transplants
and the extra controls recorded in `docs/styles.md`, which is the binding
visual authority (palette with measured contrast, geometry, type ladder,
tile-state invariants). Exemplar frames are in `assets/exemplar/`. Where
this document and `styles.md` disagree on a visual matter, `styles.md`
wins.

## 10. First-session flow

Launch -> splash (native, < 1 s) -> consent form if required -> home. First
Play tap goes straight into a classic game with the first-game catalogue
(5.5). No account, no name, no permissions asked. The reminder notification
permission is requested only after the second completed game, from a sheet
that explains it ("Get a reminder when the daily puzzle is ready"), with a
"Not now" that never re-asks. The daily reward sheet is not shown on day 1.

Reminder: one local notification, scheduled inexactly for 19:00 local
time on the first local date after today (never today's 19:00, since the
player has just used the app). On every open the pending reminder is
cancelled; on every background it is recomputed from the current local
time zone and rescheduled. Text (Codex, 2026-09-08): title "Daily puzzle
ready", body "Today's puzzle is ready to play."

## 11. Technical shape

Flutter 3.41 / Dart 3.11, Android only in v1 (minSdk 24, targetSdk from the
Flutter template, currently 36). Packages: flame 1.38, flame_audio 2.12,
google_mobile_ads 9.1, in_app_purchase 3.3, shared_preferences 2.5,
flutter_local_notifications 22.3, timezone 0.11, flutter_timezone,
package_info_plus, url_launcher, share_plus. `in_app_purchase_android`
resolves to 0.5.0 (Play Billing 8.0.0, the version Play requires since
2026-08-31); 0.5.1+ needs Flutter 3.44, so do not bump it without
upgrading the SDK.

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

Service wiring lives in `app/lib/bootstrap.dart`: `Future<AppServices>
bootstrap()` builds every service (storage, clock, audio, haptics, ads,
purchases, analytics, notifications) and `main.dart` only awaits it,
constructs `AppController(services)`, awaits `controller.start()`, and
runs the app. `start()` loads the envelope, reconciles the profile, then
calls `services.purchases.start(this)` and `services.ads.start(this)`:
the services receive the controller through narrow sink interfaces
declared beside them (`PurchaseSink` with `applyPurchase(productId,
token)` and `markPending`/`showMessage`; `AdSink` with the policy
transitions of 8.2), and every callback they raise lands in the
controller's mutation queue. The service interfaces, their sinks and the
fakes are created in phase 2b so the UI compiles; phase 4 owns those
files from then on and adds the real implementations, including the
process-lifetime purchase listener, without editing `main.dart` or
`app.dart`.

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
