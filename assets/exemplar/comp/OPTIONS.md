# Settle — design comps, round 1 (Play + Home)

## 1. Where everything is

| what | path |
| --- | --- |
| workshop | `/tmp/settle-comps-r1/` |
| contact sheet | `/tmp/settle-comps-r1/index.html` (open in a browser) |
| concepts | `a-well.html` `b-slab.html` `c-column.html` `d-lattice.html`, each `?scenario=p1…p5,h1,h2,p2w` |
| shared fixture | `data.js` (numbers, boards, pieces, palette, declared synthetic deltas) |
| shared primitives | `render.js` (grid, piece, ring, icons, quiet-window finder) |
| shared type + reset | `base.css` + `fonts/manrope-latin-{300..800}-normal.woff2` |
| instrument | `shoot.js` — `node shoot.js [concept] [scenarios]`, `node shoot.js zoom` |
| palette measurement | `measure.js` — `node measure.js` prints contrast and CIEDE2000 |
| sheet generator | `mksheet.js` |
| shots | `shots/<concept>-<scenario>-<frame>.png`, true device resolution |

**Recommendation in one line:** ship **A / Well** as the exemplar, widened to C's grid geometry and
with D's sheet-less game over transplanted; §3 has three measurements that constrain any choice.

## 2. Ground rules held to

- **Spec.** Every concept answers all five items; they diverge only in how.
  (1) grid is the hero — 64/64 cells above the fold at all three frames in all four;
  (2) eight block colours measured, §3; (3) combo banner and score popup carry themselves on weight,
  size and placement — no scrim box, no blur panel anywhere in the round;
  (4) Home has one accent-filled Play, the Daily card directly under it, coins/level/streak in
  small-caps at 5.2 : 1 or dimmer; (5) no mascots, no faces, no confetti, no reward-machine motion.
- **Borrowed, not invented.** There is no house style yet, so the material is the design doc:
  the piece catalogue and family→colour map (§2.2), the drag behaviour (§9.2), the timings (§9.3),
  the screen inventory (§9.1), the first-session hint lines (§5.5), the economy numbers (§7).
  One type ladder per concept: 9–11 px letterspaced small-caps labels · 12–13 px body · 15–16 px
  action · one hero numeral. Labels are the only uppercase; "Combo x4", "Continue", "Play again",
  "Home" and the hints stay in the case the copy list gives them.
- **Data sources.** All values are from the design doc. Copy is exactly the supplied placeholder list —
  no word appears on a comp that was not on it (the wordmark "Settle" and the numerals aside).
- **Synthetic deltas, all four declared in `data.js`, the sheet lede and here.**
  (a) The four board fills are hand-authored, not director output; each is legal — `mid` 31/64 with
  row 5 two cells short, `clear` 34/64 with exactly one full row and one full column, `danger` 51/64 =
  80% with no full line standing and **zero** legal placements for its 3×3.
  (b) coins earned "+96" = 4,820 ÷ 50 (§7.1) applied by hand.
  (c) level 7 at 60% ring is picked inside the §7.2 curve, not read from a save.
  (d) p1 shows score 0 and **no Best line**: a new profile has no best. This is a design proposal, not
  just a fixture — it is the only difference between p1 and a normal HUD.
- **Frozen and untouched.** 8×8, three-piece tray under the grid, HUD above, dark only, solid rounded
  tiles, one bundled OFL font, verbatim copy.
- **The repo was not modified.**

## 3. Findings that outrank the concepts

1. **The vertical budget is never the constraint; the horizontal one always is.** At every frame the
   whole Play screen fits with 140–250 px of slack (64/64 cells above the fold, four concepts, three
   frames, zero overflow). The board is square and full-width, so cell size is set entirely by side
   padding: 16 px of padding costs 4 px of cell. Edge-to-edge (C) buys 38.1 px cells against the
   well's 35.8 — 13% more tile area — for the price of a board that touches the screen edge.
   **Any concept can be made "more hero" only by giving up side margin.**
