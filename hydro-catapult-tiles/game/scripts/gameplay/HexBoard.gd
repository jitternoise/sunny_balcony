extends Node2D
class_name HexBoard

## Owns the grid state and the beat-based water simulation for one level.
## Level.gd drives it by calling setup() once, then one of
## resolve_placement_phase() / resolve_water_phase() / resolve_terrain_phase() /
## resolve_status_phase() per beat (see Level.gd's beat-cycle doc comment for
## what each one does and why they're split), and listens for level_won /
## level_lost.

signal level_won
signal level_lost

const CellState := {
	EMPTY = "empty",
	FIRE = "fire",
	POOL = "pool",
	TOWN = "town",
	GEYSER = "geyser",
	DIRT = "dirt",
	HYDRO = "hydro", # one of a Hydro Electric Power Plant's 3 cells -- see hydro_plants
}

## Terrain icon textures. Placeable-block icons come from each BlockData
## resource's own `icon` field (data-driven, see BlockData.gd) since new
## block types get their icon by just filling in that field on their
## .tres -- no code change needed. Terrain isn't a Resource per-type, so
## its icons are preloaded here instead. Geyser has no dedicated glyph yet
## (see claude/icon-system.md's open follow-ups) -- it keeps its existing
## procedural _draw_geyser_icon() droplet shape. Dirt deliberately has no
## glyph at all: per the "color stages only" design decision for the dig
## mechanic, an undug/partially-dug hex communicates its state purely
## through its fill color (see _draw_cell()'s DIRT branch).
const ICON_FIRE := preload("res://assets/icons/icon_fire.svg")
const ICON_POOL := preload("res://assets/icons/icon_pool.svg")
const ICON_TOWN := preload("res://assets/icons/icon_town.svg")
const ICON_SOURCE := preload("res://assets/icons/icon_source.svg")
const ICON_HYDRO := preload("res://assets/icons/icon_hydro.svg")

## Every pool needs exactly this many beats of water connection to finish,
## visualized as a 4-box status bar above the pool. Fixed for every pool on
## every level -- not configurable per level/pool (see LevelData.pool_targets
## doc comment).
const POOL_BEATS_REQUIRED := 4

## A geyser needs exactly this many beats of water connection before it
## activates and becomes a permanent new water source (see LevelData.geyser_cells
## and _try_enter()'s GEYSER branch). Fixed for every geyser on every level,
## same fixed-requirement pattern as POOL_BEATS_REQUIRED.
const GEYSER_BEATS_REQUIRED := 3

## "Dig the River" mechanic (see LevelData.dirt_cells): a DIRT cell needs
## exactly this many taps to dig open (dig(), called by Level.gd's tap
## handler). Until fully dug it behaves exactly like a Wall toward water --
## natural fall can't land on it and retries the other diagonal instead, and
## if every candidate is dirt/blocked the water backs up and waits. Fixed
## for every dirt cell on every level, same fixed-requirement pattern as
## POOL_BEATS_REQUIRED / GEYSER_BEATS_REQUIRED.
const DIG_TAPS_REQUIRED := 3

## Fill colors for a dirt cell's three visual states, indexed by tap count
## (0 taps = packed dark earth, 1 and 2 taps progressively lighter/looser as
## the digging progresses), plus the distinct "dug-open trench" color an
## opened cell keeps afterward so the carved river channel stays readable
## against ordinary empty cells. Color stages are the ONLY progress feedback
## for digging (no status bar, no counter glyph) -- a deliberate design
## choice to keep the board clean.
const DIRT_COLORS: Array[Color] = [
	Color(0.42, 0.30, 0.18), # untouched packed dirt
	Color(0.53, 0.40, 0.24), # 1 tap -- loosened
	Color(0.65, 0.52, 0.33), # 2 taps -- almost through
]
const DUG_TRENCH_COLOR := Color(0.30, 0.24, 0.18)

## Mudslide mechanic: once a water drop has spent this many consecutive
## WATER beats pressing against undug dirt (see dirt_stall /
## _note_dirt_stall()), the dirt gives way on its own -- a chain of
## MUDSLIDE_COLLAPSE_TILES dirt tiles collapses downward from the blocking
## tile (see _trigger_mudslide()), opening a path the PLAYER didn't choose.
## Collapsed tiles are fully open (water flows through immediately) and
## drawn in MUDSLIDE_COLOR, distinct from the player-dug trench color, so
## the board tells the story of where the river forced its own way. At the
## current tempo (0.3s/beat) 10 beats is ~3 seconds of standing water --
## enough time to finish a tile you're already digging, but a real threat
## if you fall behind.
const MUDSLIDE_BEATS_REQUIRED := 10
const MUDSLIDE_COLLAPSE_TILES := 3
const MUDSLIDE_COLOR := Color(0.22, 0.15, 0.10) # wet mud -- darker than the dug trench

## Bomb Catapult aiming range (see Level.gd's press-and-hold aim state
## machine and fire_catapult() below): a charged shot always lands at
## least this many tiles out from the catapult itself along the aimed
## direction...
const CATAPULT_MIN_RANGE := 2
## ...and grows by up to this many additional tiles the longer the player
## holds, capping the farthest possible shot at
## CATAPULT_MIN_RANGE + CATAPULT_MAX_EXTRA_RANGE (5) tiles out. The actual
## per-tile hold-time growth rate lives in Level.gd
## (CATAPULT_CHARGE_MSEC_PER_TILE), since that's an input-timing concern,
## not a simulation rule.
const CATAPULT_MAX_EXTRA_RANGE := 3

## How many hex-to-hex moves the pre-start flow preview forecasts per
## source -- see show_flow_preview / _predict_flow_arrows().
const PREVIEW_ARROW_STEPS := 4

## Color of the pre-start flow-preview arrows (see _draw_flow_preview()) --
## amber, distinct from the white ring/first-move arrow drawn on every
## source marker and from any placed-block color.
const PREVIEW_ARROW_COLOR := Color(1.0, 0.82, 0.2)

## Screen-layout rules (see _fit_hex_layout()): the hex grid always fills
## this fraction of the screen's width, leaving an equal margin on each
## side, and its top edge always starts this fraction of the way down the
## screen. Grid tile size is solved for per level so this holds regardless
## of grid_radius -- a small level and a big level both fill 90% of the
## width, just with different tile sizes.
const GRID_WIDTH_FRACTION := 0.9
const GRID_SIDE_MARGIN_FRACTION := 0.05
const GRID_TOP_MARGIN_FRACTION := 0.10

## Level-design convention (not enforced here, but relied on by
## _fit_hex_layout()'s sizing so tiles stay reasonably large): a grid
## should never be more than this many tiles wide, i.e. grid_radius should
## not exceed floor((MAX_GRID_WIDTH_HEXES - 1) / 2) = 4.
const MAX_GRID_WIDTH_HEXES := 9

## Reserved screen space below the grid's available area for the bottom
## inventory bar, so scrolling can't hide the grid's bottom edge behind it.
const BOTTOM_UI_RESERVED_PX := 110.0

## position.y when the grid is scrolled all the way to the top (its natural
## resting position, set by _fit_hex_layout()). Level.gd clamps manual
## vertical scroll drags between this and (top_position_y - max_scroll_down).
var top_position_y: float = 0.0

## How much further (in px) the board can move upward (decreasing
## position.y) to reveal the bottom of a grid taller than one screen's
## available vertical space. 0 if the whole grid already fits on screen.
var max_scroll_down: float = 0.0

var level_data: LevelData
var block_catalog: Dictionary = {} # block id (String) -> BlockData

var cell_terrain: Dictionary = {}  # Vector2i -> String (CellState)
var placed_blocks: Dictionary = {} # Vector2i -> String block id

## Queued block placements/removals made during any beat -- committed to
## placed_blocks in resolve_placement_phase() on the next PLACEMENT beat
## (see Level.gd's beat-cycle doc comment). Inventory/budget bookkeeping
## happens immediately at queue time (in place_block()/remove_block()), not
## at commit time, so the inventory bar always reflects availability right
## away even though the board itself doesn't visibly change until the
## PLACEMENT beat lands.
var pending_placements: Dictionary = {} # Vector2i -> String block id, to add
var pending_removals: Dictionary = {} # Vector2i -> true, to remove

## Cells water entered during this measure's WATER beat that still need
## their terrain contact effect (fire extinguish, pool fill, geyser fill)
## applied -- populated by _try_enter() during resolve_water_phase(),
## consumed and cleared by resolve_terrain_phase(). See the WATER/TERRAIN
## beat split doc comments below for why this isn't resolved inline the way
## the old single-phase tick() used to.
var _pending_terrain: Array[Vector2i] = []

## Vector2i -> true. Town cells that water has actually reached (which is
## also the instant the level is lost, see _try_enter()'s TOWN branch).
## Drawn as light blue instead of the usual brown in _draw_cell() so the
## board visibly shows exactly which town cell the flood hit, since the
## level ends the same tick this becomes true. Cleared on setup()/retry.
var flooded_towns: Dictionary = {}

## Vector2i -> int. Cumulative count of beats this pool has been connected to
## water, capped at POOL_BEATS_REQUIRED. Never decreases once incremented --
## a pool's 4-box status bar only appears once this is > 0, and boxes already
## turned stay turned even if the water disconnects later (progress is
## preserved, not reset by a disconnect).
var pool_fill: Dictionary = {}
var fires_remaining: int = 0

## Vector2i -> int. Same cumulative/preserved semantics as pool_fill, but for
## geysers -- capped at GEYSER_BEATS_REQUIRED. Once a geyser reaches the cap
## it's moved from here into active_geysers and its terrain reverts to EMPTY
## (see _try_enter()'s GEYSER branch), so an entry staying in this dict at
## exactly GEYSER_BEATS_REQUIRED never actually happens -- it's the moment
## before that transition on the same tick it fires.
var geyser_fill: Dictionary = {}

## Vector2i -> int. How many times each of this level's dirt cells
## (LevelData.dirt_cells) has been tapped so far -- see dig(). A cell whose
## count reaches DIG_TAPS_REQUIRED has its terrain reverted to EMPTY (it's
## open, water can flow through), but its entry deliberately STAYS in this
## dictionary at the cap: _draw_cell() reads it to paint the opened cell in
## DUG_TRENCH_COLOR, so the player's carved channel stays visible as a
## distinct "riverbed" against ordinary empty cells. Cleared and
## re-initialized to 0 for every dirt cell on setup()/retry.
var dig_progress: Dictionary = {}

## Vector2i -> int. How many CONSECUTIVE water beats a drop has been stuck
## at this coordinate specifically because undug dirt blocks it (see
## _note_dirt_stall()). Pruned the moment the water moves on or the dirt is
## dug open -- only an unbroken stall counts toward a mudslide. When a
## coord's count reaches MUDSLIDE_BEATS_REQUIRED, _trigger_mudslide() fires
## for it and the counter resets. Cleared on setup()/retry.
var dirt_stall: Dictionary = {}

