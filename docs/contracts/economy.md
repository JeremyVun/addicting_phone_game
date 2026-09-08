# Contract: economy (`app/lib/meta/**`)

As built in phase 3a. Pure Dart: nothing under `meta/` imports
`package:flutter` or `app/lib/core/**`; the only packages used are `dart:*`
and `package:collection`. There is no clock class and no `DateTime.now()`
anywhere in `meta/` — every function that needs the time takes
`DateTime now` (a *local* `DateTime`) as an argument. Every type here is
immutable, JSON-serialisable with a `v` field, and compares by deep value.

`import 'package:settle/meta/meta.dart';` re-exports the whole package.

## 1. API

| unit | entry points |
| --- | --- |
| `Calendar` | `dayOrdinal(DateTime localNow) -> int`, `isSameLocalDay(a, b)`, `epoch` |
| `Levels` | `xpForLevel(L)`, `levelFor(xp)`, `progressWithinLevel(xp)`, `levelUpReward(newLevel)` |
| `Themes` | `all` (12 `ThemeSlot`s), `bySlot(n)`, `unlockedBy(profile)`, `isUnlocked(profile, slot)`, `canBuy(profile, slot)`, `buy(profile, slot)`, `select(profile, slot)` |
| `Economy` / `Products` | every constant (section 2) and the 5-product table |
| `PlayerProfile` | value type with `copyWith`, `toJson`, `fromJson`, `initial(analyticsUnitId:, now:)`, derived `level`, `levelProgress`, `createdAt` |
| `GameSummary` | the value the app hands to meta at game over |
| `Progression` | `finish(profile, summary, now) -> FinishOutcome`, `doubleCoins(profile, lastResult) -> (profile:, result:)` |
| `LastGameResult` | the persisted game-over result |
| `DailyRewards` | `claimable(profile, now)`, `claim(profile, now)`, `dismiss(profile, now)`, `nextCycleDay(profile, now)`, `nextReward(profile, now)` |
| `Streaks` | `onDailyCompleted(profile, ordinal)`, `reconcile(profile, now)`, `canBuyFreeze(profile)`, `buyFreeze(profile)` |
| `Achievements` | `all` (16), `byId(id)`, `coinsFor(ids)`, `check(before, after, summary) -> List<String>` |
| `Purchases` | `grant(profile, productId, purchaseToken)`, `markPurchaseCompleted(profile, token)`, `alreadyGranted(profile, token)` |
| `InterstitialPolicy` | `shouldShow({profile, adFree, gameDurationMs, loaded, now})`, `reconcileClock`, `afterInterstitialShown/Closed`, `afterRewardedShown/Closed`, `afterGameCompleted` |
| `Reminders` | `nextReminderTime(DateTime localNow) -> DateTime` |
| `Buckets` | `score`, `placements`, `streak`, `level` -> the design 12 strings |

Every mutating function is total and refusing: when a rule forbids the
action (not enough coins, cap reached, already granted, already claimed,
already finished) it returns the *unchanged* profile. Nothing throws.

## 2. Constants (`economy.dart`), with their design section

| constant | value | section |
| --- | --- | --- |
| `coinsScoreDivisor` / `coinsMinPerGame` / `coinsMaxPerGame` | 50 / 5 / 200 | 7.1 |
| `firstGameOfDayBonus` | 25 | 7.1 |
| `xpScoreDivisor` | 10 | 7.2 |
| `levelXpFactor` / `levelXpExponent` | 150 / 1.7 | 7.2 |
| `levelUpCoinsPerLevel` | 50 (x new level) | 7.2 |
| `dailyRewardCycle` | 25, 50, 75, 100, 150, 200, 400 | 7.4 |
| `dailyRewardCycleLength` | 7 | 7.4 |
| `freezeCost` / `maxFreezesHeld` | 200 / 2 | 7.5 |
| `initialSkill` / `skillRetain` / `skillLearn` / `skillScoreCap` | 0.35 / 0.8 / 0.2 / 4000 | 7.6 |
| `continueCost` / `maxContinuesPerGame` | 150 / 1 | 6, 8.1 |
| `rerollCost` / `maxRerollsPerGame` | 50 / 3 | 6, 8.1 |
| `interstitialMinLifetimeGames` | 3 | 8.2 |
| `interstitialMinGamesSince` | 2 | 8.2 |
| `interstitialCooldownMs` | 90 000 | 8.2 |
| `rewardedCooldownMs` | 45 000 | 8.2 |
| `interstitialMinGameDurationMs` | 30 000 | 8.2 |
| `clockRollbackResetMs` | 86 400 000 | 8.2 |
| `completedTokensCap` | 200 | 8.3 |
| `reminderHourLocal` | 19 | 10 |

