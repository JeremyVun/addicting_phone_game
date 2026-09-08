# Contract: meta screens (`app/lib/app_daily.dart`, the daily/streak/reward/theme UI, reminders)

As built in phase 3b. Everything here extends the app shell
(`docs/contracts/app-shell.md`); every number comes from `meta`
(`docs/contracts/economy.md`) and every string from `ui/strings.dart`.

`DailyFlows` is an `extension` on `AppController` in `app_daily.dart`, a
`part of 'app.dart'`, so it reaches the controller's private members
(`_data`, `_markResumed`, `_watchRewarded`, `_reminderPromptArmed`).

## 1. The daily state machine

`today == dayOrdinalOf(clock.now())` is the only calendar value used.

| controller member | rule |
| --- | --- |
| `dailyAttemptsToday` | `profile.dailyAttempts[today] ?? 0` |
| `canStartDaily` | `dailyAttemptsToday < (dailySecondAttemptUsed == today ? 2 : 1)` |
| `secondDailyAttemptOffered` | `dailySecondAttemptUsed != today && dailyAttemptsToday > 0` |
| `dailyCardState` | `inProgress` when a saved daily carries today's ordinal, else `done` when an attempt is recorded, else `notPlayed` |

- `startDaily()` resumes instead when a saved daily for today exists, refuses
  when `!canStartDaily`, and otherwise writes
  `Game.newGame(mode: daily, seed: dailySeedFor(today), dayOrdinal: today)` as
  `savedGame` with `lastResult: null`. `newGame` itself forces skill 0.5 and
  `restricted: false` for a daily, so the controller passes neither.
- `resumeDaily()` re-anchors elapsed time and pushes Play; a saved daily
  already at `status == over` reopens the game-over sheet on top, exactly as
  a classic resume does.
- A saved daily from another date is discarded by the shell's `start()`; this
  phase adds nothing there.
- `startSecondDailyAttempt()` refuses unless `secondDailyAttemptOffered`,
  takes the `dailySecondAttempt` rewarded placement, and then writes
  `dailySecondAttemptUsed = today` **and** the new board in one envelope, so a
  kill between them cannot yield a free third attempt. The test asserts that
  exactly one written envelope in the whole flow carries a `savedGame`, and
  that the same envelope carries the flag.
- `finishGame()` is the shell's and already records `dailyBest[today]`,
  `dailyAttempts[today]` and the streak through `Progression.finish`.

**Trap.** `GameState.id` is `'$seed-$startedAtMs'` and a daily's seed is fixed
for the day, so two attempts started in the same millisecond would share an id
and `Progression.finish` would treat the second as already applied. Real clocks
make this impossible; a `FixedClock` test that starts two attempts must advance
the clock between them.

## 2. Where the daily result sheet appears

`GameOverSheet` keeps the **continue offer** unchanged for both modes (the
offer carries no `lastResult`, so it cannot branch on mode) and switches to
`DailyResultSheet` as soon as `lastResult.mode == GameMode.daily`. That is the
one edit this phase made to `game_over_sheet.dart`.

`DailyResultSheet` has two shapes, chosen by whether it is given a
`LastGameResult`:

- **With a result** (game over, or a launch that reopens a pending daily
  result): score, best today, streak with `+1 today` while
  `lastCompletedOrdinal == today`, coins earned, Double coins (rewarded, only
  while `!doubled`), Try again (only while `secondDailyAttemptOffered`), Share,
  Home. There is no Play again in daily.
- **Without one** (reopened from the Home daily card): the same header and the
  two stat rows read from `dailyBest[today]` and `profile.streak`, no coins row
  and no Double coins, Share, and a Home that just pops the sheet.

Home decides which: it passes `lastResult` when it is present *and*
`lastResult.dayOrdinal == today`, otherwise null.

Share is `share_plus` 12 (`SharePlus.instance.share(ShareParams(text: ...))`)
with `S.dailyShareText(day, score, streak)`.

## 3. Home

- The Daily card is one `InkWell`: `notPlayed` starts the daily, `inProgress`
  resumes it, `done` opens the read-only result sheet. Its subtitle is
  `S.homeDailyNotPlayed` / `S.homeDailyInProgress` /
  `S.homeDailyDone(dailyBestToday)`, plus an accent
  `S.homeDailySecondAttemptAvailable` line while the second attempt is unused.
- The streak numeral inside the card is its own tap target and opens the
  **Streak sheet**; a snowflake sits beside it while a freeze is held.
- Home is a `StatefulWidget`. On every frame it offers, in priority order, the
  **notification prompt** (when `reminderPromptDue`) and then the **daily
  reward sheet** (when `DailyRewards.claimable`). Both are non-dismissible, so
  the only way out is one of their two buttons; that is what makes design 7.4's
  "offered again on every return to Home until claimed or dismissed" terminate.
  A single `_sheetUp` latch stops a second copy opening.