## Vector2i -> Vector2i (preferred collapse direction). Rebuilt from scratch
## every WATER beat by _note_dirt_stall(); consumed by _process_mudslides()
## right after the advance loop. A coord present here means "a drop stayed
## put at this cell this beat, blocked by dirt in this direction."
var _stalled_this_beat: Dictionary = {}

## Vector2i -> true. Cells opened by a mudslide rather than by the player's
## digging -- drawn in MUDSLIDE_COLOR by _draw_cell() so slide damage stays
## visible. Cleared on setup()/retry.
var mudslide_cells: Dictionary = {}

## Axial coordinates of geysers that have activated (reached
## GEYSER_BEATS_REQUIRED beats). Each one spawns a new falling water stream
## every tick, exactly like level_data.water_sources -- see tick(). A geyser
## can only ever be added here once (its terrain reverts to EMPTY on
## activation, so _try_enter()'s GEYSER branch can't fire again for it).
## Also treated as a permanent Wall by _is_wall() (see its doc comment) so
## the ORIGINAL stream that fed the geyser into activation stops there
## instead of sailing straight through the now-EMPTY-terrain cell forever.
var active_geysers: Array[Vector2i] = []

## Vector2i (each plant's CENTER cell, i.e. a LevelData.hydro_plant_cells
## entry) -> Dictionary{"cells": Array[Vector2i] (all 3 of the plant's
## cells), "touched": bool (has water ever backed up against any of its 3
## cells?), "active": bool (has it been double-tap-activated?)}. Built once
## in setup() from LevelData.hydro_plant_cells and never re-keyed
## afterward -- see hydro_cell_to_anchor for the per-cell reverse lookup
## used by the simulation and by Level.gd's double-tap handler.
var hydro_plants: Dictionary = {}

## Vector2i (any one of a plant's 3 cells) -> Vector2i (that plant's anchor
## key into hydro_plants). Lets any code that's holding one specific cell
## coordinate (the simulation, or a tap) look up which plant -- and thus
## which shared touched/active state -- it belongs to, without having to
## search hydro_plants' cell lists. Built alongside hydro_plants in
## setup().
var hydro_cell_to_anchor: Dictionary = {}

## Axial coordinates of the 3 cells belonging to every Hydro Plant that's
## been activated so far (see try_activate_hydro()) -- each one spawns a
## fresh falling water stream every WATER beat from the moment it
## activates on, exactly like level_data.water_sources or active_geysers
## (see resolve_water_phase()'s "for source in hydro_source_cells" loop).
## Unlike active_geysers, activated hydro cells are NOT also treated as a
## permanent Wall by _is_wall() -- there's no "original feeding stream"
## to protect against here (a Hydro Plant fully blocks ALL water, from
## every direction, until activated; nothing was ever "passing through"
## it beforehand the way water passes through a filling Geyser), so once
## active a plant's cells behave as perfectly ordinary EMPTY terrain that
## also happens to spawn new drops -- any water arriving from upstream
## after activation flows straight through and merges with the plant's
## own new streams, which reads as "the dam opened, water resumes
## flowing AND 3 new rivers join it," matching the design brief.
var hydro_source_cells: Array[Vector2i] = []

## Vector2i -> true. Cells opened by a Bomb Catapult blast (see
## fire_catapult()) rather than by player digging or a mudslide -- drawn
## in a distinct scorched color by _draw_cell() so the player can tell how
## each open cell in a dig level actually got that way.
var catapult_blast_cells: Dictionary = {}

## The currently-charging Bomb Catapult aim, if any -- {"coord": Vector2i
## (the catapult's own cell), "direction": Vector2i, "distance": int} while
## Level.gd's press-and-hold state machine is actively aiming a shot, or an
## empty Dictionary the rest of the time. Set every frame by
## set_catapult_aim() while charging, read by _draw_catapult_aim() to
## render the live amber aim arrow + blast-radius preview so the player
## can see exactly what will be cleared before committing by releasing.
## Purely a rendering/UI concern -- never read by the water simulation.
var active_catapult_aim: Dictionary = {}

## Active falling water this tick. Each entry is a Dictionary:
##   {"coord": Vector2i, "next_dir": Vector2i, "mode": String (optional)}
## next_dir is the diagonal THIS stream will attempt on its next natural
## (unblocked) fall step -- on a "pointy" level, Hex.DOWN_LEFT or
## Hex.DOWN_RIGHT; on a "flat" level, Hex.FLAT_DOWN_LEFT or
## Hex.FLAT_DOWN_RIGHT (unused for a "straight"-mode flat stream, which
## always tries Hex.FLAT_DOWN). "mode" is flat-grid-only (inherited from
## the spawning source's LevelData.source_flow_style, see tick()) --
## omitted/ignored entirely on a "pointy" level. Every stream tracks its
## own alternation/mode independently (there is no single global parity
## for the whole board); a freshly spawned drop always starts with
## whatever tick() computes as its first move.
var water_cells: Array[Dictionary] = []

var inventory: Dictionary = {} # block id -> remaining count

## True for a "jamboree" level (level_data.total_block_budget > 0): the
## player draws from one shared pool (block_budget_remaining) instead of
## per-block-type counts in `inventory`, and can place any block id in the
## catalog. `inventory` is left empty and unused in this mode. Set once in
## setup(), read by Level.gd to decide how to build/label the inventory bar.
var use_block_budget: bool = false

## Remaining total placements for a jamboree level (see use_block_budget).
## Decremented by place_block()/incremented by remove_block() instead of
## `inventory`, regardless of which block type is placed or removed. Always
## 0 for a normal (non-jamboree) level.
var block_budget_remaining: int = 0

var selected_block_id: String = ""

var game_over: bool = false

## True before the player has pressed Start -- while true, _draw() shows the
## amber multi-step flow-preview arrows (see _draw_flow_preview() /
## _predict_flow_arrows()) tracing where each source's leading drop would
## travel over its next PREVIEW_ARROW_STEPS ticks given the CURRENT
## placed_blocks, recomputed live every redraw so placing/removing a block
## pre-start updates the preview immediately. Also suppresses the small
## single first-move arrow _draw_source_marker() normally draws (that
## segment is already covered, in more detail, by the preview's first
## arrow). Level.gd sets this to false in _on_start_pressed() (and forces a
## redraw right then, so the preview disappears the instant Start is
## tapped, not on the next tick) -- setup() below resets it to true on
## every (re)load/retry.
var show_flow_preview: bool = true

## Why the level was lost, set right before level_lost fires. One of
## LoseReason's values below; empty string if the level hasn't been lost
## (or was won instead). Lets the UI show a specific message ("the town
## flooded" vs "water overflowed the bottom edge") instead of one generic
## "you lost" string.
const LoseReason := {
	EDGE = "edge",
	TOWN = "town",
}
var lose_reason: String = ""


func setup(data: LevelData, blocks: Dictionary) -> void:
	level_data = data
	block_catalog = blocks
	use_block_budget = data.total_block_budget > 0
	if use_block_budget:
		inventory.clear()
		block_budget_remaining = data.total_block_budget
	else:
		inventory = data.starting_inventory.duplicate()
		block_budget_remaining = 0

	# Sets the pixel-math/corner-angle orientation every Hex.* call uses for
	# the rest of this level (rendering, layout fitting, tap-to-place input)
	# -- see Hex.gd's `orientation` doc comment for why this is a shared
	# mutable static rather than an instance field.
	Hex.orientation = Hex.Orientation.FLAT if data.grid_style == "flat" else Hex.Orientation.POINTY

	cell_terrain.clear()
	placed_blocks.clear()
	pending_placements.clear()
	pending_removals.clear()
	_pending_terrain.clear()
	pool_fill.clear()
	geyser_fill.clear()
	dig_progress.clear()
	dirt_stall.clear()
	_stalled_this_beat.clear()
	mudslide_cells.clear()
	active_geysers.clear()
	hydro_plants.clear()
	hydro_cell_to_anchor.clear()
	hydro_source_cells.clear()
	catapult_blast_cells.clear()
	active_catapult_aim = {}
	water_cells.clear()
	flooded_towns.clear()
	game_over = false
	lose_reason = ""
	show_flow_preview = true

	for coord in data.fire_cells:
		cell_terrain[coord] = CellState.FIRE
	fires_remaining = data.fire_cells.size()

	for coord in data.pool_targets.keys():
		cell_terrain[coord] = CellState.POOL
		pool_fill[coord] = 0

	for coord in data.town_cells:
		cell_terrain[coord] = CellState.TOWN

	for coord in data.geyser_cells:
		cell_terrain[coord] = CellState.GEYSER
		geyser_fill[coord] = 0

	for coord in data.dirt_cells:
		cell_terrain[coord] = CellState.DIRT
		dig_progress[coord] = 0

	# Hydro Electric Power Plant: 3 horizontally-adjacent cells per
	# LevelData.hydro_plant_cells entry (that entry is the CENTER cell --
	# see its doc comment). All 3 start as HYDRO terrain, which the water
	# simulation treats exactly like a Wall (see _is_inactive_hydro()/
	# _is_wall()) until try_activate_hydro() fires.
	for anchor in data.hydro_plant_cells:
		var cells: Array[Vector2i] = [anchor + Vector2i(-1, 0), anchor, anchor + Vector2i(1, 0)]
		for cell in cells:
			cell_terrain[cell] = CellState.HYDRO
			hydro_cell_to_anchor[cell] = anchor
		hydro_plants[anchor] = {"cells": cells, "touched": false, "active": false}

	# Preset blocks (LevelData.preset_blocks): committed straight into
	# placed_blocks at setup, so they're live from the very first beat --
	# no PLACEMENT-beat queueing, no inventory/budget interaction. They
	# render and behave exactly like player-placed blocks of the same id
	# (same icon, same _resolve_block_targets() behavior), but are FIXED
	# terrain: remove_block() refuses to pick one up. Retry naturally
	# restores them, since this setup() runs again.
	for coord in data.preset_blocks.keys():
		placed_blocks[coord] = data.preset_blocks[coord]

	_fit_hex_layout()
	queue_redraw()


## Returns the viewport's visible size. Falls back to the project's
## configured viewport size when there's no live viewport (e.g. a HexBoard
## created standalone in a headless verification script, not added to the
## scene tree) so layout math stays testable outside a running game.
func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp:
		return vp.get_visible_rect().size
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 720),
		ProjectSettings.get_setting("display/window/size/viewport_height", 1280)
	)


func _all_playable_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	var radius := level_data.grid_radius
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var coord := Vector2i(q, r)
			if in_playable_area(coord):
				coords.append(coord)
	return coords


