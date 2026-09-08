# Contract — the Play screen (`app/lib/ui/play/**`, `app/lib/ui/theme/**`)

As built by phase 2b. The visual authority is `docs/styles.md` and the frames
in `assets/exemplar/`; this file records what shipped, where it differs and
why, and the traps the next phase would otherwise pay for again.

Files: `play_host.dart` (the seam), `play_screen.dart` (Flutter: HUD, gutter,
band, pause), `settle_play_game.dart` (the `FlameGame`), `board_component.dart`,
`tray_component.dart`, `held_piece_component.dart`, `score_popup_component.dart`,
`tile_painter.dart`, `play_geometry.dart`, `play_icons.dart`,
`play_strings.dart`; `../theme/palettes.dart`, `../theme/typography.dart`.

## The `PlayHost` seam

`play_host.dart` is byte-identical to the copy the shell phase landed on
`main`. **No member was added or changed.** The screen calls nothing else on
the app.

How the shell must implement it:

- `state` must never be null while Play is shown, and must be the *same*
  object between notifications — the screen diffs `state.board` against what
  it last drew.
- `place` is a synchronous reducer call. Call `Game.place`, store the new
  state, **return the result, and do not notify listeners for it.** The
  screen already has the result and animates from it; a notification would
  make it animate the same placement twice.
- Every other change to `state` — `requestReroll`, continue, new game, a
  theme change, a settings toggle — must notify. Persist after notifying, not
  before; the screen's frame does not wait on storage.
- `requestReroll` handles payment itself (rewarded ad or `rerollCoinPrice`
  coins), calls `Game.reroll`, then notifies. The screen only draws the pill
  and reports the tap.
- `requestPause` opens the pause sheet. The screen does not pause the engine;
  a Flutter route on top stops it receiving pointers, which is enough.
- `onGameOver` is called **once**, after the 500 ms hold and the 250 ms dim
  have finished, i.e. ~750 ms after the fatal placement. The board is already
  dimmed to brightness 40% / saturation 65% behind whatever sheet is shown.
  `state.status` is `over` from the moment `place` returned.
- `rewardedRerollAvailable` picks the pill's right-hand glyph: a play triangle
  when true, the coin icon and `rerollCoinPrice` when false.
- `showFirstGameHints` is `profile.gamesCompleted == 0`. The screen picks
  which of the two lines to show from `state.placements` and `state.maxCombo`.
- `bestScore == 0` hides the whole Best column (the round-1 finding that a new
  profile has no best).

### Which animation is triggered by what

| trigger | animates |
| --- | --- |
| `place` returns a `PlacementResult` | place flash on `cellsPlaced`, staggered clear of `cellsCleared`, particles, shake by `linesCleared`, banner from `comboCount`, popup of `pointsAwarded`, tray refill on `newSetGenerated`, game over on `gameOver` |
| notification, same `state.id` | the board diff (cells that emptied animate a clear, cells that filled animate a place), the tray refill, the score roll, the banner. This is how a **continue**'s three cleared rows and a **reroll**'s new pieces animate |
| notification, new `state.id` | hard reset: the new board and tray are drawn on the next frame, no animation. Design 9.3's "restart visible within 300 ms" is one frame here |
| notification, different `palette` | every `Paint` is rebuilt; no animation |

## Geometry

Everything is derived in `PlayGeometry.of(size, safeTop:, safeBottom:)` from
the **width**, as `styles.md`'s 360 CSS px ladder times `s = width / 360`.
Nothing else in the screen computes a position.

| element | 360 px reference |
| --- | --- |
| screen side padding | 10 |
| well radius / padding | 16 / 7 |
| cell gap / radius | 4 / 5 |
| cell (falls out) | (340 − 14 − 28) / 8 = **37.25** |
| HUD label / score / best | 11 letterspaced ·16em / 36 w800 −·02em / 15 w700 |
| gutter (combo only) | 22 |
| band (reroll pill right, hint centred) | 44, fixed |
| tray | 106; pieces at 60 % of a grid cell, gap 3, radius 4 |
| empty tray slot | an 8 px dot; a piece that fits nowhere at 45 % opacity |
| pause button | 44 square, top right, `safeTop + 6` |

Vertically the HUD + rule + gutter + well group is centred in what is left
above the band, never higher than the pause button. At 320, 360 and 411 px
wide the tray is above the fold with room to spare — the horizontal budget is
the binding one, as the comps found.

The drop anchor is the grid cell under the piece's **top-left cell** after
rounding, clamped into `[0, 8 − pieceWidth/Height]` so an edge drag still
lands. A drag only aims at the board while that lead cell is within one cell
of the well.

