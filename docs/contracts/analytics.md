# Contract: analytics (`services/analytics.dart`, `config.dart`)

As built in phase 4 against the shared analytics service (`analytics-stack`
skill, wire contract `~/projects/analytics/README.md`).

## Transport

`HttpAnalytics` POSTs a JSON **array** of events to `$baseUrl/e` with
`content-type: application/json` and `X-Analytics-Key: $key`. Every event
carries `p: "settle"`, `t: <event>`, `sid: <per-launch random id>`, `u: <the
profile's analyticsUnitId>` and, when the event has dimensions, `d: {…}`.

- Batched: at most 50 events per request, flushed every 10 s, immediately at 20
  queued, and on app pause (`AppLifecycleListener`).
- The queue is capped at 500; the oldest event is dropped past that.
- `count()` is synchronous, enqueues and returns. It never blocks and never
  throws. A failed POST drops the whole queue — there is no retry.
- `u` is resolved late and memoised: `bootstrap()` builds the service before the
  profile exists, so the id is read from the envelope at the first flush and
  re-read while it is still empty. Events sent before it resolves omit `u`.
- `sid` is a fresh 16-hex-character id per launch. It is carried into the raw
  archive, not aggregated.
- No PII anywhere. `u` is the v4 UUID the profile generates on first launch.

`AnalyticsTransport` is the seam (`dart:io` `HttpClient` in production, a
recording fake in tests).

## Configuration

| define | meaning |
| --- | --- |
| `SETTLE_ANALYTICS_URL` | base URL of the service. **Empty ⇒ `NoopAnalytics`.** |
| `SETTLE_ANALYTICS_KEY` | `X-Analytics-Key`; omitted from the headers when empty |

`kAnalyticsProject` is `settle` and never changes — it partitions all history.
The operator must register `settle:<key>` in the service's
`ANALYTICS_INGEST_KEYS` before events are accepted (deny-by-default once that
env var is set at all).

## Events as emitted

| event | dims | emitted by |
| --- | --- | --- |
| `session_started` | `first: true/false` | `AppController.start` |
| `game_started` | `mode: classic` | `startClassic`, `playAgain` |
| `game_ended` | `mode`, `score`, `placements`, `continued` (buckets from `Buckets`) | `finishGame` |
| `rewarded_completed` | `placement` | `AppController._watchRewarded` |
| `rewarded_unavailable` | `placement` | `_watchRewarded`, both no-ad and no-reward |
| `interstitial_shown` | — | `playAgain`, after the ad returns |
| `purchase_completed` | `product` | `PlayPurchaseService`, on `purchased` only |
| `theme_selected` | `theme` | `selectTheme` |

Numeric values are bucketed at emit time; the service has no average or
percentile primitive.

`purchase_completed` is emitted by the purchase service rather than the
controller because the controller's `purchaseCompleted(token)` sink method does
not carry the product id. It is not emitted for `restored` updates, so a
reinstall does not inflate the count. The fake purchase service (debug drives)
emits nothing.

Still owed by later phases (design 12): `daily_completed`, `level_reached`,
`notification_permission`.