## Solves for the tile size (Hex.SIZE) that makes this level's grid exactly
## GRID_WIDTH_FRACTION of the screen's width, then positions this node
## (self.position) so the grid's top-left bounding corner lands at the
## GRID_SIDE_MARGIN_FRACTION / GRID_TOP_MARGIN_FRACTION point. Also computes
## max_scroll_down so Level.gd knows how far the player can drag the grid
## up to see its bottom, for grids taller than one screen.
func _fit_hex_layout() -> void:
	var viewport_size := _viewport_size()
	var target_width := viewport_size.x * GRID_WIDTH_FRACTION

	# Measure the grid's bounding box at Hex.SIZE = 1, then solve for the
	# size that scales that box to exactly target_width wide. Hex.SIZE is
	# shared/static (see Hex.gd) so this temporarily repurposes it for the
	# measurement pass before setting it to the real computed value below.
	Hex.SIZE = 1.0
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for coord in _all_playable_coords():
		var center := Hex.axial_to_pixel(coord)
		for i in range(6):
			var corner := Hex.hex_corner(center, i)
			min_x = minf(min_x, corner.x)
			max_x = maxf(max_x, corner.x)
			min_y = minf(min_y, corner.y)
			max_y = maxf(max_y, corner.y)

	var width_at_size_1 := max_x - min_x
	var computed_size := target_width / width_at_size_1 if width_at_size_1 > 0.0 else 1.0
	Hex.SIZE = computed_size

	var grid_left := min_x * computed_size
	var grid_top := min_y * computed_size
	var grid_bottom := max_y * computed_size
	var grid_height := grid_bottom - grid_top

	var left_margin := viewport_size.x * GRID_SIDE_MARGIN_FRACTION
	var top_margin := viewport_size.y * GRID_TOP_MARGIN_FRACTION

	position.x = left_margin - grid_left
	top_position_y = top_margin - grid_top
	position.y = top_position_y

	var available_height: float = viewport_size.y - top_margin - BOTTOM_UI_RESERVED_PX
	max_scroll_down = maxf(0.0, grid_height - available_height)


func in_playable_area(coord: Vector2i) -> bool:
	if level_data.blocked_cells.has(coord):
		return false
	var q := coord.x
	var r := coord.y
	var s := -q - r
	var dist: int = maxi(absi(q), maxi(absi(r), absi(s)))
	if dist > level_data.grid_radius:
		return false
	# Corridor levels (LevelData.corridor_half_width > 0): the playable area
	# is additionally restricted to a narrow vertical band centered on
	# q = round(-r/2) per row -- the exact same visual-vertical band rule
	# the existing tall levels (13-17) hand-carved via thousands of
	# blocked_cells entries, now expressed as one field. Essential for very
	# deep levels (e.g. level 22's radius-50 grid): listing the ~7000
	# outside cells in blocked_cells would bloat the .tres AND make this
	# function's Array.has() check ruinously slow, since it runs per cell
	# per redraw. 0 (the default) skips this entirely -- every existing
	# level is untouched.
	if level_data.corridor_half_width > 0:
		var band_center := int(roundf(-r / 2.0))
		if absi(q - band_center) > level_data.corridor_half_width:
			return false
	return true


## Cube-coordinate distance from the grid's center (axial 0,0) -- used by
## the "flat" grid's loss detection (_advance_water_flat()/_flat_try_enter())
## to tell "genuinely off the edge of the whole level" apart from "hit a
## blocked_cells carve-out", independent of which direction caused it. The
## "pointy" grid's natural-fall path doesn't need this (its two down
## directions both always increase r, so a simple r > grid_radius check
## already disambiguates the same thing -- see _try_natural_step()).
func _cube_distance(coord: Vector2i) -> int:
	var q := coord.x
	var r := coord.y
	var s := -q - r
	return maxi(absi(q), maxi(absi(r), absi(s)))


## True if `coord` is a dirt cell that hasn't been fully dug open yet --
## i.e. its terrain is still DIRT (dig() reverts it to EMPTY on the tap
## that reaches DIG_TAPS_REQUIRED). Undug dirt is treated exactly like a
## Wall by the water simulation (see _is_wall()) and can't have a block
## placed on it (see place_block()); a fully dug cell is ordinary EMPTY
## terrain in every way except its trench-colored fill (see _draw_cell()).
func _is_undug_dirt(coord: Vector2i) -> bool:
	return cell_terrain.get(coord, CellState.EMPTY) == CellState.DIRT


## One dig tap on a dirt cell -- the core "Dig the River" interaction,
## called by Level.gd's _handle_tap() whenever the player taps a hex whose
## terrain is DIRT. Increments that cell's dig_progress; the tap that
## reaches DIG_TAPS_REQUIRED (3) opens the cell -- its terrain reverts to
## EMPTY so water can flow through it from the next WATER beat on. Returns
## false (and does nothing) for a non-dirt/already-open cell, so callers
## can simply try-dig first and fall through to block placement/pickup on
## false. Digging takes effect immediately (not queued to the PLACEMENT
## beat the way block placement is) -- carving earth is a direct action on
## the terrain, and the "tap the river forward" feel depends on the water
## being released the moment the third tap lands, not up to a measure
## later. Free and unlimited: no inventory or budget cost, any number of
## dirt cells can be dug, before or after Start.
func dig(coord: Vector2i) -> bool:
	if game_over:
		return false
	if not in_playable_area(coord):
		return false
	if not _is_undug_dirt(coord):
		return false
	dig_progress[coord] = (dig_progress.get(coord, 0) as int) + 1
	if dig_progress[coord] >= DIG_TAPS_REQUIRED:
		cell_terrain[coord] = CellState.EMPTY
	queue_redraw()
	return true


## The target cell plus its 6 immediate neighbors -- the 7-cell "radius 1"
## hex cluster a Bomb Catapult blast clears (see fire_catapult()) and
## _draw_catapult_aim() previews. Doesn't filter by in_playable_area() or
## terrain type itself -- callers that care (both current callers do)
## check that per-cell.
func _catapult_blast_area(target: Vector2i) -> Array[Vector2i]:
	var area: Array[Vector2i] = [target]
	area.append_array(Hex.neighbors(target))
	return area


## Fires a charged Bomb Catapult shot -- called by Level.gd on release,
## once its press-and-hold aiming sequence has run. `direction` is one of
## Hex.NEIGHBOR_OFFSETS (snapped by Level.gd from wherever the player's
## finger/cursor currently sits relative to the catapult), `distance` is
## CATAPULT_MIN_RANGE..(CATAPULT_MIN_RANGE + CATAPULT_MAX_EXTRA_RANGE)
## tiles out along that direction, grown by however long the player held.
## Instantly clears every DIRT cell in the 7-cell blast cluster centered on
## the target (see _catapult_blast_area()) -- exactly as if each had been
## tapped DIG_TAPS_REQUIRED times -- and marks them catapult_blast_cells so
## _draw_cell() paints them in a color distinct from a player-dug trench
## or a mudslide collapse. Non-dirt cells in the cluster (already-open
## terrain, water, fire, another block, off-grid, ...) are silently
## skipped -- a shot doesn't need every one of its 7 cells to be dirt to
## "count." The catapult block itself is then removed from the board: a
## one-time-use consumable, matching its real-world namesake -- it fires
## once and is spent, same as a Geyser only activates once (see
## claude/new-tiles-hydro-catapult-design.md for the reasoning and for
## how a future "reusable" variant could be added instead/alongside).
## Takes effect immediately, same "acting on terrain is instant, not
## queued to the next PLACEMENT beat" philosophy as dig() -- see that
## function's doc comment.
func fire_catapult(catapult_coord: Vector2i, direction: Vector2i, distance: int) -> bool:
	if game_over:
		return false
	if not placed_blocks.has(catapult_coord):
		return false
	var block: BlockData = block_catalog[placed_blocks[catapult_coord]]
	if block.behavior != BlockData.TickBehavior.CATAPULT:
		return false

	var target := catapult_coord + direction * distance
	for cell in _catapult_blast_area(target):
		if not in_playable_area(cell):
			continue
		if cell_terrain.get(cell, CellState.EMPTY) == CellState.DIRT:
			cell_terrain[cell] = CellState.EMPTY
			dig_progress[cell] = DIG_TAPS_REQUIRED
			catapult_blast_cells[cell] = true

	placed_blocks.erase(catapult_coord)
	clear_catapult_aim()
	queue_redraw()
	return true


## Pushes the current in-progress aim (see Level.gd's press-and-hold state
## machine) so _draw_catapult_aim() can preview it live -- called every
## frame while the player is charging a shot.
func set_catapult_aim(coord: Vector2i, direction: Vector2i, distance: int) -> void:
	active_catapult_aim = {"coord": coord, "direction": direction, "distance": distance}
	queue_redraw()


## Clears the in-progress aim preview -- called on release (fire_catapult()
## calls this itself) or if a charging press is ever abandoned without
## firing.
func clear_catapult_aim() -> void:
	if active_catapult_aim.is_empty():
		return
	active_catapult_aim = {}
	queue_redraw()


## Queues a block placement. Validated and reserved (inventory/budget
## decremented) immediately, so the inventory bar reflects availability
## right away, but NOT added to placed_blocks -- and so not affecting the
## simulation -- until the next PLACEMENT beat commits it via
## resolve_placement_phase(). See Level.gd's beat-cycle doc comment.
func place_block(coord: Vector2i, block_id: String) -> bool:
	if game_over:
		return false
	if not in_playable_area(coord):
		return false
	# Rule: player-placeable tiles can never sit ON a water source -- an
	# original level_data.water_sources cell, or a geyser that has
	# activated into a source. (Level design must respect a companion
	# authoring rule: no PREPLACED level tile -- fire/pool/town/geyser/
	# dirt/preset block -- within 2 rows vertically of a starting source;
	# that one is enforced at authoring time, not here.) Levels 1/10/11/12
	# were relaid when this rule landed: their old documented solutions
	# placed a diverter directly on the source, which is exactly what this
	# forbids -- their new solutions use a Wall on the source's first
	# landing cell instead (see README).
	if level_data.water_sources.has(coord) or active_geysers.has(coord):
		return false
	if placed_blocks.has(coord) or pending_placements.has(coord):
		return false
	if pending_removals.has(coord):
		return false # a pickup of this exact cell is already queued this beat
	var terrain: String = cell_terrain.get(coord, CellState.EMPTY)
	if terrain == CellState.FIRE or terrain == CellState.POOL or terrain == CellState.TOWN or terrain == CellState.GEYSER or terrain == CellState.DIRT or terrain == CellState.HYDRO:
		return false
	if use_block_budget:
		if block_budget_remaining <= 0:
			return false
	elif not inventory.has(block_id) or inventory[block_id] <= 0:
		return false

	pending_placements[coord] = block_id
	if use_block_budget:
		block_budget_remaining -= 1
	else:
		inventory[block_id] -= 1
	queue_redraw()
	return true


