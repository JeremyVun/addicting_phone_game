# Contract — core engine (`app/lib/core/**`)

As built by phase 1. Pure Dart: nothing under `core/` imports Flutter, so it
runs in `dart test` and in `bin/sim.dart`. Rule numbers from design 2–6 live
in named constants here and nowhere else in the app.

Files: `cell.dart`, `piece.dart`, `rng.dart`, `board.dart`, `scoring.dart`,
`director.dart`, `game_state.dart`, `game.dart`, `day_ordinal.dart`,
`sim/bots.dart`.

## Cell

`Cell(row, col)`, value equality. Used for piece offsets and for board
coordinates; which one it is is always clear from context.

## Piece — design 2.2

Immutable, built once at startup into `Piece.all` (37 pieces).

| member | meaning |
| --- | --- |
| `id` | `'<family>:<rotationIndex>'`, e.g. `l4:3`. Stable; it is the JSON form |
| `family` | one of the 14 family ids of design 2.2 |
| `rotation` | index into the family's deduplicated rotation list |
| `cells` | `List<Cell>` offsets, row-major sorted, min row = min col = 0 |
| `width`, `height`, `size` | bounding box and `cells.length` |
| `colourIndex` | 0–7, fixed by family, consumes no rng |
| `familyWeight`, `familyRotations` | the 5.3 sampling inputs |
| `rowMasks`, `colMasks` | 8-bit occupancy masks used by `Board` |

Statics: `Piece.all`, `Piece.byId`, `Piece.byFamily`, `Piece.dot`.

Rotations are generated from one base shape per family by repeated 90° CW
rotation with de-duplication, so counts fall out of the geometry and match
design 2.2 exactly: dot 1, i2/i3/i4/i5 2, o2 1, o3 1, r23 2, l3 4, l4 8
(4 L + 4 mirrored J; `PieceFamily.mirrored` is set only for l4), l5 4, t4 4,
s4 2, z4 2. `test/core/piece_test.dart` asserts the table and prints the
whole catalogue.

## Rng

PCG32, fixed stream, implemented locally because `dart:math`'s `Random` has
no cross-platform sequence guarantee and saved games must replay.

`Rng(seed)`, `Rng.fromState(state)`, `Rng.fromJson`, `toJson` → `{'state': int}`,
`state` getter, `clone()`, `nextUint32()`, `nextInt(max)` (rejection sampled,
uniform, throws on `max <= 0`), `nextDouble()` in `[0, 1)`.

`Rng` is **mutable**: every draw advances it. The reducer always clones the
state's rng before generating, so a `GameState` is never mutated in place.
The sequence is pinned by a test; changing the generator invalidates every
saved game.

## Board — design 2.1

Immutable 8×8 value. `Board.size` 8, `Board.cellCount` 64.

| member | contract |
| --- | --- |
| `Board.empty()` | all cells empty |
| `cellAt(r, c)` | colour index 0–7 or `null` |
| `canPlace(piece, row, col)` | in bounds and every cell lands on empty |
| `place(piece, row, col)` | new board; throws `ArgumentError` if illegal |
| `fullLines()` | `FullLines(rows, cols)`, both ascending |
| `clearLines(lines)` | `ClearResult(board, cells)`; `cells` is row-major and lists a cell in both a full row and a full column **once** |
| `filledCount`, `fill` (0..1), `isEmpty`, `isFull` | |
| `placements(piece)` | all legal anchors, row-major |
| `anyPlacement(piece)` | any legal anchor |
| `completesLine(piece, row, col)` | legal *and* completes ≥ 1 line |
| `hasLineCompletingPlacement(piece)` | any such anchor (the 5.6 "assisted" test) |
| `preview(piece, row, col)` | `PlacementPreview(rowsCleared, colsCleared, filledAfter)` without building a board; used by the bots |
| `toJson()` / `Board.fromJson` | 64-character string, `.` for empty, else the colour digit |
| `==`, `hashCode` | by cell contents |

`place` does not clear; the caller clears. Row/column occupancy is kept as
8-bit masks, so `canPlace` is three integer ops per piece row.

## Scoring — design 2.4

`Scoring.clearUnit` 10, `multiplierCap` 8, `boardClearBonus` 300,
`missesToResetCombo` 2, `comboBannerThreshold` 2.

`placementPoints(cells) = cells`, `clearPoints(n) = 10 * n * (n+1) / 2`
(0, 10, 30, 60, 100, 150, 210, …), `multiplier(combo) = min(combo, 8)`,
`boardClearPoints(bool)`.