Theme unlocks (7.3) live in `Themes.all`: slot 1 default; slots 2–10 at
levels 2, 4, 6, 9, 12, 16, 20, 25, 30; slots 11 and 12 for 1 500 and
3 000 coins. Names in slot order: Obsidian, Dawn, Meadow, Coral, Glacier,
Desert, Storm, Lavender, Ember, Plum, Pearl, Lagoon. Colours are UI.

Products (8.3): `remove_ads` (ad-free), `coins_small` 500,
`coins_medium` 3 000, `coins_large` 8 000, `theme_pack_all` (all twelve
themes; sets `themePackOwned` and fills `unlockedThemes`).

Achievements (7.7): the 16 ids, names, descriptions and coin rewards are in
`Achievements.all`, verbatim from the design table (total 2 135 coins).

## 3. `Progression.finish` — the sequence, in order

1. If `profile.lastFinishedGameId == summary.gameId`, return
   `FinishOutcome(profile: unchanged, result: null, alreadyApplied: true)`.
   Nothing else runs. `result` is null **only** in this case; the caller
   keeps the `lastResult` already in the envelope.
2. `baseCoins = max(5, min(200, score ~/ 50))` (7.1).
3. First game of the local day: `+25` when
   `profile.lastFirstGameOfDayOrdinal != dayOrdinal(now)`; the field is then
   set to today's ordinal. Not doubled by Double coins.
4. `xp += score ~/ 10`; every level crossed is listed in `levelUps` and pays
   `50 x level`.
5. `gamesCompleted += 1`, `gamesSinceInterstitial += 1`,
   `lastFinishedGameId = summary.gameId`; classic games also
   `classicGamesCompleted += 1` (design 5.5's first-game restriction and the
   tray hints read that field, ruled 2026-09-09).
6. Classic only: `bestClassic = max(...)` and
   `skill = 0.8 * skill + 0.2 * clamp(score / 4000, 0, 1)` (7.6). A daily
   game never moves `skill`.
7. Daily only, at `ordinal = summary.dayOrdinal ?? dayOrdinal(now)`:
   `bestDaily = max(...)`, `dailyBest[ordinal] = max(...)`,
   `dailyAttempts[ordinal] += 1`, then `Streaks.onDailyCompleted`.
8. `Achievements.check(profileBefore, profileSoFar, summary)`; the new ids
   are added and their coins paid. Conditions are read from the profile
   *after* steps 3–7, so `games_10`, `streak_3` and `level_10` see this
   game's own effect.
9. `LastGameResult` is built with `baseCoins`, `bonusCoins`
   (first-of-day + level-up + achievement coins) and `totalCoins`
   (their sum, exactly the increase in `profile.coins`), plus `elapsedMs`
   and, for a daily, `dayOrdinal`.

`Progression.doubleCoins(profile, lastResult)` adds `baseCoins` (never
`bonusCoins`) once and sets `doubled: true`; called again with a result
that already has `doubled` it returns both values unchanged.

## 4. Streak / freeze state machine (7.5)

Two ordinals drive it. `lastCompletedOrdinal` (null until the first completed
daily) is always factual: the last day the player actually finished a daily.
`streakReconciledOrdinal` (null initially) is the last day already accounted
for by `reconcile`, whether it was covered by a freeze or lost.

`anchor = max(lastCompletedOrdinal, streakReconciledOrdinal ?? lastCompletedOrdinal)`
— the last day that counts as "kept". `missed = today - anchor - 1`.
`Streaks.reconcile(profile, now)` runs on launch and is idempotent.

| state | condition | streak | freezes | `streakReconciledOrdinal` |
| --- | --- | --- | --- | --- |
| never played a daily | `lastCompletedOrdinal == null` | — | — | — |
| up to date | `missed <= 0` | unchanged | unchanged | unchanged |
| covered | `0 < missed <= freezesHeld` and `streak > 0` | unchanged | `- missed` | `today - 1` |
| broken | `missed > freezesHeld` | **0** | unchanged | `today - 1` |

