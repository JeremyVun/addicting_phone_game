# Settle — visual language

Ruled 2026-09-08 by the orchestrating session on the round-1 comps
(owner absent; first thing to revisit if the owner disagrees). Exemplar
frames are in `assets/exemplar/`; the comp source that produced them is in
`assets/exemplar/comp/` (`a-well.html` + `base.css` + `render.js` +
`data.js`; open with `?scenario=p1|p2|p3|p4|p5|h1|h2`). Build against the
exemplar images, not this prose, and compare side by side each iteration.

## The verdict

Concept A "Well" is the design: the board sunk into a recess, editorial
numerals on a hairline rule, a bare tray with no dock or cards, and the
combo typeset in the gutter above the board. Transplants ruled in:

- C's board geometry: side padding 10 px at 360 CSS px width (cell about
  37.6 px), keeping the recess.
- The bottom sheet for game over stays as in A (the D "type on the dimmed
  board" transplant was refused: a modal sheet is the standard, cheaper
  pattern and the dimmed board behind it is enough context).
- D and B stay refused: D hides the empty cells behind a dot lattice, which
  a first-time player must decode; B's pill chips cannot hold the widest
  legal score.

Controls the comps did not draw, now ruled: a pause icon at the top right
of the HUD (opens a sheet with Resume, Home, sound and haptics toggles);
the reroll button as a small pill, right-aligned in the band between the
board and the tray, showing the reroll icon and either a play triangle
(rewarded ad available) or the coin price; the first-game hint line
centred in the same band. The band has a fixed height so the board never
moves when the hint disappears.

## Materials

- Font: Manrope (OFL), weights 300–800, bundled under `app/assets/fonts/`.
- Ground `#0D1016`; well `#090C12`; empty cell `#1C2230`; hairline
  `rgba(255,255,255,.08)`; ink `#F2F4F8`; muted `#8A93A6`; faint `#5B6478`;
  accent (Play button, combo, New best, rings) `#F0A03A`.
- Block colours by family (design 2.2), contrast on ground / on empty cell:

| slot | family | hex | ground | empty |
| --- | --- | --- | --- | --- |
| 0 | dot | `#E8543F` | 5.23 | 4.27 |
| 1 | i2, i3 | `#F0A03A` | 8.88 | 7.25 |
| 2 | i4, i5 | `#A9C94E` | 10.11 | 8.26 |
| 3 | o2 | `#3EB98C` | 7.73 | 6.31 |
| 4 | o3, r23 | `#3AA6DE` | 6.97 | 5.69 |
| 5 | l3, l4 | `#7C7CEA` | 5.38 | 4.39 |
| 6 | l5 | `#C167D6` | 5.60 | 4.58 |
| 7 | t4, s4, z4 | `#EE7CA8` | 7.33 | 5.99 |

The Obsidian theme is exactly this table. Other themes change the eight
block colours, ground, well, empty cell and accent; every theme must keep
each block colour at 4.0:1 or better against its empty cell and a closest
pair of block colours at CIEDE2000 12 or more (the comp's `measure.js`
prints both).

## Geometry and type (360 CSS px reference; scale by width)

- Screen padding 10 px sides on Play; well radius 16, well padding 7, cell
  gap 4, cell radius 5, tray piece cell radius 4.
- HUD: label 11 px letterspaced small caps; score 36 px weight 800,
  letter-spacing -0.02em; best 15 px weight 700 muted; hairline rule under
  the HUD; combo 15 px weight 800 accent, right-aligned in the gutter.
- Tray height 106 px; pieces at 60% of grid cell size; an empty slot shows
  an 8 px dot; a piece that fits nowhere is drawn at 45% opacity.
- Score popup 34 px weight 800 white with a soft text shadow, no box.
- Game over sheet: radius 22 top, big numeral 44 px, stat rows 13 px on
  hairlines, primary button 52 px high radius 13 accent with dark text,
  secondary button outlined, Home as a text button.
- Home: coins and level (progress ring) top left, settings top right,
  wordmark 19 px letterspaced 0.42em, a motif board, Play 64 px high
  accent, the Daily card with the streak numeral, Themes and Shop as
  outlined links.

## Tile states (build invariants)

- Filled: colour fill, inset top highlight `rgba(255,255,255,.42)` 2 px,
  inset bottom shade `rgba(0,0,0,.3)` 2.5 px.
- Held (being dragged): grid scale 1.0 (the comps used 1.26 only because a
  still frame cannot show motion), 64 px above the finger, a 16 px drop
  shadow and a 1.5 px light rim on every cell.
- Ghost: never a dimmed fill (amber at 40% is brown). Fill the target cells
  at 18% of the piece colour over black and draw a 2.5 px inset ring in the
  full piece colour.
- Line-imminent: every cell of any row or column that the ghost would
  complete gets a 2 px white inset ring at 55–62% and a soft glow.
- Clearing: 80 ms flash to `rgba(255,255,255,.9)`, then the shrink-and-fade
  of design 9.3.
- Game over: HUD, well and tray at brightness 40% and saturation 65%
  behind the sheet.

## Instrument traps inherited from the comps

Playwright device emulation must use `browser.newContext({deviceScaleFactor})`;
a CDP metrics override reports the right ratio but screenshots at 1x.
Assert the PNG's own pixel size. The on-device instrument for the app is
`tools/emu.sh`.
