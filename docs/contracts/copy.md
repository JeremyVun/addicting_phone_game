# Copy

Every player-facing string lives in `app/lib/ui/strings.dart` (`S`) and the
play HUD labels in `app/lib/ui/play/play_strings.dart`. Widgets never
inline text. Tests assert on `S.*`, never on literals.

Drafting: strings are drafted by Codex (`codex exec -m gpt-6-astra`, owner
ruling 2026-09-08; the v1 draft was `gpt-5.6-sol`, reviewed by
`gpt-6-astra` on 2026-09-09) under the `user-facing-copy` skill; agents
wire keys and may add a plain placeholder string, listing it for the next
Codex pass.

Naming, one thing one name: coins, streak, daily puzzle, theme, level,
freeze (a streak freeze), continue, reroll, blocks. "Vibration", not
"haptics". No developer words (interstitial, session, token) in copy.

Review verdicts already ruled (do not relitigate): labels take no full
stop, including the two first-game hints; "Resume" stays (Continue is the
game feature); "Home" and "Not now" stay as labels; "Best" and "New best"
stay short; "Day streak" keeps its unit; the HUD's SCORE/BEST uppercase is
the letterspaced small-caps treatment of `docs/styles.md`, not a copy
choice. Shop copy avoids "interstitial": "No ads between games, plus one
free continue every game".

Fixed texts: hint 1 "Drag a block onto the grid", hint 2 "Fill a row or
column to clear it", reminder title "Daily puzzle ready", body "Today's
puzzle is ready to play.", theme names in slot order Obsidian, Dawn,
Meadow, Coral, Glacier, Desert, Storm, Lavender, Ember, Plum, Pearl,
Lagoon; achievement names and descriptions in `app/lib/meta/achievements.dart`.

Store text lives in `docs/store/` (listing, privacy policy, data safety).