## Picks up a block -- either cancelling a still-pending placement (refunds
## immediately, never having touched placed_blocks or the simulation at
## all) or queuing the removal of an already-committed block, which -- like
## placement -- only actually takes effect at the next PLACEMENT beat via
## resolve_placement_phase(). The refund itself still happens immediately
## at queue time either way, matching place_block()'s "inventory reflects
## availability right away" behavior. Works at any time, including mid-
## simulation while water is actively ticking, same as before.
func remove_block(coord: Vector2i) -> bool:
	if game_over:
		return false

	# Preset blocks are fixed level terrain (see LevelData.preset_blocks /
	# setup() above) -- tapping one does nothing, same as tapping a fire or
	# pool. Checked before anything else so a preset can never be picked
	# up, refunded, or queued for removal.
	if level_data.preset_blocks.has(coord):
		return false

	if pending_placements.has(coord):
		var pending_id: String = pending_placements[coord]
		pending_placements.erase(coord)
		if use_block_budget:
			block_budget_remaining += 1
		else:
			inventory[pending_id] = inventory.get(pending_id, 0) + 1
		queue_redraw()
		return true

	if not placed_blocks.has(coord) or pending_removals.has(coord):
		return false

	pending_removals[coord] = true
	var block_id: String = placed_blocks[coord]
	if use_block_budget:
		block_budget_remaining += 1
	else:
		inventory[block_id] = inventory.get(block_id, 0) + 1
	queue_redraw()
	return true


## Beat 1 -- PLACEMENT. Commits every block placement/removal queued since
## the last PLACEMENT beat (via place_block()/remove_block() above) to
## placed_blocks, then clears both queues. Inventory/budget bookkeeping
## already happened at queue time, so this step is pure board-state commit
## -- it's what makes a placed/picked-up block actually appear/disappear on
## the board and start/stop affecting the water simulation.
func resolve_placement_phase() -> void:
	for coord in pending_removals.keys():
		placed_blocks.erase(coord)
	for coord in pending_placements.keys():
		placed_blocks[coord] = pending_placements[coord]
	pending_removals.clear()
	pending_placements.clear()
	queue_redraw()


## Beat 2 -- WATER, the core simulation step (this used to be the whole of
## tick()). Spawns a fresh drop from every source/active geyser, advances
## every existing drop one hex, and redraws immediately -- water position is
## the one piece of state meant to visibly update the instant this beat
## lands. Terrain contact effects (fire/pool/geyser) are NOT applied here
## anymore; _try_enter() below only records them into _pending_terrain for
## the TERRAIN beat to resolve. Town-contact and edge-of-board loss still
## fire immediately in this phase -- see _try_enter()'s doc comment for why
## those are treated differently from terrain contact.
func resolve_water_phase() -> void:
	if game_over:
		return

	var is_flat := level_data.grid_style == "flat"
	for source in level_data.water_sources:
		if is_flat:
			var mode: String = level_data.source_flow_style.get(source, "straight")
			var start_dir := Hex.FLAT_DOWN_LEFT if mode == "zigzag" else Hex.FLAT_DOWN
			water_cells.append({"coord": source, "next_dir": start_dir, "mode": mode})
		else:
			water_cells.append({"coord": source, "next_dir": Hex.DOWN_LEFT})
	for source in active_geysers:
		# Active geysers on a "flat" level always flow "straight" -- not
		# configurable per-geyser yet (see LevelData.source_flow_style doc
		# comment).
		if is_flat:
			water_cells.append({"coord": source, "next_dir": Hex.FLAT_DOWN, "mode": "straight"})
		else:
			water_cells.append({"coord": source, "next_dir": Hex.DOWN_LEFT})
	for source in hydro_source_cells:
		# Same "straight" default as an active geyser -- Hydro Plants
		# aren't yet supported on a "flat" level (see hydro_plant_cells'
		# doc comment), but this mirrors the geyser branch above so that
		# support is a small follow-up rather than a new code path.
		if is_flat:
			water_cells.append({"coord": source, "next_dir": Hex.FLAT_DOWN, "mode": "straight"})
		else:
			water_cells.append({"coord": source, "next_dir": Hex.DOWN_LEFT})

	_stalled_this_beat.clear()
	var next_water: Array[Dictionary] = []
	for entry in water_cells:
		_advance_water(entry, next_water)

	water_cells = next_water
	# Mudslides resolve after every drop has moved for this beat, so a
	# slide's terrain changes can't affect drops mid-loop -- see
	# _process_mudslides().
	_process_mudslides()
	queue_redraw()


## Beat 3 -- TERRAIN. Applies the fire/pool/geyser contact effects flagged
## by _try_enter() during this measure's WATER beat (_pending_terrain),
## mutating fires_remaining/cell_terrain/pool_fill/geyser_fill/
## active_geysers exactly as the old single-phase tick() used to do inline.
## Deliberately does NOT call queue_redraw() -- see resolve_status_phase()
## for why revealing this beat's changes is deferred to beat 4.
func resolve_terrain_phase() -> void:
	if game_over:
		return
	for coord in _pending_terrain:
		_resolve_terrain_contact(coord)
	_pending_terrain.clear()


## Beat 4 -- STATUS. Doesn't change simulation state itself -- it checks the
## win condition (now that beat 3 has finalized pool_fill/fires_remaining
## for this measure) and reveals whatever beats 2/3 changed by finally
## calling queue_redraw(). Holding the redraw until this beat is what makes
## a pool's status-bar box flipping, or a fire going out, visibly land on
## beat 4 specifically, even though the underlying state changed a beat
## earlier.
func resolve_status_phase() -> void:
	if game_over:
		return
	_check_end_conditions()
	queue_redraw()


## Applies the actual contact effect for a cell flagged into
## _pending_terrain by _try_enter() during the WATER beat -- exactly the
## FIRE/POOL/GEYSER branches the old single-phase _try_enter() used to run
## inline, just deferred to the TERRAIN beat. cell_terrain is read fresh
## here (not cached at flag time) since nothing else can change it between
## beats 2 and 3 within the same measure.
func _resolve_terrain_contact(coord: Vector2i) -> void:
	var terrain: String = cell_terrain.get(coord, CellState.EMPTY)

	if terrain == CellState.FIRE:
		cell_terrain[coord] = CellState.EMPTY
		fires_remaining -= 1
		return

	if terrain == CellState.POOL:
		# Capped at POOL_BEATS_REQUIRED -- water connecting on beats beyond
		# that doesn't do anything further, it's already maxed out.
		pool_fill[coord] = mini(pool_fill.get(coord, 0) + 1, POOL_BEATS_REQUIRED)
		return

	if terrain == CellState.GEYSER:
		# Dormant until GEYSER_BEATS_REQUIRED beats of connection, exactly
		# like a Pool filling up. On the beat that reaches the requirement,
		# the geyser activates: its terrain reverts to EMPTY (so it stops
		# consuming water here and can never re-trigger this branch) and
		# it's added to active_geysers, which resolve_water_phase() spawns
		# a brand new falling stream from every beat from then on, same as
		# any of the level's original water_sources.
		geyser_fill[coord] = geyser_fill.get(coord, 0) + 1
		if geyser_fill[coord] >= GEYSER_BEATS_REQUIRED:
			cell_terrain[coord] = CellState.EMPTY
			active_geysers.append(coord)
		return


## Dispatches to the "flat"-grid natural-fall/redirect logic when this level
## uses that orientation; otherwise runs the original "pointy"-grid zigzag
## logic completely unchanged below (kept as its own untouched code path
## specifically so this feature can't regress any of the existing, already
## verified "pointy" levels).
func _advance_water(entry: Dictionary, next_water: Array[Dictionary]) -> void:
	if level_data.grid_style == "flat":
		_advance_water_flat(entry, next_water)
		return

	var coord: Vector2i = entry["coord"]
	var next_dir: Vector2i = entry["next_dir"]
	var opposite_dir: Vector2i = Hex.DOWN_RIGHT if next_dir == Hex.DOWN_LEFT else Hex.DOWN_LEFT

	if placed_blocks.has(coord):
		# A block sits where this water currently is -- its behavior decides
		# the exit direction(s) outright (no zigzag, no retry-other-diagonal;
		# that's specific to natural unblocked fall, handled below).
		var targets := _resolve_block_targets(coord)
		if targets.is_empty():
			# WALL: fully blocks, no exit at all -- water backs up and stays
			# here, ready to try again (or divert sideways) next tick.
			_add_water(next_water, coord, opposite_dir)
			return
		# DIVERT/SPLIT always have somewhere to go, so this stream is handled
		# either way -- even if a target turns out to be a fire/pool/loss
		# and gets consumed there, that's a real outcome, not "stuck". Never
		# re-add the water at its OLD cell here: doing so on a consumed
		# target used to corrupt that stream's alternation timing by
		# freezing it in place for a spurious extra tick.
		#
		# EXCEPTION -- undug dirt (the "Dig the River" mechanic) OR an
		# inactive Hydro Plant cell: either behaves like a Wall sitting on
		# the target, so it's skipped rather than entered (and, for
		# hydro, the contact is recorded -- see _note_hydro_contact() --
		# so the plant becomes double-tap-able). If EVERY target is
		# blocked this way, the water has nowhere to go after all and
		# backs up on the block, exactly as it would against a Wall,
		# until the player digs/activates one of the targets open.
		var all_targets_dirt := true
		for target in targets:
			if _is_undug_dirt(target) or _is_inactive_hydro(target):
				_note_hydro_contact(target)
				continue
			all_targets_dirt = false
			if _try_enter(target):
				_add_water(next_water, target, opposite_dir)
		if all_targets_dirt:
			var dirs: Array[Vector2i] = []
			for target in targets:
				dirs.append(target - coord)
			_note_dirt_stall(coord, dirs)
			_add_water(next_water, coord, opposite_dir)
		return

	# Default: no block here -- natural zigzag fall. Try this stream's
	# current alternation direction first; if that hex is blocked (off the
	# grid edge, or a WALL block already sits there), try the opposite
	# diagonal instead. If both are blocked, the water stays here and pools
	# up for this tick. Either way, the alternation counter advances for
	# next tick.
	if _try_natural_step(coord, next_dir, opposite_dir, next_water):
		return
	if _try_natural_step(coord, opposite_dir, opposite_dir, next_water):
		return
	var stall_dirs: Array[Vector2i] = [next_dir, opposite_dir]
	_note_dirt_stall(coord, stall_dirs)
	_add_water(next_water, coord, opposite_dir)


## Attempts one natural-fall diagonal step. Returns true if the step was NOT
## blocked (whether the water actually moved there, was absorbed by a
## fire/pool, or triggered a bottom-edge loss) -- false only when the caller
## should retry the other diagonal instead.
func _try_natural_step(coord: Vector2i, dir: Vector2i, future_dir: Vector2i, next_water: Array[Dictionary]) -> bool:
	var target := coord + dir

	if target.y > level_data.grid_radius:
		# Straight past the bottom edge is always a loss -- both diagonals
		# increase r by 1, so the other diagonal would lose the same way.
		# No point retrying it.
		_try_enter(target)
		return true

	if not in_playable_area(target) or _is_wall(target):
		# Only a WALL block (or an activated geyser, a still-undug dirt
		# cell, or an inactive Hydro Plant cell -- see _is_wall()) truly
		# obstructs natural fall. A Diverter or Splitter is a pass-through
		# -- water lands on it just fine, and THAT block's own behavior
		# (via the placed_blocks.has(coord) branch above) decides where it
		# goes next tick, same as always. _note_hydro_contact() is a no-op
		# unless `target` is actually a Hydro Plant cell.
		_note_hydro_contact(target)
		return false

	if _try_enter(target):
		_add_water(next_water, target, future_dir)
	return true


