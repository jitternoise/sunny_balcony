# Flash Flood — Gameplay changes, 2026-08-31

Six changes requested this session, all built into `HexBoard.gd` / `Level.gd` /
`BlockData.gd` / `LevelData.gd` / `wall.tres`. Same standing caveat as everything else in
this project: verified by inspection only, never run in a live Godot window.

---

## 1. Dirt is no longer diggable before Start

`HexBoard.dig()` now returns false whenever `started` is false, so a tap on packed dirt
during the planning phase does nothing at all (it falls through to block handling, which
rejects DIRT terrain anyway).

Digging is a during-the-run action. Letting the whole board be pre-carved while the water
sat still turned a dig level into an ordinary layout puzzle with the timing pressure
removed, and made the mudslide threat (`MUDSLIDE_BEATS_REQUIRED`) nearly impossible to
provoke — you could simply open every cell before releasing a drop.

Knock-on: the pre-start flow preview now always forecasts through a fully sealed dirt
field, so what it shows is the route through the blocks you laid out rather than a
half-carved channel. Doc comments in `dig()`, `_predict_flow_arrows()`,
`LevelData.dirt_cells` and `Level._handle_tap()` were corrected — several of them
explicitly promised the old behaviour.

## 2. The Wall is 2 tiles wide

New `BlockData.footprint_offsets: Array[Vector2i]` — extra cells a block occupies beyond
the one the player taps. Empty for every block except `wall.tres`, which now ships
`[Vector2i(1, 0)]`. Diverters, the Splitter and the Bomb Catapult are untouched and take
exactly the code path they always did.

How it works:

- `place_block()` builds the footprint, and if the preferred (rightward) one doesn't fit it
  retries a **mirrored** one with each offset's x negated — so a wall can still be placed
  hard against the right-hand wall of a corridor. Placement is all-or-nothing: every cell
  is validated by `_footprint_placeable()` (playable area, not a water source / activated
  geyser / activated hydro cell, not occupied or queued, terrain clear).
- **Every** occupied cell gets its own `placed_blocks` entry, so the water simulation,
  `_resolve_block_targets()` and `_is_wall()` need no concept of multi-cell blocks — each
  half behaves exactly like the whole.
- A new `block_anchors` dictionary maps every covered cell back to the anchor. That's what
  lets `remove_block()` pick the whole block up from either half, refunding **one**
  inventory slot rather than one per cell, and what keeps the preset guard and the preset
  outline working from either half.
- Presets, pending placements, pending removals, `resolve_placement_phase()` and
  `fire_catapult()` all group by anchor too.

`LevelData.preset_blocks` now documents that its coordinate is the block's anchor and that
a multi-cell preset occupies its full unmirrored footprint from there.

### ⚠ This invalidates roughly half the solution book

A survey of all 100 levels:

| | count |
|---|---|
| Levels with `"wall"` in `starting_inventory` | **41** (level 54 has two) |
| Jamboree levels (full catalogue, walls placeable) | **12** |
| Distinct levels where a 2-wide wall can now appear | **53** |
| Documented solutions in `level-solutions.md` that place a wall | **49 of 100** (51 placements) |
| Levels with a wall in `preset_blocks` | **0** — nothing doubles silently at load |

Every one of those 49 solutions now covers one more cell than it was verified with, which
can dam a channel the solution relied on. `claude/level-solutions.md` and
`claude/level-min-times.md` should be treated as unverified for those levels until the
Python sim is re-run with footprint support.

Two levels stand out and should be re-checked first:

- **Level 54 "Town Defense VIII"** — the only two-wall level. `wall (0,-3)` now also covers
  `(1,-3)` and `wall (0,0)` also covers `(1,0)`, the latter immediately adjacent to the
  4-cell town blob.
- **Level 92 "The Gauntlet VI"** — `wall (0,0)` sits in a `corridor_half_width = 2` row
  spanning q ∈ [-2,2], so the wall now takes 2 of that row's 5 cells.

