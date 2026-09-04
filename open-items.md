# Flash Flood — Open Items

Reconciled 2026-09-04 against the actual code and level data. The previous
version of this file was compiled from the 2026-08-10 `dev-progress.md`
session and had drifted badly: it described a 20-level project with no dig
mechanic, no mudslides, no hydro plant and no bomb catapult, all of which now
exist. Every claim below was checked against the tree rather than carried
forward from the older doc.

Method and its limits: everything here is verified by reading source, level
`.tres` data and asset paths. **Nothing has been run.** Godot is not installed
in the environment where this reconciliation was done, so no claim about how
anything *looks or feels* is verified — see "Needs a live playtest" at the end.

---

## ✅ Blockers cleared 2026-09-04

Both missing icon assets have been supplied and installed, and every `res://`
reference in the project now resolves (120 checked: scripts, scenes, block and
level data, theme). The project should compile again.

- **`icon_hydro.svg`** — was `preload()`ed as a `const` on `HexBoard.gd:38`
  without existing, a parse-time failure that stopped the whole game loading,
  not just the hydro feature. Now at `game/assets/icons/icon_hydro.svg`.
- **`icon_catapult.svg`** — referenced as an `ext_resource` by
  `game/data/blocks/bomb_catapult.tres`. Now present.

Both arrived in the `hydro-catapult-tiles/` drop (commit `2a081ed`) and match
the house style `icon-system.md` specifies — 100×100 viewBox, `#1e2530`
outline, stroke-width 5, same as the existing Diverter and Splitter glyphs.

⚠️ **Compilation is inferred from static reference checking, not observed.**
Godot still isn't installed here, so nothing has actually been launched. The
first real playtest is still pending and is still the project's largest
unknown.

Note that the same drop also carried older copies of `HexBoard.gd`, `Level.gd`,
`BlockData.gd` and `LevelData.gd` predating the 2026-08-31 session — they lack
`_draw_block_direction_arrows`, `_block_target_offsets`, `_preview_arrows`,
`_preview_from_cells` and `footprint_offsets`. **Those were deliberately not
taken**; only the two icons were. Anyone revisiting commit `2a081ed` should
know its scripts are a regression, not an update.

---

## ✅ Resolved since the 2026-08-10 list

- **All 100 levels are authored.** The old list said "currently 20 of ~100".
  `game/data/levels/` holds 100 `.tres` files, `level_id` 1–100 with no gaps
  or duplicates, every one carrying a non-empty `intro_text`, a `pool_targets`
  entry, and (99 of 100) `fire_cells`. `LevelSelect.LEVEL_PATHS` lists all 100.
- **A fresh project build was delivered.** The old list asked for a rebuilt zip
  because the last one predated the win popup, intro popup, flow-preview
  arrows, town-flood color, the array-type crash fix, geyser feed-blocking and
  the 4-beat tick cycle. All of those are present in the current tree
  (`win_panel`, `intro_panel`, `flow_preview`, `flooded_towns`, the
  `BeatPhase` enum).

## ❌ Still open — verified as genuinely outstanding

**The level editor is further behind than the old list said.**
`level-editor.html` supports 6 level fields: `water_sources`, `fire_cells`,
`pool_targets`, `starting_inventory`, `blocked_cells`, `town_cells`. It knows
nothing of the other **nine**: `intro_text`, `grid_style`, `source_flow_style`,
`geyser_cells`, `dirt_cells`, `hydro_plant_cells`, `total_block_budget`,
`corridor_half_width`, `preset_blocks` — nor of `footprint_offsets`, so it
still draws the Wall one cell wide when the game now makes it two. The old list
named four missing fields; it is nine.

**No Geyser icon.** Still using the procedural `_draw_geyser_icon()` droplet
(`HexBoard.gd:1954`) while every other terrain type has real art.

**Tempo work — all three items untouched.**
- `ticks_per_beat` is a single global `var` on `Level.gd:31`, currently `2`.
  It is not per-level and the 72/80 BPM figures from the timing spec appear
  nowhere in the codebase (`grep -i bpm` returns nothing).
- Mid-level tempo shift is unbuilt; `Level.gd:29` still describes it as
  hypothetical.
- `_on_subtick()` (`Level.gd:580`) still returns early on every sub-tick that
  isn't a beat boundary. No animation or audio pulse hangs off it.

**Save-slot delete/reset UI.** `GameState.delete_slot()` exists and works; it
has exactly one occurrence in the codebase — its own definition. Nothing calls
it.

**Never built at all** (each confirmed by grep returning zero hits): scoring;
pause handling; sound and music (no `AudioStreamPlayer` anywhere); a settings
menu; an accessibility pass; level-complete visual polish; any level curriculum
beyond `GameState.is_level_unlocked()`'s linear gate.

**No campaign-complete screen.** Unchanged in substance, but the old list
described it at level 20 — it is now level 100. `_on_level_won()` sets the win
button's label to "Level Select" when `_next_level_path()` is empty. Finishing
the game is indistinguishable from finishing any other level.

---

## 🟡 Found by the first real playtest (2026-09-04)

Godot 4.7.2 is now available, so the project has been **run** for the first
time, not just read. It imports cleanly (all 11 SVGs), every script compiles,
and the main scene runs without errors. The two icon fixes above are confirmed
by execution, not just by reference checking.

Two headless tools were added under `game/tools/` to make this repeatable:

