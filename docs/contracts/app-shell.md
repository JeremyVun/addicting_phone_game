# Contract: app shell (`app/lib/main.dart`, `bootstrap.dart`, `app.dart`, `navigator.dart`, `services/**`, `ui/**` outside `ui/play`)

As built in phase 2b-shell. The shell owns persistence, the mutation queue, the
game lifecycle and every screen except the play screen itself, which it drives
through the `PlayHost` seam.

## 1. Launch

`main.dart` is fixed and never grows:

```dart
WidgetsFlutterBinding.ensureInitialized();
final services = await bootstrap();
final controller = AppController(services);
await controller.start();
runApp(SettleApp(controller));
```

`bootstrap()` returns `AppServices {storage, clock, ads, purchases, analytics,
notifications}`. **Audio and haptics are deliberately not fields**: those two
interfaces belong to the play screen and integration adds them to `AppServices`
and to `bootstrap()` (section 8).

`AppController.start()`, in this order:

1. `storage.load()`; on null, `PlayerProfile.initial` with a fresh v4 UUID
   analytics unit id and `createdAt = clock.now()`.
2. one mutation applying `Streaks.reconcile`, then
   `InterstitialPolicy.reconcileClock`, then discarding a saved **daily** whose
   `dayOrdinal` is not today (a saved classic survives any gap).
3. `purchases.start(this)`, `ads.start(this)`.
4. analytics `session_started {first}`.

`SettleApp` then calls `controller.resumeFromLaunch()` after the first frame:
a pending `lastResult` reopens the game over sheet on Home; otherwise a saved
game pushes Play, and if its status is already `over` the sheet opens on top
(design 6.1: killing the app in the continue offer resumes to the continue
offer).

## 2. The envelope

One `shared_preferences` string key, `settle.appdata.v1`, written whole through
`SharedPreferencesAsync.setString`:

```json
{"v": 1, "profile": {...}, "savedGame": {...} | null, "lastResult": {...} | null}
```

`profile`, `savedGame` and `lastResult` are `PlayerProfile.toJson`,
`GameState.toJson` and `LastGameResult.toJson` verbatim — the shell adds no
fields of its own. A `v` other than 1 throws `FormatException`.
`MemoryStorage` is the test double and records every write in order.

## 3. The mutation queue (design 4)

```dart
Future<AppData> mutate(AppData Function(AppData) fn);
Future<T> mutateWith<T>(({AppData data, T result}) Function(AppData) fn);
Future<void> get idle;                 // the queue has drained
```

`mutate` is `mutateWith` with the new data as its own result. Each queued
function runs against the **latest committed** `AppData`, the envelope write is
awaited, `_data` is replaced and listeners are notified **only after the write
succeeds**, and only then does the caller's future complete and the next queued
function start. A failed write therefore leaves memory and disk agreeing on the
last committed state; the caller's future carries the error and the queue
carries on with the next mutation. Two callbacks can therefore never
derive from the same stale state. `idle` exists for tests and for lifecycle
code that must wait for the disk.

Every write in the app goes through this queue: UI actions, the reducer result
of `place`, rewarded callbacks, the purchase sink, `finishGame()`.

```dart
void mutateInBackground(AppData Function(AppData) fn);
```

A mutation is either awaited or run through `mutateInBackground`, never
`unawaited(mutate(...))`: a write behind a fire-and-forget mutation (`place`
and the four `AdSink` transitions) fails into a log line, not an unhandled
async error. The last committed state stands and the queue continues.

Every guard that decides whether an action is affordable or allowed is
re-evaluated **inside** the mutation that spends, against the committed data
that mutation is handed (`Themes.buy` and `DailyRewards.claim` are the shape).
Two unawaited taps therefore charge once, and the refused one is a no-op: no
`StateError` from the reducer ever reaches the UI.

## 4. Game lifecycle

