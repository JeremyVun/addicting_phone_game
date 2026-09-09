# Analytics dashboards

Roadmap v1.1 item: "Analytics dashboards on the shared service: D1/D7, ads per
DAU, ARPDAU." Designed 2026-09-09; owner rulings dated inline.

## What and why

The shared analytics service (`~/projects/analytics`, deployed at
`https://analytics.jeremyvun.com`) keeps per-project counters and histograms
per hour and shows them on a per-project dashboard at `/ui`. Settle already
emits ten events (`docs/contracts/analytics.md`) but none of them answers the
three launch questions: do players come back (D1/D7 retention), how many ads
does an active player see (ads per DAU), and what is a day of a player worth
(ARPDAU). The service has no retention or per-user primitives, so every one
of those numbers has to be composed at emit time in the app and then divided
at read time by a dashboard ratio widget.

This item adds the emit-time events, a saved dashboard layout for project
`settle`, a script that installs the layout, and the SQL recipes for the exact
versions of the same numbers from the service's raw-arrival table. Nothing
changes for the player.

## Verified facts about the service (2026-09-09)

- Ingest is open: `POST /e` with `p: settle` and no key returned 204. No
  server registration is needed. Reads (`/stats`, `/series`) return
  `unauthorized` without the read key.
- A counter with dimensions increments both `counters[t]` and
  `histograms[t][dim][value]`, by `n` (default 1). `n` is an integer count
  increment; the service has no averages.
- Dashboard widgets (`server/internal/analytics/dashboard.go`): at most
  twelve of kind `count` (`event`), `ratio` (`event` / `denominator`, optional
  `complement`) or `breakdown` (`event` by `dimension`). Ratios divide whole
  counters; a dimension value cannot be a numerator. Config is saved per
  project in Postgres with a revision; `PUT /ui/api/dashboard?project=settle`
  with `{config, revision}`; stale revision is 409.
- Dashboard routes sit behind Authelia at the edge (Caddy `@operator`
  matcher on `/ui*`). Authelia's forward-auth accepts only a Bearer header or
  its session cookie, so a script must log in first
  (`POST https://auth.jeremyvun.com/api/firstfactor`, cookie domain
  `jeremyvun.com`). Past the edge, a PUT without the read key must carry
  `Origin: https://analytics.jeremyvun.com`.
- Raw arrivals are kept in Postgres table `analytics_raw` for 30 days
  (`project`, `at_ms`, `record` bytea holding the sanitised event JSON) and are
  downloadable from the dashboard as NDJSON. Exact retention and joint
  questions come from there.
- `unique_units` in an hourly row is distinct `u` per hour, so daily uniques
  cannot be summed from aggregates; DAU must be an emit-time counter.

## Mechanism

### Emitted by the app (new or changed events)

| event | dims | `n` | emitted when |
| --- | --- | --- | --- |
| `installed` | — | 1 | `AppController.start` creates a new profile (`loaded == null`), once ever |
| `day_active` | `since_install`: `0`, `1`, `2-6`, `7`, `8-29`, `30+` | 1 | first `markActive` of a local calendar day (start and every lifecycle resume) |
| `retained_d1` | — | 1 | alongside `day_active` when the day is exactly 1 after the install day |
| `retained_d7` | — | 1 | alongside `day_active` when the day is exactly 7 after the install day |
| `ad_shown` | `kind`: `rewarded`, `interstitial` | 1 | `AdSink.onRewardedShown` / `onInterstitialShown` (replaces `interstitial_shown`) |
| `revenue_usd_micros` | `source`: `rewarded`, `interstitial`, `iap`; `product` (iap only) | USD micros | AdMob paid event with currency `USD` and value > 0; purchase `purchased` at list price |

Everything else in `docs/contracts/analytics.md` is unchanged.
`session_started.first` stays; `installed` duplicates it as a plain counter
because ratio widgets need a counter denominator.

**Day bookkeeping.** `PlayerProfile` gains `lastActiveDayOrdinal` (`int?`,
absent in stored v2 profiles, no version bump). `AppController.markActive()`
runs one mutation: with `today = Calendar.dayOrdinal(now)`, if
`profile.lastActiveDayOrdinal == today` the data is returned unchanged;
otherwise the profile is updated and the mutation returns, as its
`mutateWith` result, the events to count; `markActive` counts them only after
the write has succeeded. The serial queue is what makes a resume that races
`start` unable to double-emit: the second `markActive` runs against the
committed profile that already carries today's ordinal. Counting after the
write rather than inside the function keeps a failed write from emitting an
event the disk never recorded (build-stage refinement, 2026-09-09: the
original wording had the count inside the function, which runs before the
write and so contradicted the failed-write rule below).

`since_install = today - Calendar.dayOrdinal(profile.createdAt)`. A
`createdAtMs` of 0 (pre-field profiles) yields a huge day count and lands in
`30+`, which is the truthful bucket. The comparison is `!=`, not `>`: a clock
moved back re-emits for an old day (a tiny DAU overcount) rather than muting
the player until the real date catches up.

