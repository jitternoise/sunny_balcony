# Revision Check — 2026-08-25

Scope: the six files added to the project earlier today (Hydro Electric Power Plant + Bomb
Catapult), reviewed by inspection against the previously shipped copies, plus a consistency
sweep across the project's docs, the level editor, and the level data.

Nothing here has been run in a live Godot window — same standing caveat as the rest of the
project. Findings are ordered by severity.

> **Status update (same day):** every code defect below — items 3, 4, 5, 6, 7 and the
> `_is_wall()`/CATAPULT bug found while fixing them — has been fixed, and the six files
> have been consolidated onto their canonical `claude/game/...` paths with the root
> duplicates deleted (blocker 2). See the "Revision-check fixes" section at the end of
> `claude/new-tiles-hydro-catapult-design.md` for what changed and why.
>
> **Still open:** blocker 1 (the missing `icon_hydro.svg` / `icon_catapult.svg` assets —
> nothing runs until those exist), the polish/design questions, the stale README /
> `dev-progress.md` / `open-items.md`, the level-editor field gap, and authoring levels
> that actually use the two new tiles.

---

## Blockers

### 1. Two referenced asset files don't exist in the project

`HexBoard.gd` line ~36:

```gdscript
const ICON_HYDRO := preload("res://assets/icons/icon_hydro.svg")
```

`preload()` is resolved at parse time. If `icon_hydro.svg` isn't on disk, **HexBoard.gd fails to
compile and the entire game won't run** — not a missing-glyph fallback, a hard error.

`bomb_catapult.tres` has the same problem one level down:

```
[ext_resource type="Texture2D" path="res://assets/icons/icon_catapult.svg" id="2"]
```

Neither file is in the project. Existing icons all live at `claude/game/assets/icons/` (9 of
them: wall, diverter_left, diverter_right, splitter, fire, pool, town, source, blocked), mirrored
at `claude/icons/`. Nothing matching `hydro` or `catapult` exists at any path.

The design doc claims both were created this session. Either they were never actually written, or
they were written and never added to the project. Both need to exist at
`claude/game/assets/icons/icon_hydro.svg` and `icon_catapult.svg` before this revision can load.

### 2. The new files landed at the project root, not their canonical paths

| Added today (root) | Where it belongs |
|---|---|
| `HexBoard.gd` | `claude/game/scripts/gameplay/HexBoard.gd` |
| `Level.gd` | `claude/game/scripts/gameplay/Level.gd` |
| `LevelData.gd` | `claude/game/scripts/resources/LevelData.gd` |
| `BlockData.gd` | `claude/game/scripts/resources/BlockData.gd` |
| `bomb_catapult.tres` | `claude/game/data/blocks/bomb_catapult.tres` |
| `new-tiles-hydro-catapult-design.md` | `claude/new-tiles-hydro-catapult-design.md` |

The old copies are still sitting at the canonical paths, so the project now holds **two divergent
versions of four scripts**. Anyone (or any future session) reading
`claude/game/scripts/gameplay/HexBoard.gd` gets the pre-Hydro version with no indication it's
stale. This is the same root-vs-`claude/game/` divergence the 2026-08-10 "stale project upload"
entry records having already been cleaned up once.

`bomb_catapult.tres` matters most: `Level._load_block_catalog()` scans `res://data/blocks/`, so
until the file is in that folder the Bomb Catapult **does not exist in the catalog at all** — no
inventory button, no preset resolution, and `preset_blocks` referencing `"bomb_catapult"` would
crash on the `block_catalog[...]` lookup.

Also note `HexBoard.gd`'s own comment points readers at
`claude/new-tiles-hydro-catapult-design.md` — a path that doesn't currently exist.

---

## Real bugs in the new code

### 3. A scroll drag that starts on a catapult fires the catapult

`Level._process()` promotes a press into an aiming sequence based only on elapsed hold time:

```gdscript
if not _catapult_press_active:
        return
if Time.get_ticks_msec() - _catapult_press_started_msec < CATAPULT_HOLD_THRESHOLD_MSEC:
        return
_catapult_aiming = true
```

It never checks `_drag_active`. So on a tall dig level, the player presses a catapult tile, drags
to scroll the board, and 300 ms later the press silently becomes an aim — the release then fires
a live shot instead of ending a scroll. Catapults are one-shot consumables, so the resource is
gone.

