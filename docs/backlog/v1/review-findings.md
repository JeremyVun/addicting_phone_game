# v1 adversarial review — findings

Probes live in `app/test/probes/**` (63 tests, 52 passing, 11 failing) and run
with `cd app && flutter test test/probes`. A failing probe is a defect or an
open ruling; nothing in `app/lib/**` was changed by this review.

## Defects

| id | sev | invariant | probe | symptom | suspected location |
| --- | --- | --- | --- | --- | --- |
| D1 | HIGH | design 6: a continue is paid by *one* rewarded ad **or** 150 coins | `money_probe_test.dart` — `a continue paid by a rewarded ad is never also charged in coins` | the player watches the ad and is charged 150 coins as well | `AppController.continueGame` re-reads `continuePayment` after the await, and the real ads service reports not-ready between show and reload |
| D2 | HIGH | money: coins never go negative | `money_probe_test.dart` — `coins never go negative when a rewarded continue is granted` | a 0-coin player who takes the rewarded continue lands on -150 coins | same line; the rewarded branch of `continueGame` never checks the balance that the coin branch checks |
| D3 | HIGH | money: a reroll is paid once, coins never go negative | `money_probe_test.dart` — `two unawaited coin rerolls spend one price` | two taps before the first write lands spend 100 coins from a 50-coin balance and leave -50 | `AppController.rerollWithCoins` tests `canReroll`/`coins` outside the mutation |
| D4 | MEDIUM | a refused action is a no-op, not an error | `money_probe_test.dart` — `two unawaited coin continues charge once` | the second concurrent continue throws `StateError: continue already used` out of the mutation queue to the UI | `continueAvailable` is read outside the mutation; `Game.continueGame` throws inside it |
| D5 | HIGH | `Board.filledCount`/`fill` count the cells on the grid | `rules_probe_test.dart` — `filledCount still counts the cells on the grid`, `a board with cells on it never reports empty` | after a continue the count is short by every empty cell in the three cleared rows: `fill` under-reports (mercy and the 5.4 fill branch misfire) and a board holding 15 cells can report `isEmpty`, which is the +300 board-clear bonus and the `board_clear` achievement | `Board.clearLines` decrements `filled` per cell of a cleared line without checking occupancy; `Game.continueGame` feeds it rows that are not full |
| D6 | HIGH | design 4: `fromJson(toJson(s)) == s`, a resumed game replays identically | `rules_probe_test.dart` — `a continued state round trips` | a continued game saved and reloaded is a different state (`fromJson` recomputes `filledCount` from the grid), so a relaunch mid-continue can generate different pieces | same root as D5 |
| D7 | MEDIUM | design 4: a mutation completes only after the write succeeds | `persistence_probe_test.dart` — `a write that fails leaves the envelope and the controller agreeing` | when the envelope write throws, `_data` already holds the unwritten state, so the app keeps playing on state the disk never saw | `AppController.mutateWith` assigns `_data` before awaiting `storage.save` |
| D8 | MEDIUM | a storage failure never escapes as an unhandled error | `persistence_probe_test.dart` — `a failed write behind a fire-and-forget mutation is handled` | the error from an `unawaited(mutate(...))` (every `place()` write and all four `AdSink` transitions) reaches no handler and surfaces as an unhandled async exception | `AppController.mutateWith`'s `completer.completeError` with no listener |

D1–D4 are one family: the guard that decides whether the player can afford the
action runs outside the mutation that spends. `Themes.buy` and
`DailyRewards.claim` re-check inside the mutation and are safe — that is the
shape the money paths need.

## Rulings needed