`markActive` is called at the end of `start` (after the profile exists and
`session_started`) and from `didChangeAppLifecycleState(resumed)` in
`ui/app.dart`, next to `cancelReminder`. Both go through `mutateInBackground`
semantics: a failed envelope write leaves the last committed state and the
event is not counted.

**Ads.** `AdCallbacks` gains `onPaid(double valueMicros, String currencyCode)`;
the AdMob handles set `onPaidEvent` on the loaded ad before `show`.
`AdMobAdsService` takes an `AnalyticsService` (wired in
`wiring_monetisation.dart`, the same way `PlayPurchaseService` does) and counts
`revenue_usd_micros` with `n = valueMicros.round()` and `source` = the kind
when the currency is `USD` and the value is positive; anything else is logged
and dropped. `FakeAdsService` counts nothing. `ad_shown` is emitted by the
controller in its `AdSink` hooks, which both the fake and AdMob call.

**Purchases.** `Product` gains `usdMicros`, the store checklist's suggested
list prices in micro-dollars: `remove_ads` 3 990 000, `coins_small` 990 000,
`coins_medium` 4 990 000, `coins_large` 9 990 000, `theme_pack_all`
2 990 000. `PlayPurchaseService` counts `revenue_usd_micros` with that `n`,
`source: iap` and `product`, at the same point it counts
`purchase_completed` (status `purchased` only, never `restored`). List price
is deliberate: the store's localised price is in local currency and cannot be
summed. If the owner changes a price in Play Console, this table is the one
to change too.

**Client.** `AnalyticsService.countN(event, n, [dims])` beside the existing
`count(event, [dims])` (Dart cannot combine an optional positional `dims` with
a named `n`; as built 2026-09-09). The wire event carries `n` only when it is
not 1. `RecordingAnalytics` records `n`.

### Dashboard layout (project `settle`, twelve widgets)

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

`showPresence: false` (the app sends no heartbeats); `experiment` empty.
Widget 2 over a 24 h range is DAU; over longer ranges it is the sum of daily
actives, which is what widgets 5 to 9 need as a denominator (player-days).

**Reading the ratios.** Widgets 3 and 4 divide returns by installs inside the
same window, so they lag: a 7-day window counts day-1 returns of players who
installed just before the window and misses the day-1 returns of the last
day's installs. Over a 30-day window with steady installs the error is a few
percent; the exact cohort numbers come from the SQL below. Widget 7 is
micro-dollars per player-day: 25 000 means 2.5 cents.

### Install script

`tools/analytics_dashboard.sh` reads `tools/analytics_dashboard.json`, prompts
for the Authelia username and password (`read -s`, never stored, never
echoed), posts them to `https://auth.jeremyvun.com/api/firstfactor`, keeps the
cookie in a private temp file, GETs the current revision, PUTs
`{config, revision}` with `Origin: https://analytics.jeremyvun.com` and
`content-type: application/json`, and prints the HTTP status and the new
revision. A 409 means someone edited the dashboard in the browser since;
rerun. The JSON is the layout above, verbatim. Fallback if the first-factor
call does not yield a usable cookie: add the twelve widgets by hand in Edit
dashboard.

### Exact numbers from raw arrivals

Documented in `docs/contracts/analytics.md` under "Exact queries". From a
dashboard NDJSON download (`Download` tab, up to 720 h) with DuckDB:

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

Raw arrivals are best-effort (bounded capture, 30-day retention); the hourly
aggregates remain the totals of record.

## Decisions

| date | decision | ruling |
| --- | --- | --- |
| 2026-09-09 | Revenue source for ARPDAU | AdMob paid events plus USD list prices for purchases. AdMob and Play Console stay the books of record. |
| 2026-09-09 | How the layout is applied | A script the owner runs; credentials prompted, never stored. |
| 2026-09-09 | `interstitial_shown` | Replaced by `ad_shown{kind}` before launch; no history exists to preserve. |
| 2026-09-09 | Day definition | Local calendar day via `Calendar.dayOrdinal`, the app's only calendar arithmetic. Server aggregation is by UTC arrival hour; the mismatch is noted, not corrected. |

## Rejected alternatives

- **Dedup key `k` for DAU.** The service's dedup TTL is 6 h, not a day.
- **Summing hourly `unique_units`.** Per-hour uniques overcount a player who
  plays in two hours.
- **Session heartbeats for presence.** Costs a request every 30 s per open
  app for a live-online gauge nobody needs at this scale.
- **Localised purchase prices as revenue.** Mixed currencies cannot be summed;
  list price in USD is stable and matches the Play Console table.
- **Read-key script.** The edge never lets an unauthenticated request reach
  the dashboard API, so the key alone cannot write.
- **Bucketing revenue as a dimension.** Loses the sum; `n` is exactly the
  additive primitive the service offers.

## Open questions

None. The one unverified step is whether Authelia's `/api/firstfactor` cookie
satisfies the forward-auth route from curl; the plan verifies it and the
hand-entry fallback is documented.