## Animation timings, as shipped (design 9.3)

| moment | as built |
| --- | --- |
| pick up | 120 ms ease-out, cell size tray-scale → grid scale |
| place | cells 1.1 → 1.0 over 120 ms |
| clear | 80 ms white flash at 90 %, then 180 ms shrink to 0.55 and fade, staggered 15 ms per cell of distance from the placed piece's centroid; 8 particles per cell, 450 ms, gravity 620·s |
| score popup | `+n` at the clear centroid, clamped inside the well, floats 40 px over 500 ms, opaque until 60 % then fades |
| shake | only for `linesCleared >= 2`: 2 px × n, 150 ms, damped sine on the well |
| combo banner | scales in 200 ms `easeOutBack` on every change, then **holds while `comboCount >= 2`** and reverses when it drops |
| score roll | 300 ms smoothstep to the new value |
| game over | 500 ms hold → sound and the double heavy haptic → 250 ms dim to brightness 40 % / saturation 65 % → `host.onGameOver()` |
| fly back | 200 ms `easeOutCubic` to the slot, shrinking back to tray scale |
| tray refill | 220 ms fade and 6 px rise per new slot |

Design 9.3's pick-up "scale 1.0 → 1.15" is realised as tray-scale → grid
scale, because `styles.md` pins the held piece at grid scale 1.0 (the comps'
1.26 existed only because a still frame cannot show motion).

## Sound and haptics (design 9.4)

Driven only from `PlacementResult`. `place` → `place.wav` + selection click.
A clear → `clear_<multiplier>.wav` (1–8) and light impact for one line,
medium for two or more. `comboCount` 3/5/8 → the matching stinger and a heavy
impact. A board clear → `board_clear.wav`. Game over → `game_over.wav` and two
heavy impacts 120 ms apart.

`AudioService` is `preload()` / `play(Sfx)` / `setEnabled`. `FlameAudioService`
holds one `AudioPool` per WAV; `place` and the first two clear steps keep a
warm player, the rest are created on demand. `NoopAudioService` and
`NoopHapticsService` are the defaults, so a `PlayScreen` in a test is silent.

## Palettes

`ThemePalette` is `id, name, ground, well, empty, hairline, ink, muted, faint,
accent, onAccent, blocks[8], lightGround`. `ThemePalette.all` is design 7.3's
slot order, so slot *N* is `all[N]`; `byId` falls back to Obsidian so a stale
saved id cannot crash. `lightGround` is true only for Pearl.

Obsidian is the `styles.md` table verbatim. The other eleven are held to the
`styles.md` rules by `test/ui/play/palette_test.dart`: every block colour at
4.0:1 or better on its own empty cell, and each theme's closest block pair at
CIEDE2000 12 or more (`palette_metrics.dart` beside it has the maths, and
reproduces the comps' `measure.js` numbers exactly — Obsidian's closest pair
is 16.5 in both).