- **`smoke_test.gd`** — loads all 100 levels and the block catalog, validates
  ids, sources, win conditions, block references, and that terrain sits inside
  each level's declared playable area. Exits non-zero on failure, so it can
  gate a build.
  `godot --headless --path game --script res://tools/smoke_test.gd`
- **`LevelHarness.tscn`** — runs any level for N beats with no input and
  reports water depth, live cells, fires remaining and win/loss state. With a
  third argument it saves a PNG of the board, which is how the screenshots
  below were produced.
  `godot --headless --path game res://tools/LevelHarness.tscn -- 24 40`

**Water sources outside the playable area — 13 of 19 fixed.** All 19 sat at
`(-1, -4)` on a `grid_radius = 4` board (distance 5), where every other source
in the game (88 of 107) sits exactly on the rim.

This was never a simulation bug. From `(-1, -4)` the down-left diagonal is
off-board and gets skipped, and the fallback lands on the same cell an on-rim
source reaches. It was a rendering bug: `HexBoard._draw_source_marker()` is
called for every `water_sources` entry with no `in_playable_area()` check, so
the marker and its first flow-preview arrow drew detached from the grid.

**Fixed (13 pointy-grid levels)** — 24, 28, 29, 34, 38, 42, 46, 47, 48, 50, 53,
66, 72 — moved to `(0, -4)`. Verified by running all 19 levels for 60 beats
before and after: output is byte-identical, so nothing about the simulation
moved. Confirmed visually too — the marker now sits on a tile.

**⏸ KNOWN — deferred (6 flat-grid levels)** — 55, 56, 59, 60, 61, 62.
Acknowledged and left for later, not an oversight. These need a
design decision, because on a `grid_style = "flat"` board water falls straight
down a column (`Hex.FLAT_DOWN`), so moving the source sideways moves the entire
stream. Both candidate fixes were tested and both change gameplay:

- `(0, -4)` — shifts the stream one column. Measurably different: level 59 goes
  from an edge loss at beat 38 to still running at beat 60, level 55's fire
  stops being extinguished.
- `(-1, -3)` — keeps the column (it's the topmost in-area cell at `q = -1`) but
  starts the water one row lower, shifting every level's timing by a beat.

A third option is to guard the draw call instead of touching the data, but then
those levels show no source marker at all, which is arguably worse than one in
the wrong place. Note these 6 also use `(-1, -4)` as a `source_flow_style` key
(level 56's is `"zigzag"`), so any data fix must update both or the flow style
silently reverts to `"straight"`.

`smoke_test.gd` carries these 6 in its `KNOWN_ISSUES` allowlist: they print
under a KNOWN heading and do not fail the run, so the exit code stays
meaningful and a genuine regression still stands out. **Remove them from that
allowlist when fixing** — a stale entry silently hides the thing it tracks.

---

## 🆕 New items the old list predates

**The solution book is roughly half invalid.** The 2026-08-31 change making the
Wall 2 tiles wide invalidated every documented solution that places one — **49
of 100** levels, 51 placements. `level-solutions.md` and `level-min-times.md`
must be treated as unverified for those levels. Levels **54** ("Town Defense
VIII", the only two-wall level, one wall now landing adjacent to the town blob)
and **92** ("The Gauntlet VI", where a 2-wide wall takes 2 of 5 cells in a
`corridor_half_width = 2` row) were called out for re-checking first.

**The Python simulator is not in the repository.** Every re-verification path
above depends on it, and the docs reference it repeatedly, but there is no
`.py` file anywhere in the tree. It needs `footprint_offsets` support to redo
the wall solutions — which cannot start until the sim itself is recovered and
committed. This also means the sim and engine can silently diverge, the exact
failure class behind the 2026-08-17 rounding-parity bug.

**The Hydro Electric Power Plant is dead code.** Fully implemented in
`LevelData.gd`, `HexBoard.gd` (`hydro_plants`, `hydro_ready_at()`,
`try_activate_hydro()`, `_is_inactive_hydro()`) and documented at length — and
used by **zero** of the 100 levels. It has never been exercised by real level
data. Its doc comment also notes it is pointy-grid only and untested on a flat
grid.

**Placement failure is silent.** When neither footprint orientation of a 2-wide
Wall fits, the tap does nothing, with no feedback to the player.

**The mudslide mechanic exists** (added 2026-08-17: water stalled against dirt
collapses 3 tiles) and is absent from the old list entirely. Level 21's
`intro_text` teaches it, so it is player-facing.

**Splitter/Diverter direction arrows have never been looked at.** Added in the
2026-08-31 change set and reasoned about only on paper — specifically whether
two arrows crowd a Splitter tile at real device size.

---

## Needs a live playtest

Unchanged as a category, and still the single largest risk: **no feature in
this project has been confirmed running in a live Godot window.** All
verification to date, including this reconciliation, has been static.

With the two missing icons now in place the project should load, so this list
is finally checkable. The items worth confirming by eye are the
ones the old list named (buffered placement responsiveness, the beat-4 status
reveal, scrolling on tall levels, the Jamboree inventory bar, icon and glyph
rendering, Level Select word-wrap, the loss/intro/win popups, pre-start flow
arrows, the flat grid's pixel geometry on level 20, the sky/grass background at
multiple aspect ratios, town-flood coloring, geyser feed-blocking), plus the new
direction arrows above. Note that popup routing now needs checking at level
**100**, not 20, and that `level_018.tres` — reconstructed from a README
description and never re-verified against the engine — is still unconfirmed.