| method | what it does |
| --- | --- |
| `startClassic()` | seed = `Random.secure().nextInt(1 << 32)`, `skill = profile.skill`, `restricted = profile.classicGamesCompleted == 0` (design 5.5, ruled 2026-09-09: daily games do not spend the restriction, and `showFirstGameHints` reads the same field), `startedAtMs = clock.now()`; stores it as `savedGame`, clears `lastResult`, emits `game_started`, navigates to Play |
| `place(slot, row, col)` | synchronous `Game.place`, then an unawaited queued write of the result state with the elapsed time folded in. On `gameOver` the state is already `over` and is saved by that same write; the play screen then calls `onGameOver()` |
| `requestReroll()` / `requestPause()` | open their sheets |
| `rerollWithAd()` / `rerollWithCoins()` | design 6: the ad path rerolls **only** from the reward, the coin path deducts 50 and rerolls in one mutation. Both refuse past `canReroll` (3 per game, game still playing) |
| `continueGame()` | fixes `continuePayment` **once, before the ad** (free when ad-free, else rewarded when one is loaded, else 150 coins) and carries that decision into the mutation, so the ad going not-ready while it plays never turns a watched ad into a 150-coin charge. The mutation re-checks `continueAvailable` and, for the coin price, the balance; if either fails it is a no-op and nothing navigates |
| `endGame()` → `finishGame()` | builds `GameSummary` (`durationMs` from the state's `elapsedMs`, `maxCombo`, `placements`, `boardClearedCount`, `dayOrdinal` for daily), runs `Progression.finish`, stores `lastResult` and deletes `savedGame` in one mutation, then emits `game_ended`. Idempotent: `savedGame == null` returns the existing `lastResult`, and `Progression.finish` is idempotent on `gameId` besides |
| `doubleCoins()` | rewarded, then `Progression.doubleCoins` once (`doubled` guards it twice: before the ad and inside the mutation) |
| `playAgain()` | `InterstitialPolicy.shouldShow` with `lastResult.elapsedMs`; if true `ads.showInterstitial()` (the `AdSink` transitions land first because the sink enqueues synchronously), then a new classic game and `lastResult: null` in one mutation |
| `goHome()` | clears `lastResult`, dismisses the sheet, pops to Home |
| `selectTheme(slot)` / `setSound` / `setHaptics` | one mutation each; `selectTheme` goes through `Themes.select` and emits `theme_selected` |

Elapsed time is tracked as `elapsedAtResume + (now - resumedAtMs)`, re-anchored
on `startClassic`, `playAgain`, `continueGame` and on a resume at launch, so a
game left in the background overnight does not accumulate hours.

## 5. Sheets and navigation

The controller never imports `package:flutter/material.dart`. It talks to an
`AppNavigator` (`lib/navigator.dart`) with `goPlay`, `goHome`, `showGameOver`,
`showPause`, `showReroll`, `dismissSheet`, `showMessage`; `WidgetNavigator`
(`lib/ui/navigation.dart`) implements it over the root `Navigator` and
`ScaffoldMessenger`, and unit tests use `NoopNavigator` or a recording fake.
Only one sheet is open at a time (`_sheetOpen`); the game over sheet is
non-dismissible.

Sheet state machine: the game over sheet renders the **continue offer** while
`lastResult == null && continueAvailable`, and the **final** state as soon as
`lastResult` is present. It rebuilds on `notifyListeners`, so Double coins
updates in place.

Routes: `/` Home, `/play` the stand-in, `/shop`, `/themes`, `/settings`,
`/achievements` a single `PlaceholderScreen(title)`.

## 6. Service interfaces and sinks

- `Storage` — `load()`, `save(AppData)`. `SharedPreferencesStorage`, `MemoryStorage`.
- `Clock` — `now()` local. `SystemClock`, `FixedClock`.
- `AdsService` — `start(AdSink)`, `isRewardedReady`, `showRewarded` (true only
  on an earned reward), `isInterstitialReady`, `showInterstitial`,
  `privacyOptionsRequired`, `showPrivacyOptions`. `AdSink` —
  `onInterstitialShown/Closed`, `onRewardedShown/Closed`, each one mutation
  applying the matching `InterstitialPolicy` transition.
  **`RewardedPlacement` is `meta/economy.dart`'s enum, re-exported from
  `services/ads.dart`** so the two layers cannot drift; do not redeclare it.
- `PurchaseService` — `start(PurchaseSink)`, `products()`, `buy(id)`,
  `restore()`; `StoreProduct {id, title, price}` where `price` is the store's
  localised string. `PurchaseSink` — `applyPurchase(productId, token)` →
  `Purchases.grant`, `purchaseCompleted(token)` → `Purchases.markPurchaseCompleted`,
  `purchasePending`, `purchaseFailed`. Both grant paths are idempotent per token.
- `AnalyticsService` — `count(event, [dims])`. `NoopAnalytics`, `RecordingAnalytics`.
- `NotificationsService` — `requestPermission()`, `scheduleReminder(DateTime)`,
  `cancelReminder()`. `NoopNotifications`.

`FakeAdsService` has settable `rewardedReady`, `interstitialReady` and
`grantsReward` and a 300 ms simulated show that raises the sink transitions in
order. `FakePurchaseService` grants after 300 ms with the token
`fake-<productId>-<n>` and prices like `$0.99`.

## 7. Analytics emitted by this phase

`session_started {first}`, `game_started {mode}`,
`game_ended {mode, score, placements, continued}` (buckets from `Buckets`),
`rewarded_completed {placement}`, `rewarded_unavailable {placement}`,
`interstitial_shown`, `theme_selected {theme}`. The rest of design 12 belongs
to later phases.

## 8. What integration must do

1. **Swap the stand-in.** `lib/ui/screens/play_route.dart` is a plain Flutter
   board-and-tray with tap-a-slot-then-tap-a-cell placement and a
   `S.standInPlayBanner` label. Delete it, point `/play` in `lib/ui/app.dart`
   at the real `PlayScreen(host: controller)`, and delete
   `S.standInPlayBanner`. `AppController` already satisfies `PlayHost` in full
   and needs no change.
2. **Wire audio and haptics.** Add `audio` and `haptics` fields to
   `AppServices`, construct them in `bootstrap()`, and read
   `controller.soundOn` / `controller.hapticsOn` (already on `PlayHost`) for
   the on/off setting. Nothing in `app.dart` or `main.dart` needs to change.
3. **Real ads and purchases (phase 4).** Replace the two fakes in
   `bootstrap()`. The interfaces, the sinks and the idempotency rules above are
   the contract; the real purchase listener must be attached inside
   `PurchaseService.start` so it lives for the process.
4. **Daily mode (meta-screens phase).** The shell has no `startDaily()`. That
   phase adds, in this file's style: `startDaily()` (seed and `dayOrdinal` =
   today's ordinal, `Game.newGame` forces skill 0.5 and unrestricted),
   `startSecondDailyAttempt()` (one mutation setting
   `profile.dailySecondAttemptUsed = today` **and** storing the new daily game,
   after the `dailySecondAttempt` reward), `buyStreakFreeze()`,
   `claimDailyReward()` / `dismissDailyReward()`, `buyTheme(slot)`,
   `buyProduct(id)` / `restorePurchases()`, and a Daily result sheet branch in
   `GameOverSheet` keyed on `lastResult.mode == GameMode.daily`. The Home
   Daily card is drawn but inert until then. `finishGame()` already handles a
   daily summary correctly.

## 9. Traps

- `meta` and `core` both export a `GameMode`. Files that touch both import
  `core` with a prefix (`import 'core/game.dart' as core;`).
- `place()` returns the reducer's `PlacementResult` synchronously but the write
  is queued; `controller.state` only reflects it after `await controller.idle`.
  Tests that place repeatedly must await between moves.
- The continue offer carries no `lastResult` — progression has not run. Do not
  key the sheet on `savedGame == null`.
- `bestScoreFor` is read from the profile *after* `finishGame`, so "new best"
  is `profile.best == result.score`, not a stored flag.
- `PlayHost.state` is non-nullable but `finishGame()` deletes `savedGame` while
  the play screen is still mounted under the sheet. The controller keeps the
  finished `GameState` in `_finishedGame` and `state` falls back to it, so the
  board stays drawn behind the result sheet. The emulator drive caught this as
  a null-check crash; do not "simplify" it back to `savedGame!`.
