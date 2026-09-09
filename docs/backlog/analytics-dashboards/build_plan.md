# Build plan: analytics dashboards

Design: `design.md`. Contracts touched: `docs/contracts/analytics.md`,
`docs/contracts/monetisation.md` (paid events, list prices), `app-shell`
(lifecycle resume hook). Baseline: main at b16fa70, 390 tests green.

Arithmetic a builder can check against: list prices in micros are
3 990 000 / 990 000 / 4 990 000 / 9 990 000 / 2 990 000; `since_install`
buckets are `0`, `1`, `2-6`, `7`, `8-29`, `30+` (7 is its own bucket because
D7 keys on it); a paid event of 0.012 USD arrives as `valueMicros = 12000`.

## Phase 1: events in the app (one agent, one worktree)

Owns: `app/lib/services/analytics.dart`, `app/lib/meta/player_profile.dart`,
`app/lib/meta/buckets.dart`, `app/lib/meta/economy.dart`, `app/lib/app.dart`,
`app/lib/ui/app.dart`, `app/lib/services/ads.dart`,
`app/lib/services/purchases.dart`, `app/lib/services/wiring_monetisation.dart`,
tests under `app/test/services`, `app/test/meta`, `app/test/app`,
`app/test/probes`.

Seam contract:
- `AnalyticsService.count(String event, [Map<String,String> dims = const {}, {int n = 1}])`;
  wire `n` present only when `n != 1`. `RecordingAnalytics` exposes `n`.
- `Buckets.sinceInstall(int days)` returns the six buckets above.
- `PlayerProfile.lastActiveDayOrdinal` (`int?`), in `toJson`/`fromJson`/`copyWith`;
  a stored profile without the key loads as null. No version bump.
- `Product.usdMicros` on all five products.
- `AppController.markActive()`: the single mutation described in the design;
  `installed` counted in `start` only when `loaded == null`, before
  `markActive` runs. `start` ends with `markActive()`. `ui/app.dart` calls
  `controller.markActive()` on `resumed`.
- `AdSink` hooks count `ad_shown{kind}`; `interstitial_shown` is gone.
- `AdCallbacks.onPaid`; `_RewardedHandle` / `_InterstitialHandle` set
  `ad.onPaidEvent` before showing; `AdMobAdsService({AnalyticsService analytics = const NoopAnalytics(), ...})`
  (the `PlayPurchaseService` shape, so existing tests keep constructing it bare)
  counts `revenue_usd_micros` per the design; `FakeAdsService` untouched.
- `PlayPurchaseService` counts `revenue_usd_micros{source: iap, product}` with
  `n = product.usdMicros` next to `purchase_completed`.

Verify gate (all must pass, run unpiped so the exit code is real):
- `tools/check.sh` green.
- New tests: `n` on the wire only when not 1; `markActive` counts once per
  day and again after the day changes; two `markActive` calls queued in the
  same tick count once; day 1 and day 7 after install add the retention
  counters, day 2 and day 8 do not; a profile JSON without
  `lastActiveDayOrdinal` round-trips; paid event in USD counts micros, in
  another currency counts nothing; a `purchased` update counts list-price
  micros, a `restored` update counts nothing; `onInterstitialShown` and
  `onRewardedShown` count `ad_shown` with the right kind.
- Probe: `app/test/probes/persistence_probe_test.dart` extended with the new
  field so a crash between the mutation and the flush leaves
  `lastActiveDayOrdinal` consistent with what was counted (the count happens
  only after the mutation's write succeeds; a failed write counts nothing and
  the next `markActive` counts once).

Done marker: `## Phase 1: done <date>` appended to this file with the test
count.

## Phase 2: dashboard layout, script and contracts (orchestrator, main)

Owns: `tools/analytics_dashboard.json`, `tools/analytics_dashboard.sh`,
`docs/contracts/analytics.md`, `docs/contracts/monetisation.md`,
`docs/roadmap.md`, `CLAUDE.md` run table (one line for the script).

- JSON: the twelve widgets from the design, `showPresence: false`,
  `experiment` with empty strings and `complement: false` (the server's
  decoder rejects unknown fields and requires the key).
- Script per the design; `set -euo pipefail`; temp cookie file created with
  `mktemp` under a `settle-dash-` prefix and removed on exit; no credential
  ever printed; exits non-zero on any status other than 200.
- Contract: event table updated (six new rows, `interstitial_shown` removed),
  `n` semantics, the dashboard layout table, the reading caveats, and the
  "Exact queries" section from the design.

Verify gate: `bash -n` and `shellcheck` on the script; `python3 -m json.tool`
on the JSON; a dry PUT of the JSON against a local `docker compose up` of
`~/projects/analytics` (`ANALYTICS_READ_KEY=x`, then
`curl -X PUT -H 'X-Analytics-Key: x' ... localhost:8789/ui/api/dashboard?project=settle`)
returns 200 with revision 1, proving the config validates.

Done marker: `## Phase 2: done <date>`.

## Phase 3: end-to-end verification (one agent, own emulator)

Owns nothing in the repo except a verification record appended to
`docs/contracts/analytics.md`.

- Run `~/projects/analytics` locally (`docker compose up`, port 8789). Boot a
  private AVD (`-memory 2048 -cores 2`, never `emulator-5554`), install a
  release-mode or arm64 debug build with
  `--dart-define=SETTLE_ANALYTICS_URL=http://10.0.2.2:8789 --dart-define=SETTLE_FAKE_SERVICES=true`.
- Fresh install: `/stats?project=settle` shows `installed` 1, `day_active` 1
  with `since_install: 0`, `session_started` 1.
- Background and resume the app: no second `day_active`.
- Play one classic game to the end, play again through the fake interstitial:
  `ad_shown{interstitial}` 1, no `interstitial_shown`.
- Buy `coins_small` through the fake shop: `purchase_completed` 1, and
  because the fake purchase service emits nothing, `revenue_usd_micros` is
  absent. That is the expected fake behaviour; record it.
- Day rollover: there is no clock override define (`services/clock.dart` has
  only `SystemClock` and the test `FixedClock`), and `adb shell date` needs a
  rooted image. If the private AVD is a non-Play image, `adb root` then set
  the date forward one day, resume the app and expect a second `day_active`
  with `since_install: 1` and `retained_d1` 1. Otherwise say in the record
  that rollover is covered by the phase 1 unit tests only.
- Reclaim the AVD at the end.

Done marker: `## Phase 3: done <date>` with the observed counters.

## Owner step after phase 2

Run `tools/analytics_dashboard.sh` once with the Authelia login, then open
`https://analytics.jeremyvun.com/ui` and pick project `settle`. Until the app
is on a test track the widgets show only the smoke event `onboard_test` from
2026-09-09.