`typography.dart`'s `manrope(...)` sets `fontWeight` **and**
`fontVariations: [FontVariation('wght', n)]`. Manrope ships as one variable
TTF, so without the variation every weight renders the same. Verified on the
emulator at 300/400/500/700/800 (the harness's `type` scenario).

## Differences from the exemplar frames, and why

The exemplar PNGs were shot from concept A **before** the two transplants
`styles.md` ruled in, so these are deliberate:

1. **The board is bigger.** Side padding 10 instead of 16 (C's geometry),
   cell 37.25 instead of 35.75 at 360 px.
2. **The hint is above the tray, not below it.** `styles.md` and design 9.1
   put the hint and the reroll pill in one fixed-height band between the board
   and the tray, so the board never moves when the hint goes.
3. **There is a pause icon** at the top right and a **reroll pill** in the
   band. Neither is on any comp; both were ruled in afterwards.
4. **The held piece is at grid scale and sits on its own ghost.** The comp
   drew it 1.26× and 66 px off-lattice because a still frame cannot show
   motion; in the hand the piece tracks the finger 64 px above it and the
   ghost shows around it whenever the piece is off-lattice.
5. **The clear is staggered**, so a screenshot rarely catches the whole line
   white at once the way the comp did.
6. Filled tiles carry the comp's `0 1px 2px` shadow as one extra rounded rect
   rather than a blur — 64 mask filters a frame is not affordable. The sampled
   colours are identical to the exemplar (highlight `#8FD6BC` over `#3EB98C`,
   shade `#2B8161`, seat `#06080D`); only the falloff below the tile is 5 px
   hard instead of 10 px soft.

Everything else was matched by sampling the exemplar's own pixels: ground,
well, empty cell, the empty cell's inner top shadow, tile body, highlight and
bottom shade all read the same values as `play-first-launch.png` and
`play-mid-drag.png`.

## Performance

`build`/`update` allocate nothing per frame: the board keeps 64-cell
`Int8List`/`Float32List`/`Uint8List` arrays and one `Paint` per role per
palette, `render` does no layout, and the ghost and line-imminent sets are
recomputed only when the drop anchor changes — never per frame. The hover
recompute uses `Board.canPlace` and `Board.place(...).fullLines()`, never
`Game.place`.

Measured on `emulator-5554` (1024×2216, density 420), profile build, 36
placements with clears and particles, against a static-board control:

| | frames | janky (>16.67 ms) | p50 | p90 | p99 |
| --- | --- | --- | --- | --- | --- |
| build, 36 placements | 1125 | 0.0 % | 0.3 | 0.5 | 1.3 |
| raster, 36 placements | 1125 | 34.9 % | 16.2 | 18.2 | 21.7 |
| total span | 1125 | 81.8 % | 18.8 | 20.9 | 24.2 |
| raster, idle control | 777 | 27.5 % | 15.3 | 17.8 | 22.4 |

The emulator cannot show a sub-16 ms p90 even on a static frame, so the 60 fps
target is unverified here. What is measurable is the delta: a full game of
placements, clears and particles adds ~0.9 ms to raster p50 and keeps the Dart
side under 1 ms at p90. Re-measure on hardware before trusting a number.

## Instrument traps

- **`tools/emu.sh perf` is useless for this app.** `dumpsys gfxinfo` counts
  HWUI frames; Flutter on Impeller draws to its own surface and reports none,
  so it prints zeros or single digits. Real frame times come from the
  harness: open its menu, tap `perf`, and read the `PERF` lines out of
  `emu.sh logcat`. It reports build, raster and total separately — only
  `build` is yours.
- **`input swipe` is not a drag.** It sends down, one move, up, so the ghost
  never appears. Use `emu.sh drag` (multi-step `motionevent`), or `emu.sh
  hold` + `emu.sh release` when you need to screenshot mid-drag.
- **To catch an animation, burst inside one `adb shell`:**
  `adb shell "input motionevent UP x y; for i in 1 2 3; do screencap -p
  /sdcard/c$i.png; done"`. A round trip per screenshot is slower than the
  260 ms clear.
- The emulator's `/data` fills after a few `install -r`; `emu.sh install`
  uninstalls first.
- The emulator carries a `wm size` override (1024×2216 on 1080×2400). Read it
  with `emu.sh size` and compute taps from it; never reset it.
- The device is shared with other sessions installing the same package id.
  Reinstall the harness before a shot batch and check
  `dumpsys activity activities | grep topResumedActivity`.

## Flutter and Flame traps paid for here

- **`DragUpdateEvent.canvasEndPosition` is one move ahead of the finger.**
  Flame builds it as `details.globalPosition + details.delta`, and
  `globalPosition` is already current. Use `canvasStartPosition`.
- **The first `LayoutBuilder` pass can arrive at zero size.** A game built
  from that geometry never recovers unless `applyGeometry` stores the new
  geometry even before `onLoad` has run.
- **A `GameWidget` in a loose `Stack` renders nothing.** The Stack sizes to
  its smallest child, `Positioned.fill` fills zero, and the positioned
  siblings still paint — so the HUD appears and the game does not. Give the
  Stack an explicit size.
- Anything reached from a host notification must be guarded until `onLoad`
  has run, or `late` component fields throw on the first notification.
- `TextPaint` caches a `TextPainter` per distinct string forever; the score
  popup owns its own `TextPainter` per instance instead.

## The harness

`flutter run -t lib/dev/play_harness.dart -d emulator-5554`, or
`tools/emu.sh install -t lib/dev/play_harness.dart [-p]`. A fake profile
(best 12,460, coins 1,240) and an in-memory `PlayHost`; game over shows a
placeholder for a second and starts a new game.

The dot at the bottom left opens the menu: `perf` prints and clears the frame
timings, then `empty`, `mid`, `clear`, `danger`, `over`, `type`, then the
twelve themes. `clear` is authored so that dropping slot 0's `i3` at row 3,
column 5 completes a row and a column at once on a combo of 3 — the exemplar's
"Combo x4" and a `+123` popup. `over` is the 51/64 danger board with a `dot`
and an `o3`: place the dot and the `o3` fits nowhere.