Fix: bail out of the promotion when `_drag_active` is already true (a press that has passed
`DRAG_THRESHOLD` is a scroll, not a hold), and/or clear `_catapult_press_active` the moment
`_drag_active` is set.

### 4. Blocks can be placed on an activated Hydro Plant's cells

`place_block()` enforces the "no player-placed tiles on a water source" rule against
`level_data.water_sources` and `active_geysers`, but not `hydro_source_cells`:

```gdscript
if level_data.water_sources.has(coord) or active_geysers.has(coord):
        return false
```

After activation a plant's 3 cells revert to `EMPTY` terrain, so the `HYDRO` terrain guard further
down no longer catches them either. The player can drop a Wall directly onto a live hydro source —
exactly what that rule was introduced to forbid, and what levels 1/10/11/12 were relaid over.

Fix: add `or hydro_source_cells.has(coord)` to the same guard.

### 5. The pre-start flow preview walks straight through an inactive Hydro Plant

`_predict_branch()`'s block-redirect loop was not updated alongside the two real-simulation
equivalents:

```gdscript
# _predict_branch() — block-redirect branch (NOT updated)
if not in_playable_area(target) or _is_undug_dirt(target):

# _advance_water() and _advance_water_flat() — both updated
if _is_undug_dirt(target) or _is_inactive_hydro(target):
```

So a Diverter or Splitter aimed at a plant draws a preview arrow *into* the plant and keeps
forecasting past it, while the real water stops dead there. The natural-fall path in the same
function is fine — it routes through `_is_wall()`, which does handle hydro.

`_predict_would_consume()` should probably also be revisited: an inactive plant is a permanent
stop for preview purposes.

### 6. A spent preset catapult leaves a cell that swallows blocks

`fire_catapult()` does `placed_blocks.erase(catapult_coord)` unconditionally. If the catapult was a
`preset_blocks` entry, the coord stays in `level_data.preset_blocks` forever — so afterwards:

- `place_block()` allows a new block there (`placed_blocks.has(coord)` is now false), but
- `remove_block()` refuses to pick it back up (its first check is `preset_blocks.has(coord)`).

Any block placed on a spent preset catapult is permanently lost from inventory. Fix: have
`remove_block()`'s preset guard also require that `placed_blocks[coord]` still matches the preset
id, or track spent presets explicitly.

### 7. A catapult can't be fired before Start

`fire_catapult()` requires `placed_blocks.has(coord)`, but a player-placed block only reaches
`placed_blocks` on a PLACEMENT beat — and PLACEMENT beats only run after Start. So a catapult
placed during the planning phase is inert: `_is_live_catapult()` returns false, the hold does
nothing, and the release falls through to `place_block()`, which rejects it because a pending
placement already occupies the cell.

This is worth deciding deliberately rather than leaving as an accident, especially given the
project's "extra resources, multiple solve paths" goal — blasting a channel open *before*
releasing the water is an obvious thing a player will try.

