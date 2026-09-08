# Settle

A one-thumb block puzzle for Android, built to be the game people open in
every short break and to earn from rewarded video, capped interstitials and
a small purchase catalogue. Provisional name Settle, package
`com.perch.settle` (permanent once uploaded to Play; confirm before the
first upload).

Three block shapes are offered at a time. You drag each onto an 8x8 grid.
Full rows and columns clear. Consecutive clears build a combo. The game ends
when nothing fits. Around that loop: a daily puzzle (same for everyone)
with a day streak and streak freezes, coins, a player level that unlocks
twelve colour themes, sixteen achievements, a daily reward calendar and a
reminder notification.

## Shape

- `app/` is the Flutter app (Flutter 3.41, Dart 3.11, Android only).
  `lib/core` and `lib/meta` are pure Dart and hold every rule and number;
  `lib/services` adapts plugins behind interfaces with fakes; `lib/ui` is
  the Flutter shell and the Flame play screen.
- The piece generator (the director) is the retention lever: it keeps
  beginners alive, keeps good players in flow, and is calibrated against
  headless bots (`app/bin/sim.dart`). Its constants are in
  `docs/contracts/core-engine.md`.
- All persistent state is one JSON envelope written whole through a
  serialised mutation queue; every spend is re-checked inside the mutation
  that pays.
- Monetisation: opt-in rewarded video (continue, reroll, double coins,
  second daily attempt), interstitials under a strict persisted policy,
  five products (remove ads, three coin packs, all themes), UMP consent
  before any ad, Play Billing 8 with token-keyed idempotent grants.
- Copy is drafted by Codex, never by build agents (`docs/contracts/copy.md`).

## Key decisions

- Engine Flutter + Flame over native Kotlin, Godot or a WebView.
- 8x8 rows and columns, no 3x3 boxes; colour is cosmetic.
- No loot boxes or random purchases; every purchase grants a stated amount.
- One daily attempt plus one rewarded second attempt.
- Combo one-move grace so the banner is on screen often.
- No banner ads, no music, no leaderboard server in v1.
- Director size-bias offset 1.6 from a bot sweep (the random bot's band was
  retired as non-discriminating); skill divisor 4,000.
- A continue demolishes occupied cells only; a device clock moved back
  never breaks a streak; first-game onboarding keys on classic games.

## Status

v1 built 2026-09-08/09: 387 tests including 63 adversarial probes, verified
on the emulator, signed release pipeline. Not yet on Play: the owner's
to-do list is `docs/store/checklist.md`. Next items: `docs/roadmap.md`.
