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

| event | dims | `n` | emitted by |
| --- | --- | --- | --- |
| `installed` | — | 1 | `AppController.start`, only when no envelope was loaded |
| `session_started` | `first: true/false` | 1 | `AppController.start` |
| `day_active` | `since_install`: `0`, `1`, `2-6`, `7`, `8-29`, `30+` | 1 | `markActive`, first call of a local calendar day |
| `retained_d1` | — | 1 | with `day_active` when the day is exactly 1 after the install day |
| `retained_d7` | — | 1 | with `day_active` when the day is exactly 7 after the install day |
| `game_started` | `mode: classic` | 1 | `startClassic`, `playAgain` |
| `game_ended` | `mode`, `score`, `placements`, `continued` (buckets from `Buckets`) | 1 | `finishGame` |
| `rewarded_completed` | `placement` | 1 | `AppController._watchRewarded` |
| `rewarded_unavailable` | `placement` | 1 | `_watchRewarded`, both no-ad and no-reward |
| `ad_shown` | `kind`: `rewarded`, `interstitial` | 1 | the `AdSink` hooks `onRewardedShown` / `onInterstitialShown` (fake and AdMob both raise them) |
| `revenue_usd_micros` | `source`: `rewarded`, `interstitial`, `iap`; `product` (iap only) | USD micros | `AdMobAdsService` from an AdMob paid event in USD; `PlayPurchaseService` at list price on `purchased` |
| `purchase_completed` | `product` | 1 | `PlayPurchaseService`, on `purchased` only |
| `theme_selected` | `theme` | 1 | `selectTheme` |

`n` is the counter increment (the service adds it to the event's counter and to
each dimension's histogram). The wire event carries `n` only when it is not 1.
Numeric values other than revenue are bucketed at emit time; the service has
no average or percentile primitive, so revenue is summed as micro-dollars and
divided by player-days on the dashboard.

**Day bookkeeping.** `PlayerProfile.lastActiveDayOrdinal` (`int?`, absent in
older envelopes, no version bump) holds the last local day (`Calendar.dayOrdinal`)
that counted `day_active`. `AppController.markActive()` is one `mutateWith`:
when the stored ordinal already equals today the data is returned unchanged;
otherwise the profile is updated and the events to count are returned as the
result, and `markActive` counts them only after the write has landed. The
serial queue is the dedup: a resume that races `start` runs against the
committed profile that already carries today's ordinal. A failed write counts
nothing and the next `markActive` counts once. `start` ends with `markActive()`;
`ui/app.dart` calls it on every `resumed`. `since_install` is
`today - Calendar.dayOrdinal(profile.createdAt)`; a `createdAtMs` of 0 lands in
`30+`. The comparison is `!=`, so a clock moved back re-emits for an old day
rather than muting the player.

**Revenue.** AdMob paid events (`onPaidEvent`, set on the ad before `show`)
count `revenue_usd_micros` with `n = valueMicros.round()` and `source` = the
ad kind when the currency is `USD` and the value is positive; any other
currency is logged and dropped. Purchases count the USD list price from
`Product.usdMicros` (`remove_ads` 3 990 000, `coins_small` 990 000,
`coins_medium` 4 990 000, `coins_large` 9 990 000, `theme_pack_all`
2 990 000) with `source: iap` and `product`, on `purchased` only. List price is
deliberate: the store's localised price is in local currency and cannot be
summed. When a Play Console price changes, `Product.usdMicros` is the number
to change. AdMob and Play Console stay the books of record. The fake ads and
purchase services count no revenue.

**Day definition.** Local calendar day via `Calendar.dayOrdinal`. The service
aggregates by UTC arrival hour; the mismatch is noted, not corrected.

`purchase_completed` is emitted by the purchase service rather than the
controller because the controller's `purchaseCompleted(token)` sink method does
not carry the product id. It is not emitted for `restored` updates, so a
reinstall does not inflate the count. The fake purchase service (debug drives)
emits nothing.

Still owed by later phases (design 12): `daily_completed`, `level_reached`,
`notification_permission`.

## Dashboard (project `settle`)

`tools/analytics_dashboard.json` is the layout; `tools/analytics_dashboard.sh`
installs it (Authelia login prompted, never stored; `ANALYTICS_BASE` and
`ANALYTICS_READ_KEY` select a local compose instead). A 409 means the dashboard
was edited in the browser since the script read the revision: rerun.

| # | title | kind | event | denominator / dimension |
| --- | --- | --- | --- | --- |
| 1 | Installs | count | `installed` | |
| 2 | Active players | count | `day_active` | |
| 3 | D1 retention | ratio | `retained_d1` | `installed` |
| 4 | D7 retention | ratio | `retained_d7` | `installed` |
| 5 | Ads per active player | ratio | `ad_shown` | `day_active` |
| 6 | Rewards per active player | ratio | `rewarded_completed` | `day_active` |
| 7 | ARPDAU (USD micros) | ratio | `revenue_usd_micros` | `day_active` |
| 8 | Revenue by source | breakdown | `revenue_usd_micros` | `source` |
| 9 | Games per active player | ratio | `game_started` | `day_active` |
| 10 | Purchases | count | `purchase_completed` | |
| 11 | Games by placements | breakdown | `game_ended` | `placements` |
| 12 | Active by days since install | breakdown | `day_active` | `since_install` |

`showPresence` is off (the app sends no heartbeats). Widget 2 over a 24 h
range is DAU; over longer ranges it is the sum of daily actives (player-days),
which is the denominator widgets 5 to 9 need.

**Reading the ratios.** Widgets 3 and 4 divide returns by installs inside the
same window, so they lag: a 7-day window counts day-1 returns of players who
installed just before it and misses the day-1 returns of the last day's
installs. Over 30 days with steady installs the error is a few percent; the
exact cohort numbers come from the queries below. Widget 7 is micro-dollars
per player-day: 25 000 means 2.5 cents.

## Exact queries

Raw arrivals are kept for 30 days and downloadable from the dashboard's
Download tab as NDJSON (up to 720 h). They are best-effort (bounded capture);
the hourly aggregates remain the totals of record. With DuckDB:

```sql
-- installs per day and D1 / D7 by cohort
WITH e AS (SELECT * FROM read_json_auto('settle-events-720h.ndjson')),
inst AS (SELECT u, date_trunc('day', to_timestamp(at/1000)) AS d0
         FROM e WHERE t = 'installed'),
act AS (SELECT DISTINCT u, date_trunc('day', to_timestamp(at/1000)) AS d
        FROM e WHERE t = 'day_active')
SELECT d0, count(*) AS installs,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM act WHERE act.u = inst.u AND act.d = d0 + INTERVAL 1 DAY)) * 1.0 / count(*) AS d1,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM act WHERE act.u = inst.u AND act.d = d0 + INTERVAL 7 DAY)) * 1.0 / count(*) AS d7
FROM inst GROUP BY d0 ORDER BY d0;

-- DAU by server day and ARPDAU
SELECT date_trunc('day', to_timestamp(at/1000)) AS d,
       count(DISTINCT u) FILTER (WHERE t = 'day_active') AS dau,
       sum(coalesce(n, 1)) FILTER (WHERE t = 'revenue_usd_micros') / 1e6 AS usd
FROM read_json_auto('settle-events-720h.ndjson') GROUP BY d ORDER BY d;
```