`onDailyCompleted(profile, ordinal)`: `ordinal <= anchor` -> unchanged (a
second daily attempt never extends the streak, and a device clock moved
backwards never destroys one: streak, `lastCompletedOrdinal` and
`streakReconciledOrdinal` all stand, ruled 2026-09-09);
`anchor == ordinal - 1` -> `streak + 1`; anything else -> `streak = 1`. Except
in the unchanged case it sets `lastCompletedOrdinal = ordinal`. Reading the *anchor*
rather than `lastCompletedOrdinal` is what makes a freeze work: reconcile
marks yesterday as kept, so today's daily continues the run.

A daily for a stale ordinal (device date behind the anchor, as after a
westward date-line crossing) may still be started and played; its best and
attempt are recorded under that ordinal and only the completion's effect on
the streak is ignored (design 7.5, ruled 2026-09-09).

Two rules the design left open, decided here:

- **A gap wider than the freezes held consumes nothing.** Freezes are spent
  only when they cover the whole gap; a 2-day gap with 1 freeze resets the
  streak and keeps the freeze. Since at most 2 are held, `missed >= 3`
  always resets.
- **A dead streak is never protected.** When `streak == 0` no freeze is
  consumed however small the gap; without this, every day after a reset
  would spend one freeze defending a streak of zero.

`buyFreeze` refuses (returns the profile unchanged) when `coins < 200` or
`freezesHeld == 2`; `canBuyFreeze` is the same predicate for the UI's
disabled state.

## 5. Daily reward calendar (7.4 + design 10)

State: `rewardCycleDay` (1–7, starts at 1), `lastRewardClaimOrdinal` (null),
`rewardDismissedOrdinal` (null).

