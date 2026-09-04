# Flash Flood — Hydro Electric Power Plant & Bomb Catapult

Design + implementation notes for two new tiles, built into `HexBoard.gd`/
`Level.gd`/`LevelData.gd`/`BlockData.gd` this session. Like everything else
in this project, **not yet verified in a live Godot window** — verified here
only by inspection/reading the code paths through, same caveat as every
other feature (see `claude/open-items.md`).

## Hydro Electric Power Plant

**What it is:** a 3-tile-wide PREPLACED terrain structure (never
player-placed). Any water reaching any of its 3 cells stops there
completely, exactly like running into a Wall — from any direction, whether
by natural fall or a Diverter/Splitter aimed at it. Once water has actually
reached it, the player can double-tap any of its 3 cells to activate it:
all 3 cells revert to open terrain and each becomes a brand-new permanent
water source — "3 rivers come out of it" — while any water still arriving
from upstream also resumes flowing straight through.

**Why double-tap requires prior contact:** per your answer, the plant can
only be activated *after* water has actually backed up against it, not
pre-emptively. This means a plant sitting on a branch of the board water
hasn't reached yet just sits there inert and un-tappable — nothing to
double-tap on, since `try_activate_hydro()` no-ops until
`hydro_ready_at()` is true.

**Level authoring:** add a `hydro_plant_cells` entry to a level's `.tres`
(one axial coordinate = the plant's CENTER cell; the level editor doesn't
support this field yet — see Known gaps below, so for now hand-edit the
`.tres` or extend `_fitToView`/serializeLevel in `level-editor.html`
yourself). The plant occupies that center cell plus its immediate left/right
neighbors (`center + Vector2i(-1,0)` and `center + Vector2i(1,0)`) — make
sure all 3 land inside the playable area (`grid_radius`/`blocked_cells`/
`corridor_half_width`), and keep the same "≥2 rows clear of any source's
first landing spot" rule every other preplaced terrain type already
follows.

**Known limitation:** pointy-grid only for now. `resolve_water_phase()`'s
hydro spawn loop mirrors the geyser spawn loop's "straight" default for a
flat level, but this hasn't been exercised on an actual `"flat"`
`grid_style` level — the 3-cells-wide-horizontally layout (using
`Vector2i(±1, 0)`) is itself defined in terms of the pointy grid's own axial
neighbors, so a flat-grid plant's 3 cells would need re-deriving before this
is safe to use there.

## Bomb Catapult

**What it is:** a single-tile block, placeable either as a `preset_blocks`
entry (preplaced, non-removable, same as any other preset) or from a
level's `starting_inventory`/jamboree pool (player-placed, pickup-able with
a quick tap same as any other block) — no new `LevelData` field needed for
placement, since the existing generic block-catalog machinery already
covers both. For water simulation purposes it behaves exactly like a Wall
(fully blocks, water backs up against it) — an assumption, not something
you specified; flip `BlockData.TickBehavior.WALL, BlockData.TickBehavior.CATAPULT:`
in `HexBoard._resolve_block_targets()`'s match statement to give it its own
pass-through behavior instead, if you'd rather water ignore it entirely.

**Firing it, per your answer:**
1. Player **presses and holds** on the catapult's own cell (`CATAPULT_HOLD_THRESHOLD_MSEC`
   = 300ms before anything visible happens — a quick tap below that
   threshold is treated as an ordinary tap: picks the block up if it's
   player-placed, no-ops if it's preset, exactly like tapping any other
   block today).
2. Once past the hold threshold, an aim arrow appears starting
   `HexBoard.CATAPULT_MIN_RANGE` (2) tiles out from the catapult, in
   whichever of the 6 hex directions the player's finger/cursor currently
   sits relative to the catapult (re-snapped every frame, so dragging while
   held re-aims live).
3. The longer the hold continues, the farther the arrow reaches —
   `+1` tile every `CATAPULT_CHARGE_MSEC_PER_TILE` (350ms), capped at
   `HexBoard.CATAPULT_MAX_EXTRA_RANGE` (3), so the farthest possible shot
   lands 5 tiles out. A translucent orange overlay previews the exact
   7-cell blast cluster (the target cell + its 6 neighbors) that will clear
   if released right now.
4. **Releasing fires**: `HexBoard.fire_catapult()` opens every `DIRT` cell
   in that 7-cell cluster instantly (same end state as 3 taps each, via
   `dig_progress`), marks them `catapult_blast_cells` (drawn in a distinct
   scorched color from a manually-dug trench or a mudslide collapse), and
   removes the catapult block from the board.

