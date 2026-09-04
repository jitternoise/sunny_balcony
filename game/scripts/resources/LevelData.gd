extends Resource
class_name LevelData

## Defines one fixed, hand-designed level. Create one .tres per level under
## res://data/levels/, then add its path to LEVEL_PATHS in LevelSelect.gd.

@export var level_id: int = 1
@export var display_name: String = "Level 1"

## Short player-facing blurb describing what this level does/teaches --
## shown in a "Got it" intro popup the instant the level scene loads,
## before the player can interact with anything else (see Level.gd's
## intro_panel handling). Deliberately NOT a full solution -- it explains
## the mechanic/hazard in play, not the exact placement. Empty string means
## no popup is shown for that level (kept optional so a level file missing
## this field, e.g. an older save-incompatible edge case, still works).
@export var intro_text: String = ""

## The hex grid extends this many cells from the center (axial 0,0) in every
## direction -- i.e. it's a hexagon of this "radius".
@export var grid_radius: int = 4

## Corridor levels: when > 0, the playable area is additionally restricted
## to a narrow vertical band, corridor_half_width cells to each side of
## q = round(-r/2) per row (2 * half_width + 1 tiles wide) -- the exact
## same visually-vertical band rule the tall levels 13-17 hand-carved via
## blocked_cells, now expressed as one field. Use this instead of
## blocked_cells for VERY deep levels (e.g. level 22's radius-50, 101-row
## grid), where listing the thousands of outside cells would bloat the
## .tres and make in_playable_area()'s blocked_cells Array.has() check
## ruinously slow. 0 (the default) disables it -- every existing level is
## untouched. Composes with blocked_cells (both restrictions apply).
@export var corridor_half_width: int = 0

## Which hex orientation this level uses -- "pointy" (default, the original
## grid: pointed top/bottom vertices, no direct-down neighbor, water
## naturally zigzags between its two down-diagonals) or "flat" (rotated 90
## degrees: a flat bottom EDGE gives a genuine direct-down neighbor, so
## water sources on this grid can fall straight down -- see
## source_flow_style below). Set once by HexBoard.setup() into Hex.orientation
## for the whole level's pixel math/rendering. Existing levels are untouched
## by this -- they simply never set it, leaving the "pointy" default.
@export var grid_style: String = "pointy"

## Flat-grid-only: axial water source coordinate -> "straight" or "zigzag".
## Lets each source on a "flat" level independently choose to fall straight
## down every tick (Hex.FLAT_DOWN) or zigzag between the true down-left/
## down-right diagonals (Hex.FLAT_DOWN_LEFT / Hex.FLAT_DOWN_RIGHT, mirroring
## the classic pointy-top zigzag using this grid's own diagonal pair -- see
## HexBoard._advance_water_flat()). A source not listed here defaults to
## "straight". Ignored entirely on a "pointy" level. Active geysers on a
## flat level always use "straight" (not configurable per-geyser yet).
@export var source_flow_style: Dictionary = {}

## Axial coordinates where a new water cell spawns every tick.
@export var water_sources: Array[Vector2i] = []

## Axial coordinates that must be hit by water to be extinguished. The level
## is won only once all of these are cleared.
@export var fire_cells: Array[Vector2i] = []

## Axial coordinate -> int (kept for file-format/back-compat reasons only).
## Every pool now requires exactly POOL_BEATS_REQUIRED (4, see HexBoard.gd)
## beats of water connection to finish, shown as a 4-box status bar that
## pops up above the pool on its first connected beat -- the stored int
## value here is NOT read by the simulation and can be left at any value.
## Only the dictionary's keys (which cells are pools) matter.
@export var pool_targets: Dictionary = {}

## Blocks baked into the level as FIXED terrain: axial coordinate ->
## (NOTE: for a multi-cell block type -- see BlockData.footprint_offsets,
## e.g. the 2-wide Wall -- the coordinate is the block's ANCHOR, and it
## occupies its whole unmirrored footprint from there. Check every cell of
## that footprint is inside the playable area and clear of other terrain.)
## block id (String, must exist in the res://data/blocks/ catalog, e.g.
## "splitter"). Committed straight into HexBoard.placed_blocks at setup()
## -- live from the first beat, no inventory/budget cost, rendered and
## simulated exactly like a player-placed block of the same id -- but
## non-removable: remove_block() refuses to pick one up, same as tapping
## a fire/pool/town. Lets a level ship with its machinery (e.g. level
## 22's cascade of 10 splitters) pre-installed while the player works
## around/through it. Level-design note: a pool must never be a direct
## down-neighbor of a cell water flows THROUGH (it consumes every stream
## forever, starving everything downstream) -- give each side pool its own
## spur at least 2 columns off the main flow; level 22's layout shows the
## pattern.
@export var preset_blocks: Dictionary = {}