`ComboState(comboCount, missCount).afterPlacement(cleared:)` — a clear gives
`(combo + 1, 0)`; a miss gives `(combo, miss + 1)` unless that reaches 2, in
which case `(0, 0)`. The miss counter therefore cycles 1, 0, 1, 0 even while
the combo sits at 0; only the combo is player-visible.

## Director — design 5

All constants are `static const` on `Director`: `pressureFloor` 0.15,
`pressureGain` 0.70, `pressureCeiling` 0.85, `pressureSetsToCeiling` 40,
`skillAdjustment` 0.30, `skillMidpoint` 0.5, `mercyFillThreshold` 0.70,
`mercyChanceBase` 0.70, `mercyChancePressureFactor` 0.40, `mercyMaxCells` 3,
`assistChanceBase` 0.45, `assistCandidates` 12, `fitTriesAtPressure` 10,
`fitTriesTotal` 30, `sizeBiasScale` 2.0, **`sizeBiasOffset` 2.6**,
`restrictedFamilies` = dot, i2, i3, o2, l3, l4, t4.

- `pressure(setsGenerated, skill)` — design 5.2.
- `pieceWeight(piece, p)` and `weights(pool, p)` — design 5.3, exponent
  `sizeBiasScale * p - sizeBiasOffset` (tuned, see below).
- `generateSet(board, rng, p, count, {restricted = false, pool})` — design
  5.4. `count` 1..3 (else `ArgumentError`). `pool` is a test seam only.
- `setIsAssisted(board, set)` — the 5.6 predicate.

Order inside one try: draw `count` pieces by 5.3 → mercy (only at
`fill >= 0.70`; replaces the **first** largest piece with a uniform piece of
≤ 3 cells drawn from the whole catalogue, not from `pool`) → assist (up to 12
candidates, first one with a line-completing placement replaces a random
slot). Tries 1–10 use `p`, tries 11–30 use `p = 0`. After 30 failed tries:
below 70% fill slot 0 becomes `dot`, at or above it the last draw is
returned unfit.

Rng consumption per try is variable (mercy and assist each consume draws
only when they fire), so a reroll of 2 slots is *not* a prefix of a 3-slot
generation. This is intentional and part of the save format's meaning.

## GameState — design 4

Immutable. Fields: `id`, `board`, `set` (3 slots, `Piece?`, `null` = played),
`score`, `comboCount`, `missCount`, `setsGenerated`, `placements`,
`maxCombo`, `boardClears`, `continuesUsed`, `rerollsUsed`, `mode`
(`classic|daily`), `seed`, `rng`, `status` (`playing|over`), `skill`,
`restricted`, `startedAtMs`, `elapsedMs`, `dayOrdinal` (daily only).
`bestScore` is **not** here; it is profile data.

`id` is `'$seed-$startedAtMs'` and never changes, so `finishGame()` can be
made idempotent against it.

`skill` and `restricted` are director configuration: they are set by
`newGame` and no reducer method ever changes them, so a resumed game
generates exactly what the original would have.

`setsGenerated` counts normal sets **already returned**; it starts at 1 after
`newGame` and increments after each refill. Every generation rule reads the
value current at generation time, so the first three sets of a restricted
game are made at 0, 1, 2 and the fourth at 3 (unrestricted). Continue and
reroll never change it.

`toJson`/`fromJson` carry `'v': 1`; a different version throws. The grid is
the 64-character string, the set is a list of piece ids or nulls, the rng is
its state. `fromJson(toJson(s)) == s` with deep equality, rng state included.

## Game (the reducer)

- `newGame({mode, seed, skill = 0.5, restricted = false, startedAtMs = 0, dayOrdinal})`
  — generates the first set at `setsGenerated = 0`. For `mode == daily` the
  caller's `skill` and `restricted` are **silently overridden** to 0.5 and
  false, so a day ordinal fixes the whole sequence for every player.
- `place(state, slot, row, col) -> PlacementResult` — throws `ArgumentError`
  for a bad slot, an already-played slot, an illegal target or a finished
  game. The UI is expected to call `board.canPlace` first.
- `continueGame(state)` — design 6: clears the three rows with the most
  filled cells (ties topmost), no points and no combo change for that clear,
  discards the set, generates a fresh 3-set at `p = 0`, `continuesUsed += 1`,
  status back to `playing` (or `over` if even that set does not fit).
  Throws `StateError` when a continue was already used.