## Flat-grid equivalent of the pointy-grid block above -- natural fall and
## placed-block redirects for a level using LevelData.grid_style == "flat".
## Kept as a fully separate function (rather than branching throughout the
## pointy code above) so the pointy path is provably untouched by this
## feature.
##
## Unlike the pointy grid, this orientation's natural fall isn't always a
## two-way zigzag: a "straight" stream (LevelData.source_flow_style) only
## ever tries Hex.FLAT_DOWN, while a "zigzag" stream alternates between
## Hex.FLAT_DOWN_LEFT and Hex.FLAT_DOWN_RIGHT exactly like the pointy grid's
## zigzag, just using this grid's own diagonal pair. Loss detection can't
## reuse the pointy grid's "target.y > grid_radius" shortcut, because
## FLAT_DOWN_RIGHT doesn't increase r the way the pointy grid's two down
## directions (or this grid's FLAT_DOWN/FLAT_DOWN_LEFT) do -- instead, each
## candidate direction is checked directly against _cube_distance() so a
## definite off-the-edge exit is detected regardless of which axis caused
## it, and a loss only fires once every candidate for this stream has
## failed (matching the pointy grid's actual observable behavior: only
## trigger a loss once there's truly nowhere left to go).
func _advance_water_flat(entry: Dictionary, next_water: Array[Dictionary]) -> void:
	var coord: Vector2i = entry["coord"]
	var mode: String = entry.get("mode", "straight")
	var next_dir: Vector2i = entry.get("next_dir", Hex.FLAT_DOWN_LEFT)
	var opposite_dir: Vector2i = Hex.FLAT_DOWN_RIGHT if next_dir == Hex.FLAT_DOWN_LEFT else Hex.FLAT_DOWN_LEFT

	if placed_blocks.has(coord):
		var targets := _resolve_block_targets(coord)
		if targets.is_empty():
			_add_water(next_water, coord, opposite_dir, mode)
			return
		# Same undug-dirt-or-inactive-hydro exception as the pointy-grid
		# branch above: either is skipped like a Wall, and if every target
		# is blocked this way the water backs up on the block until one is
		# dug/activated open.
		var all_targets_dirt := true
		for target in targets:
			if _is_undug_dirt(target) or _is_inactive_hydro(target):
				_note_hydro_contact(target)
				continue
			all_targets_dirt = false
			if _flat_try_enter(target):
				_add_water(next_water, target, opposite_dir, mode)
		if all_targets_dirt:
			var dirs: Array[Vector2i] = []
			for target in targets:
				dirs.append(target - coord)
			_note_dirt_stall(coord, dirs)
			_add_water(next_water, coord, opposite_dir, mode)
		return

	# NOTE: building this as a single-line ternary between two array
	# literals (`[Hex.FLAT_DOWN] if mode != "zigzag" else [...]`) used to
	# throw a runtime "Trying to assign an array of type Array to a
	# variable of type Array[Vector2i]" error -- GDScript's ternary
	# operator doesn't propagate the declared Array[Vector2i] type onto
	# its branch literals, so the result comes back as a plain untyped
	# Array even though the surrounding `var candidates: Array[Vector2i]`
	# declaration looks like it should force it. Building the typed array
	# imperatively (append() calls) instead of via a ternary-of-literals
	# sidesteps that entirely. This hit every "straight" mode stream (the
	# `mode != "zigzag"` branch), i.e. any flat-grid level with a
	# `"straight"` source -- including Level 20.
	var candidates: Array[Vector2i] = []
	if mode == "zigzag":
		candidates.append(next_dir)
		candidates.append(opposite_dir)
	else:
		candidates.append(Hex.FLAT_DOWN)

	var any_boundary_exit := false
	for dir in candidates:
		var target := coord + dir
		if not level_data.blocked_cells.has(target) and _cube_distance(target) > level_data.grid_radius:
			# Definitely off the true edge of the level via this candidate
			# -- noted, but don't act on it yet, since a LATER candidate
			# (e.g. the other diagonal) might still be a valid move.
			any_boundary_exit = true
			continue
		if not in_playable_area(target) or _is_wall(target):
			_note_hydro_contact(target) # no-op unless `target` is a Hydro Plant cell
			continue # blocked by a corridor carve-out, a Wall, an activated geyser, undug dirt, or an inactive Hydro Plant cell (see _is_wall()) -- try the next candidate
		if _try_enter(target):
			var spawn_dir := opposite_dir if mode == "zigzag" else Hex.FLAT_DOWN
			_add_water(next_water, target, spawn_dir, mode)
		return # handled (moved, or consumed by fire/pool/town/geyser)

	# No candidate succeeded. Only lose if at least one of them failed
	# specifically by exiting the level's true boundary -- if every
	# candidate was blocked purely by a Wall/corridor cell instead, the
	# water just backs up and pools here for this tick, same as the pointy
	# grid's Wall-blocks-natural-fall behavior.
	if any_boundary_exit:
		_lose(LoseReason.EDGE)
	else:
		_note_dirt_stall(coord, candidates)
		_add_water(next_water, coord, opposite_dir, mode)


## Records that a drop stayed put at `coord` this WATER beat, IF at least
## one of the directions it tried (`dirs`, in try order) is blocked
## specifically by undug dirt -- that's what makes it a mudslide stall
## rather than an ordinary Wall/edge backup, which never slides. The first
## dirt direction found becomes the slide's preferred collapse direction.
## Consumed by _process_mudslides() at the end of the beat.
func _note_dirt_stall(coord: Vector2i, dirs: Array[Vector2i]) -> void:
	for dir in dirs:
		if _is_undug_dirt(coord + dir):
			_stalled_this_beat[coord] = dir
			return


## Runs at the end of every WATER beat (after all drops have moved). Prunes
## dirt_stall counters for any coord where water is no longer stalled on
## dirt (the water moved on, or the player dug the blocker open -- either
## way the pressure is relieved and the clock restarts from zero if it ever
## backs up there again), increments the counter for every coord that
## stalled this beat, and fires _trigger_mudslide() for any counter
## reaching MUDSLIDE_BEATS_REQUIRED (resetting that counter, so a still-
## stalled drop starts a fresh 10-beat clock toward the NEXT slide).
func _process_mudslides() -> void:
	for coord in dirt_stall.keys():
		if not _stalled_this_beat.has(coord):
			dirt_stall.erase(coord)
	for coord in _stalled_this_beat.keys():
		dirt_stall[coord] = (dirt_stall.get(coord, 0) as int) + 1
		if dirt_stall[coord] >= MUDSLIDE_BEATS_REQUIRED:
			_trigger_mudslide(coord, _stalled_this_beat[coord])
			dirt_stall.erase(coord)


## The mudslide itself: collapses a downward chain of up to
## MUDSLIDE_COLLAPSE_TILES undug dirt tiles, starting with the tile
## blocking the stalled water at `from_coord` and continuing tile-by-tile
## in the slide's direction (falling back to the grid's other downward
## option(s) whenever the preferred one isn't dirt; the chain simply stops
## early if no dirt continues it). Each collapsed tile opens fully --
## terrain reverts to EMPTY and dig_progress jumps to the cap, exactly as
## if the player had dug it -- but is marked in mudslide_cells so
## _draw_cell() paints it MUDSLIDE_COLOR: the river forced this path, the
## player didn't choose it. The freed water then flows into the collapsed
## channel on the very next WATER beat, wherever that leads -- possibly
## somewhere unfortunate, which is the entire point of the threat.
func _trigger_mudslide(from_coord: Vector2i, dir: Vector2i) -> void:
	var alts: Array[Vector2i] = []
	if level_data.grid_style == "flat":
		alts = [dir, Hex.FLAT_DOWN, Hex.FLAT_DOWN_LEFT, Hex.FLAT_DOWN_RIGHT]
	else:
		alts = [dir, Hex.DOWN_RIGHT if dir == Hex.DOWN_LEFT else Hex.DOWN_LEFT]
	var cur := from_coord
	for i in range(MUDSLIDE_COLLAPSE_TILES):
		var next_cell := Vector2i(9999, 9999)
		for alt in alts:
			var target := cur + alt
			if in_playable_area(target) and _is_undug_dirt(target):
				next_cell = target
				break
		if next_cell == Vector2i(9999, 9999):
			return # no dirt continues the chain -- slide ends early
		cell_terrain[next_cell] = CellState.EMPTY
		dig_progress[next_cell] = DIG_TAPS_REQUIRED
		mudslide_cells[next_cell] = true
		cur = next_cell


## Flat-grid version of _try_enter() used for forced block redirects (see
## _advance_water_flat()'s placed_blocks branch) -- adds the same
## boundary-vs-blocked_cells distinction _advance_water_flat()'s natural-fall
## loop uses, since a Diverter-Right on this grid can redirect water via
## Hex.FLAT_DOWN_RIGHT, which (like natural fall) doesn't always increase r
## the way _try_enter()'s own "coord.y > grid_radius" check assumes.
func _flat_try_enter(target: Vector2i) -> bool:
	if not level_data.blocked_cells.has(target) and _cube_distance(target) > level_data.grid_radius:
		_lose(LoseReason.EDGE)
		return false
	return _try_enter(target)


## True if natural water fall (and forced block redirects, via the same
## in_playable_area/_is_wall check both grid styles run before ever calling
## _try_enter()) should treat `coord` as fully obstructed -- an explicitly
## placed WALL block, an activated geyser, or a still-undug dirt cell (the
## "Dig the River" mechanic -- packed earth holds the water back exactly
## like a Wall until the player digs it open, see dig()).
##
## A geyser that has already fired (see active_geysers / _resolve_terrain_contact()'s
## GEYSER branch) reverts its terrain to EMPTY so its OWN newly-spawned
## stream has somewhere to start from, but that used to also let the
## ORIGINAL river that fed it into activation keep sailing straight through
## that now-empty cell forever afterward (every later beat from the
## original source just passed through untouched). Treating an active
## geyser exactly like a permanent Wall here means that original feed
## backs up and stays put instead -- it retries the other diagonal each
## tick and pools at the cell just above the geyser, same as running into
## any other Wall -- while the geyser's own spawned stream is unaffected
## (that water is injected directly into water_cells by resolve_water_phase(),
## which never goes through this check).
##
## This also makes the README's old "place a terminal Pool/Wall right after
## the geyser to catch the leftover original feed" manual workaround
## unnecessary going forward -- it's still harmless if an existing level
## (e.g. Level 18) already does it, just redundant now.
func _is_wall(coord: Vector2i) -> bool:
	if active_geysers.has(coord):
		return true
	if _is_undug_dirt(coord):
		return true
	if _is_inactive_hydro(coord):
		return true
	if not placed_blocks.has(coord):
		return false
	var block: BlockData = block_catalog[placed_blocks[coord]]
	return block.behavior == BlockData.TickBehavior.WALL