## 4. Streak sheet and reward sheet

`StreakSheet` shows the streak, `S.streakFreezes(freezesHeld)`, the coin
balance and the explanation line. `Buy for 200 coins` is disabled when
`!Streaks.canBuyFreeze` — under `Economy.freezeCost` coins or at
`Economy.maxFreezesHeld` — and the footer is `Get coins` (popping to `/shop`)
only in the first case, `Close` otherwise. `buyStreakFreeze()` is one mutation
through `Streaks.buyFreeze`, which refuses by returning the profile unchanged.

`DailyRewardSheet` reads `DailyRewards.nextCycleDay` / `nextReward`, shows
`Day n of 7` and `+coins`, and calls `claimDailyReward()` or
`dismissDailyReward()`. Neither is offered on the install day
(`DailyRewards.claimable` compares against the profile's creation ordinal).

## 5. Themes and achievements

`ThemesScreen` is a two-column grid of the twelve `Themes.all` slots. Each tile
draws its own `ThemePalette` (that theme's ground, four block colours and its
accent as a dot) so the swatch is honest, while the surrounding chrome stays in
the *selected* theme. State label, in order: `Selected`, `Select` (unlocked),
`Level N` (level lock), `Buy for N coins` (`Themes.canBuy`), `N coins`
(coin lock, unaffordable). Tapping selects (`selectTheme`) or buys
(`buyTheme`, which buys *and* selects in two queued mutations). `SettleApp`
rebuilds on `controller.palette`, so the whole app re-themes at once.

`AchievementsScreen` lists the sixteen `Achievements.all` in order with name,
description, `+coins` and a `Done` badge for ids in `profile.achievements`.

## 6. Reminder lifecycle and the prompt

- `_SettleAppState` is a `WidgetsBindingObserver`: `paused` calls
  `controller.scheduleReminderIfEnabled()`, `resumed` calls
  `controller.cancelReminder()`. The controller stays free of Flutter widget
  imports.
- `scheduleReminderIfEnabled()` is a no-op unless `profile.remindersEnabled`,
  and otherwise schedules `Reminders.nextReminderTime(clock.now())` — 19:00 on
  the next local date, never today's.
- `setRemindersEnabled(bool)` (the name phase 4's settings screen will call)
  persists the flag and then schedules or cancels.
- `reminderPromptDue` is `_reminderPromptArmed && !reminderPermissionAsked &&
  gamesCompleted == Economy.reminderPromptAfterGames`. `finishGame()` sets the
  arming flag (its one added line, `_afterFinish(result)`), so a cold launch
  that merely finds the profile at two games does not ask.
  `enableRemindersFromPrompt()` requests the OS permission, emits
  `notification_permission {granted}` and persists
  `reminderPermissionAsked: true` with `remindersEnabled: granted`;
  `declineReminderPrompt()` persists only `reminderPermissionAsked: true`, so
  "Not now" never re-asks.

`LocalNotificationsService` (`services/notifications.dart`, returned by
`wiring_notifications.dart`): lazy `_ensureReady` does
`tz.initializeTimeZones()`, `flutter_timezone`'s `TimezoneInfo.identifier` into
`tz.setLocalLocation`, `initialize(settings:)` with
`AndroidInitializationSettings('@mipmap/ic_launcher')`, and creates the
`daily_reminder` channel. `scheduleReminder` cancels id 1 then `zonedSchedule`s
it with `AndroidScheduleMode.inexactAllowWhileIdle` — never an exact mode, as
Play restricts those to alarm-clock apps. `RecordingNotifications` in the same
file is the test double.

## 7. Manifest

Added to `android/app/src/main/AndroidManifest.xml` (the AdMob meta-data is
untouched): `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, and the
`ScheduledNotificationReceiver` plus `ScheduledNotificationBootReceiver`
(with `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`). Without
the boot receiver every pending reminder is lost on reboot and on every Play
update. Desugaring was already enabled in `build.gradle.kts`.

## 8. Analytics added by this phase

`daily_completed {streak}` and `level_reached {level}` from `_afterFinish`,
`notification_permission {granted}` from the prompt, `game_started {mode:
daily}` from the two daily starts. `theme_selected {theme}` was already
emitted by the shell's `selectTheme`.

## 9. Gap fills

- `Economy.reminderPromptAfterGames = 2` was added to `meta/economy.dart`:
  design 10's "second completed game" was the only rule number with no
  constant, and UI/controller code may not restate one.
- Strings added to `S`: `homeDailyInProgress`, `dailyStreakToday`,
  `dailyStreakIncrement`, `streakFreezesHeld`, `notifyChannelName`,
  `notifyChannelDescription`, `reminderTitle`, `reminderBody`. The last two are
  design 10's verbatim copy; the rest are placeholder English awaiting a Codex
  pass.