- `reroll(state)` — design 6: `count` = remaining slots, generated at the
  current pressure and filled into the open slots **in slot order**;
  `rerollsUsed += 1`; `setsGenerated` and the board unchanged; status becomes
  `over` if nothing in the new set fits. Throws `StateError` past three
  rerolls, on a finished game, or with nothing to reroll.
- `withElapsed(state, ms)`.
- Helpers: `pressureFor(setsGenerated, skill, restricted)`,
  `pressureAt(state)` (the pressure the *next* set will use),
  `restrictedAt(state)`, `Game.onboardingSets` = 3.

Order inside `place`: place → clear all full rows and columns at once →
combo update → score → free the slot → refill the set if all three are gone
(`setsGenerated += 1`) → game-over check on whatever is now in the set. This
is design 2.3 exactly: with pieces still in hand the check runs on them,
with an exhausted set the next set is generated first.

### PlacementResult

`state`, `cellsPlaced` (board coordinates, piece order), `rowsCleared`,
`colsCleared` (ascending), `cellsCleared` (row-major, each cell once),
`placementPoints`, `clearPoints` (already multiplied), `boardClearPoints`,
`multiplier`, `comboCount` (after), `boardCleared`, `newSetGenerated`,
`gameOver`, plus `linesCleared` and `pointsAwarded`.

The UI animates from this alone and never recomputes a rule: flash
`cellsPlaced`, then `cellsCleared` staggered from the placed piece, shake by
`linesCleared`, banner from `comboCount`, popup from `pointsAwarded`, refill
the tray when `newSetGenerated`, sheet when `gameOver`.

## day_ordinal.dart — design 3

`dayOrdinalOf(DateTime local)` =
`DateTime.utc(y, m, d).difference(DateTime.utc(2026, 1, 1)).inDays`.
`dailySeedFor(ordinal) == ordinal`. This is the only calendar arithmetic in
the app.

## Simulator — design 5.6

`dart run bin/sim.dart --bot random|greedy --games 2000 --skill 0.5 [--seed 1] [--restricted]`
from `app/`. Prints games, p10/median/p90 placements and score, mean sets
generated, `rate(A)`, `rate(B)` with both denominators, and one PASS/FAIL
line. Assist buckets use the board and pressure at generation time and count
only sets generated at fill in [30%, 70%); the assist gate is evaluated for
the greedy bot only (random games never reach bucket B pressures).

`sim/bots.dart` exposes `RandomBot`, `GreedyBot`, `Move`, `playGame` and
`GameRecord` so tests can drive games headlessly. 2,000 greedy games take
about one second.

### As-built numbers (2,000 games, skill 0.5, seed 1)

| bot | placements p10/med/p90 | score p10/med/p90 | mean sets |
| --- | --- | --- | --- |
| random | 17 / 23 / 38 | 37 / 61 / 154 | 8.90 |
| greedy | 65 / 104 / 146 | 403 / 754 / 1234 | 35.44 |

Assist gate (greedy): rate(A) 0.8219 (n = 1,870), rate(B) 0.6511
(n = 5,652). Required rate(A) ≥ 0.35 and ≥ rate(B) + 0.10 — PASS.

### Tuning applied

One constant changed from the design: the 5.3 size-bias exponent
`(cells / 4) ^ (2p - 1)` became `(cells / 4) ^ (2p - 2.6)`
(`Director.sizeBiasOffset` 1.0 → 2.6). With the design value the greedy bot
finishes at a median of 44 placements and the random bot at 14, both below
their 5.6 bands, and no setting of the 5.2 pressure constants can fix it: at
`p = 0` for the whole game the greedy median is still only 68. Nothing else
was touched — the catalogue, the base weights and the scoring are as
designed, and the pressure curve still reaches 0.85 at 40 sets (which the
assist gate needs, since bucket B only exists if games reach `p >= 0.8`).
The bag now never reaches the neutral base table; the base table is the
`p = 1.3` extreme.

## Traps for callers

- `Rng` is mutable and shared by reference inside a `GameState`. Never draw
  from `state.rng` outside the reducer; clone it first.
- Piece ids, the 64-character grid string and the `v: 1` envelope are the
  save format. Renaming a family or reordering a family's rotations breaks
  every saved game.
- Colour is cosmetic and consumes no randomness, so a theme change never
  affects the sequence.
- Game over almost always arrives through the first branch of 2.3 (pieces
  left in hand that no longer fit). The second branch — a freshly generated
  set that fits nowhere — is possible only at fill ≥ 70% after 30 failed
  retries and was not observed in 20,000 attempts on a board where only a
  `dot` fits; do not rely on it firing.