| id | the two readings | recommendation |
| --- | --- | --- |
| R1 | A device clock moved backwards. (a) Design 7.5 says `lastCompletedOrdinal` is "always factual", so a daily completed on an earlier ordinal records that ordinal and restarts the streak at 1 — today's code. (b) A live streak must survive a clock move or a flight west; the run is data, not a clock reading. Today's behaviour also rewinds the anchor, so the next real day reads as a multi-day gap and breaks the streak again, and past ordinals hand out extra daily attempts. Probe: `streak_time_probe_test.dart` — `a device clock moved backwards never destroys a streak` (fails). | (b): ignore a completion whose ordinal is below `lastCompletedOrdinal` for streak purposes, and refuse to start a daily for an ordinal already behind it. |
| R2 | Who spends the first-game catalogue. (a) Design 5.5 literally: "a classic game started while `profile.gamesCompleted == 0`", and `gamesCompleted` counts daily games too, so a player whose first game is the daily never sees the onboarding catalogue or the hints. (b) Design 10's intent is that the *first game the player plays a classic board* is eased. Probe: `onboarding_probe_test.dart` — `the restriction is spent by a finished game, not by any finished game` (fails). | (b): key the restriction and `showFirstGameHints` on completed **classic** games. If (a) stands, say so in design 5.5 and in the app-shell contract, because the daily card is on Home from launch. |
| R3 | What a continue's row clear is. (a) It is a clear: `ClearResult.cells` lists all 24 cells of the three rows, so the UI animates empty cells and `filledCount` is decremented for them. (b) It is a demolition of occupied cells only. | (b): give `Board` a `clearRows` that counts only occupied cells (this is also the D5/D6 fix), and let `ClearResult.cells` list only cells that held a block. |

## Probes that passed

**Rules (`rules_probe_test.dart`)**
- game over fires exactly when nothing in hand fits, over 200 full games.
- a reroll ends the game only when the new set fits nowhere (120 games).
- a continue always drops below 70% fill and resumes with a playable set (200 games).
- score, combo, the one-move grace, `maxCombo` and `boardClears` match design 2.4 recomputed independently over 60 full games.
- the combo grace restated as a rule table.
- a restricted game draws only the seven families for its first three sets.
- a daily game ignores a caller's `skill` and `restricted` and gives every player the same set.
- two replays of one seed and its moves match through a reroll and a continue.
- fresh, mid-game, over, rerolled and daily states all round trip through JSON.

**Director (`director_probe_test.dart`)**
- a checkerboard where only a dot fits always gets a fitting set, for counts 1–3 and 500 draws.
- adversarial scattered boards at every fill from 0 to 69% always get a fitting set.
- a board with a single free cell is always served something (63/64 full).
- a full board is correctly *not* rescued and reports an unfit set.
- mercy and assist never leave a set unplayable below 70% fill, at five pressures.
- `generateSet` returns exactly `count` pieces for 1–3 and throws outside it.
- sets 0, 1, 2 are restricted at `p = 0` and set 3 is not.
- a reroll and a continue never advance `setsGenerated` or extend the restriction.

**Money (`money_probe_test.dart`)**
- a dismissed rewarded ad grants no reroll, no continue and no doubled coins.
- double coins pays `baseCoins` once even from two concurrent calls.
- a reroll at the three-per-game cap refuses without charging and without showing an ad.
- the ad-free free continue is once per game and available again in the next game.
- a long sequence of freeze, theme, reroll, continue and finish never drives coins negative.

**Persistence (`persistence_probe_test.dart`)**
- `place`, `applyPurchase`, `doubleCoins`, `claimDailyReward` and `buyStreakFreeze` interleaved without awaiting commit the same envelope as the sequential run.
- `finishGame` is idempotent across a relaunch over the same storage.
- a pending `lastResult` reopens the sheet once and is cleared exactly once.
- a crash on the second-attempt write leaves the flag and the new board both absent, and the attempt is still offered after the relaunch.
- every write of the second attempt carries the flag and the board together.

**Purchases (`purchase_probe_test.dart`, scripted gateway into the real controller)**
- a crash-replayed token grants once however often it replays.
- a token whose consume never succeeds is granted once and stays pending for ever.
- 250 completed tokens trim to 200 without re-granting a still-pending purchase.
- an empty token, an empty product id and an unknown product grant nothing and record nothing.
- a restored non-consumable after a relaunch grants nothing again.

**Streak and time (`streak_time_probe_test.dart`)**
- reconciling twice on the same day charges the gap once and the kept streak still increments.
- the full gap 1–4 x freezes 0–2 matrix through the controller and a relaunch, coins never negative.
- a daily run across a 25-hour DST day counts three days.
- two concurrent reward claims pay one day.
- the reward cycle pays 25/50/75 on consecutive days and restarts at 25 after a missed day.
- a clock moved back more than 24 h is repaired on launch and the interstitial cooldown is free again.
- the interstitial cooldown and the 30 s game-duration rule are exact at their boundaries.

**Onboarding (`onboarding_probe_test.dart`)**
- the first classic game is restricted and the hints are on.
- the second classic game is unrestricted and the hints are off.