2. **A dragged piece rendered at grid scale is ambiguous in a still frame, in all four directions.**
   The §9.2 rule (full grid scale, 64 px above the finger) is not enough on its own: at 1.0× the held
   piece reads as already placed. All four needed three cues together — 1.26× scale, a 7 px
   off-lattice offset, and a 16 px drop shadow — plus a 1.5 px light rim on the held cells.
   The rim is a new proposal and should become a build invariant.
3. **Highlighting only the two cells that complete a line is illegible; highlight the whole line.**
   §9.2 says the completing cells are drawn at 70%. On a busy board two brighter cells among 31 read
   as noise. Ringing all eight cells of the row that is about to clear (2 px white inset) makes the
   consequence readable in one glance, and the two ghost cells stay distinct (18% fill + a 2.5 px
   ring in the piece colour, with a second white ring). Every concept adopted it; the zoom row shows it.
4. **A ghost drawn as a dimmed fill of the piece colour turns brown.** Amber at 40% luminance is
   brown; so is every warm hue. The hue has to be carried by a full-strength ring, not by the fill.
5. **The game over sheet is the most expensive element on the small frame.** On frame C the sheet
   leaves 32/64 (A), 40/64 (B), 16/64 (C) cells visible; D's sheet-less treatment leaves all 64.
6. **The pill-chip HUD is the only one that cannot hold the widest legal score.** With a 7-digit score
   (`?scenario=p2w`, "1,284,600") on frame C, B's gear chip was crushed to 19 px wide — a tap target
   failure the instrument caught and the eye did not. Fixed with `flex:none` and a clamped numeral.
   The editorial HUDs (A, C) and the hero numeral (D) all held at their design size.
7. **All eight block colours pass on both grounds** (§ palette below); the closest pair is ΔE00 16.5,
   three times the usual "clearly different" floor, so the palette is not what decides this round.

## 4. The concepts

### A — Well  *(proposed exemplar)*
**Idea.** The board is sunk into the ground as a recess and the tiles seat into it, so placing reads as
seating a part. The HUD is editorial: a small-caps label over a 36 px numeral at the left margin, Best
answering at the right, a hairline under both. The tray is bare ground — three pieces, no slots, no dock —
and the combo is typeset in the 22 px gutter between the hairline and the board.
**Emotional target.** A well-made instrument on a desk at night. Quiet, precise, adult.
**Where the spec lands.** (1) grid 314/274 px, cell 35.8/30.8, 64/64 above the fold. (2) soft bevel,
2 px light top edge and 2.5 px shade — the strongest "solid object" of the four; contrast per §5.
(3) combo lives in the gutter, so it can never land on a tile; "+180" sits in the emptiest 1×3 window
at 34 px/800 with a contact shadow. (4) Home: wordmark, a board motif recessed in a small well, Play,
Daily, then Themes/Shop as outlined 48 px links; coins and level ride the top bar at 12–13 px.
(5) no decoration anywhere; the only colour outside the blocks is one amber accent.
**Motion.** Pick up 1.0→1.15 in 120 ms with the rim fading in; place 1.1→1.0 in 120 ms; the line rings
brighten as the ghost lands; clear = 80 ms flash then a 180 ms outward stagger; the combo types into the
gutter as the rule shortens; "+180" floats 40 px and fades.
**Build cost. S.** One container, one shadow recipe, no per-frame layout maths.
**Why this might be wrong.** The well costs 12 px of board on each side for an effect that is nearly
invisible at arm's length; C proves the same screen with a 13% bigger tile, and the well's inner shadow
may vanish on cheap panels at low brightness.
**Passes.** 1 fixed a dead vertical layout (`#root` had no height, the tray floated mid-screen);
2 bound HUD and board into one centred cluster so the hairline stopped drifting; 3 replaced the muddy
70%-mix highlight with a white ring on the whole completing row; 4 gave the home screen a recessed board
motif — the pure-air version left a 480 px void that read as unfinished; 5 strengthened the bevel and
rebuilt the ghost as ring-carried colour after the 6× clip showed it as brown.