## True if `coord` is one of a Hydro Plant's 3 cells and that plant hasn't
## been activated yet -- treated exactly like undug dirt/a Wall by the
## water simulation (see _is_wall() above and both block-redirect loops'
## "EXCEPTION" comments) until the player double-taps it (see
## try_activate_hydro()). Once active, a plant's cells revert to ordinary
## EMPTY terrain (see try_activate_hydro()), so this always returns false
## for them afterward.
func _is_inactive_hydro(coord: Vector2i) -> bool:
	if cell_terrain.get(coord, CellState.EMPTY) != CellState.HYDRO:
		return false
	var anchor: Vector2i = hydro_cell_to_anchor.get(coord, coord)
	var plant: Dictionary = hydro_plants.get(anchor, {})
	return not (plant.get("active", false) as bool)


## Records that water has backed up against `coord` -- a no-op unless
## `coord` is actually one of a Hydro Plant's 3 cells, so every call site
## that discovers a blocked step can call this unconditionally without
## checking terrain type first (see _try_natural_step(),
## _advance_water_flat(), and both block-redirect loops above). This is
## what makes hydro_ready_at()/the double-tap handler possible -- a plant
## can't be told "the water actually arrived" just from _is_wall()
## returning true, since that's a pure predicate with no side effects.
func _note_hydro_contact(coord: Vector2i) -> void:
	if cell_terrain.get(coord, CellState.EMPTY) != CellState.HYDRO:
		return
	var anchor: Vector2i = hydro_cell_to_anchor.get(coord, coord)
	if hydro_plants.has(anchor):
		hydro_plants[anchor]["touched"] = true


## True if `coord` (any of a plant's 3 cells, or its center/anchor
## coordinate) belongs to a Hydro Plant that's been touched by water (see
## _note_hydro_contact()) but hasn't activated yet -- the exact
## precondition Level.gd's double-tap handler requires before calling
## try_activate_hydro(). Also used by _draw_cell() to decide whether to
## show the "ready to activate" ring.
func hydro_ready_at(coord: Vector2i) -> bool:
	var anchor: Vector2i = hydro_cell_to_anchor.get(coord, coord)
	var plant: Dictionary = hydro_plants.get(anchor, {})
	if plant.is_empty():
		return false
	return (plant.get("touched", false) as bool) and not (plant.get("active", false) as bool)


## The core Hydro Plant activation -- called by Level.gd on the SECOND tap
## of a double-tap landing on any of a plant's 3 cells. Returns false (no
## effect at all) unless hydro_ready_at(coord) is true, i.e. water must
## have actually reached the plant first; an untouched or already-active
## plant can't be (re)activated. On success: all 3 of the plant's cells
## revert to ordinary EMPTY terrain (so they stop blocking natural
## fall/redirects -- see _is_inactive_hydro()) and each is added to
## hydro_source_cells, becoming a brand new permanent water source from
## the very next WATER beat on -- "3 rivers come out of it." Same "tap
## fires it, effect is immediate, not queued to the next PLACEMENT beat"
## philosophy as dig() -- see that function's doc comment for the
## reasoning (this is a direct action on terrain/board state, not a block
## placement).
func try_activate_hydro(coord: Vector2i) -> bool:
	if game_over:
		return false
	if not hydro_ready_at(coord):
		return false
	var anchor: Vector2i = hydro_cell_to_anchor.get(coord, coord)
	var plant: Dictionary = hydro_plants[anchor]
	plant["active"] = true
	for cell in (plant["cells"] as Array):
		cell_terrain[cell] = CellState.EMPTY
		hydro_source_cells.append(cell)
	queue_redraw()
	return true


## Decides where water sitting ON a placed block moves to. Determined by
## whatever block is at `coord` -- this is what makes a WALL block hold
## water back and a DIVERT block redirect it. The direction pair used for
## DIVERT_LEFT/DIVERT_RIGHT/SPLIT depends on level_data.grid_style: the same
## block conceptually always means "send water down-and-to-the-left/right"
## on either grid, it just resolves to that grid's own actual down-left/
## down-right directions (on "pointy", Hex.DOWN_LEFT/DOWN_RIGHT; on "flat",
## Hex.FLAT_DOWN_LEFT/FLAT_DOWN_RIGHT) -- no separate "flat" block type
## needed.
func _resolve_block_targets(coord: Vector2i) -> Array[Vector2i]:
	var block: BlockData = block_catalog[placed_blocks[coord]]
	var down_left := Hex.FLAT_DOWN_LEFT if level_data.grid_style == "flat" else Hex.DOWN_LEFT
	var down_right := Hex.FLAT_DOWN_RIGHT if level_data.grid_style == "flat" else Hex.DOWN_RIGHT
	var targets: Array[Vector2i] = []
	match block.behavior:
		BlockData.TickBehavior.WALL, BlockData.TickBehavior.CATAPULT:
			# A Bomb Catapult is a solid structure for water purposes --
			# fully blocks, same as a Wall. Its actual gameplay (clearing
			# dirt) happens entirely outside the tick simulation, via
			# fire_catapult() -- see BlockData.TickBehavior.CATAPULT's doc
			# comment.
			pass
		BlockData.TickBehavior.DIVERT_LEFT:
			targets.append(coord + down_left)
		BlockData.TickBehavior.DIVERT_RIGHT:
			targets.append(coord + down_right)
		BlockData.TickBehavior.SPLIT:
			targets.append(coord + down_left)
			targets.append(coord + down_right)
		_:
			targets.append(coord + down_right)
	return targets


## Adds a water entry for next tick, unless one already occupies that coord
## this tick (in which case the first stream to arrive keeps its
## alternation state for the merged puddle). `mode` is flat-grid-only (see
## water_cells' doc comment) -- omitted from the stored entry when empty so
## a "pointy" level's entries keep their original shape exactly.
func _add_water(next_water: Array[Dictionary], coord: Vector2i, next_dir: Vector2i, mode: String = "") -> void:
	for existing in next_water:
		if existing["coord"] == coord:
			return
	var new_entry := {"coord": coord, "next_dir": next_dir}
	if mode != "":
		new_entry["mode"] = mode
	next_water.append(new_entry)


## Attempts to move a water unit into `coord`, called during the WATER beat
## (resolve_water_phase(), via _advance_water()/_advance_water_flat()).
## Returns true if the water should now occupy that cell (nothing stopped
## it), false if the move is illegal (off the grid) or the cell will
## consume it.
##
## Town-contact and edge-of-board loss still fire immediately, right here
## in the WATER beat -- those aren't "terrain reacting to contact" so much
## as "the water left the play area or hit an instant-loss cell," so
## there's no reason to defer them a beat. Fire/pool/geyser contact, by
## contrast, is real terrain resolution and is deferred to the TERRAIN beat
## (see _pending_terrain / _resolve_terrain_contact()) -- this function just
## flags the coord and stops the water here, exactly like the old
## single-phase version did, just without applying the effect yet. Note
## that an activated geyser is NOT handled here -- both callers
## (_try_natural_step() for the pointy grid, and _advance_water_flat()'s
## candidate loop for the flat grid) already filter it out earlier via
## _is_wall(), so water heading for one never reaches this function in the
## first place; see _is_wall()'s doc comment for why. The same is true of
## undug DIRT cells -- filtered out by _is_wall() (natural fall) or the
## explicit dirt check in both placed-block branches (forced redirects), so
## the DIRT branch below is purely defensive: water can simply never enter
## packed dirt, with no side effects and never a loss.
func _try_enter(coord: Vector2i) -> bool:
	if not in_playable_area(coord):
		# Falling past the bottom edge of the grid is a loss. Exits off the
		# sides/top (shouldn't normally happen given level design) just
		# drop the water silently rather than crashing the sim.
		if coord.y > level_data.grid_radius:
			_lose(LoseReason.EDGE)
		return false

	var terrain: String = cell_terrain.get(coord, CellState.EMPTY)

	if terrain == CellState.TOWN:
		# Any water reaching the town is an instant loss, same as flooding
		# past the bottom edge. Marked as flooded so _draw_cell() shows this
		# specific cell as light blue instead of brown -- the level ends
		# this same beat.
		flooded_towns[coord] = true
		_lose(LoseReason.TOWN)
		return false

	if terrain == CellState.DIRT:
		# Defensive only -- see the doc comment above. Packed dirt simply
		# can't be entered; no terrain effect, no loss.
		return false

	if terrain == CellState.FIRE or terrain == CellState.POOL or terrain == CellState.GEYSER:
		# Real terrain resolution -- defer the actual effect to the TERRAIN
		# beat (resolve_terrain_phase() / _resolve_terrain_contact()).
		# Water still stops here this beat either way (matches the old
		# single-phase behavior of returning false for all three).
		if not _pending_terrain.has(coord):
			_pending_terrain.append(coord)
		return false

	return true


func _check_end_conditions() -> void:
	if game_over:
		return

	var all_pools_full := true
	for coord in pool_fill.keys():
		if pool_fill[coord] < POOL_BEATS_REQUIRED:
			all_pools_full = false
			break

	if all_pools_full and fires_remaining <= 0:
		_win()


func _lose(reason: String) -> void:
	if game_over:
		return
	game_over = true
	lose_reason = reason
	level_lost.emit()


func _win() -> void:
	if game_over:
		return
	game_over = true
	level_won.emit()


func screen_to_hex(local_pos: Vector2) -> Vector2i:
	return Hex.pixel_to_axial(local_pos)