- `claimable` is true when today's ordinal is greater than the creation-day
  ordinal (nothing on the player's first day, design 10) and today is neither
  `lastRewardClaimOrdinal` nor `rewardDismissedOrdinal`.
- `claim` pays `dailyRewardCycle[cycleDay - 1]` where `cycleDay` is
  `rewardCycleDay` when `lastRewardClaimOrdinal == today - 1` and `1`
  otherwise; then `rewardCycleDay = cycleDay % 7 + 1` and
  `lastRewardClaimOrdinal = today`. The first claim after install therefore
  always pays day 1, however long after install it happens.
- `dismiss` sets `rewardDismissedOrdinal = today`; a dismissed day breaks the
  run exactly like a missed one.
- The cycle is driven by *claims*, not by games played.

## 6. Interstitial policy (8.2)

`shouldShow` is true only when all seven hold: not `adFree`; an
interstitial is `loaded`; `gamesCompleted >= 3`;
`gamesSinceInterstitial >= 2`; `gameDurationMs >= 30 000`; at least 90 000 ms
since `lastInterstitialClosedAt`; at least 45 000 ms since
`lastRewardedClosedAt`.

Elapsed-time rule: `now - stored >= threshold`. A stored `0` means never and
trivially passes; a clock moved back makes the difference negative, which
counts as *not* elapsed. `reconcileClock(profile, now)` resets any
stamp more than 24 h in the future to `now` — call it on launch, since
`shouldShow` is a predicate and cannot repair state.

Transitions: `finish` increments `gamesCompleted` and
`gamesSinceInterstitial`; `afterInterstitialShown` zeroes
`gamesSinceInterstitial` and stamps `lastInterstitialClosedAt`;
`afterInterstitialClosed` stamps it again; `afterRewardedShown` and
`afterRewardedClosed` stamp `lastRewardedClosedAt`. A failed load or show
changes nothing.

## 7. Purchases (8.3)

The idempotency key is the **Play purchase token**
(`verificationData.serverVerificationData`), never `purchaseID`. Two lists
hold it:

- `pendingPurchaseTokens` — granted, but the consume/acknowledge is not yet
  confirmed. Unbounded: losing one of these would grant twice.
- `completedPurchaseTokens` — the transaction is finished. Trimmed to the
  most recent 200 in completion order.

`grant(profile, productId, purchaseToken)` is a no-op when the token is in
either list, when the token is empty, or when the product id is unknown
(nothing is recorded then, so a later fix can still grant). Otherwise it
applies the grant and adds the token to pending.
`markPurchaseCompleted(profile, token)` moves the token from pending to
completed and trims; it is idempotent, and a token that was never pending is
still recorded as completed so a replayed update cannot re-grant.

## 8. JSON

`PlayerProfile.toJson()` (`v: 2`; `classicGamesCompleted` is the only field
v2 adds, and a v1 envelope reads it as `gamesCompleted` so existing testers
keep their onboarding state). Int-keyed maps are written with string
keys; sets are written as sorted lists.

```json
{
  "v": 2,
  "coins": 0, "xp": 0, "gamesCompleted": 0, "classicGamesCompleted": 0,
  "bestClassic": 0, "bestDaily": 0, "skill": 0.35,
  "unlockedThemes": [1], "selectedTheme": 1,
  "achievements": [],
  "rewardCycleDay": 1, "lastRewardClaimOrdinal": null,
  "rewardDismissedOrdinal": null,
  "streak": 0, "lastCompletedOrdinal": null,
  "streakReconciledOrdinal": null, "freezesHeld": 0,
  "dailyBest": {"240": 1500}, "dailyAttempts": {"240": 1},
  "dailySecondAttemptUsed": null, "lastFirstGameOfDayOrdinal": null,
  "adFree": false, "themePackOwned": false,
  "pendingPurchaseTokens": [], "completedPurchaseTokens": [],
  "lastFinishedGameId": null,
  "gamesSinceInterstitial": 0,
  "lastInterstitialClosedAt": 0, "lastRewardedClosedAt": 0,
  "soundEnabled": true, "hapticsEnabled": true,
  "remindersEnabled": false, "reminderPermissionAsked": false,
  "analyticsUnitId": "", "createdAtMs": 0
}
```

Every "ordinal" field is `null` when there is no such day yet; `0` on the two
ad stamps is "never" (8.2). `level` is derived from `xp` and is not stored.

`LastGameResult.toJson()` (`v: 1`):

```json
{
  "v": 1,
  "gameId": "seed-7:1748000000000",
  "mode": "daily",
  "score": 4820,
  "baseCoins": 96, "bonusCoins": 175,
  "xp": 482,
  "levelUps": [4, 5],
  "newAchievements": ["score_2500", "combo_5"],
  "streakAfter": 12,
  "elapsedMs": 214000,
  "dayOrdinal": 240,
  "doubled": false
}
```

`totalCoins` is derived (`baseCoins + bonusCoins`) and not stored.
`dayOrdinal` is null for a classic game; `elapsedMs` is the finished game's
duration, which is what the interstitial policy's 30 s rule reads.
`GameSummary` also round trips, for logs and test fixtures; it is not part
of the persisted envelope.

## 9. Invariants the tests enforce

- `dayOrdinal` depends only on the local y/m/d: it advances by exactly 1
  across a 23-hour and a 25-hour DST day and is constant within a local day.
- The level table is exactly 150, 487, 1 583, 6 285, 22 386, 45 938 at
  L2, L3, L5, L10, L20, L30, and `levelFor` inverts it at each boundary.
- Coins per game are 5 at scores 0, 249 and 250, 6 at 300, 200 at 10 000
  and above.
- The first-game-of-day +25 is paid once per local day ordinal, is reported
  in `bonusCoins`, and is never doubled.
- `finish` is idempotent on `gameId`; `doubleCoins` is idempotent on
  `doubled`.
- The whole gap x freeze matrix (gaps 0–4 against 0–2 freezes held),
  reconcile called twice on the same day, a covered gap still incrementing
  when today is played, and a reset streak never spending a later freeze.
- The reward cycle advances on consecutive claims, wraps 7 -> 1, restarts at
  1 after a missed or dismissed day, allows one claim per ordinal, and is
  refused on the profile's first day.
- Each of the 16 achievements unlocks exactly once, for its own coin value,
  and every threshold is exact (one combo or one point short unlocks
  nothing).
- The theme unlock table, coin purchase, and the theme pack unlocking all 12.
- Purchase grants are idempotent per token against both the pending and the
  completed list, reject an empty token, and `completedPurchaseTokens` holds
  the most recent 200 while pending is unbounded.
- Each of the seven interstitial conditions toggled individually at its
  boundary, the clock-rollback rule, and the shown-then-closed sequences.
- The reminder is 19:00 on the next local date across month and year ends.
- `PlayerProfile` with every field non-default round trips through
  `jsonEncode`/`fromJson` to an equal value with an equal hash code, and its
  collections are unmodifiable.

Every one of these was verified to bite by breaking its guard in the source
and watching the suite fail.

`Economy.reminderPromptAfterGames = 2` (design 10): the reminder permission prompt is armed by the finish that makes `gamesCompleted` equal this value, and offered from Home once.