### B — Slab
**Idea.** The board is a lifted slab floating over the ground with flat matte tiles, the HUD is pill
chips, and the tray is a dock of three recessed wells. The combo lights the slab's edge and rides its
top-left corner, so the board itself reacts.
**Emotional target.** A crisp, confident product — the most "app" of the four.
**Where the spec lands.** (1) grid 312/272, cell 35.5/30.5. (2) flat tiles, radius 4, no highlight —
the colours do all the work. (3) the edge glow is a second, non-typographic channel for the combo;
"+180" is placed by the same quiet-window rule. (4) Home: chips at the top, a slab-mounted board motif,
Play, Daily card with the streak numeral, two filled links. (5) restrained, though the glow is the one
element that could tip toward arcade if it is animated hard.
**Motion.** The slab edge lights over 200 ms and holds 700 ms; place presses the tile 1 px into the slab.
**Build cost. M.** Two nested surfaces plus a glow state on the container.
**Why this might be wrong.** The dock and the chips are 150 px of chrome that exist only to frame things
that could sit on the ground unaided; it is the least distinctive of the four and the one a competitor
screenshot would be mistaken for.
**Passes.** 1 fixed a class collision (`.hero` on the home wordmark restyled the score pill — the pill's
type was silently centred); 2 moved "+180" off the flashing row where white-on-white made it invisible;
3 hardened the chip track after the 7-digit stress crushed the gear chip to 19 px; 4 gave Home a board
motif and left-aligned the hint.

### C — Column
**Idea.** No container at all: the board runs edge to edge on the bare ground with printed-ink tiles
(a solid darker bottom face, no highlight), the score is a 46 px numeral at the left margin over a
single Best line, and the tray is three outlined cards. The combo is set large in the board's emptiest
window and Home is a hairline ledger, not cards.
**Emotional target.** An editorial page. The most grown-up, the least "game".
**Where the spec lands.** (1) grid 340/300, cell 38.1/33.1 — the biggest board in the round.
(2) printed ink: a 4 px darker base band reads as a block with a side, and survives the white flash
(the cleared cells keep a coloured foot). (3) the banner takes the emptiest 1×5 window in the lower
half and the popup the emptiest 1×3 in the upper half, so they never stack. (4) Home: coins / level /
streak as a three-column ledger between hairlines, then Play as a filled bar, Daily as a row, Themes and
Shop as small-caps links. (5) severe, but never cold — the accent bar carries the warmth.
**Motion.** The banner rises 12 px into place as the row flashes; the ledger numbers roll on return.
**Build cost. M.** The quiet-window search runs per clear; everything else is cheap.
**Why this might be wrong.** Edge-to-edge means a tile is 10 px from the screen edge — on a phone with a
curved display or a gesture bar the outer column is the one that gets mis-dragged, and the full-bleed
game over sheet hides 48 of 64 cells on the small frame, the worst in the round.
**Passes.** 1 fixed a 60% board with nowhere quiet enough for the banner — the fixture was thinned to
34/64 and the search given separate upper/lower bands after the banner and the popup collided;
2 raised the daily row to a 64 px target and killed the duplicated streak; 3 gave the tiles their
printed foot once the 6× clip showed C and B were the same flat material.

### D — Lattice  *(the brave one)*
**Idea.** Empty cells are not tiles: the board is an 8×8 lattice of 4 px marks inside four corner ticks,
and only placed blocks are objects — lit like glass, with a top sheen and a coloured halo on black.
One hero numeral centres the screen; when a combo runs it takes over the Best line, so **nothing new is
ever drawn over the board**; at game over there is no sheet at all, only type on the dimmed board.
**Emotional target.** A dark room with lit objects in it. The one that would be recognised from a
thumbnail.
**Where the spec lands.** (1) grid 324/284, cell 36.1/31.1; the board is the only lit thing on the
screen. (2) glass: 22% top sheen, 1.5 px light edge, a 14 px halo of the tile's own colour — measured
against the ground, not an empty cell, because there is no empty cell. (3) the combo never touches the
board; "+180" is the only thing that does. (4) Home: lattice motif, one centred stats line, Play,
Daily as an outlined row. (5) the halo is the one thing to watch — at 26% it reads premium, at 50% it
would read casino.
**Motion.** Marks under a legal ghost dim out as the ghost lands; the cleared cross blows out to white
and the tiles fall away leaving marks; the score numeral is the only thing that ever scales.
**Build cost. L.** Two materials, a mark layer, and a game-over screen that is not a sheet.
**Why this might be wrong.** Every competitor draws empty cells as tiles because they are the drop
target: a lattice of dots may make the board read as decoration rather than as 64 places to put
something, and that is a first-ten-seconds risk this round cannot measure. The centred axis is also the
least room for a long localised label.
**Passes.** 1 killed a doubled score (the dimmed HUD showed through the game-over type); 2 fixed the
home motif rendering as circles (radius 9 on a 19 px cell); 3 rebuilt the ghost as ring-carried colour;
4 added the glass sheen once the 6× clip showed D and A were the same bevel.