## Returns every predicted arrow segment {"from": Vector2i, "to": Vector2i}
## for the pre-start flow preview (see show_flow_preview) -- one branch per
## water_sources entry, walking up to PREVIEW_ARROW_STEPS hex-to-hex moves
## following the exact same natural-fall/block-redirect rules
## resolve_water_phase()/_advance_water()/_advance_water_flat() use, but
## WITHOUT mutating any real game state (no fire/pool/geyser consumption, no
## win/loss, no water_cells changes) -- purely a read-only forecast of where
## the water ultimately flows given the CURRENT placed_blocks. A Splitter
## branches into two separate arrow chains; a Wall, a boxed-in dead end, or
## an edge exit all silently end a branch with no further arrow (there's
## nothing useful to draw beyond them). An undug DIRT cell ends a branch
## the same silent way a Wall does (via _is_wall()) -- which also means
## digging a cell open pre-start immediately EXTENDS the preview through
## it on the next redraw, letting the player watch their channel's
## forecast grow tap by tap. A town/pool/still-dormant-geyser cell gets an
## arrow drawn INTO it and then ends the branch there too (see
## _predict_would_consume()'s doc comment for why those three specifically
## are treated as permanent stops). A fire cell also gets an arrow drawn
## into it, but does NOT end the branch -- a fire only consumes the first
## water that ever reaches it and is transparent to every beat after that,
## so the preview continues straight through, tracing the path all the way
## to wherever it actually ends up (e.g. a pool further down).
func _predict_flow_arrows() -> Array:
	var arrows: Array = []
	if level_data == null:
		return arrows
	var is_flat := level_data.grid_style == "flat"
	for source in level_data.water_sources:
		var mode: String = level_data.source_flow_style.get(source, "straight") if is_flat else ""
		var next_dir: Vector2i
		if is_flat:
			next_dir = Hex.FLAT_DOWN_LEFT if mode == "zigzag" else Hex.FLAT_DOWN
		else:
			next_dir = Hex.DOWN_LEFT
		_predict_branch(source, next_dir, mode, is_flat, PREVIEW_ARROW_STEPS, arrows)
	return arrows


## Recursive helper for _predict_flow_arrows() -- extends one branch by one
## step (following whichever rule applies: sitting on a placed block, or
## natural fall) and recurses for the remaining steps if the branch is
## still "open" (not consumed, not stuck, not off the edge). Mirrors
## _advance_water()/_advance_water_flat() closely enough to forecast the
## real outcome, but every terrain check goes through the read-only
## _predict_would_consume() instead of _try_enter() (which flags
## _pending_terrain / mutates flooded_towns and can fire level_lost --
## neither of which this preview should ever do).
func _predict_branch(coord: Vector2i, next_dir: Vector2i, mode: String, is_flat: bool, steps_remaining: int, arrows: Array) -> void:
	if steps_remaining <= 0:
		return

	var opposite_dir: Vector2i
	if is_flat:
		opposite_dir = Hex.FLAT_DOWN_RIGHT if next_dir == Hex.FLAT_DOWN_LEFT else Hex.FLAT_DOWN_LEFT
	else:
		opposite_dir = Hex.DOWN_RIGHT if next_dir == Hex.DOWN_LEFT else Hex.DOWN_LEFT

	if placed_blocks.has(coord):
		var targets := _resolve_block_targets(coord)
		if targets.is_empty():
			return # WALL: water backs up here forever -- nothing further to draw
		for target in targets:
			if not in_playable_area(target) or _is_undug_dirt(target):
				continue # this branch would exit the grid or hit packed dirt -- no arrow, nothing further
			arrows.append({"from": coord, "to": target})
			if _predict_would_consume(target):
				continue # town/pool/dormant geyser -- this branch ends right here
			_predict_branch(target, opposite_dir, mode, is_flat, steps_remaining - 1, arrows)
		return

	# Natural (unblocked) fall -- same candidate order _try_natural_step()/
	# _advance_water_flat() use: try the stream's current direction first,
	# fall back to the other diagonal (pointy only; a "straight" flat
	# stream has just the one candidate).
	var candidates: Array[Vector2i] = []
	if is_flat:
		if mode == "zigzag":
			candidates.append(next_dir)
			candidates.append(opposite_dir)
		else:
			candidates.append(Hex.FLAT_DOWN)
	else:
		candidates.append(next_dir)
		candidates.append(opposite_dir)

	for dir in candidates:
		var target := coord + dir
		if is_flat:
			if not level_data.blocked_cells.has(target) and _cube_distance(target) > level_data.grid_radius:
				continue # exits the true boundary via this candidate -- try the next one
		else:
			if target.y > level_data.grid_radius:
				continue # straight bottom-edge exit -- both diagonals would lose the same way, nothing to draw
		if not in_playable_area(target) or _is_wall(target):
			continue # blocked by a corridor carve-out, a Wall, an activated geyser, or undug dirt -- try the next candidate
		arrows.append({"from": coord, "to": target})
		if _predict_would_consume(target):
			return # town/pool/dormant geyser -- this branch ends right here
		var spawn_dir := (opposite_dir if mode == "zigzag" else Hex.FLAT_DOWN) if is_flat else opposite_dir
		_predict_branch(target, spawn_dir, mode, is_flat, steps_remaining - 1, arrows)
		return
	# No candidate succeeded -- boxed in by walls/edges on every side, or a
	# pure edge exit either way. Nothing further to draw for this branch.


## Read-only stand-in for the terminal-vs-continues distinction in
## _try_enter()'s terrain check -- true for terrain that permanently ends a
## stream on contact (town: instant loss; pool: consumes every stream that
## ever reaches it, forever, so nothing placed further down that path could
## matter; a still-dormant geyser: consumes each beat until it activates).
## Deliberately NOT true for fire, even though a real fire cell does
## consume the first water that reaches it -- that consumption is one-time
## (see _resolve_terrain_contact()'s FIRE branch: the cell reverts to EMPTY
## on the following TERRAIN beat), so every later beat sails straight
## through untouched, same as this preview treating it as open. Since this
## preview is forecasting the eventual steady-state path a solution settles
## into (not literally "what happens to the very first drop"), continuing
## straight through a fire is what actually shows the player where the
## water ultimately goes -- e.g. on Level 12, this is what lets the 4-step
## preview trace all the way from the source through the redirect, through
## the fire, and into the pool, instead of stopping dead at the first fire
## cell it touches. DIRT never reaches this function (both callers filter
## undug dirt out beforehand, same as the real simulation does).
##
## Doesn't touch fires_remaining/pool_fill/geyser_fill/flooded_towns/
## _pending_terrain or fire level_lost/level_won the way the real
## _try_enter() does -- purely a read-only lookup against cell_terrain.
func _predict_would_consume(coord: Vector2i) -> bool:
	var terrain: String = cell_terrain.get(coord, CellState.EMPTY)
	return terrain == CellState.TOWN or terrain == CellState.POOL or terrain == CellState.GEYSER


func _draw() -> void:
	if level_data == null:
		return

	var radius := level_data.grid_radius
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var coord := Vector2i(q, r)
			if in_playable_area(coord):
				_draw_cell(coord)

	# Source markers: every original water_sources cell, plus any geyser
	# that has activated into a new source (see active_geysers). Drawn
	# after the base cells but before the falling water circles, so the
	# marker/arrow read as a fixed part of the board (always visible, even
	# with no water currently there) rather than something that comes and
	# goes with the simulation.
	for source in level_data.water_sources:
		_draw_source_marker(source)
	for source in active_geysers:
		_draw_source_marker(source)
	for source in hydro_source_cells:
		_draw_source_marker(source)

	# Pre-start flow preview (see show_flow_preview) -- drawn after the
	# source markers so its amber arrows sit on top of them, and before the
	# water circles below (there's never any real water yet while this is
	# showing, since it's only true before Start is pressed).
	if show_flow_preview:
		_draw_flow_preview()

	# Live Bomb Catapult aim preview (see active_catapult_aim/
	# set_catapult_aim()) -- drawn after the flow preview so it's never
	# hidden by it (the two can't actually overlap in practice, since
	# aiming a catapult only makes sense after Start when show_flow_preview
	# is already false, but layering it last keeps that assumption from
	# ever silently hiding the aim if it changes).
	_draw_catapult_aim()

	for entry in water_cells:
		_draw_water(entry["coord"])


func _draw_cell(coord: Vector2i) -> void:
	var center := Hex.axial_to_pixel(coord)
	var points := PackedVector2Array()
	for i in range(6):
		points.append(Hex.hex_corner(center, i))

	var color := Color(0.15, 0.15, 0.18) # default empty cell
	var terrain: String = cell_terrain.get(coord, CellState.EMPTY)

	if placed_blocks.has(coord):
		var block: BlockData = block_catalog[placed_blocks[coord]]
		color = block.color
	elif terrain == CellState.FIRE:
		color = Color(0.9, 0.3, 0.1)
	elif terrain == CellState.POOL:
		var filled: bool = (pool_fill.get(coord, 0) as int) >= POOL_BEATS_REQUIRED
		color = Color(0.2, 0.5, 0.9) if filled else Color(0.25, 0.35, 0.45)
	elif terrain == CellState.TOWN:
		# Flooded (water actually reached this town cell -- see
		# _try_enter()'s TOWN branch) shows light blue instead of the usual
		# earthy brown, so the board visibly marks exactly which cell the
		# flood hit.
		color = Color(0.65, 0.85, 0.95) if flooded_towns.has(coord) else Color(0.55, 0.45, 0.35)
	elif terrain == CellState.GEYSER:
		color = Color(0.5, 0.3, 0.6) # dormant purple -- distinct from every other terrain color
	elif terrain == CellState.HYDRO:
		color = Color(0.25, 0.55, 0.75) # steel-blue "structure" color -- distinct from Pool's water-blue and every block color
	elif terrain == CellState.DIRT:
		# "Dig the River": color stages are the ONLY dig-progress feedback
		# (no status bar/counter, by design) -- packed dark earth at 0 taps,
		# progressively lighter/looser at 1 and 2 (see DIRT_COLORS).
		var taps: int = mini(dig_progress.get(coord, 0) as int, DIRT_COLORS.size() - 1)
		color = DIRT_COLORS[taps]
	elif mudslide_cells.has(coord):
		# Opened by a mudslide, not by the player -- wet-mud color, darker
		# than the dug trench, so slide damage stays visible on the board.
		color = MUDSLIDE_COLOR
	elif catapult_blast_cells.has(coord):
		# Opened by a Bomb Catapult blast, not by tapping or a mudslide --
		# scorched reddish-brown, distinct from both of those.
		color = Color(0.35, 0.18, 0.12)
	elif (dig_progress.get(coord, 0) as int) >= DIG_TAPS_REQUIRED:
		# A fully dug-open cell (terrain is EMPTY now, but its dig_progress
		# entry stays at the cap -- see dig_progress's doc comment) keeps a
		# distinct trench color so the carved channel stays readable as
		# "riverbed" against ordinary empty cells.
		color = DUG_TRENCH_COLOR

	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0, 0, 0, 0.4), 1.0)

	# Icon glyph on top of the flat fill color. Placeable blocks use
	# whatever texture is set on their own BlockData resource (data-driven --
	# a new block type gets its icon just by filling in that field, no
	# code change here). Terrain types use the preloaded ICON_* constants
	# above where a glyph exists; Geyser still falls back to its own
	# procedural droplet shape since no SVG has been made for it yet, and
	# Dirt deliberately has no glyph at all (color stages only, see above).
	if placed_blocks.has(coord):
		var block: BlockData = block_catalog[placed_blocks[coord]]
		_draw_icon(center, block.icon)
	elif terrain == CellState.FIRE:
		_draw_icon(center, ICON_FIRE)
	elif terrain == CellState.POOL:
		_draw_icon(center, ICON_POOL)
	elif terrain == CellState.TOWN:
		_draw_icon(center, ICON_TOWN)
	elif terrain == CellState.GEYSER:
		_draw_geyser_icon(center)
	elif terrain == CellState.HYDRO:
		_draw_icon(center, ICON_HYDRO)

	if terrain == CellState.POOL:
		_draw_pool_status_bar(coord)

	if terrain == CellState.GEYSER:
		_draw_status_bar(coord, geyser_fill.get(coord, 0) as int, GEYSER_BEATS_REQUIRED, Color(0.75, 0.35, 0.85))

	if terrain == CellState.HYDRO and hydro_ready_at(coord):
		# Water has reached this plant but it hasn't been activated yet --
		# a bright ring cues the player that a double-tap here will do
		# something, same ring style _draw_source_marker() always shows on
		# a source, just a warmer color so it doesn't read as "already
		# flowing."
		draw_arc(center, Hex.SIZE * 0.55, 0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9), 2.5)