**One-time use — an assumption, please confirm or correct:** you didn't
specify whether a catapult can fire more than once. I made it a
single-shot consumable (it's erased from `placed_blocks` the moment it
fires) since that matches the "launches a bomb" flavor most directly and
avoids the extra design surface of a reload/cooldown system. If you want it
reusable instead, the fix is small: don't erase it in `fire_catapult()`,
and add a short per-catapult cooldown (a `Dictionary[Vector2i, int]` of
"last fired at beat/msec X") so it can't be re-triggered every single
frame.

**Direction snapping:** `Level._snap_to_hex_direction()` picks whichever of
`Hex.NEIGHBOR_OFFSETS`' 6 directions the finger/cursor angle is closest to
via a dot-product comparison against each direction's own screen-space
bearing (`Hex.axial_to_pixel(dir)`). This is a rough approximation good
enough for "which of 6 buckets" — worth a hands-on pass to confirm it feels
precise/responsive on an actual touchscreen, same live-playtest caveat as
everything else.

## Files touched this session

- `scripts/resources/LevelData.gd` — new `hydro_plant_cells: Array[Vector2i]`
  field.
- `scripts/resources/BlockData.gd` — new `TickBehavior.CATAPULT` enum value.
- `scripts/gameplay/HexBoard.gd` — `CellState.HYDRO`; `hydro_plants` /
  `hydro_cell_to_anchor` / `hydro_source_cells` state + `_is_inactive_hydro()`
  / `_note_hydro_contact()` / `hydro_ready_at()` / `try_activate_hydro()`;
  hooked into `_is_wall()`, both block-redirect loops (pointy + flat), and
  both natural-fall blocked-step checks; hydro spawn loop in
  `resolve_water_phase()`; `catapult_blast_cells` / `active_catapult_aim`
  state + `fire_catapult()` / `set_catapult_aim()` / `clear_catapult_aim()`
  / `_catapult_blast_area()` / `_draw_catapult_aim()`; new `place_block()`
  guard against placing on `HYDRO` terrain; `_draw_cell()` branches for both
  new visual states (including the "ready to activate" ring); `ICON_HYDRO`
  preload.
- `scripts/gameplay/Level.gd` — catapult press/hold/drag/release state
  machine (new `_process()`, `_is_live_catapult()`, `_update_catapult_aim()`,
  `_current_catapult_distance()`, `_snap_to_hex_direction()`); hydro
  double-tap detection prepended to `_handle_tap()`.
- `assets/icons/icon_hydro.svg`, `assets/icons/icon_catapult.svg` — new
  placeholder glyphs (dam+turbine, A-frame+fused bomb), matching the
  existing flat-vector/dark-outline icon style.
- `data/blocks/bomb_catapult.tres` — new `BlockData` resource
  (`id = "bomb_catapult"`, `behavior = 5` i.e. `CATAPULT`).

## Known gaps / next steps

- `claude/level-editor.html` doesn't support `hydro_plant_cells` or a
  `bomb_catapult` inventory/preset entry yet — same "needs an editor pass"
  gap flagged for every mechanic added since the original 17-level feature
  set (Geyser, Jamboree, flat-grid, `intro_text`, `dirt_cells` all hit this
  same note in `dev-progress.md`/`open-items.md`).
- No level actually uses either tile yet — none of the 100 `.tres` files
  were touched this session. Authoring a couple of example levels (one
  hydro plant teaching level, one dig level with a catapult as an
  alternate/faster solve path alongside manual digging) would be the
  natural next step, and would directly serve the "extra resources to solve
  levels multiple ways" goal you mentioned.
- Live-playtest items specific to these two tiles: does the hold threshold
  feel right (not too twitchy, not too laggy) before aiming kicks in; does
  the direction-snap feel precise on a real touchscreen; does clearing a
  7-cell cluster feel like the right blast size relative to typical dig-level
  corridor widths; does the hydro plant's "ready" ring read clearly at
  actual on-device tile sizes.
- Not addressed: what happens if a Hydro Plant's 3 cells overlap another
  preplaced terrain type (fire/pool/town/dirt/another plant) or a
  `preset_blocks` entry — `setup()` just overwrites `cell_terrain` for
  those coordinates in field-declaration order, so a conflicting level
  design would silently produce an unintended board rather than erroring.
  Same "not enforced in code, an authoring convention" pattern the rest of
  `LevelData.gd`'s terrain fields already rely on.