## 5. Block palette (recommended, identical in all four)

| slot | family (§2.2) | hex | on ground `#0D1016` | on empty cell `#1C2230` |
| --- | --- | --- | --- | --- |
| 0 | dot | `#E8543F` | 5.23 : 1 | 4.27 : 1 |
| 1 | i2 · i3 | `#F0A03A` | 8.88 : 1 | 7.25 : 1 |
| 2 | i4 · i5 | `#A9C94E` | 10.11 : 1 | 8.26 : 1 |
| 3 | o2 | `#3EB98C` | 7.73 : 1 | 6.31 : 1 |
| 4 | o3 · r23 | `#3AA6DE` | 6.97 : 1 | 5.69 : 1 |
| 5 | l3 · l4 | `#7C7CEA` | 5.38 : 1 | 4.39 : 1 |
| 6 | l5 | `#C167D6` | 5.60 : 1 | 4.58 : 1 |
| 7 | t4 · s4 · z4 | `#EE7CA8` | 7.33 : 1 | 5.99 : 1 |

Ground `#0D1016`, well `#090C12`, empty cell `#1C2230` (1.22 : 1 on the ground), hairline `#1E2430`,
ink `#F4F6FA` (17.6 : 1), muted `#9AA4B8` (7.6 : 1), faint `#6E7889` (5.24 : 1), accent `#F0A03A`.
Closest colour pair ΔE00 = 16.5 (`#7C7CEA` / `#C167D6`); every colour's nearest neighbour is ≥ 16.5.
Font **Manrope** (OFL), weights 300–800, bundled latin woff2, 84 kB total.

## 6. Vocabulary and contract additions needed (each an owner call)

1. **`line-imminent`** — the state of a row or column that the current ghost would complete. Proposed:
   every cell of it takes a 2 px white inset ring at 55%. §9.2 currently names only the completing cells.
2. **`held`** — a piece under the finger. Proposed: 1.26× scale, 1.5 px light rim, 16 px shadow, drawn
   off-lattice. §9.2 currently specifies only scale and the 64 px offset.
3. **`gutter`** — the 22 px band between the HUD rule and the board, reserved for the combo banner
   and for nothing else (concept A). Needs a name in `docs/contracts/visual.md`.
4. **First-launch HUD** — score 0 and no Best line until a first game ends. Not in the design doc.
5. **Game over surface** — "sheet" (a panel) vs "wash" (type on the dimmed board). §9.1 says modal
   bottom sheet; D proposes the wash and measurably keeps the whole board visible.

## 7. Recommendation

**Ship A / Well as the exemplar**, with three named transplants:

- **from C**: its board geometry. Take A's side padding from 16 px to 10 and the well padding from 7 to
  6 — grid 330 px, cell 37.6 on frame A, within 1 px of C — keeping the recess.
- **from D**: the game over treatment. No opaque sheet: dim the board to 20% and set the score, "New
  best", coins, Continue, "Play again" and Home directly on it. Measured gain: 64/64 cells stay visible
  on frame C instead of 32.
- **from B**: nothing structural, but its *edge* response is the right secondary channel — on a combo,
  let the well's inner edge take the accent for 700 ms while the banner does the typography.