## Draws `texture` centered on `center`, scaled to comfortably fit inside a
## hex tile (SVG icons share a 100x100 viewBox, so this scales relative to
## Hex.SIZE regardless of grid zoom level). No-op if `texture` is null, so
## callers can pass an unset BlockData.icon safely and just fall back to the
## flat fill color with no glyph.
func _draw_icon(center: Vector2, texture: Texture2D, scale_factor: float = 1.5) -> void:
	if texture == null:
		return
	var size := Hex.SIZE * scale_factor
	var rect := Rect2(center.x - size / 2.0, center.y - size / 2.0, size, size)
	draw_texture_rect(texture, rect, false)


## Draws the 4-box status bar above a pool cell once water has connected to
## it at least once (pool_fill > 0). Each box left-to-right represents one
## beat of connection; a box's color flips once that beat has been reached.
## Boxes stay flipped even if the water disconnects later -- progress is
## cumulative, not reset by a gap.
func _draw_pool_status_bar(coord: Vector2i) -> void:
	var connected_beats: int = pool_fill.get(coord, 0) as int
	if connected_beats <= 0:
		return # bar hasn't "popped up" yet -- no connection landed here yet
	_draw_status_bar(coord, connected_beats, POOL_BEATS_REQUIRED, Color(0.2, 0.85, 0.4))


## Shared box-bar renderer for anything that fills up over a fixed number of
## beats (Pool, Geyser, ...) -- `required` boxes above the cell, `filled`
## of them lit in `lit_color`, the rest dark. Used by both
## _draw_pool_status_bar() and the Geyser branch in _draw_cell().
func _draw_status_bar(coord: Vector2i, filled: int, required: int, lit_color: Color) -> void:
	if filled <= 0:
		return # bar hasn't "popped up" yet -- no connection landed here yet

	var center := Hex.axial_to_pixel(coord)
	var box_size := 10.0
	var gap := 4.0
	var total_width: float = required * box_size + (required - 1) * gap
	var start_x: float = center.x - total_width / 2.0
	var bar_y: float = center.y - Hex.SIZE - box_size - 6.0

	for i in range(required):
		var box_x: float = start_x + i * (box_size + gap)
		var rect := Rect2(box_x, bar_y, box_size, box_size)
		var box_color: Color = lit_color if i < filled else Color(0.15, 0.15, 0.18)
		draw_rect(rect, box_color, true)
		draw_rect(rect, Color(0, 0, 0, 0.5), false, 1.0)


## Draws a simple upward-spraying droplet shape (a triangular "spout" plus
## small droplets above it) centered on a dormant geyser cell, so it reads
## as "something will erupt here" distinct from every other terrain icon.
## Kept procedural (no SVG asset exists for Geyser yet -- see the ICON_*
## constants' doc comment above).
func _draw_geyser_icon(center: Vector2) -> void:
	var half := Hex.SIZE * 0.22
	var spout_height := Hex.SIZE * 0.35

	var spout := PackedVector2Array([
		Vector2(center.x - half, center.y + half),
		Vector2(center.x + half, center.y + half),
		Vector2(center.x, center.y + half - spout_height),
	])
	draw_colored_polygon(spout, Color(0.85, 0.7, 0.9))

	draw_circle(Vector2(center.x, center.y - spout_height * 0.9), Hex.SIZE * 0.08, Color(0.85, 0.7, 0.9))
	draw_circle(Vector2(center.x - Hex.SIZE * 0.18, center.y - spout_height * 0.5), Hex.SIZE * 0.06, Color(0.85, 0.7, 0.9))
	draw_circle(Vector2(center.x + Hex.SIZE * 0.18, center.y - spout_height * 0.5), Hex.SIZE * 0.06, Color(0.85, 0.7, 0.9))


## Marks a water source cell (an original level_data.water_sources entry, or
## a geyser that's activated into one) with the river glyph (ICON_SOURCE)
## underneath a bright ring plus a small arrow pointing toward its first
## move -- see _first_move_direction() for how that direction is chosen.
## Drawn every frame so it's always visible regardless of whether water
## currently occupies the cell.
##
## While show_flow_preview is true (pre-start), the small single arrow is
## skipped entirely -- _draw_flow_preview() already draws a (more detailed,
## amber) arrow for this exact first segment, so drawing both would just
## double up two overlapping arrows on the same spot. The ring + source icon
## still draw either way.
func _draw_source_marker(coord: Vector2i) -> void:
	var center := Hex.axial_to_pixel(coord)
	_draw_icon(center, ICON_SOURCE)

	var ring_color := Color(1.0, 1.0, 1.0, 0.9)

	draw_arc(center, Hex.SIZE * 0.55, 0, TAU, 24, ring_color, 2.5)

	if show_flow_preview:
		return

	var first_move := _first_move_direction(coord)
	var target_center := Hex.axial_to_pixel(coord + first_move)
	var dir_vec := (target_center - center).normalized()
	var arrow_start := center + dir_vec * (Hex.SIZE * 0.15)
	var arrow_end := center + dir_vec * (Hex.SIZE * 0.85)
	draw_line(arrow_start, arrow_end, ring_color, 3.0)

	# Arrowhead: two short strokes angled back from the tip.
	var back := -dir_vec * (Hex.SIZE * 0.22)
	var perp := Vector2(-dir_vec.y, dir_vec.x) * (Hex.SIZE * 0.14)
	draw_line(arrow_end, arrow_end + back + perp, ring_color, 3.0)
	draw_line(arrow_end, arrow_end + back - perp, ring_color, 3.0)


## The direction a freshly-spawned drop at `coord` will try first -- always
## Hex.DOWN_LEFT on a "pointy" level (every stream's first move is always
## down-left there, see resolve_water_phase()). On a "flat" level it depends
## on that source's LevelData.source_flow_style: Hex.FLAT_DOWN for
## "straight", Hex.FLAT_DOWN_LEFT for "zigzag" -- matching exactly what
## resolve_water_phase() computes when it actually spawns the stream, so
## this marker never shows a direction the water doesn't really take.
func _first_move_direction(coord: Vector2i) -> Vector2i:
	if level_data.grid_style != "flat":
		return Hex.DOWN_LEFT
	var mode: String = level_data.source_flow_style.get(coord, "straight")
	return Hex.FLAT_DOWN_LEFT if mode == "zigzag" else Hex.FLAT_DOWN


## Draws every arrow returned by _predict_flow_arrows() in amber, fading
## slightly step-by-step (the segment right at the source is brightest, the
## 4th/final segment dimmest) so the chain reads as a directional trail
## rather than a wall of identical arrows. _predict_branch() appends a
## branch's segments in order, so a simple running index approximates this
## fade reasonably even across a Splitter's multiple branches.
func _draw_flow_preview() -> void:
	var arrows := _predict_flow_arrows()
	for i in range(arrows.size()):
		var seg: Dictionary = arrows[i]
		var fade: float = 1.0 - 0.15 * mini(i, 4)
		_draw_flow_arrow(seg["from"], seg["to"], fade)


## Draws one amber preview arrow from the center of `from_coord` to the
## center of `to_coord` -- same line + two-stroke arrowhead style as
## _draw_source_marker()'s own first-move arrow, just colored/alpha'd
## (PREVIEW_ARROW_COLOR, `alpha_scale`) to read as a distinct forecast layer
## rather than a permanent board fixture.
func _draw_flow_arrow(from_coord: Vector2i, to_coord: Vector2i, alpha_scale: float) -> void:
	var from_center := Hex.axial_to_pixel(from_coord)
	var to_center := Hex.axial_to_pixel(to_coord)
	var color := Color(PREVIEW_ARROW_COLOR.r, PREVIEW_ARROW_COLOR.g, PREVIEW_ARROW_COLOR.b, 0.9 * alpha_scale)

	var dir_vec := (to_center - from_center).normalized()
	var arrow_start := from_center + dir_vec * (Hex.SIZE * 0.3)
	var arrow_end := to_center - dir_vec * (Hex.SIZE * 0.3)
	draw_line(arrow_start, arrow_end, color, 3.0)

	# Arrowhead: two short strokes angled back from the tip.
	var back := -dir_vec * (Hex.SIZE * 0.22)
	var perp := Vector2(-dir_vec.y, dir_vec.x) * (Hex.SIZE * 0.14)
	draw_line(arrow_end, arrow_end + back + perp, color, 3.0)
	draw_line(arrow_end, arrow_end + back - perp, color, 3.0)


## Live preview of a charging Bomb Catapult shot (see active_catapult_aim /
## Level.gd's press-and-hold aiming state machine, which calls
## set_catapult_aim() every frame while the player holds). Draws one amber
## arrow from CATAPULT_MIN_RANGE tiles out from the catapult to the current
## charged distance (grows toward CATAPULT_MIN_RANGE + CATAPULT_MAX_EXTRA_RANGE
## the longer the player holds), plus a translucent orange highlight over
## the 7-cell blast cluster centered on the current target (see
## _catapult_blast_area()) so the player can see exactly what will be
## cleared before committing by releasing. No-op whenever no shot is
## currently charging.
func _draw_catapult_aim() -> void:
	if active_catapult_aim.is_empty():
		return
	var origin: Vector2i = active_catapult_aim["coord"]
	var dir: Vector2i = active_catapult_aim["direction"]
	var distance: int = active_catapult_aim["distance"]

	var start_coord := origin + dir * CATAPULT_MIN_RANGE
	var end_coord := origin + dir * distance
	_draw_flow_arrow(start_coord, end_coord, 1.0)

	for cell in _catapult_blast_area(end_coord):
		if not in_playable_area(cell):
			continue
		var center := Hex.axial_to_pixel(cell)
		var points := PackedVector2Array()
		for i in range(6):
			points.append(Hex.hex_corner(center, i))
		draw_colored_polygon(points, Color(1.0, 0.4, 0.15, 0.35))


func _draw_water(coord: Vector2i) -> void:
	var center := Hex.axial_to_pixel(coord)
	draw_circle(center, Hex.SIZE * 0.4, Color(0.3, 0.6, 1.0))
