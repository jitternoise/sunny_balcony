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

## 🔴 Blockers — the project does not currently run

Both are missing icon assets, and they are the first thing to fix. Neither
appeared in the previous open-items list.

**1. `icon_hydro.svg` is missing and breaks compilation.**
`HexBoard.gd:38` has `const ICON_HYDRO := preload("res://assets/icons/icon_hydro.svg")`.
A `preload()` of a nonexistent path is a *parse-time* failure in Godot, so
`HexBoard.gd` never compiles, `Level.tscn` can't instance its board, and the
game cannot start at all — not just the hydro feature. `game/assets/icons/`
contains 9 SVGs and this is not one of them.

**2. `icon_catapult.svg` is missing.**
Referenced as an `ext_resource` by `game/data/blocks/bomb_catapult.tres:4`.
Fails at resource load rather than parse, so it's the less severe of the two,
but the Bomb Catapult block is unusable until it exists.

Both were already flagged at the end of `gameplay-changes-2026-08-31.md` as
"still outstanding from the 2026-08-25 revision check". They have not been
addressed since.

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

Fix the two missing icons first — until then the game cannot launch, so none of
this list can be checked. After that, the items worth confirming by eye are the
ones the old list named (buffered placement responsiveness, the beat-4 status
reveal, scrolling on tall levels, the Jamboree inventory bar, icon and glyph
rendering, Level Select word-wrap, the loss/intro/win popups, pre-start flow
arrows, the flat grid's pixel geometry on level 20, the sky/grass background at
multiple aspect ratios, town-flood coloring, geyser feed-blocking), plus the new
direction arrows above. Note that popup routing now needs checking at level
**100**, not 20, and that `level_018.tres` — reconstructed from a README
description and never re-verified against the engine — is still unconfirmed.