**Why A over each other direction.** Over B: B spends 150 px on a dock and two chips to frame things
that stand on their own, and its HUD was the only one to fail the widest-value test. Over C: C is the
better page but the worse board — a tile 10 px from the screen edge is the one the thumb fumbles, and
its game over hides three quarters of the board on the small frame. Over D: D is the most beautiful and
the most recognisable, and I would ship it if this were a premium puzzle app — but it removes the drop
targets from the screen, and that is a risk the comps cannot measure.

**The condition under which it flips.** If the owner's priority is that Settle be recognisable in a
store screenshot rather than familiar in the hand, take D and transplant A's gutter combo into it; the
call turns on one playtest question — does a first-time player see 64 places to put a block, or a
pattern of dots?

## 8. Open questions

1. Is the accent amber `#F0A03A` the brand, or a placeholder? Every Play/Continue button and the combo
   depends on it, and it is also block colour 1 — the same hue is doing two jobs.
2. Should the daily card carry its own state word (played / not played) or is the accent play mark
   enough? The verbatim copy list has no word for it, so all four comps use a mark.
3. Reroll and pause are in §9.1 but on no comp — the tray has no reroll button and the screen has no
   pause. Where do they go, and does the answer change the tray?
4. Does the board keep its side margin (A, B, D) or run to the screen edge (C)?
5. Game over: sheet or wash (vocabulary item 5)?
6. First launch shows no Best line — agreed, or should it show "Best 0"?
7. Home: does it carry a board motif (A, B, D) or stay a pure ledger (C)?

## 9. What the next agent must know

- **Shoot.** `cd /tmp/settle-comps-r1 && node shoot.js` shoots everything (4 concepts × 8 scenarios ×
  3 frames = 96 PNGs, ~90 s). `node shoot.js c-column p3,p4` narrows it. `node shoot.js zoom` cuts the
  6× detail clips. Scenario names: `p1 p2 p3 p4 p5 h1 h2` plus `p2w` (the widest-legal-value stress:
  score and best both 1,284,600, combo x8). Frames `A` 360×800@3, `B` 360×760@2, `C` 320×640@2.
- **Instrument traps, all paid for once.**
  - `page.setViewportSize` + a raw CDP `Emulation.setDeviceMetricsOverride` gives you a page that
    *reports* `devicePixelRatio: 3` and then screenshots at 1×. The assert on `innerWidth/innerHeight`
    passes and the PNGs are silently 360×800. Only `browser.newContext({deviceScaleFactor})` captures at
    device resolution. `shoot.js` now asserts the **PNG's own pixel dimensions** and deletes the file if
    they are wrong — keep that check.
  - `chromium.launch({args:['--user-data-dir=…']})` throws; Playwright wants
    `launchPersistentContext`, but that gives one context and therefore one scale factor. Use plain
    `launch()` (fresh profile per run) plus a context per frame.
  - `document.fonts.check('700 16px Manrope')` returns false on a screen that uses only weights 500 and
    800, and reports a font failure that is not one. Check `document.fonts` entries for a loaded family.
  - A translucent overlay counts as occlusion unless you look at its alpha; the sheet-occlusion probe
    ignores panels with background alpha < 0.9, which is why D reports no sheet.
- **Layout traps.**
  - `#root` needs an explicit height or every `.screen { height:100% }` collapses to content height and
    the whole vertical composition silently top-anchors. This cost a cycle.
  - Class collisions are real even in one file: `.hero` styled the home wordmark and restyled the score
    pill in B. Namespace per screen.
  - Piece cell size is set in JS from a measured grid cell after layout (`--ps`, `--pgap`); if you add a
    concept, call `layout()` again after inserting the dragged piece — it is not in the first pass.
  - Google Fonts' CSS endpoint is blocked from this machine (it returns an HTML interstitial). The woff2
    files came from the `@fontsource/manrope` npm package, `files/manrope-latin-*.woff2`.
- **Fixture invariants** worth keeping if you edit the boards: `danger` must stay at 80% with zero legal
  placements for its 3×3 and no full line standing; `clear` must have exactly one full row and one full
  column; `mid` must leave row 5 exactly two cells short at columns 4–5. `node -e` checks in the git
  history of this file's siblings are trivial to rewrite — check before you shoot.