The good news on geometry: no wall-capable level is narrower than 5 tiles, so a 2-wide wall
can never fully dam a corridor and the right-then-left fallback means placement is always
geometrically legal. (Level 16 narrows to 3 tiles but has no wall in inventory and isn't a
jamboree level.) One direction-flip case to watch: **level 6** is the only wall level with a
`blocked_cells` hole inside the play area, so a wall tapped next to it silently expands
left instead of right.

## 3. Dormant geysers show which way they'll flow

`_draw_geyser_direction_arrow()` draws a small arrow on every still-dormant geyser pointing
at the cell its stream will enter on its first move, so you can lay out the downstream
channel before spending `GEYSER_BEATS_REQUIRED` beats filling it. Drawn in the geyser's own
pale purple, and deliberately thinner and shorter than the white first-move arrow on a live
source, so a dormant geyser never reads as already flowing.

It uses a dedicated `_geyser_first_move_direction()` rather than `_first_move_direction()`:
that one reads `LevelData.source_flow_style`, which only ever applies to a level's original
`water_sources`. An activated geyser on a flat grid always flows "straight", so sharing the
helper would have advertised a zigzag the water never takes.

## 4. Blocks placed before Start are visible

Already fixed on 2026-08-25 by the `HexBoard.started` change (pre-Start placements commit
straight to `placed_blocks` instead of queueing for a PLACEMENT beat that never arrives),
so planning-phase blocks now render and the flow preview responds to them.

This session covers the other half of the same complaint — **mid-run** taps. After Start a
placement legitimately buffers until the next PLACEMENT beat, and the board used to look
completely unchanged for up to a full measure, which reads as a dropped input.
`_draw_cell()` now ghosts a queued placement at `PENDING_PLACEMENT_ALPHA` (0.45) with its
block glyph drawn on top at full opacity — the glyph is what tells you *which* block you
queued — and fades a cell queued for pickup toward the empty-cell colour.

## 5. Preset blocks have an outline

A preset Splitter renders identically to one the player placed, with nothing saying it's
bolted down. `_draw_cell()` now draws a second outline inset to
`PRESET_OUTLINE_INSET` (0.72) of the way to the hex corners, in a warm off-white
(`PRESET_OUTLINE_COLOR`), on any cell covered by a standing preset — both halves of a
multi-cell preset included.

`_is_preset_cell()` resolves through `block_anchor_at()`, and goes false for a preset Bomb
Catapult once it's been fired, since that cell is ordinary board again by then.

## 6. Diverters and Splitters show where the water goes next

The same cue change 3 gave dormant geysers, now on the placeable routing blocks.
`_draw_block_direction_arrows()` draws a small arrow from a placed block toward each cell
it will push water into — one for a Diverter-Left or Diverter-Right, **two for a
Splitter**, none for a Wall or a Bomb Catapult (neither sends water anywhere). Same
smaller/thinner arrow geometry as the geyser's (`0.42`→`0.92` of `Hex.SIZE`, width 2), so
"this tile is about to send water that way" reads identically everywhere on the board.

**One direction table, not two.** The behaviour match that was inline in
`_resolve_block_targets()` is now `_block_target_offsets(block_id)`, returning direction
offsets; `_resolve_block_targets(coord)` is a thin wrapper that adds `coord` to each. The
arrows read from that same function, so a drawn arrow cannot point somewhere the
simulation won't actually send the water — on either grid orientation, since the
pointy/flat resolution happens inside that one table. This is deliberately the opposite of
the pattern that produced the 2026-08-17 rounding-parity bug and the still-open "the
Python sim and the engine can now disagree about what a wall covers" risk from change 2:
a second copy of a behaviour table is a divergence waiting to happen.

Behaviour change worth noting: `_block_target_offsets()` returns an empty list for an
unknown block id instead of indexing a missing catalog entry and crashing, as the old
inline lookup did. An unknown block therefore acts like a Wall — the safest fallback,
since it can only hold water back, never route it somewhere the player wasn't shown.

