# Settle

A one-thumb block puzzle for Android, built to be the game people open in
every short break and to earn from rewarded video, capped interstitials and
a small purchase catalogue.

Three block shapes are offered at a time. You drag each onto an 8x8 grid.
Full rows and columns clear. Consecutive clears build a combo. The game ends
when nothing fits. A daily puzzle with a streak, coins, a player level that
unlocks colour themes, and achievements sit around that loop.

## Shape

- `app/` is the Flutter app (Flutter 3.41, Dart 3.11, Android only in v1).
  `lib/core` and `lib/meta` are pure Dart and hold every game rule and
  economy number; `lib/services` adapts plugins behind interfaces with
  fakes; `lib/ui` is the Flutter and Flame front end.
- The piece generator ("director") is the retention lever: it keeps
  beginners alive, keeps good players in flow, and is tuned against a
  headless bot simulation in `app/bin/sim.dart`.
- Monetisation is opt-in rewarded video (continue, reroll, double coins,
  second daily attempt), interstitials under a strict frequency policy,
  and five products (remove ads, three coin packs, all themes). Consent is
  gathered with Google's UMP before any ad loads.
- Every player-facing string is drafted by Codex under the
  `user-facing-copy` skill and lives in `app/lib/ui/strings.dart`.

## Key decisions

See `docs/backlog/v1/design.md` section 15 while v1 is in flight; durable
rules move to `docs/contracts/` at closeout.

## Status

v1 in build (started 2026-09-08). Provisional name "Settle", package
`com.perch.settle`; the package name is permanent once uploaded to Play, so
confirm it before the first upload.