## Starting inventory for this level: block id (String) -> count (int).
@export var starting_inventory: Dictionary = {}

## Axial coordinates that are holes in the grid shape (not playable), for
## levels that aren't a full hexagon.
@export var blocked_cells: Array[Vector2i] = []

## Axial coordinates making up the level's "town" -- an instant-loss hazard.
## Water reaching ANY of these cells ends the level in a loss immediately,
## same as water reaching the bottom edge. Authoring convention: a town is
## exactly 4 hex cells that are all edge-adjacent to each other (connected
## as one blob), in whatever shape fits the level, but this isn't enforced
## in code -- any number of cells here works mechanically.
@export var town_cells: Array[Vector2i] = []

## Axial coordinates for "geyser" cells -- dormant until water has connected
## to them for GEYSER_BEATS_REQUIRED (3, see HexBoard.gd) beats, same as a
## Pool filling up. Once that happens the geyser activates permanently: it
## turns into a brand new water source (added to HexBoard.active_geysers)
## that spawns its own falling stream every tick from then on, exactly like
## one of this array's `water_sources` -- the level doesn't have to place
## every source at the very top of the board.
@export var geyser_cells: Array[Vector2i] = []

## "Dig the River" levels: axial coordinates of packed-dirt cells. An undug
## dirt cell behaves exactly like a permanent Wall toward water (natural
## fall can't land on it, block redirects can't push water into it -- the
## water backs up and waits) and can't have a block placed on it. The
## player opens one by tapping it DIG_TAPS_REQUIRED (3, see HexBoard.gd)
## times -- free and unlimited, but only AFTER Start: digging is a
## during-the-run action, so a dig level can't be pre-carved during the
## planning phase (see HexBoard.dig()) -- at which
## point it becomes ordinary empty terrain (drawn in a distinct trench
## color) that water flows through normally. Authoring idea: surround the
## route to the pool with dirt so the player has to carve ("tap") the
## river's channel forward themselves -- see level_021.tres. Empty (the
## default) for every level that doesn't use the mechanic.
@export var dirt_cells: Array[Vector2i] = []

## "Hydro Electric Power Plant" structures: axial coordinates of each
## plant's CENTER cell. Always PREPLACED, fixed level terrain -- never
## player-placed or removable, same category as geyser_cells/town_cells,
## not preset_blocks (a plant is 3 cells of TERRAIN, not one placed block).
## Each plant occupies exactly 3 horizontally-adjacent cells (the center
## plus its immediate left/right neighbors, i.e. center + Vector2i(-1, 0)
## and center + Vector2i(1, 0)) -- see HexBoard.setup()'s hydro_plants
## construction. Any water reaching one of a plant's 3 cells stops there
## completely (identical to running into a Wall -- see
## HexBoard._is_inactive_hydro()) until the player DOUBLE-taps any of the
## 3 cells, which is only possible once water has actually reached it (see
## HexBoard.hydro_ready_at()/try_activate_hydro()). On that double-tap, all
## 3 cells revert to ordinary EMPTY terrain and each becomes a brand new
## permanent water source -- "3 rivers come out of it" -- exactly like an
## activated Geyser, just tap-triggered instead of beat-count-triggered.
## Level-design note: like every other preplaced terrain type, keep a
## plant at least 2 rows clear of any water_sources cell's very first
## landing spot (same authoring rule preset_blocks/fire_cells/etc. already
## follow) and make sure all 3 of its cells sit inside grid_radius/
## blocked_cells/corridor_half_width's playable area, or two of them will
## silently never render. Pointy-grid only for now -- untested on a "flat"
## level. The 3-cell layout itself (center + Vector2i(-1, 0) / Vector2i(1, 0))
## is defined in terms of the pointy grid's own axial neighbors and would
## need re-deriving there; the water-spawn side is already handled, since
## HexBoard.resolve_water_phase()'s hydro loop mirrors the geyser loop's
## "straight"/Hex.FLAT_DOWN default on a flat level.
## Empty (the default) for every level that doesn't use the mechanic.
@export var hydro_plant_cells: Array[Vector2i] = []

## "Jamboree" mode switch. 0 (the default) means this level uses the normal
## per-block-type starting_inventory above, unchanged. Any positive value
## instead grants a single shared pool of this many total block placements,
## with NO per-type limit -- the player can freely mix and match any block
## type from the full catalog (res://data/blocks/) in any combination, as
## long as the running total placed across ALL types never exceeds this
## number. starting_inventory is ignored entirely when this is > 0 (see
## HexBoard.use_block_budget / block_budget_remaining).
@export var total_block_budget: int = 0