**Colour.** Each arrow is tinted from its own block's `BlockData.color`, lightened
`BLOCK_ARROW_WHITEN` (0.6) toward white at `BLOCK_ARROW_ALPHA` (0.9). Diverter-Left,
Diverter-Right and the Splitter keep their identities, and the arrow stays legible on the
block's own fill whatever colour a level author picks — a single fixed neutral would have
disappeared on some of them.

**Two deliberate suppressions:**

- **Anchor cell only.** Every cell of a multi-cell block carries its own `placed_blocks`
  entry, so without the `block_anchor_at(coord) != coord` guard a hypothetical 2-wide
  diverter would draw its arrows twice, once per half. No shipped multi-cell type routes
  water today (Wall and Catapult are the only ones with footprints, and neither draws an
  arrow), but the guard costs nothing.
- **Not under the pre-start preview.** If the amber flow preview already draws a segment
  out of this cell, the block's own arrow is skipped — otherwise two arrows land on the
  exact same segment, one amber and one tinted, which reads as a rendering bug. This is
  the same overlap `_draw_source_marker()` already avoids by suppressing its own
  first-move arrow while the preview is up. A Diverter the preview does *not* reach —
  beyond its `PREVIEW_ARROW_STEPS` (4) budget, or on a branch no water gets to — still
  draws its arrow, which is exactly the case where the player has nothing else to go on.

**Queued placements get an arrow too**, using the pending block's id, so a mid-run tap
tells you what the block does before the PLACEMENT beat actually lands it — same reasoning
as change 4 drawing the ghost's glyph at full opacity.

**Performance.** `_draw_block_direction_arrows()` needs to know which cells the preview
already covers, and re-running `_predict_flow_arrows()` per cell would mean thousands of
forecast walks per frame on a board like level 22's radius-50 grid. The forecast is now
computed **once** at the top of `_draw()` into `_preview_arrows` / `_preview_from_cells`
(a set of "from" coords), and `_draw_flow_preview()` reads the same cache instead of
recomputing it. Net effect: the preview is computed once per redraw rather than once, and
the per-cell check is a dictionary lookup. Both are cleared in `setup()` and at the top of
every `_draw()`, so nothing survives a retry or a `show_flow_preview` flip.

`_preview_from_cells` is keyed by "from" coord rather than by segment because a Splitter's
two outputs are either both covered by the preview or both not — the forecast branches at
the block itself, so it never draws one of a splitter's arrows without the other.

**No simulation change.** Nothing in this change touches `resolve_water_phase()`,
`_advance_water()`, `_advance_water_flat()` or `_try_enter()`; the only non-drawing edit is
the pure extraction of the direction table. Every documented solution and win-measure stays
valid — unlike change 2, this one needs no re-verification.

---

## Follow-ups this opens

- **Re-verify the 49 wall solutions** against the updated rules, and regenerate
  `level-solutions.md` / `level-min-times.md`. The Python sim needs `footprint_offsets`
  support (including the mirrored fallback) to do this.
- **The Python sim and the engine can now disagree** about what a wall covers — that's
  exactly the class of divergence the 2026-08-17 rounding-parity bug came from.
- **Placement failure is silent.** If neither footprint orientation fits, the tap does
  nothing with no feedback. A brief flash on the offending cells would help.
- `claude/level-editor.html` still knows none of this — it has no `footprint_offsets`
  concept, so a wall drawn in the editor is one cell wide there and two in the game.
- Still outstanding from the 2026-08-25 revision check: the missing `icon_hydro.svg` and
  `icon_catapult.svg` assets. `HexBoard.gd` `preload()`s the first one, so the game will
  not compile until it exists.
- **New from change 6:** the direction arrows have only ever been reasoned about, not
  looked at. Worth a live pass on whether two arrows on a Splitter crowd the tile at
  real on-device sizes, and whether a Diverter's arrow reads clearly against that
  block's specific fill colour once real art replaces the flat colours.