**Related pre-existing issue, same root cause:** `_draw_cell()` and `_predict_flow_arrows()` both
read only `placed_blocks`, never `pending_placements`. Before Start there is no PLACEMENT beat at
all, so a block placed during planning is **invisible on the board and absent from the flow
preview** until the player presses Start. Several doc comments assert the opposite ("placing/
removing a block pre-start updates the preview immediately"). This predates today's work — it
arrived with the buffered-placement/4-beat-cycle change — but it's the single most likely
"why does the game feel broken" item on the first live playtest.

---

## Polish / design questions raised by the new code

- **The aim arrow is invisible for the first 350 ms of every shot.** At minimum charge,
  `_draw_catapult_aim()` computes `start_coord == end_coord`, so `_draw_flow_arrow()` normalizes a
  zero vector and draws nothing. Only the blast overlay shows. Either draw the arrow from the
  catapult itself, or start the preview at `CATAPULT_MIN_RANGE + 1`.
- **No way to cancel a charged shot.** Releasing always fires and always consumes the block, even
  if the target cluster contains no dirt at all. A "drag back onto the catapult to cancel" gesture,
  or refusing to consume a shot that clears zero cells, would soften a very punishing mis-tap.
- **A shot's distance is recomputed at release**, not taken from the last previewed frame, so a
  release landing just after a charge tick can fire one tile further than what was on screen.
- **Untouched Hydro Plant = soft lock.** An inactive plant blocks water permanently, and hydro
  stalls don't feed the mudslide counter (dirt only). A level whose only route runs through a plant
  will sit forever with no win and no loss if the player never double-taps. The "ready" ring
  mitigates this once water arrives — worth confirming it reads clearly on-device.
- **`_try_enter()` has no HYDRO branch.** DIRT has a defensive one; HYDRO doesn't. No live path
  reaches it today, but the asymmetry is a trap for the next person adding a water code path.

---

## Documentation contradictions inside today's own files

- `LevelData.hydro_plant_cells`' comment says flat grids are unsupported "see
  `HexBoard.resolve_water_phase()`'s hydro source-spawn loop, **which always uses the pointy
  `Hex.DOWN_LEFT` start**". The code does not — it has an explicit `is_flat` branch using
  `Hex.FLAT_DOWN`, mirroring the geyser loop. The design doc describes the code correctly; the
  field comment is the odd one out.
- `_is_wall()` gained `if _is_inactive_hydro(coord): return true`, but its doc comment is
  byte-identical to the old one and still enumerates only "a WALL block, an activated geyser, or a
  still-undug dirt cell".
- `_predict_flow_arrows()`' doc comment and `_try_enter()`'s doc comment were not updated for
  HYDRO. `_predict_branch()` line ~1486's inline comment still omits it too.

---

## Stale project docs

- **`claude/game/README.md`** — zero mentions of either tile. Stale in at least: "4 sample block
  types (Wall, Diverter-Left, Diverter-Right, Splitter)"; the icon list under Project structure;
  the `TickBehavior` enum walkthrough under "Adding content" (no CATAPULT = 5); the
  `_is_wall()`/`_try_enter()` terrain enumeration under "Notes on the current simulation model";
  the Playtesting section (tap-to-place/tap-to-dig only — no double-tap, no press-and-hold);
  "Known gaps" (still says Geyser is the only type without SVG art).
- **`claude/dev-progress.md`** — most recent entry is *"full 100-level campaign … (2026-08-17)"*.
  It's now **two sessions behind**: nothing for the 2026-08-20 work (levels, `level-min-times.md`)
  and nothing for today's tiles.
- **`claude/open-items.md`** — compiled 2026-08-10 and materially wrong now. It still lists
  "Author the remaining ~80 levels (currently 20 of ~100)" when all 100 ship, and its level-editor
  extension list predates `dirt_cells`, `preset_blocks`, `corridor_half_width`, and
  `hydro_plant_cells`.

## Level editor and level data

- **`claude/level-editor.html` now silently drops 9 fields.** It parses and serializes only
  `level_id`, `display_name`, `grid_radius`, `water_sources`, `fire_cells`, `pool_targets`,
  `starting_inventory`, `blocked_cells`, `town_cells`. It does not know `hydro_plant_cells`,
  `preset_blocks`, `corridor_half_width`, `dirt_cells`, `geyser_cells`, `intro_text`,
  `total_block_budget`, `grid_style`, or `source_flow_style`. Its block catalog is hardcoded to the
  4 original ids with behaviors 0–4, and its presets are the old 17-level snapshot. **Loading any
  current level into the editor and re-exporting it destroys that level.** This has been on the
  backlog since Geyser; it's now a data-loss hazard against 100 shipped levels rather than a
  missing feature.
- **No level uses either new tile.** None of the 100 `.tres` files were touched. Two teaching
  levels — one hydro plant, one dig level where a catapult is an alternate faster route alongside
  manual digging — are the obvious next step and land squarely on the "extra resources, multiple
  solve paths" goal.
- **`claude/level-solutions.md` and `claude/level-min-times.md` would need regenerating** for any
  level retrofitted with these tiles. Min-times additionally assumes "solution applied before
  Start, then no further input", which a double-tap activation and a press-and-hold aim both break
  conceptually — those are timed in-run actions.

---

## Suggested order of work

1. Create the two missing SVG icons (blocker #1 — nothing runs without them).
2. Move all six new files to their canonical paths and delete the stale root duplicates (#2).
3. Fix #3 (scroll fires catapult), #4 (blocks on hydro sources), #5 (preview through hydro).
4. Decide #7 (pre-Start catapult) and the pre-Start placement visibility issue behind it.
5. Update the README, add a `dev-progress.md` entry covering 08-20 and 08-25, rewrite
   `open-items.md`.
6. Author the two teaching levels, then regenerate the solution/min-time docs.
7. The level editor field gap is now the largest standing risk to existing content.
