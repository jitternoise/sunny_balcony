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

## Something happened on the board that the presentation layer may want
## to show or sound: `kind` is one of the EVENT_* names below, `coord` the
## cell it happened at (or Vector2i.ZERO where there is no single cell).
## The board itself never plays a sound -- it is compiled by
## tools/verify_solutions.gd under --script where no autoload exists, so it
## must not name Sfx (see CLAUDE.md); Level.gd listens and does.
##
## Terrain events (fire out, pool fill/full, geyser, a tunnel's first
## water) are held back to the STATUS beat, when the change is also first
## drawn (see resolve_status_phase()), so what is heard lands with what is
## seen.
## Water and mudslides draw on the WATER beat and emit there.
signal board_event(kind: StringName, coord: Vector2i)

const EVENT_WATER_ADVANCED := &"water_advanced" # a WATER beat on which some drop moved; coord is ZERO
const EVENT_MUDSLIDE := &"mudslide"             # dirt collapsed into the channel
const EVENT_FIRE_OUT := &"fire_out"
const EVENT_POOL_FILL := &"pool_fill"           # a beat of connection credited to a lake
const EVENT_POOL_FULL := &"pool_full"           # the beat that filled it
const EVENT_GEYSER := &"geyser"                 # a geyser waking into a source
const EVENT_TUNNEL := &"tunnel"                 # water surfacing at a tunnel exit, once per exit per run

## Terrain events waiting for the STATUS beat -- [kind, coord] pairs.
var _events_to_reveal: Array = []

const CellState := {
	EMPTY = "empty",
	FIRE = "fire",
	POOL = "pool",
	TOWN = "town",
	GEYSER = "geyser",
	DIRT = "dirt",
	HYDRO = "hydro", # one of a Hydro Electric Power Plant's 3 cells -- see hydro_plants
	TUNNEL_IN = "tunnel_in",   # swallows every drop that reaches it -- see tunnel_transit
	TUNNEL_OUT = "tunnel_out", # where they surface: ordinary ground to surface water
}

## Terrain icon textures. Placeable-block icons come from each BlockData
## resource's own `icon` field (data-driven, see BlockData.gd) since new
## block types get their icon by just filling in that field on their
## .tres -- no code change needed. Terrain isn't a Resource per-type, so
## its icons are preloaded here instead. A dormant geyser is the cracked
## stone vent (ICON_GEYSER); once it activates it is drawn as a source with
## the waterfall glyph (see _draw_source_marker()). Dirt deliberately has no
## glyph at all: per the "color stages only" design decision for the dig
## mechanic, an undug/partially-dug hex communicates its state purely
## through its fill color (see _draw_cell()'s DIRT branch).
const ICON_FIRE := preload("res://assets/icons/icon_fire.svg")
const ICON_TOWN := preload("res://assets/icons/icon_town.svg")
const ICON_SOURCE := preload("res://assets/icons/icon_source.svg")
const ICON_HYDRO := preload("res://assets/icons/icon_hydro.svg")
const ICON_GEYSER := preload("res://assets/icons/icon_geyser.svg")
const ICON_TUNNEL_IN := preload("res://assets/icons/icon_tunnel_in.svg")
const ICON_TUNNEL_OUT := preload("res://assets/icons/icon_tunnel_out.svg")

## Animated water tiles. Each sheet is WATER_FRAMES frames of
## WATER_FRAME_PX laid out in a row, and every frame fills a whole hex --
## the art is drawn edge to edge with no rim, so adjacent water cells merge
## into one continuous stream instead of reading as separate blobs.
##
## There are two pairs. "lead" is the aerated, foaming front of the flow
## (see _is_lead_water()); "body" is the settled water behind it. Each
## comes in both grid orientations, because a pointy-top tile laid over a
## flat-top cell would poke its corners out through the cell's flat edges.
const WATER_BODY_POINTY := preload("res://assets/water/water_body_pointy.png")
const WATER_BODY_FLAT := preload("res://assets/water/water_body_flat.png")
const WATER_LEAD_POINTY := preload("res://assets/water/water_lead_pointy.png")
const WATER_LEAD_FLAT := preload("res://assets/water/water_lead_flat.png")
const WATER_FRAMES := 6
const WATER_FRAME_PX := 128.0

## Flipbook rates, deliberately far below the display's refresh: the board
## is only redrawn when a frame index actually changes, so this costs ~12
## redraws a second rather than 60. That matters on the Android hardware
## this ships to, where a per-frame redraw is the expensive part -- see
## claude/open-items.md. The front churns faster than the water behind it.
const WATER_FPS := 8.0
const WATER_LEAD_FPS := 12.0

## Half-texel inset on the region read out of any animation sheet. Frames
## are butted edge to edge, so without this the filtering can pull a sliver
## of the neighbouring frame in at non-integer scales.
const SHEET_REGION_INSET := 0.5

## Animated terrain glyphs. A GLYPH sheet needs only one version -- a
## centred glyph never reaches the cell edge, so it does not care which way
## the hex is turned.
const FIRE_SHEET := preload("res://assets/tiles/fire_sheet.png")

## How a tile's art covers its cell.
##   GLYPH -- a flat-coloured hex with a small centred icon. The original
##            look, and what every terrain type still uses.
##   FILL  -- the art covers the whole hex edge to edge, the way flowing
##            water does. FILL art must ship in both grid orientations,
##            because a pointy-top tile laid over a flat-top cell pokes its
##            corners through the cell's edges; a centred glyph never
##            touches the edge, so GLYPH art needs only one version.
enum TileMode { GLYPH, FILL }

## Every state a cell can resolve to. _resolve_tile_state() is the single
## place terrain precedence lives, and TILE_VISUALS below is the single
## place each state's appearance lives -- between them they replace the
## three parallel if/elif chains this function used to carry (one for the
## fill colour, one for the glyph, one for the overlays), which had drifted
## into 25 branches that all had to be kept in the same order by hand.
##
## States are variants, not types: a pool that is full and a pool that is
## filling are two states, because they look different. That is what keeps
## the table static and lets the dispatch be a dictionary lookup.
const TILE_EMPTY := &"empty"
const TILE_BLOCK := &"block"
const TILE_FIRE := &"fire"
const TILE_POOL := &"pool"
const TILE_POOL_FULL := &"pool_full"
const TILE_TOWN := &"town"
const TILE_TOWN_FLOODED := &"town_flooded"
const TILE_GEYSER := &"geyser"
const TILE_HYDRO := &"hydro"
const TILE_DIRT_0 := &"dirt_0"
const TILE_DIRT_1 := &"dirt_1"
const TILE_DIRT_2 := &"dirt_2"
const TILE_MUDSLIDE := &"mudslide"
const TILE_BLAST := &"blast"
const TILE_TRENCH := &"trench"
const TILE_TUNNEL_IN := &"tunnel_in"
const TILE_TUNNEL_OUT := &"tunnel_out"

## What each state looks like. Keys per entry:
##   fill   -- Color of the hex underneath (always drawn, even under FILL
##             art, so a sheet with transparency still sits on the right
##             ground). TILE_EMPTY's is the one the player can thin with
##             the Options menu's grid opacity slider -- see empty_fill().
##   icon   -- static Texture2D, or null for states that draw no glyph
##   sheet / sheet_flat -- optional animation strip, replacing `icon`. Two
##             entries only where mode is FILL; a GLYPH sheet needs one.
##   frames / fps -- animation shape. fps is quantised to ANIM_TICK_FPS.
##   mode   -- TileMode
## A state with no sheet simply draws its icon, exactly as before, which is
## what lets tile types be converted to animation one at a time.
## Basin (pool) palette. Dry lakebed is a pale, greyish tan so it sits
## apart from the warm browns of dirt (DIRT_COLORS) and a town; the water
## is the old "pool full" blue. The shoreline rims the lake's OUTER edges
## only, so four cells read as one body.
const BASIN_DRY_COLOR := Color(0.70, 0.64, 0.52)
const BASIN_CRACK_COLOR := Color(0.42, 0.36, 0.28, 0.9)
const BASIN_WATER_COLOR := Color(0.2, 0.5, 0.9) # table fill under the water art
const BASIN_SURFACE_COLOR := Color(0.75, 0.9, 1.0, 0.95)
const BASIN_SHORE_COLOR := Color(0.92, 0.86, 0.64, 0.95)
const BASIN_SHORE_WIDTH := 3.0

## Underground tunnel palette (LevelData.tunnel_pairs). Both ends sit on
## the same mossy cave stone -- a cool green-grey, clear of every terrain
## fill here, every block colour and every backdrop ground (the nearest,
## "Badger dusk", is bluer) -- under a limestone arch glyph. The route
## between them is a row of earthy stepping stones, one per underground
## beat of travel, rimmed in the arch's limestone so they read as the same
## structure on a dark empty cell, each with a small chevron pointing the
## way the water runs underground (entrance to exit). A stone lights up
## water-blue while a drop is at that step, rimmed in the water glyphs'
## navy so it still stands out over a frothy surface stream -- see
## _draw_tunnel_routes().
const TUNNEL_FILL_COLOR := Color(0.33, 0.40, 0.36)
const TUNNEL_STONE_COLOR := Color(0.46, 0.34, 0.22)
const TUNNEL_STONE_OUTLINE := Color(0.79, 0.73, 0.62, 0.95)
const TUNNEL_STONE_LIT_COLOR := Color(0.18, 0.56, 0.95)
const TUNNEL_STONE_LIT_OUTLINE := Color(0.04, 0.24, 0.39)
const TUNNEL_STONE_LIT_CHEVRON := Color(0.95, 0.98, 1.0)
const TUNNEL_ROUTE_COLOR := Color(0.79, 0.73, 0.62, 0.35)
const TUNNEL_STONE_RADIUS := 0.22 # of Hex.SIZE
## The exit's pre-Start first-move arrow (_draw_tunnel_exit_arrows()): a
## bold pale arrow in a dark casing that starts past the foot of the arch
## glyph and reaches into the cell the spring falls to, so it never sits on
## the glyph's own water. Drawn after the cells and the pool animals, so a
## neighbouring cell cannot paint over its tip. In Hex.SIZEs from the
## exit's centre.
const TUNNEL_ARROW_COLOR := Color(0.93, 0.97, 1.0)
const TUNNEL_ARROW_CASING := Color(0.04, 0.12, 0.2, 0.95)
const TUNNEL_ARROW_FROM := 0.68
const TUNNEL_ARROW_TO := 1.2

const TILE_VISUALS := {
	TILE_EMPTY: {"fill": Color(0.15, 0.15, 0.18), "icon": null},
	# The first terrain type converted to animation: the flame sways, and an
	# ember lifts off across the middle frames. `icon` stays as the fallback
	# for anything that cannot resolve the sheet.
	TILE_FIRE: {"fill": Color(0.9, 0.3, 0.1), "icon": ICON_FIRE,
		"sheet": FIRE_SHEET, "frames": 6, "fps": 8.0},
	# A pool is a dry, cracked lakebed that visibly fills as beats land --
	# the fill level is per-lake state, so like a block it cannot be a
	# static table entry: _draw_cell() hands both states to _draw_basin().
	# The fills here are what the basin draws over (dry earth, then the
	# full lake) and what anything that only reads the table gets.
	TILE_POOL: {"fill": BASIN_DRY_COLOR, "icon": null},
	TILE_POOL_FULL: {"fill": BASIN_WATER_COLOR, "icon": null},
	# Flooded (water actually reached this town cell -- see _try_enter()'s
	# TOWN branch) shows light blue instead of the usual earthy brown, so
	# the board visibly marks exactly which cell the flood hit.
	TILE_TOWN: {"fill": Color(0.55, 0.45, 0.35), "icon": ICON_TOWN},
	TILE_TOWN_FLOODED: {"fill": Color(0.65, 0.85, 0.95), "icon": ICON_TOWN},
	# Dormant purple -- distinct from every other terrain colour. The vent
	# glyph is centred, so one orientation serves both grids.
	TILE_GEYSER: {"fill": Color(0.5, 0.3, 0.6), "icon": ICON_GEYSER},
	# Steel-blue "structure" colour -- distinct from Pool's water-blue and
	# from every block colour.
	TILE_HYDRO: {"fill": Color(0.25, 0.55, 0.75), "icon": ICON_HYDRO},
	# "Dig the River": colour stages are the ONLY dig-progress feedback (no
	# status bar or counter, by design) -- packed dark earth at 0 taps,
	# progressively lighter and looser at 1 and 2. Dirt deliberately has no
	# glyph at all.
	TILE_DIRT_0: {"fill": DIRT_COLORS[0], "icon": null},
	TILE_DIRT_1: {"fill": DIRT_COLORS[1], "icon": null},
	TILE_DIRT_2: {"fill": DIRT_COLORS[2], "icon": null},
	# Opened by a mudslide rather than by the player -- wet-mud colour,
	# darker than the dug trench, so slide damage stays visible.
	TILE_MUDSLIDE: {"fill": MUDSLIDE_COLOR, "icon": null},
	# Opened by a Bomb Catapult blast -- scorched reddish-brown, distinct
	# from both a mudslide and a dug trench.
	TILE_BLAST: {"fill": Color(0.35, 0.18, 0.12), "icon": null},
	# A fully dug-open cell (terrain is EMPTY now, but its dig_progress
	# entry stays at the cap -- see dig_progress) keeps a distinct trench
	# colour so the carved channel stays readable as riverbed.
	TILE_TRENCH: {"fill": DUG_TRENCH_COLOR, "icon": null},
	# Underground tunnel ends -- one cave-stone fill, two glyphs: the arch
	# with chevrons going in, and the arch with water spilling out.
	TILE_TUNNEL_IN: {"fill": TUNNEL_FILL_COLOR, "icon": ICON_TUNNEL_IN},
	TILE_TUNNEL_OUT: {"fill": TUNNEL_FILL_COLOR, "icon": ICON_TUNNEL_OUT},
}

## The board's single animation heartbeat. Every animated tile derives its
## frame from this one counter rather than from its own clock: a redraw
## repaints the WHOLE board, so independent rates would interleave their
## frame changes and multiply the redraws. Ticking once here and letting
## slower tiles repeat frames caps the board at ANIM_TICK_FPS redraws a
## second no matter how many tile types animate -- which is the number that
## matters on the Android hardware this ships to.
const ANIM_TICK_FPS := 12.0

## How much of a hex a centred GLYPH covers. Shared by _draw_icon() and the
## animated-glyph path so a converted tile type lands at exactly the size
## its static icon used to.
const ICON_SCALE := 1.5
## The source's waterfall ledge is full-cell art: its rock shelf runs the
## width of the hex's flat middle band, so it draws bigger than a glyph.
const SOURCE_ICON_SCALE := 1.75

## The pool's animal (Characters) lives IN its lake: a square sprite the
## size of a glyph, standing on the lakebed of the lake's top cells, so the
## dry pool it lies in is its own and the water rises to it -- lying on the
## cracked mud, head up, standing, at the water's edge, drinking, one pose
## per beat of pool_fill. Nothing outside the lake is ever covered, and
## the lake's own cells draw no glyph. The art keeps its feet on a baseline
## this far down its frame (tools/gen_characters.py writes every pose to
## that line); the feet go CHARACTER_BED_DEPTH Hex.SIZEs below the lake's
## top corner, the middle of the top cells' band on either grid. Two
## animals at one pool (the Jamboree band) each draw at the pair scale.
const CHARACTER_SCALE := ICON_SCALE
const CHARACTER_BASELINE := 0.94
const CHARACTER_BED_DEPTH := 0.95
const CHARACTER_PAIR_SCALE := 0.8
const CHARACTER_PAIR_GAP := 0.05

## Every pool needs exactly this many beats of water connection to finish.
## Each beat is one pose of the pool's animal (see _draw_pool_characters()).
## Fixed for every pool on every level -- not configurable per level/pool
## (see LevelData.pool_targets doc comment).
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

## Fixed level furniture (LevelData.preset_blocks) is drawn with a second,
## inset outline inside its normal hex border -- see _draw_cell(). A preset
## Splitter renders identically to one the player placed themselves, so
## without this there's nothing on the board saying "this one is bolted
## down, don't waste a tap trying to pick it up." INSET is the fraction of
## the way out to the hex corners the inner ring sits at.
const PRESET_OUTLINE_COLOR := Color(1.0, 0.95, 0.8, 0.85)
const PRESET_OUTLINE_INSET := 0.72

## Tutorial hint outline (LevelData.hint_cells): a dashed ring just inside
## the cell edge, in the same amber as the flow-preview arrows so it reads
## as "guidance" rather than as terrain. Hidden once anything is placed or
## queued on the cell -- the hint has done its job.
const HINT_OUTLINE_COLOR := Color(1.0, 0.82, 0.2, 0.95)
const HINT_OUTLINE_INSET := 0.82
const HINT_OUTLINE_WIDTH := 4.0
const HINT_DASH_PX := 12.0

## A placement that's been queued but hasn't reached its PLACEMENT beat yet
## is drawn as a ghost of the block at this alpha, and a block queued for
## pickup fades toward the empty-cell colour -- see _draw_cell(). Before
## this, a tap made mid-measure changed nothing on screen for up to a full
## measure, which read as the tap having been dropped.
const PENDING_PLACEMENT_ALPHA := 0.45
const PENDING_REMOVAL_COLOR := Color(0.15, 0.15, 0.18, 0.55)

## Mudslide mechanic: once a water drop has spent this many consecutive
## WATER beats pressing against undug dirt (see dirt_stall /
## _note_dirt_stall()), the dirt gives way on its own -- a chain of
## MUDSLIDE_COLLAPSE_TILES dirt tiles collapses downward from the blocking
## tile (see _trigger_mudslide()), opening a path the PLAYER didn't choose.
## Collapsed tiles are fully open (water flows through immediately) and
## drawn in MUDSLIDE_COLOR, distinct from the player-dug trench color, so
## the board tells the story of where the river forced its own way. These
## are WATER beats, and there is one per measure (see _note_dirt_stall()),
## so 10 of them is ten measures = 12 s of standing water at the current
## tempo -- not the "~3 s" an earlier comment claimed (handheld-audit.md
## finding 32). Enough time to finish a tile you're already digging, a
## real threat if you fall behind.
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

## Direction arrows drawn on every placed Diverter/Splitter (see
## _draw_block_direction_arrows()), the same "this is where your water is
## about to go" cue a dormant geyser already gets. A block's arrow is
## tinted from that block's OWN color, lightened this far toward white so
## it always reads against its own fill whatever color a level author gave
## the block -- keeping the Diverter-Left/Diverter-Right/Splitter identity
## visible rather than painting every arrow the same neutral shade.
const BLOCK_ARROW_WHITEN := 0.6
const BLOCK_ARROW_ALPHA := 0.9

## Screen-layout rules (see _fit_hex_layout()): the hex grid fills this
## fraction of the screen's width, leaving an equal margin on each side.
## Grid tile size is solved for per level so this holds regardless of
## grid_radius -- a small level and a big level both fill 90% of the
## width, just with different tile sizes. The one exception is a board
## that fits the band between the HUD and the inventory bar on a plain
## screen but not once a cutout and a gesture bar have eaten into that
## band: it shrinks to fit the inset band instead of scrolling, and is
## then narrower than this (see _fit_hex_layout()).
const GRID_WIDTH_FRACTION := 0.9

## Where the grid's top edge sits. This clears the HUD's top button row,
## which Level.tscn anchors to the top at a fixed 96px bottom edge, so it
## is an absolute distance and NOT a fraction of viewport height: under
## stretch/aspect=expand a taller device grows the viewport, and a
## fraction would push the grid further from a button row that has not
## moved. The row ends at y=136 (40px inset + a 96px button, raised from 56
## so the buttons clear the 48dp Android / 44pt iOS minimum touch target on
## a 360dp-wide phone) + 16px breathing room.
const GRID_TOP_MARGIN_PX := 152.0

## Level-design convention (not enforced here, but relied on by
## _fit_hex_layout()'s sizing so tiles stay reasonably large): a grid
## should never be more than this many tiles wide, i.e. grid_radius should
## not exceed floor((MAX_GRID_WIDTH_HEXES - 1) / 2) = 4.
const MAX_GRID_WIDTH_HEXES := 9

## Reserved screen space below the grid's available area for the bottom HUD,
## so scrolling can't hide the grid's bottom edge behind it. Matches the
## topmost bottom-anchored control in Level.tscn -- BudgetLabel's offset_top,
## which sits just above InventoryBar -- so keep the two in step. 174 for the
## label (itself pushed up by the inventory bar growing to a 96px touch
## target) + 16px breathing room.
##
## Note this only changes how far a grid can SCROLL, never how big its tiles
## are: _fit_hex_layout() solves tile size from the viewport's WIDTH. (The
## single exception is the inset shrink described at GRID_WIDTH_FRACTION,
## and even that only ever makes a tile smaller than the width-solved
## size, never larger.)
const BOTTOM_UI_RESERVED_PX := 190.0

## position.y when the grid is scrolled all the way to the top (its natural
## resting position, set by _fit_hex_layout()). Level.gd clamps manual
## vertical scroll drags between this and (top_position_y - max_scroll_down).
var top_position_y: float = 0.0

## How much further (in px) the board can move upward (decreasing
## position.y) to reveal the bottom of a grid taller than one screen's
## available vertical space. 0 if the whole grid already fits on screen.
var max_scroll_down: float = 0.0

## The grid's bounding box in this node's OWN coordinates, as solved by
## _fit_hex_layout() -- add `position` for viewport coordinates. Kept so the
## layout can be checked (tests/VerifySafeArea.gd) without re-deriving the
## hex maths, and so anything that needs the board's extent has one answer
## to read rather than its own copy of the corner walk.
var grid_bounds := Rect2()

var level_data: LevelData
var block_catalog: Dictionary = {} # block id (String) -> BlockData

var cell_terrain: Dictionary = {}  # Vector2i -> String (CellState)
var placed_blocks: Dictionary = {} # Vector2i -> String block id

## Vector2i -> Vector2i. Every cell covered by a block mapped back to that
## block's ANCHOR -- the cell the player actually tapped (or, for a preset,
## the coordinate listed in LevelData.preset_blocks). A single-cell block
## maps its one cell to itself; a 2-wide Wall maps both of its cells to the
## same anchor. This is what lets remove_block(), the preset guard and the
## preset outline all start from EITHER half of a block and act on the
## whole of it. Covers pending placements as well as committed ones, so a
## queued 2-wide placement can be cancelled from either half too. Cleared
## on setup()/retry and rebuilt as blocks are placed and removed.
var block_anchors: Dictionary = {}

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
## it is the pool's animal's pose (0 lying by the dry basin .. 4 drinking),
## and the animal never goes back to lying if the water disconnects later
## (progress is preserved, not reset by a disconnect).
var pool_fill: Dictionary = {}

## The pool animal's art for this level's band: one Array[Texture2D] of
## Characters.POSES textures per animal at the pool (one, or two for the
## Jamboree band). Filled by setup(); empty means no animal is drawn.
var _character_poses: Array = []
var fires_remaining: int = 0

## Vector2i -> Vector2i. Every cell of every lake mapped to that lake's
## anchor (its pool_targets key); the anchor maps to itself. This is what
## makes a four-cell pool one target: pool_fill is keyed by anchor, and any
## cell's contact is credited there -- see _resolve_terrain_contact().
var lake_anchor: Dictionary = {}

## Anchors credited during the CURRENT terrain beat. Cleared each beat by
## resolve_terrain_phase(). A lake fills by one per beat however many of its
## cells are wet -- a Splitter feeding two cells of one lake must not fill it
## twice as fast, or "four beats of connection" stops meaning anything.
var _lakes_credited_this_beat: Dictionary = {}

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

## Water flipbook clock. Advanced in _process(), which only calls
## queue_redraw() on the frames where an index actually changes -- and not
## at all when there is no water on the board, so a level sits idle during
## planning exactly as it did before this animation existed.
var _anim_time: float = 0.0
var _anim_tick: int = 0

## True when this level has at least one animated tile state on the board,
## so a level built entirely from static art never starts the heartbeat.
## Recomputed in setup().
var _has_animated_tiles: bool = false

## Every playable cell on this level, resolved once in setup(). _draw()
## used to walk the grid's bounding square and test each coordinate --
## 101 x 101 = 10,201 tests to draw ~500 cells on level 22's corridor.
## Harmless at one redraw per measure; not harmless now that the board
## repaints on an animation tick.
var _playable_cells: Array[Vector2i] = []

## The lowest playable row (largest r). On a plain hexagon this is
## grid_radius; a level that blocks its bottom rows outright -- the 6-wide
## column levels carve a radius-5 hexagon down to rows -4..4 -- ends here
## instead, and falling past it is the edge loss. Set by
## _cache_playable_cells(). Pointy grids only; a flat grid's loss test is
## _cube_distance() against grid_radius (see _advance_water_flat()).
var bottom_row: int = 0

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

## Vector2i -> true. Coordinates whose PRESET block (LevelData.preset_blocks)
## has been consumed by firing it -- only a Bomb Catapult can do this today
## (see fire_catapult()). remove_block()'s preset guard skips these: the
## preset that made the cell non-removable isn't on the board anymore, and
## without this exception a block later placed on a spent preset catapult's
## now-empty cell could never be picked up again -- it was silently lost
## from inventory for the rest of the attempt. Cleared on setup()/retry,
## which also restores the preset itself.
var _spent_preset_cells: Dictionary = {}

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

## How many WATER beats this run has resolved -- incremented at the start
## of every resolve_water_phase() that runs, reset to 0 by setup(). The
## clock the underground tunnels keep time by (see tunnel_transit).
var water_beat: int = 0

## Drops travelling underground right now, one entry per (entrance, due)
## pair: {"entrance": Vector2i, "exit": Vector2i, "entered": int (the
## water_beat it went in on), "due": int (the water_beat it surfaces on)}.
##
## THE TIMING RULE (LevelData.tunnel_pairs). "The standard flow rate" is
## one cell per WATER beat, and the underground route is the straight
## line, so with d = the hex distance between entrance E and exit X:
##
##   - a drop that would enter E on WATER beat t -- by natural fall, by a
##     Diverter/Splitter redirect, on a pointy or a flat grid -- leaves the
##     surface on beat t. Every one of those paths ends in _try_enter(),
##     which records the transit here and refuses the drop, so it is not
##     in water_cells afterwards;
##   - at the end of WATER beat t + d it is placed ON X, merging with
##     anything already there -- exactly where a surface drop moving one
##     cell per beat would be after d moves;
##   - from beat t + d + 1 it falls from X by the spring rule, exactly a
##     water source's: DOWN_LEFT first then the zigzag on a pointy grid,
##     "straight" (Hex.FLAT_DOWN) on a flat one, like an active geyser.
##
## Deduped on (entrance, due): two drops into one mouth on one beat are one
## drop underground, the same way two streams into one cell merge on the
## surface (_add_water()). Throughput is otherwise unlimited -- a mouth
## fed every beat keeps d drops in flight -- and nothing on the surface,
## a Wall included, touches the route. Cleared by setup().
##
## The EXIT is ordinary ground to surface water, enterable the way a
## source's own cell is: a stream that happens to cross it passes through
## (merging with whatever surfaces there), and it is neither solid nor a
## second mouth. Solid, it would be a wall the player never placed and
## cannot move; swallowing, it would be an entrance leading nowhere. Only
## the block ban (_footprint_placeable()) sets it apart -- a Wall parked
## on a spring would bury the tunnel for good.
var tunnel_transit: Array[Dictionary] = []

## Tunnel exits water has already surfaced at this run -- each one sounds
## EVENT_TUNNEL once, the first time, like a geyser waking. Cleared by
## setup().
var _tunnel_exits_opened: Dictionary = {}

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

## This redraw's flow-preview segments, and the set of cells any of them
## leaves FROM. Both are rebuilt once per _draw() (before the cell loop)
## and are empty whenever show_flow_preview is false.
##
## Computing the forecast once per frame rather than once per consumer
## matters for two reasons. _draw_flow_preview() and
## _draw_block_direction_arrows() both need it, and on a board like level
## 22's radius-50 grid, re-running _predict_flow_arrows() inside the
## per-cell loop would mean thousands of forecast walks per frame. And a
## Diverter/Splitter that the preview ALREADY draws an arrow out of must
## not also draw its own -- two arrows on the exact same segment, one
## amber and one tinted, reads as a rendering bug. `_preview_from_cells`
## is what lets _draw_block_direction_arrows() check that cheaply. It's a
## set of "from" coords rather than of segments because a Splitter's two
## outputs are either both covered by the preview or both not: the
## forecast branches at the block itself, so it never draws one of a
## splitter's arrows without the other.
var _preview_arrows: Array = []
var _preview_from_cells: Dictionary = {}

## False until Level.gd's Start button is pressed (it sets this true in
## _on_start_pressed(); setup() resets it to false on every load/retry).
## While false there is no beat cycle running at all -- no PLACEMENT beat
## is ever coming -- so place_block()/remove_block() commit straight to
## placed_blocks instead of queueing into pending_placements/
## pending_removals. Without this, a block placed during the planning
## phase sat invisibly in the pending queue: _draw_cell() never drew it
## and the pre-start flow preview (which reads placed_blocks) ignored it,
## so the arrows didn't respond to planning at all -- and a Bomb Catapult
## couldn't be fired pre-start either, since fire_catapult() only knows
## about committed blocks. Post-Start behavior is completely unchanged:
## buffering resumes the instant Start is tapped, and since beat 1 of
## measure 1 is PLACEMENT (which already ran before the first WATER beat),
## every existing level's simulation trace is identical either way.
var started: bool = false

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


## The Settings autoload, found at runtime rather than named. This script
## must never spell out an autoload: the solution verifier
## (tools/verify_solutions.gd) compiles it under --script, where there are
## no autoloads and a bare `Settings` is "Identifier not found" -- which,
## being a compile error, hangs the run instead of failing it. Null there,
## and in any harness that builds a board outside the tree; the grid then
## draws fully opaque.
var _settings: Node = null


func _ready() -> void:
	# The Options menu opens over a paused level, so the grid opacity
	# slider has to show on the board behind it as it moves. The heartbeat
	# is off while a popup covers the board (Level._update_board_animation),
	# so nothing else would repaint it until the menu closed.
	_settings = get_node_or_null("/root/Settings")
	if _settings != null:
		_settings.grid_opacity_changed.connect(_on_grid_opacity_changed)


func _on_grid_opacity_changed(_value: float) -> void:
	queue_redraw()


## The base colour of a cell with nothing on it, with the player's grid
## opacity (Settings.grid_opacity) applied. Only the EMPTY state fades:
## terrain, blocks and water keep their table colours whatever the slider
## says, since those are what the player reads the level from.
func empty_fill() -> Color:
	var fill: Color = TILE_VISUALS[TILE_EMPTY]["fill"]
	if _settings != null:
		fill.a *= _settings.grid_opacity
	return fill


func setup(data: LevelData, blocks: Dictionary) -> void:
	level_data = data
	block_catalog = blocks
	_character_poses = Characters.poses_for_level(data.level_id)
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
	block_anchors.clear()
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
	_playable_cells.clear()
	_events_to_reveal.clear()
	hydro_plants.clear()
	hydro_cell_to_anchor.clear()
	hydro_source_cells.clear()
	catapult_blast_cells.clear()
	_spent_preset_cells.clear()
	active_catapult_aim = {}
	_preview_arrows.clear()
	_preview_from_cells.clear()
	water_cells.clear()
	water_beat = 0
	tunnel_transit.clear()
	_tunnel_exits_opened.clear()
	flooded_towns.clear()
	game_over = false
	lose_reason = ""
	show_flow_preview = true
	started = false

	for coord in data.fire_cells:
		cell_terrain[coord] = CellState.FIRE
	fires_remaining = data.fire_cells.size()

	lake_anchor.clear()
	_lakes_credited_this_beat.clear()
	for coord in data.pool_targets.keys():
		cell_terrain[coord] = CellState.POOL
		pool_fill[coord] = 0
		lake_anchor[coord] = coord
		# The rest of the lake: pool terrain too, credited to this anchor.
		for extra in data.lake_cells.get(coord, []):
			cell_terrain[extra] = CellState.POOL
			lake_anchor[extra] = coord

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

	# Underground tunnels: both ends are terrain, neither takes a block
	# (_footprint_placeable()). The entrance swallows water (_try_enter());
	# the exit is ordinary ground that water also surfaces on.
	for entrance in data.tunnel_pairs.keys():
		cell_terrain[entrance] = CellState.TUNNEL_IN
		cell_terrain[data.tunnel_pairs[entrance]] = CellState.TUNNEL_OUT

	# Preset blocks (LevelData.preset_blocks): committed straight into
	# placed_blocks at setup, so they're live from the very first beat --
	# no PLACEMENT-beat queueing, no inventory/budget interaction. They
	# render and behave exactly like player-placed blocks of the same id
	# (same icon, same _resolve_block_targets() behavior), but are FIXED
	# terrain: remove_block() refuses to pick one up. Retry naturally
	# restores them, since this setup() runs again.
	for coord in data.preset_blocks.keys():
		var preset_id: String = data.preset_blocks[coord]
		# A preset of a multi-cell type (e.g. a preplaced Wall) occupies
		# its full footprint, anchored at the listed coordinate -- always
		# the UNMIRRORED one, since a level author picks the exact cells
		# rather than relying on place_block()'s fallback. Authoring note:
		# make sure every cell of that footprint is inside the playable
		# area and clear of other terrain, or the block will silently
		# overhang into cells that never render.
		for cell in block_footprint(coord, preset_id):
			placed_blocks[cell] = preset_id
			block_anchors[cell] = coord

	_fit_hex_layout()
	_cache_playable_cells()
	queue_redraw()

	# Under stretch/aspect=expand the logical viewport is no longer a fixed
	# 720x1280 -- it takes the device's aspect, and can change again on a
	# desktop window resize. Re-fit when it does. Connected here rather
	# than in _ready() because _fit_hex_layout() needs level_data.
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)


## Resolves the playable cells once, so _draw() can iterate them directly
## instead of testing every coordinate in the grid's bounding square on
## every repaint. Also notes whether any of this level's states animate, so
## a board built entirely from static art never starts the heartbeat.
##
## Safe to compute once: in_playable_area() reads only grid_radius,
## blocked_cells and corridor_half_width, none of which change during play.
func _cache_playable_cells() -> void:
	_playable_cells.clear()
	var radius: int = level_data.grid_radius
	bottom_row = -radius
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var coord := Vector2i(q, r)
			if in_playable_area(coord):
				_playable_cells.append(coord)
				bottom_row = maxi(bottom_row, r)

	_has_animated_tiles = false
	for coord in _playable_cells:
		var visual := _tile_visual(coord, _resolve_tile_state(coord))
		if _tile_sheet(visual) != null:
			_has_animated_tiles = true
			break


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


## Re-solves the grid's size and resting position for the current viewport.
## Resets vertical scroll to the top -- a reshaped viewport invalidates the
## old scroll offset anyway, since max_scroll_down is recomputed here.
func _on_viewport_resized() -> void:
	if level_data == null:
		return
	_fit_hex_layout()
	queue_redraw()


## Solves for the tile size (Hex.SIZE) that makes this level's grid exactly
## GRID_WIDTH_FRACTION of the viewport's width, then positions this node
## (self.position) so the grid sits centred between the side margins and
## vertically centred in the band between the HUD and the inventory bar --
## or, for a grid taller than that band, GRID_TOP_MARGIN_PX down with
## max_scroll_down telling Level.gd how far the player can drag it up to
## see its bottom.
##
## A cutout or gesture bar never turns a fitting board into a scrolling
## one: a grid that fits the band on a plain screen but overflows the
## inset band gets its tiles shrunk until it fits again. Side insets
## already shrink the board rather than sliding it under the cutout; this
## is the same rule for the top and bottom. A grid that scrolls even
## without insets (a corridor level) is left at full size and scrolls a
## little further.
func _fit_hex_layout() -> void:
	var viewport_size := _viewport_size()

	# Everything below is measured against the safe area rather than the
	# raw viewport: with no letterbox bars left to hide them, a cutout eats
	# into the top of the board and a gesture bar into the bottom. On a
	# device with neither -- and on every desktop -- these are all zero and
	# the layout is the plain viewport one.
	var safe := SafeArea.insets(get_viewport())
	var usable_width: float = viewport_size.x - safe.x - safe.z

	# Solved from the width that is actually there, NOT from the project's
	# 720px design width. Under stretch/aspect=expand a wider-than-9:16
	# screen -- a 4:3 tablet, an unfolded foldable -- grows the logical
	# viewport sideways; capping the grid at the design width would spend
	# that on empty margin either side of a board that stayed the same
	# size. The board fills the screen at every aspect instead, and the
	# tiles get bigger rather than the margins. Expand never makes the
	# viewport NARROWER than the design width, so this can only ever grow
	# a tile, never shrink one.
	var target_width := usable_width * GRID_WIDTH_FRACTION

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
	var height_at_size_1 := max_y - min_y
	var computed_size := target_width / width_at_size_1 if width_at_size_1 > 0.0 else 1.0

	# The band the grid can occupy: below the HUD's top row, above the
	# inventory bar, inside any cutout or gesture-bar inset. plain_band is
	# the same band on a screen with neither -- what the level was authored
	# against, since every tutorial and every level in 1-50 was sized to
	# fit it without scrolling.
	var top_margin: float = safe.y + GRID_TOP_MARGIN_PX
	var plain_band: float = viewport_size.y - GRID_TOP_MARGIN_PX - BOTTOM_UI_RESERVED_PX
	var available_height: float = plain_band - safe.y - safe.w

	# A board that fits the plain band but not the inset one shrinks to
	# fit rather than scrolling: a tutorial with its lake pushed under the
	# gesture bar reads as a layout bug, and its tiles are the largest in
	# the game (a 4-wide column gets ~1.5x the tile of a 6-wide one), so
	# they have room to give. A board that scrolls anyway keeps the width-
	# solved size -- a corridor's tiles are what the player taps -- and
	# scrolls a little further.
	var width_solved_height := height_at_size_1 * computed_size
	var fits_plain_band := width_solved_height <= plain_band
	var overflows_inset_band := width_solved_height > available_height and available_height > 0.0
	if fits_plain_band and overflows_inset_band:
		computed_size = available_height / height_at_size_1
	Hex.SIZE = computed_size

	var grid_left := min_x * computed_size
	var grid_top := min_y * computed_size
	var grid_bottom := max_y * computed_size
	var grid_width := width_at_size_1 * computed_size
	var grid_height := grid_bottom - grid_top
	grid_bounds = Rect2(grid_left, grid_top, grid_width, grid_height)

	# Centred in the safe area: the same breathing room either side at
	# every viewport width, measured from the cutout rather than the screen
	# edge. Measured from the grid's own width, not target_width, so a
	# board the inset shrink narrowed stays centred too.
	var left_margin: float = safe.x + (usable_width - grid_width) / 2.0

	position.x = left_margin - grid_left

	# A shrunk board fits exactly, give or take a floating-point ulp; snap
	# that to zero so nothing downstream sees a sub-pixel scroll and treats
	# the board as an overflowing one.
	max_scroll_down = maxf(0.0, grid_height - available_height)
	if max_scroll_down < 0.01:
		max_scroll_down = 0.0

	# A grid that fits is centred in that band rather than pinned to its
	# top. Pinned, a radius-3 tutorial board sat under the HUD with the
	# lower half of the screen empty grass, which read as a layout bug (and
	# was filed as one -- handheld-audit.md #18). A grid taller than the
	# band still starts at the top, since the player scrolls it up to see
	# the rest and the top is where the water starts.
	var slack: float = maxf(0.0, available_height - grid_height)
	top_position_y = top_margin - grid_top + slack / 2.0
	position.y = top_position_y


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
## dirt cells can be dug -- but ONLY once the level is running: dig() is a
## no-op before Start (see `started`). Digging is a during-the-run action;
## the whole feel of "tap the channel forward" depends on racing water
## that's already moving, and letting the board be fully pre-carved during
## the planning phase turned a dig level into an ordinary layout puzzle
## with the timing pressure removed. It also made the mudslide threat
## (MUDSLIDE_BEATS_REQUIRED) almost impossible to trigger.
func dig(coord: Vector2i) -> bool:
	if game_over:
		return false
	if not started:
		return false # planning phase -- dirt isn't diggable yet, see above
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

	# A PRESET catapult stays listed in level_data.preset_blocks forever,
	# which is what normally makes its cell non-removable -- record that
	# this one is spent so remove_block() stops guarding a block that
	# isn't on the board anymore (see _spent_preset_cells).
	var anchor := block_anchor_at(catapult_coord)
	if level_data.preset_blocks.has(anchor):
		_spent_preset_cells[anchor] = true
	for cell in _cells_of_anchor(anchor):
		placed_blocks.erase(cell)
		block_anchors.erase(cell)
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


## Every cell a block of type `block_id` covers when anchored at `anchor`,
## anchor first (see BlockData.footprint_offsets). `mirrored` negates each
## offset's x, which is how place_block() retries a 2-wide block leftward
## when there's no room to its right. A block with no footprint_offsets --
## i.e. every type except the Wall today -- always returns just [anchor],
## which is what keeps all the single-cell behaviour identical.
func block_footprint(anchor: Vector2i, block_id: String, mirrored: bool = false) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [anchor]
	var block: BlockData = block_catalog.get(block_id, null)
	if block == null:
		return cells
	for offset in block.footprint_offsets:
		cells.append(anchor + (Vector2i(-offset.x, offset.y) if mirrored else offset))
	return cells


## The anchor cell of whatever block covers `coord` -- or `coord` itself
## when no block does, or when the block is an ordinary single-cell one.
## Callers holding one arbitrary cell (a tap, a preset lookup) use this to
## get back to the whole block. See block_anchors.
func block_anchor_at(coord: Vector2i) -> Vector2i:
	return block_anchors.get(coord, coord)


## Every cell currently grouped under `anchor` (committed or pending),
## falling back to just [anchor] if nothing is grouped -- so a caller can
## treat single-cell and multi-cell blocks the same way. Linear in the
## number of occupied cells, which is tiny on every real board.
func _cells_of_anchor(anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in block_anchors.keys():
		if block_anchors[cell] == anchor:
			cells.append(cell)
	if cells.is_empty():
		cells.append(anchor)
	return cells


## True if EVERY cell of a candidate footprint can legally take a block
## right now. A multi-cell block is all-or-nothing: half of a Wall hanging
## off the playable area, or overlapping a fire, is not a placement.
##
## Rule: player-placeable tiles can never sit ON a water source -- an
## original level_data.water_sources cell, a geyser that has activated into
## a source, or one of an ACTIVATED Hydro Plant's 3 cells (those revert to
## EMPTY terrain the moment they start spawning water, so the HYDRO terrain
## check below stops covering them). Level design must respect a companion
## authoring rule: no PREPLACED level tile -- fire/pool/town/geyser/dirt/
## preset block -- within 2 rows vertically of a starting source; that one
## is enforced at authoring time, not here. Levels 1/10/11/12 were relaid
## when this rule landed: their old documented solutions placed a diverter
## directly on the source, which is exactly what this forbids -- their new
## solutions use a Wall on the source's first landing cell instead (see
## README).
func _footprint_placeable(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if not in_playable_area(cell):
			return false
		if level_data.water_sources.has(cell) or active_geysers.has(cell) or hydro_source_cells.has(cell):
			return false
		if placed_blocks.has(cell) or pending_placements.has(cell):
			return false
		if pending_removals.has(cell):
			return false # a pickup of this exact cell is already queued this beat
		var terrain: String = cell_terrain.get(cell, CellState.EMPTY)
		if terrain == CellState.FIRE or terrain == CellState.POOL or terrain == CellState.TOWN or terrain == CellState.GEYSER or terrain == CellState.DIRT or terrain == CellState.HYDRO:
			return false
		if terrain == CellState.TUNNEL_IN or terrain == CellState.TUNNEL_OUT:
			return false
	return true


## Queues a block placement. Validated and reserved (inventory/budget
## decremented) immediately, so the inventory bar reflects availability
## right away, but NOT added to placed_blocks -- and so not affecting the
## simulation -- until the next PLACEMENT beat commits it via
## resolve_placement_phase(). See Level.gd's beat-cycle doc comment.
##
## The exception is pre-Start (see `started`): with no beat cycle running,
## no PLACEMENT beat is ever coming, so the block is committed to
## placed_blocks straight away instead. That's what makes a layout planned
## before the water starts actually visible on the board and reflected in
## the flow preview -- and what lets a Bomb Catapult be fired during
## planning rather than only after Start.
func place_block(coord: Vector2i, block_id: String) -> bool:
	if game_over:
		return false
	if use_block_budget:
		if block_budget_remaining <= 0:
			return false
	elif not inventory.has(block_id) or inventory[block_id] <= 0:
		return false

	# A multi-cell block (BlockData.footprint_offsets -- today just the
	# 2-wide Wall) prefers its right-hand cell, but falls back to the
	# mirrored, leftward footprint so one can still be placed hard against
	# the right-hand wall of a corridor. For a single-cell block both
	# candidates are the same one cell, so this is exactly the old
	# behaviour. Whichever footprint wins is all-or-nothing -- see
	# _footprint_placeable().
	var cells := block_footprint(coord, block_id)
	if not _footprint_placeable(cells):
		cells = block_footprint(coord, block_id, true)
		if not _footprint_placeable(cells):
			return false

	# Pre-Start there is no beat cycle and so no PLACEMENT beat to commit
	# this on -- it lands on the board immediately instead, which is what
	# makes planning visible (and a Bomb Catapult firable) before Start.
	# See the `started` doc comment. After Start it queues exactly as
	# before, and _draw_cell() ghosts the queued cells in the meantime.
	#
	# Every cell of the footprint gets its own placed_blocks entry (so the
	# water simulation needs no concept of multi-cell blocks at all) plus a
	# block_anchors entry pointing back at `coord`, which is what makes the
	# whole thing removable as one unit. The inventory/budget cost is paid
	# ONCE, no matter how many cells it covers.
	for cell in cells:
		block_anchors[cell] = coord
		if started:
			pending_placements[cell] = block_id
		else:
			placed_blocks[cell] = block_id
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
## simulation while water is actively ticking, same as before. Pre-Start
## the removal itself is immediate too, for the same reason placement is --
## see place_block() above and the `started` doc comment.
func remove_block(coord: Vector2i) -> bool:
	if game_over:
		return false

	# Tapping either half of a multi-cell block picks up the WHOLE block,
	# so everything below works from the anchor rather than the tapped
	# cell -- see block_anchors/block_anchor_at().
	var anchor := block_anchor_at(coord)

	# Preset blocks are fixed level terrain (see LevelData.preset_blocks /
	# setup() above) -- tapping one does nothing, same as tapping a fire or
	# pool. Checked before anything else so a preset can never be picked
	# up, refunded, or queued for removal.
	# ...unless that preset has already been consumed by firing it (a Bomb
	# Catapult -- see _spent_preset_cells), in which case whatever sits on
	# the cell now is an ordinary player-placed block and has to be
	# pick-up-able again like any other.
	if level_data.preset_blocks.has(anchor) and not _spent_preset_cells.has(anchor):
		return false

	if pending_placements.has(anchor):
		var pending_id: String = pending_placements[anchor]
		# Cancel every cell the queued placement reserved, and refund the
		# single inventory slot it cost -- never one refund per cell.
		for cell in _cells_of_anchor(anchor):
			pending_placements.erase(cell)
			block_anchors.erase(cell)
		if use_block_budget:
			block_budget_remaining += 1
		else:
			inventory[pending_id] = inventory.get(pending_id, 0) + 1
		queue_redraw()
		return true

	if not placed_blocks.has(anchor) or pending_removals.has(anchor):
		return false

	var block_id: String = placed_blocks[anchor]
	# Same pre-Start immediacy as place_block() above -- with no PLACEMENT
	# beat coming, a queued removal would simply never take effect. Either
	# way the block leaves as one unit, and refunds once.
	for cell in _cells_of_anchor(anchor):
		if started:
			pending_removals[cell] = true
		else:
			placed_blocks.erase(cell)
			block_anchors.erase(cell)
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
		block_anchors.erase(coord)
	for coord in pending_placements.keys():
		placed_blocks[coord] = pending_placements[coord]
		# block_anchors was already written at queue time by place_block(),
		# so a multi-cell block arrives on the board already grouped.
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
	water_beat += 1

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
	# Did anything actually go anywhere this beat? A drop that advances
	# lands its successors on OTHER cells; one that is absorbed by terrain
	# or lost leaves none; only a parked drop (held by a Wall, dirt, a full
	# lake's edge) re-adds itself where it was. So the flood moved unless
	# every drop came back in place -- which is what EVENT_WATER_ADVANCED
	# promises, and a fully stalled flood stays silent.
	var moved := false
	for entry in water_cells:
		var before: int = next_water.size()
		_advance_water(entry, next_water)
		if next_water.size() == before:
			moved = true
		for i in range(before, next_water.size()):
			if next_water[i]["coord"] != entry["coord"]:
				moved = true

	# Underground arrivals, after every surface drop has moved: a drop
	# that went into a tunnel d beats ago surfaces ON its exit now, and
	# falls from there next beat -- see tunnel_transit for the rule.
	if _surface_tunnel_arrivals(next_water):
		moved = true

	water_cells = next_water
	# Mudslides resolve after every drop has moved for this beat, so a
	# slide's terrain changes can't affect drops mid-loop -- see
	# _process_mudslides().
	_process_mudslides()
	queue_redraw()
	if moved:
		board_event.emit(EVENT_WATER_ADVANCED, Vector2i.ZERO)


## Puts every tunnel_transit entry due on this WATER beat onto its exit,
## as a fresh stream with the spring's first move -- DOWN_LEFT on a pointy
## grid, "straight" on a flat one, exactly what an active geyser spawns
## (see resolve_water_phase()'s source loops) -- and drops it from the
## list. _add_water() merges it with a surface drop already on the exit,
## so the exit is enterable ground like a source's own cell rather than a
## second source stacking two drops in one hex. Returns true if anything
## surfaced, which counts as the flood moving (EVENT_WATER_ADVANCED).
func _surface_tunnel_arrivals(next_water: Array[Dictionary]) -> bool:
	if tunnel_transit.is_empty():
		return false
	var is_flat := level_data.grid_style == "flat"
	var surfaced := false
	var still_underground: Array[Dictionary] = []
	for transit in tunnel_transit:
		if transit["due"] != water_beat:
			still_underground.append(transit)
			continue
		var exit_cell: Vector2i = transit["exit"]
		if is_flat:
			_add_water(next_water, exit_cell, Hex.FLAT_DOWN, "straight")
		else:
			_add_water(next_water, exit_cell, Hex.DOWN_LEFT)
		surfaced = true
		if not _tunnel_exits_opened.has(exit_cell):
			_tunnel_exits_opened[exit_cell] = true
			_events_to_reveal.append([EVENT_TUNNEL, exit_cell])
	tunnel_transit = still_underground
	return surfaced


## A drop reaching tunnel entrance `entrance` on this WATER beat goes
## underground: it is due at the exit hex-distance beats from now, one
## cell per beat along the straight line (see tunnel_transit). Deduped on
## (entrance, due), so two streams into one mouth on one beat surface as
## one drop, as they would have merged on the surface.
func _enter_tunnel(entrance: Vector2i) -> void:
	var exit_cell: Vector2i = level_data.tunnel_pairs[entrance]
	var due: int = water_beat + _cube_distance(exit_cell - entrance)
	for transit in tunnel_transit:
		if transit["entrance"] == entrance and transit["due"] == due:
			return
	tunnel_transit.append({"entrance": entrance, "exit": exit_cell,
		"entered": water_beat, "due": due})


## Beat 3 -- TERRAIN. Applies the fire/pool/geyser contact effects flagged
## by _try_enter() during this measure's WATER beat (_pending_terrain),
## mutating fires_remaining/cell_terrain/pool_fill/geyser_fill/
## active_geysers exactly as the old single-phase tick() used to do inline.
## Deliberately does NOT call queue_redraw() -- see resolve_status_phase()
## for why revealing this beat's changes is deferred to beat 4.
func resolve_terrain_phase() -> void:
	if game_over:
		return
	_lakes_credited_this_beat.clear()
	for coord in _pending_terrain:
		_resolve_terrain_contact(coord)
	_pending_terrain.clear()


## Beat 4 -- STATUS. Doesn't change simulation state itself -- it checks the
## win condition (now that beat 3 has finalized pool_fill/fires_remaining
## for this measure) and reveals whatever beats 2/3 changed by finally
## calling queue_redraw(). Holding the redraw until this beat is what makes
## a pool's animal changing pose, or a fire going out, visibly land on
## beat 4 specifically, even though the underlying state changed a beat
## earlier.
func resolve_status_phase() -> void:
	if game_over:
		return
	_check_end_conditions()
	queue_redraw()
	# Revealed after the win/loss check so a listener can tell a pool that
	# filled on the winning beat from one that did not.
	var revealed: Array = _events_to_reveal
	_events_to_reveal = []
	for pair in revealed:
		board_event.emit(pair[0], pair[1])


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
		_events_to_reveal.append([EVENT_FIRE_OUT, coord])
		return

	if terrain == CellState.POOL:
		# Credited to the LAKE, not the cell: all four cells of a pool share
		# one counter, keyed by the anchor. And only once per beat -- two
		# streams into two cells of the same lake are still one beat of
		# connection. Capped at POOL_BEATS_REQUIRED: water connecting on
		# beats beyond that does nothing further, it is already full.
		var anchor: Vector2i = lake_anchor.get(coord, coord)
		if _lakes_credited_this_beat.has(anchor):
			return
		_lakes_credited_this_beat[anchor] = true
		var before: int = pool_fill.get(anchor, 0)
		pool_fill[anchor] = mini(before + 1, POOL_BEATS_REQUIRED)
		if before < POOL_BEATS_REQUIRED:
			_events_to_reveal.append([EVENT_POOL_FULL if pool_fill[anchor] == POOL_BEATS_REQUIRED else EVENT_POOL_FILL, anchor])
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
			_events_to_reveal.append([EVENT_GEYSER, coord])
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
		# EXCEPTION -- a target that is solid: an actual Wall or Bomb
		# Catapult block, undug dirt (the "Dig the River" mechanic), an
		# inactive Hydro Plant cell, or an erupting geyser. Each is skipped
		# rather than entered (and, for hydro, the contact is recorded --
		# see _note_hydro_contact() -- so the plant becomes double-tap-able).
		# If EVERY target is blocked, the water has nowhere to go after all
		# and backs up on the block, exactly as it would against a Wall,
		# until the player digs/activates/removes one of them open.
		#
		# This loop used to check only undug dirt and inactive hydro, so a
		# Wall sitting on a Diverter's target was not solid to the diverted
		# stream: _try_enter() has no wall check either, so the water was
		# moved ONTO the wall cell, where the wall's own empty target list
		# then held it forever. The result was a puddle drawn inside a
		# solid block that never moved again -- while wall.tres documents a
		# Wall as "fully blocks water; water backs up against it each
		# tick", and plugging a diverter's mouth with one is the obvious
		# thing to try.
		#
		# _is_solid_block(), NOT the whole of _is_wall(). _is_wall() also
		# counts an ACTIVATED GEYSER as solid, which is right for natural
		# fall (a geyser is a source, water spawns from it) but wrong here:
		# level 63 sits its Hydro Plant at (-1,0) directly below its geyser
		# at (-2,-1) and feeds the plant with a redirected stream through
		# that cell. Using the full _is_wall() here blocks that and the
		# plant can never be reached -- caught by VerifyHydroBonus, which
		# is why that suite is worth running on any water-routing change.
		var all_targets_blocked := true
		for target in targets:
			if _is_undug_dirt(target) or _is_inactive_hydro(target) or _is_solid_block(target):
				_note_hydro_contact(target)
				continue
			all_targets_blocked = false
			if _try_enter(target):
				_add_water(next_water, target, opposite_dir)
		if all_targets_blocked:
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

	if target.y > bottom_row:
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
		# Same solid-target exception as the pointy-grid branch above, and
		# the same test, for the same reason: a Wall on a Diverter's target
		# used to be entered rather than blocked, and the water was then
		# held on the wall cell forever. An activated geyser is deliberately
		# NOT included here -- see the pointy-grid comment.
		var all_targets_blocked := true
		for target in targets:
			if _is_undug_dirt(target) or _is_inactive_hydro(target) or _is_solid_block(target):
				_note_hydro_contact(target)
				continue
			all_targets_blocked = false
			if _flat_try_enter(target):
				_add_water(next_water, target, opposite_dir, mode)
		if all_targets_blocked:
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
		board_event.emit(EVENT_MUDSLIDE, next_cell)
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
## placed WALL block, a Bomb Catapult block (a solid structure for water
## purposes, see _resolve_block_targets()), an activated geyser, a
## still-undug dirt cell (the "Dig the River" mechanic -- packed earth holds
## the water back exactly like a Wall until the player digs it open, see
## dig()), or one of an INACTIVE Hydro Plant's 3 cells (see
## _is_inactive_hydro()).
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
	return _is_solid_block(coord)


## True if a PLACED BLOCK at `coord` is solid to water -- the block half of
## _is_wall(), split out because the two block-redirect loops need exactly
## this and not the rest of it (see their "EXCEPTION" comments: an activated
## geyser is solid to natural fall but must stay enterable by a redirected
## stream, which is how level 63 feeds its Hydro Plant).
##
## CATAPULT counts as solid here too. Without it, _is_wall() returned false
## for a Bomb Catapult, so natural fall LANDED water on the catapult's own
## cell -- where _resolve_block_targets()'s empty target list then held it
## permanently, instead of the water bouncing onto the other diagonal the way
## a real Wall makes it. That contradicted both this block's own documentation
## and its design brief ("behaves exactly like a Wall for water simulation
## purposes").
func _is_solid_block(coord: Vector2i) -> bool:
	if not placed_blocks.has(coord):
		return false
	var block: BlockData = block_catalog[placed_blocks[coord]]
	return block.behavior == BlockData.TickBehavior.WALL or block.behavior == BlockData.TickBehavior.CATAPULT


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


## The direction offsets a block of type `block_id` sends water in -- the
## behaviour table for DIVERT_LEFT/DIVERT_RIGHT/SPLIT (and the empty list a
## WALL/CATAPULT returns), resolved against whichever pair of "down"
## directions this level's grid_style actually uses: Hex.DOWN_LEFT/DOWN_RIGHT
## on a "pointy" level, Hex.FLAT_DOWN_LEFT/FLAT_DOWN_RIGHT on a "flat" one.
## A block conceptually always means "send water down-and-to-the-left/right"
## on either grid -- no separate "flat" block type is needed.
##
## Split out of _resolve_block_targets() (which is now a thin wrapper that
## just adds `coord` to each offset) specifically so the direction arrows
## drawn on Diverters and Splitters -- see _draw_block_direction_arrows() --
## read from this ONE table rather than a second copy of the same match
## statement. A drawing-side copy that drifted from the simulation's would
## be exactly the "the renderer and the sim disagree" class of bug this
## project has been bitten by before; with one table there is nothing to
## drift.
##
## Returns an empty list for an unknown block id (rather than indexing a
## missing catalog entry and crashing, as the old inline lookup did), which
## makes such a block behave like a Wall -- the safest possible fallback,
## since it can only ever hold water back, never route it somewhere the
## player wasn't shown.
func _block_target_offsets(block_id: String) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	var block: BlockData = block_catalog.get(block_id, null)
	if block == null:
		return offsets
	var down_left := Hex.FLAT_DOWN_LEFT if level_data.grid_style == "flat" else Hex.DOWN_LEFT
	var down_right := Hex.FLAT_DOWN_RIGHT if level_data.grid_style == "flat" else Hex.DOWN_RIGHT
	match block.behavior:
		BlockData.TickBehavior.WALL, BlockData.TickBehavior.CATAPULT:
			# A Bomb Catapult is a solid structure for water purposes --
			# fully blocks, same as a Wall. Its actual gameplay (clearing
			# dirt) happens entirely outside the tick simulation, via
			# fire_catapult() -- see BlockData.TickBehavior.CATAPULT's doc
			# comment. Neither type gets a direction arrow, since neither
			# sends water anywhere.
			pass
		BlockData.TickBehavior.DIVERT_LEFT:
			offsets.append(down_left)
		BlockData.TickBehavior.DIVERT_RIGHT:
			offsets.append(down_right)
		BlockData.TickBehavior.SPLIT:
			offsets.append(down_left)
			offsets.append(down_right)
		_:
			offsets.append(down_right)
	return offsets


## Decides where water sitting ON a placed block moves to. Determined by
## whatever block is at `coord` -- this is what makes a WALL block hold
## water back and a DIVERT block redirect it. See _block_target_offsets()
## for the behaviour table itself and for why it lives in its own function.
func _resolve_block_targets(coord: Vector2i) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for offset in _block_target_offsets(placed_blocks[coord]):
		targets.append(coord + offset)
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
## packed dirt, with no side effects and never a loss. The HYDRO branch is
## defensive for exactly the same reason -- an inactive Hydro Plant cell is
## filtered out upstream by the same checks, and an ACTIVATED plant's cells
## are ordinary EMPTY terrain by then, so neither ever arrives here.
func _try_enter(coord: Vector2i) -> bool:
	if not in_playable_area(coord):
		# Falling past the bottom edge of the grid is a loss. Exits off the
		# sides/top (shouldn't normally happen given level design) just
		# drop the water silently rather than crashing the sim.
		if coord.y > bottom_row:
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

	if terrain == CellState.TUNNEL_IN:
		# The mouth swallows the drop: it leaves the surface this beat and
		# travels underground to the exit (see tunnel_transit). Every path
		# into a cell -- natural fall and both block-redirect loops, on
		# both grids -- ends here, and none of them treats the entrance as
		# solid (it is not in _is_wall()/_is_solid_block()), so a Diverter
		# pointed at a mouth feeds it rather than backing up. Nothing to
		# resolve on the TERRAIN beat: the tunnel keeps its own clock.
		_enter_tunnel(coord)
		return false

	if terrain == CellState.DIRT:
		# Defensive only -- see the doc comment above. Packed dirt simply
		# can't be entered; no terrain effect, no loss.
		return false

	if terrain == CellState.HYDRO:
		# Defensive only, same as DIRT above -- an inactive plant is
		# already filtered out by _is_wall() (natural fall) and by both
		# placed-block redirect loops. Recording the contact anyway keeps
		# any future code path that DOES reach here from silently
		# swallowing the plant's "ready to activate" cue.
		_note_hydro_contact(coord)
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


## True if this level has a Hydro Plant at all -- i.e. whether the optional
## bonus objective even applies here. Most levels have none, and those are
## unaffected by any of it.
func has_hydro_plants() -> bool:
	return not hydro_plants.is_empty()


## True if every Hydro Plant on this level is running. A plant never
## switches back off once activated (try_activate_hydro() turns its cells
## into permanent water sources), so "running at the end of the level" and
## "was switched on at some point this attempt" are the same thing -- there
## is no way to earn this and then lose it before the level ends.
##
## Deliberately requires ALL plants rather than any: a level with two plants
## should ask for both. Returns false on a level with no plants at all, so
## callers can use it directly without checking has_hydro_plants() first.
func all_hydro_plants_running() -> bool:
	if hydro_plants.is_empty():
		return false
	for anchor in hydro_plants:
		if not (hydro_plants[anchor].get("active", false) as bool):
			return false
	return true


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
## the same silent way a Wall does (via _is_wall()) -- and since digging is
## disabled until Start (see dig()), every dirt cell is still sealed while
## this preview is on screen, so what it forecasts is the route through the
## blocks the player has laid out, never a half-carved channel. An INACTIVE
## Hydro Plant cell ends a branch the
## same silent way, on both the natural-fall and the block-redirect path --
## it's a Wall to the simulation until activated, and it can't be activated
## pre-start at all, since activation requires water to have reached it
## first. A town/pool/still-dormant-geyser cell gets an
## arrow drawn INTO it and then ends the branch there too (see
## _predict_would_consume()'s doc comment for why those three specifically
## are treated as permanent stops). A fire cell also gets an arrow drawn
## into it, but does NOT end the branch -- a fire only consumes the first
## water that ever reaches it and is transparent to every beat after that,
## so the preview continues straight through, tracing the path all the way
## to wherever it actually ends up (e.g. a pool further down). A tunnel
## entrance gets an arrow INTO it and the branch then carries on from the
## tunnel's exit, the whole underground run costing one step -- see
## _predict_from_tunnel_exit().
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
			if not in_playable_area(target) or _is_undug_dirt(target) or _is_inactive_hydro(target):
				continue # this branch would exit the grid, or hit packed dirt / an inactive Hydro Plant (both block like a Wall) -- no arrow, nothing further
			arrows.append({"from": coord, "to": target})
			if _predict_would_consume(target):
				continue # town/pool/dormant geyser -- this branch ends right here
			if _is_tunnel_entrance(target):
				_predict_from_tunnel_exit(target, is_flat, steps_remaining - 1, arrows)
				continue
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
			if target.y > bottom_row:
				continue # straight bottom-edge exit -- both diagonals would lose the same way, nothing to draw
		if not in_playable_area(target) or _is_wall(target):
			continue # blocked by a corridor carve-out, a Wall, an activated geyser, undug dirt, or an inactive Hydro Plant cell (see _is_wall()) -- try the next candidate
		arrows.append({"from": coord, "to": target})
		if _predict_would_consume(target):
			return # town/pool/dormant geyser -- this branch ends right here
		if _is_tunnel_entrance(target):
			_predict_from_tunnel_exit(target, is_flat, steps_remaining - 1, arrows)
			return
		var spawn_dir := (opposite_dir if mode == "zigzag" else Hex.FLAT_DOWN) if is_flat else opposite_dir
		_predict_branch(target, spawn_dir, mode, is_flat, steps_remaining - 1, arrows)
		return
	# No candidate succeeded -- boxed in by walls/edges on every side, or a
	# pure edge exit either way. Nothing further to draw for this branch.


## True if `coord` is an underground tunnel's entrance (LevelData.tunnel_pairs).
func _is_tunnel_entrance(coord: Vector2i) -> bool:
	return cell_terrain.get(coord, CellState.EMPTY) == CellState.TUNNEL_IN


## The flow preview's jump through a tunnel: the arrow INTO the entrance
## has already been drawn, and the branch carries on from the exit with
## the spring's first move -- the whole underground run counts as the one
## step that arrow spent, so a tunnel never eats the preview's budget.
## Nothing is drawn between the two ends here; the route's stepping stones
## (_draw_tunnel_routes()) already show that part, and how long it takes.
func _predict_from_tunnel_exit(entrance: Vector2i, is_flat: bool, steps_remaining: int, arrows: Array) -> void:
	var exit_cell: Vector2i = level_data.tunnel_pairs[entrance]
	if is_flat:
		_predict_branch(exit_cell, Hex.FLAT_DOWN, "straight", true, steps_remaining, arrows)
	else:
		_predict_branch(exit_cell, Hex.DOWN_LEFT, "", false, steps_remaining, arrows)


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


## Drives the water flipbook. Deliberately does NOT redraw every frame:
## it advances a clock and only requests a redraw when one of the two frame
## indices changes, which caps the board at WATER_LEAD_FPS redraws a second
## while water is moving and zero when the board is dry.
func _process(delta: float) -> void:
	if water_cells.is_empty() and not _has_animated_tiles:
		return
	_anim_time += delta
	var tick := int(_anim_time * ANIM_TICK_FPS)
	if tick != _anim_tick:
		_anim_tick = tick
		queue_redraw()


## The frame a given rate is showing on this heartbeat. `stagger` offsets a
## cell from its neighbours so a run of the same tile type churns instead of
## pulsing in lockstep; callers pass a coordinate hash for that.
func _anim_frame(fps: float, frames: int, stagger: int = 0) -> int:
	if frames <= 1:
		return 0
	return (int(_anim_tick * fps / ANIM_TICK_FPS) + stagger) % frames


## A stable per-cell offset. Derived from the coordinate so it survives
## every redraw without being stored anywhere.
func _cell_stagger(coord: Vector2i, frames: int) -> int:
	if frames <= 1:
		return 0
	return absi(coord.x * 7 + coord.y * 13) % frames


## Draws one piece of tile art centred on a cell -- either a frame out of an
## animation strip or a plain static texture, at `size` across. The one path
## every animated tile goes through, water included.
func _draw_tile_art(texture: Texture2D, center: Vector2, size: float,
		frames: int = 1, frame: int = 0) -> void:
	if texture == null:
		return
	var rect := Rect2(center.x - size / 2.0, center.y - size / 2.0, size, size)
	if frames <= 1:
		draw_texture_rect(texture, rect, false)
		return
	var frame_px := float(texture.get_width()) / float(frames)
	draw_texture_rect_region(texture, rect, Rect2(
		frame * frame_px + SHEET_REGION_INSET, SHEET_REGION_INSET,
		frame_px - SHEET_REGION_INSET * 2.0,
		texture.get_height() - SHEET_REGION_INSET * 2.0))


## Which state a cell is in. The ONLY place terrain precedence lives -- the
## order of these branches is the order the old three chains used, and
## changing it changes what wins when two conditions overlap.
func _resolve_tile_state(coord: Vector2i) -> StringName:
	if placed_blocks.has(coord):
		return TILE_BLOCK
	var terrain: String = cell_terrain.get(coord, CellState.EMPTY)
	if terrain == CellState.FIRE:
		return TILE_FIRE
	if terrain == CellState.POOL:
		var anchor: Vector2i = lake_anchor.get(coord, coord)
		return TILE_POOL_FULL if (pool_fill.get(anchor, 0) as int) >= POOL_BEATS_REQUIRED else TILE_POOL
	if terrain == CellState.TOWN:
		return TILE_TOWN_FLOODED if flooded_towns.has(coord) else TILE_TOWN
	if terrain == CellState.GEYSER:
		return TILE_GEYSER
	if terrain == CellState.HYDRO:
		return TILE_HYDRO
	if terrain == CellState.TUNNEL_IN:
		return TILE_TUNNEL_IN
	if terrain == CellState.TUNNEL_OUT:
		return TILE_TUNNEL_OUT
	if terrain == CellState.DIRT:
		var taps: int = mini(dig_progress.get(coord, 0) as int, DIRT_COLORS.size() - 1)
		return [TILE_DIRT_0, TILE_DIRT_1, TILE_DIRT_2][taps]
	if mudslide_cells.has(coord):
		return TILE_MUDSLIDE
	if catapult_blast_cells.has(coord):
		return TILE_BLAST
	if (dig_progress.get(coord, 0) as int) >= DIG_TAPS_REQUIRED:
		return TILE_TRENCH
	return TILE_EMPTY


## The visual record for a resolved state. Everything static comes straight
## out of TILE_VISUALS; a block is the one state whose look is per-instance,
## since its colour and glyph live on its own BlockData resource (which is
## what lets a new block type ship without touching this file).
func _tile_visual(coord: Vector2i, state: StringName) -> Dictionary:
	if state == TILE_BLOCK:
		var block: BlockData = block_catalog[placed_blocks[coord]]
		return {"fill": block.color, "icon": block.glyph(_is_flat_grid())}
	return TILE_VISUALS[state]


func _draw() -> void:
	if level_data == null:
		return

	# The pre-start forecast is computed ONCE here, before the cell loop,
	# and cached for the rest of this redraw -- see _preview_arrows /
	# _preview_from_cells. _draw_cell() needs to know which cells the
	# preview already draws an arrow out of (so a Diverter/Splitter under
	# the preview doesn't also draw its own arrow over the top of the
	# amber one), and re-running the forecast per cell would mean
	# thousands of walks per frame on a board like level 22's.
	_preview_arrows.clear()
	_preview_from_cells.clear()
	if show_flow_preview:
		_preview_arrows = _predict_flow_arrows()
		for seg in _preview_arrows:
			_preview_from_cells[seg["from"]] = true

	var visible := _visible_draw_rect()

	for coord in _playable_cells:
		if not visible.has_point(Hex.axial_to_pixel(coord)):
			continue
		_draw_cell(coord)

	# Underground tunnels: the stepping-stone route between each pair's two
	# ends, over the cells and under the water -- see _draw_tunnel_routes().
	_draw_tunnel_routes(visible)

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

	# Water is drawn BEFORE the source markers below, not last: a source
	# spawns a drop every beat, so its cell is almost always wet, and a
	# full-tile water sprite would otherwise permanently hide the marker
	# ring that tells the player where the water comes from.
	# `wet` is built from EVERY water cell, culled or not: _is_lead_water()
	# asks about a cell's neighbours, and one of those can be off-screen
	# while the cell itself is on it. Only the drawing is culled.
	var wet := {}
	for entry in water_cells:
		wet[entry["coord"]] = true
	# A tunnel mouth drinking this beat counts as wet: the drop is not in
	# water_cells any more (it left the surface as it went in), so it is
	# found in tunnel_transit instead. It goes into `wet` BEFORE the
	# stream is drawn, or _is_lead_water() takes the cell above the mouth
	# for the head of the stream and foams it, and the river looks as if
	# it stopped one cell short of the hole it is running into.
	var drinking: Array[Vector2i] = []
	for transit in tunnel_transit:
		if transit["entered"] != water_beat:
			continue
		var mouth: Vector2i = transit["entrance"]
		if not wet.has(mouth):
			wet[mouth] = true
			drinking.append(mouth)
	for entry in water_cells:
		if not visible.has_point(Hex.axial_to_pixel(entry["coord"])):
			continue
		_draw_water(entry["coord"], _is_lead_water(entry["coord"], wet))
	# The mouth itself is body water, never a head; _draw_water() puts the
	# arch back on top.
	for mouth in drinking:
		if visible.has_point(Hex.axial_to_pixel(mouth)):
			_draw_water(mouth, false)
	# Stepping stones a surface stream is running over go back on top of
	# it, the way a block's glyph does, or the player loses count of the
	# delay (and the lit stones) mid-run -- see _draw_tunnel_stones_over_water().
	_draw_tunnel_stones_over_water(visible, wet)

	# The pool animals: after the water, so a stream arriving through the
	# cells above a lake never paints over one, and before the flow preview
	# so the amber arrows stay an overlay.
	_draw_pool_characters(visible)

	# Pre-start flow preview (see show_flow_preview) -- drawn after the
	# source markers so its amber arrows sit on top of them, and before the
	# water circles below (there's never any real water yet while this is
	# showing, since it's only true before Start is pressed).
	# A tunnel exit's pre-Start first-move arrow: after the cells and the
	# animals, so nothing drawn later covers its tip in the next cell.
	if show_flow_preview:
		_draw_tunnel_exit_arrows(visible)
		_draw_flow_preview()

	# Live Bomb Catapult aim preview (see active_catapult_aim/
	# set_catapult_aim()) -- drawn after the flow preview so it's never
	# hidden by it (the two can't actually overlap in practice, since
	# aiming a catapult only makes sense after Start when show_flow_preview
	# is already false, but layering it last keeps that assumption from
	# ever silently hiding the aim if it changes).
	_draw_catapult_aim()


## The part of the board that can contribute a pixel this frame, in the
## board's own coordinates. Cells whose centre falls outside it are skipped.
##
## The board is one CanvasItem drawing the whole grid, and it drew every
## playable cell every repaint no matter where the grid was scrolled. On the
## tall corridor levels that is most of the work thrown away: level 22 is a
## radius-50 board of 505 cells, of which roughly 75 are on screen at once.
## Culling turns "a draw call per cell in the level" into "a draw call per
## cell on the screen", which is what the cost should have been proportional
## to all along.
##
## Derived from the canvas transform rather than from position.y, so it stays
## correct regardless of what the board's parent does to it -- scroll,
## offset, or a future scale.
##
## The margin is deliberately generous. A cell draws past its own centre by
## up to Hex.SIZE (a FILL sheet is 2*Hex.SIZE across and the hex corners sit
## at Hex.SIZE), a pool's animal is a glyph-sized sprite inside its own
## lake (culled on its own centre), and a geyser's status bar hangs a
## further ~26px above the tile -- a FIXED offset that
## does not scale with Hex.SIZE, so it is the term that matters on a
## small-celled board like level 22's. Overshooting
## costs a few extra cells; undershooting pops art in and out at the screen
## edge, which is exactly the bug this must not introduce.
func _visible_draw_rect() -> Rect2:
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var rect: Rect2 = to_local * get_viewport_rect()
	return rect.grow(Hex.SIZE * 2.0 + 48.0)


## Draws one cell, in a fixed layer order: base, pending overlay, outline,
## preset outline, glyph, then per-state overlays. The order matters -- each
## layer is drawn over the one before it -- so it is written out here rather
## than left implicit in the shape of a branch chain.
func _draw_cell(coord: Vector2i) -> void:
	var center := Hex.axial_to_pixel(coord)
	var points := PackedVector2Array()
	for i in range(6):
		points.append(Hex.hex_corner(center, i))

	var state := _resolve_tile_state(coord)
	var visual := _tile_visual(coord, state)
	var terrain: String = cell_terrain.get(coord, CellState.EMPTY)

	# 1. base fill. Drawn even under FILL art, so a sheet with transparent
	#    pixels still sits on the right ground rather than on the sky. An
	#    empty cell's fill is the one the Options menu's opacity slider
	#    thins -- see empty_fill() -- down to nothing at 0, leaving the
	#    border below as the grid.
	var fill: Color = empty_fill() if state == TILE_EMPTY else visual["fill"]
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	if visual.get("mode", TileMode.GLYPH) == TileMode.FILL:
		var fill_sheet: Texture2D = _tile_sheet(visual)
		if fill_sheet != null:
			var frames: int = visual.get("frames", 1)
			_draw_tile_art(fill_sheet, center, Hex.SIZE * 2.0, frames,
				_anim_frame(visual.get("fps", ANIM_TICK_FPS), frames, _cell_stagger(coord, frames)))

	# 1b. A pool draws its own lakebed, water level and shoreline on top of
	#     the base fill -- the level is per-lake state (see _draw_basin()).
	if terrain == CellState.POOL:
		_draw_basin(coord, center, points)

	# 2. Buffered placement/pickup that hasn't reached its PLACEMENT beat
	#    yet (post-Start only -- pre-Start both commit immediately, see
	#    HexBoard.started). Ghosting them is what makes a mid-measure tap
	#    visibly land: the board used to look completely unchanged for up to
	#    a full measure after the tap, which reads as a dropped input.
	if pending_placements.has(coord) and not placed_blocks.has(coord):
		var ghost: BlockData = block_catalog[pending_placements[coord]]
		draw_colored_polygon(points, Color(ghost.color.r, ghost.color.g, ghost.color.b, PENDING_PLACEMENT_ALPHA))
	elif pending_removals.has(coord):
		draw_colored_polygon(points, PENDING_REMOVAL_COLOR)

	# 3. cell border. A lake cell skips it: its shoreline (_draw_basin())
	#    is the basin's only edge, so four cells read as one body.
	if terrain != CellState.POOL:
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(0, 0, 0, 0.4), 1.0, true)

	# 4. Fixed level furniture gets a second, inset outline -- see
	#    PRESET_OUTLINE_COLOR and _is_preset_cell(). Both halves of a 2-wide
	#    preset get one, so the whole structure reads as bolted down.
	if _is_preset_cell(coord):
		var inner := PackedVector2Array()
		for i in range(6):
			inner.append(center + (Hex.hex_corner(center, i) - center) * PRESET_OUTLINE_INSET)
		inner.append(inner[0])
		draw_polyline(inner, PRESET_OUTLINE_COLOR, 2.0, true)

	# 4b. Tutorial hint -- see HINT_OUTLINE_COLOR. Drawn under the glyph so
	#    a block placed here covers it naturally as well as by the has()
	#    checks.
	if level_data.hint_cells.has(coord) and not placed_blocks.has(coord) \
			and not pending_placements.has(coord):
		_draw_hint_outline(center)

	# 5. glyph. A state with a sheet animates; one with only an icon draws
	#    it statically, which is how a tile type gets converted to animation
	#    without touching anything here.
	if visual.get("mode", TileMode.GLYPH) == TileMode.GLYPH:
		var glyph_sheet: Texture2D = _tile_sheet(visual)
		if glyph_sheet != null:
			var frames: int = visual.get("frames", 1)
			_draw_tile_art(glyph_sheet, center, Hex.SIZE * ICON_SCALE, frames,
				_anim_frame(visual.get("fps", ANIM_TICK_FPS), frames, _cell_stagger(coord, frames)))
		elif visual["icon"] != null:
			_draw_icon(center, visual["icon"])

	# 6. per-state overlays. (A pool's animal is not one of them: it is
	#    one scene per LAKE, drawn by _draw_pool_characters() after the
	#    cell loop so no later cell paints over it.)
	if terrain == CellState.GEYSER:
		_draw_status_bar(coord, geyser_fill.get(coord, 0) as int, GEYSER_BEATS_REQUIRED, Color(0.75, 0.35, 0.85))
		_draw_geyser_direction_arrow(coord)

	if terrain == CellState.HYDRO and hydro_ready_at(coord):
		# Water has reached this plant but it hasn't been activated yet --
		# a bright ring cues the player that a double-tap here will do
		# something, same ring style _draw_source_marker() always shows on
		# a source, just a warmer color so it doesn't read as "already
		# flowing."
		draw_arc(center, Hex.SIZE * 0.55, 0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9), 2.5, true)

	# Ghosted placements get their block's glyph too, at full opacity over
	# the translucent fill -- the icon is what actually tells the player
	# WHICH block they queued, so fading it as well would defeat the point.
	if pending_placements.has(coord) and not placed_blocks.has(coord):
		var ghost_block: BlockData = block_catalog[pending_placements[coord]]
		_draw_icon(center, ghost_block.glyph(_is_flat_grid()))

	# Where this block will send its water next -- the Diverter/Splitter
	# equivalent of the arrow a dormant geyser already gets. Drawn last so
	# it sits on top of the block's own glyph. A still-QUEUED placement
	# gets one too, using the queued block's id: a mid-run tap should be
	# able to tell you what the block does before the PLACEMENT beat
	# actually lands it, which is the same reason the ghost draws its
	# glyph at full opacity above.
	if placed_blocks.has(coord):
		_draw_block_direction_arrows(coord, placed_blocks[coord])
	elif pending_placements.has(coord):
		_draw_block_direction_arrows(coord, pending_placements[coord])


## True on a level using grid_style "flat". The block glyphs that state a
## direction ship a second drawing for this orientation, because a
## Diverter's exit bearing is 30 degrees off vertical on a pointy grid and
## 30 degrees off HORIZONTAL here -- see BlockData.icon_flat.
func _is_flat_grid() -> bool:
	return level_data != null and level_data.grid_style == "flat"


## The animation strip for a visual on this level's grid orientation, or
## null when the state ships no sheet and should fall back to its icon.
func _tile_sheet(visual: Dictionary) -> Texture2D:
	if level_data != null and level_data.grid_style == "flat" and visual.has("sheet_flat"):
		return visual["sheet_flat"]
	return visual.get("sheet", null)


## True if `coord` is covered by a block the level shipped with and that's
## still standing -- the condition for the inset preset outline in
## _draw_cell(). Works from either half of a 2-wide preset (via
## block_anchor_at()), and goes false for a preset Bomb Catapult once it's
## been fired, since that cell is ordinary board again by then.
## Dashed hexagonal ring for a LevelData.hint_cells entry, inset from the
## cell edge so it never touches the cell border or a neighbour's hint.
func _draw_hint_outline(center: Vector2) -> void:
	for i in range(6):
		var a := center + (Hex.hex_corner(center, i) - center) * HINT_OUTLINE_INSET
		var b := center + (Hex.hex_corner(center, (i + 1) % 6) - center) * HINT_OUTLINE_INSET
		draw_dashed_line(a, b, HINT_OUTLINE_COLOR, HINT_OUTLINE_WIDTH, HINT_DASH_PX, true, true)


func _is_preset_cell(coord: Vector2i) -> bool:
	if not placed_blocks.has(coord):
		return false
	var anchor := block_anchor_at(coord)
	return level_data.preset_blocks.has(anchor) and not _spent_preset_cells.has(anchor)


## Small arrow(s) on a placed Diverter or Splitter pointing at the cell(s)
## it will push water into -- one arrow for a Diverter-Left/Diverter-Right,
## two for a Splitter, none at all for a Wall or a Bomb Catapult (neither
## sends water anywhere, so _block_target_offsets() returns nothing and
## this exits immediately). Exactly the cue a dormant geyser already gets
## from _draw_geyser_direction_arrow(), in the same smaller/thinner arrow
## style, so "this tile is about to send water that way" reads the same
## everywhere on the board.
##
## Directions come from _block_target_offsets() -- the same single table
## the simulation itself resolves through -- so an arrow can never point
## somewhere the water won't actually go, on either grid orientation.
##
## Two deliberate suppressions:
##
## - Drawn only on a block's ANCHOR cell. Every cell of a multi-cell block
##   carries its own placed_blocks entry, so without this a hypothetical
##   2-wide diverter would draw the same pair of arrows twice, one per
##   half. (No shipped multi-cell type routes water today -- Wall and
##   Catapult are the only ones with footprints and neither draws an arrow
##   -- but the guard costs nothing and keeps this correct if that ever
##   changes.)
## - Skipped while the pre-start flow preview already draws a segment out
##   of this cell (see _preview_from_cells). The amber preview arrow and
##   this one would otherwise land on the exact same segment, doubled up
##   -- the same overlap _draw_source_marker() avoids by suppressing its
##   own first-move arrow pre-start. A Diverter the preview does NOT
##   reach (beyond its PREVIEW_ARROW_STEPS budget, or on a branch no
##   water gets to) still draws its arrow, which is exactly the case
##   where the player has nothing else to go on.
func _draw_block_direction_arrows(coord: Vector2i, block_id: String) -> void:
	if block_anchor_at(coord) != coord:
		return
	if show_flow_preview and _preview_from_cells.has(coord):
		return
	var offsets := _block_target_offsets(block_id)
	if offsets.is_empty():
		return
	var block: BlockData = block_catalog.get(block_id, null)
	if block == null:
		return

	# Tinted from the block's own colour so a Diverter-Left, a
	# Diverter-Right and a Splitter keep their identities, lightened far
	# enough (BLOCK_ARROW_WHITEN) that the arrow always reads against the
	# fill it's drawn on.
	var color: Color = block.color.lerp(Color.WHITE, BLOCK_ARROW_WHITEN)
	color.a = BLOCK_ARROW_ALPHA

	var center := Hex.axial_to_pixel(coord)
	for offset in offsets:
		var target_center := Hex.axial_to_pixel(coord + offset)
		var dir_vec := (target_center - center).normalized()
		if dir_vec == Vector2.ZERO:
			continue
		var arrow_start := center + dir_vec * (Hex.SIZE * 0.42)
		var arrow_end := center + dir_vec * (Hex.SIZE * 0.92)
		draw_line(arrow_start, arrow_end, color, 2.0, true)

		# Arrowhead: two short strokes angled back from the tip, same
		# shape and scale as the dormant geyser's.
		var back := -dir_vec * (Hex.SIZE * 0.16)
		var perp := Vector2(-dir_vec.y, dir_vec.x) * (Hex.SIZE * 0.10)
		draw_line(arrow_end, arrow_end + back + perp, color, 2.0, true)
		draw_line(arrow_end, arrow_end + back - perp, color, 2.0, true)


## The direction a dormant geyser's stream will take on its very first move
## once it activates: always Hex.DOWN_LEFT on a "pointy" level (the same
## first move every source makes there) and Hex.FLAT_DOWN on a "flat" one.
## Deliberately NOT _first_move_direction(): that reads
## LevelData.source_flow_style, which only ever applies to the level's
## ORIGINAL water_sources -- an activated geyser on a flat level always
## flows "straight" (see resolve_water_phase()), so routing geysers through
## the same helper would advertise a zigzag the water never takes.
func _geyser_first_move_direction() -> Vector2i:
	return Hex.FLAT_DOWN if level_data.grid_style == "flat" else Hex.DOWN_LEFT


## Small arrow on a still-dormant geyser pointing the way its water will
## head the moment it erupts, so the player can lay out the downstream
## channel before spending GEYSER_BEATS_REQUIRED beats filling it -- until
## now a geyser gave no clue which of its neighbours it was about to feed.
## Drawn in the geyser's own pale purple and deliberately smaller and
## thinner than the white first-move arrow on a live source, so a dormant
## geyser never reads as already flowing.
func _draw_geyser_direction_arrow(coord: Vector2i) -> void:
	var center := Hex.axial_to_pixel(coord)
	var target_center := Hex.axial_to_pixel(coord + _geyser_first_move_direction())
	var dir_vec := (target_center - center).normalized()
	if dir_vec == Vector2.ZERO:
		return
	var color := Color(0.85, 0.7, 0.9, 0.85)
	var arrow_start := center + dir_vec * (Hex.SIZE * 0.42)
	var arrow_end := center + dir_vec * (Hex.SIZE * 0.92)
	draw_line(arrow_start, arrow_end, color, 2.0, true)

	# Arrowhead: two short strokes angled back from the tip, same shape as
	# _draw_source_marker()'s, scaled down.
	var back := -dir_vec * (Hex.SIZE * 0.16)
	var perp := Vector2(-dir_vec.y, dir_vec.x) * (Hex.SIZE * 0.10)
	draw_line(arrow_end, arrow_end + back + perp, color, 2.0, true)
	draw_line(arrow_end, arrow_end + back - perp, color, 2.0, true)


## Where the first drop to surface at tunnel exit `coord` will actually go,
## given the blocks on the board right now -- the direction the exit's
## pre-Start arrow points. Unlike a dormant geyser's arrow, which always
## shows the spring's first try, this resolves that try the way the sim
## will (_try_natural_step() / _advance_water_flat()): on a pointy grid
## DOWN_LEFT, or DOWN_RIGHT when DOWN_LEFT is a Wall, a carved-out cell or
## anything else _is_wall() calls solid; on a flat grid only FLAT_DOWN
## ("straight"). A drop that falls straight off the bottom still shows its
## way off. Vector2i.ZERO when the spring is boxed in and will not move,
## which draws no arrow. The tunnel_3 lesson is exactly "set the Wall so
## the spring turns away" -- an arrow that kept pointing into the Wall
## would teach the opposite.
func _tunnel_exit_first_move(coord: Vector2i) -> Vector2i:
	# Built with append(), not a ternary of literals -- see the NOTE in
	# _advance_water_flat() on why that comes back untyped.
	var candidates: Array[Vector2i] = []
	if _is_flat_grid():
		candidates.append(Hex.FLAT_DOWN)
	else:
		candidates.append(Hex.DOWN_LEFT)
		candidates.append(Hex.DOWN_RIGHT)
	for dir in candidates:
		var target := coord + dir
		if not _is_flat_grid() and target.y > bottom_row:
			return dir # off the bottom edge: a loss, either diagonal alike
		if _is_flat_grid() and not level_data.blocked_cells.has(target) and _cube_distance(target) > level_data.grid_radius:
			return dir # off the flat grid's true boundary: a loss that way
		if in_playable_area(target) and not _is_wall(target):
			return dir
	return Vector2i.ZERO


## Draws `texture` centered on `center`, scaled to comfortably fit inside a
## hex tile (SVG icons share a 100x100 viewBox, so this scales relative to
## Hex.SIZE regardless of grid zoom level). No-op if `texture` is null, so
## callers can pass an unset BlockData.icon safely and just fall back to the
## flat fill color with no glyph.
func _draw_icon(center: Vector2, texture: Texture2D, scale_factor: float = ICON_SCALE) -> void:
	if texture == null:
		return
	var size := Hex.SIZE * scale_factor
	var rect := Rect2(center.x - size / 2.0, center.y - size / 2.0, size, size)
	draw_texture_rect(texture, rect, false)


## One cell of a lake: cracked dry earth, then water rising from the bottom
## of the WHOLE lake's bounding box as pool_fill climbs, so the four cells
## fill as one basin rather than four cups. At POOL_BEATS_REQUIRED the
## waterline reaches the top of the lake and every cell is fully water. A
## sand-coloured shoreline is drawn only on edges that do not face another
## cell of the same lake.
func _draw_basin(coord: Vector2i, center: Vector2, points: PackedVector2Array) -> void:
	var anchor: Vector2i = lake_anchor.get(coord, coord)
	var beats: int = pool_fill.get(anchor, 0) as int
	var level := clampf(float(beats) / float(POOL_BEATS_REQUIRED), 0.0, 1.0)

	_draw_basin_cracks(coord, center)

	if level > 0.0:
		var bounds := _lake_bounds(anchor)
		var top := bounds.position.y
		var bottom := bounds.end.y
		var waterline := bottom - level * (bottom - top)

		# The wet part is the stream's own animated water, cut off at the
		# waterline: the sheet's frames fill the hex's bounding box edge to
		# edge with transparent corners, so clipping the source rect to the
		# band below the waterline is the whole clip -- no polygon needed.
		var tile_top := center.y - Hex.SIZE
		var wet_from := maxf(waterline, tile_top)
		var frac := clampf((wet_from - tile_top) / (Hex.SIZE * 2.0), 0.0, 1.0)
		if frac < 1.0:
			var sheet: Texture2D = WATER_BODY_FLAT if level_data.grid_style == "flat" else WATER_BODY_POINTY
			var frame := _anim_frame(WATER_FPS, WATER_FRAMES, _cell_stagger(coord, WATER_FRAMES))
			var frame_px := float(sheet.get_width()) / float(WATER_FRAMES)
			var tex_h := float(sheet.get_height())
			var src := Rect2(frame * frame_px + SHEET_REGION_INSET, frac * tex_h + SHEET_REGION_INSET,
				frame_px - SHEET_REGION_INSET * 2.0, tex_h * (1.0 - frac) - SHEET_REGION_INSET * 2.0)
			var dest := Rect2(center.x - Hex.SIZE, wet_from, Hex.SIZE * 2.0, Hex.SIZE * 2.0 * (1.0 - frac))
			draw_texture_rect_region(sheet, dest, src)

		# Surface line where the waterline crosses this cell.
		var surface := PackedVector2Array()
		for i in range(6):
			var a := points[i]
			var b := points[(i + 1) % 6]
			if (a.y >= waterline) != (b.y >= waterline):
				surface.append(a.lerp(b, (waterline - a.y) / (b.y - a.y)))
		if surface.size() == 2:
			draw_line(surface[0], surface[1], BASIN_SURFACE_COLOR, 2.5, true)

	for i in range(6):
		var a := points[i]
		var b := points[(i + 1) % 6]
		var across := center + ((a + b) / 2.0 - center) * 2.0
		var neighbour := coord
		var best := INF
		for offset in Hex.NEIGHBOR_OFFSETS:
			var d: float = Hex.axial_to_pixel(coord + offset).distance_squared_to(across)
			if d < best:
				best = d
				neighbour = coord + offset
		if lake_anchor.get(neighbour, Vector2i(9999, 9999)) != anchor:
			draw_line(a, b, BASIN_SHORE_COLOR, BASIN_SHORE_WIDTH, true)


## Three short cracks per cell, seeded from the coordinate so they never
## crawl between redraws. Kept inside ~0.7 of the hex radius so nothing
## touches the shoreline.
func _draw_basin_cracks(coord: Vector2i, center: Vector2) -> void:
	var seed: int = (coord.x * 73856093) ^ (coord.y * 19349663)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for n in range(3):
		var angle := rng.randf_range(0.0, TAU)
		var p := center + Vector2(cos(angle), sin(angle)) * rng.randf_range(0.0, Hex.SIZE * 0.35)
		var heading := rng.randf_range(0.0, TAU)
		var line := PackedVector2Array([p])
		for k in range(3):
			heading += rng.randf_range(-0.9, 0.9)
			var q := line[line.size() - 1] + Vector2(cos(heading), sin(heading)) * Hex.SIZE * 0.22
			if q.distance_to(center) > Hex.SIZE * 0.7:
				break
			line.append(q)
		if line.size() >= 2:
			draw_polyline(line, BASIN_CRACK_COLOR, 2.0, true)


## The bounding box of every corner of every cell of the lake anchored at
## `anchor`. Its top is the waterline once the pool is full (_draw_basin),
## which is why the animal stands on it: it is the pointy grid's top vertex
## and the flat grid's top edge, so one rule serves both orientations.
func _lake_bounds(anchor: Vector2i) -> Rect2:
	var top := INF
	var bottom := -INF
	var left := INF
	var right := -INF
	for cell in lake_cells_of(anchor):
		var c := Hex.axial_to_pixel(cell)
		for i in range(6):
			var corner := Hex.hex_corner(c, i)
			top = minf(top, corner.y)
			bottom = maxf(bottom, corner.y)
			left = minf(left, corner.x)
			right = maxf(right, corner.x)
	return Rect2(left, top, right - left, bottom - top)


## The lake's cells that reach its top, left to right -- the animal stands
## on their lakebed.
func _lake_top_cells(anchor: Vector2i) -> Array[Vector2i]:
	var top := _lake_bounds(anchor).position.y
	var cells: Array[Vector2i] = []
	for cell in lake_cells_of(anchor):
		var c := Hex.axial_to_pixel(cell)
		var cell_top := INF
		for i in range(6):
			cell_top = minf(cell_top, Hex.hex_corner(c, i).y)
		if absf(cell_top - top) < 0.01:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Hex.axial_to_pixel(a).x < Hex.axial_to_pixel(b).x)
	return cells


## One animal's side; two at a pool each draw smaller.
func _character_side(slots: int) -> float:
	return Hex.SIZE * CHARACTER_SCALE * (CHARACTER_PAIR_SCALE if slots > 1 else 1.0)


## The rect one animal draws in at the lake anchored at `anchor`; slot 0 of
## `slots` is the left-most. All the slots together are centred over the
## lake's top cells, feet CHARACTER_BED_DEPTH below its top corner. Public
## so a test can measure it.
func character_rect(anchor: Vector2i, slot: int, slots: int) -> Rect2:
	var side := _character_side(slots)
	var width := side * slots + side * CHARACTER_PAIR_GAP * (slots - 1)
	var top_cells := _lake_top_cells(anchor)
	var cx := 0.0
	for cell in top_cells:
		cx += Hex.axial_to_pixel(cell).x
	cx /= maxi(top_cells.size(), 1)
	var feet := _lake_bounds(anchor).position.y + CHARACTER_BED_DEPTH * Hex.SIZE
	return Rect2(cx - width / 2.0 + slot * side * (1.0 + CHARACTER_PAIR_GAP),
		feet - side * CHARACTER_BASELINE, side, side)


## The pose a lake's animal is in: its pool_fill, 0 (lying by the dry
## basin) to POOL_BEATS_REQUIRED (drinking).
func character_pose_for(anchor: Vector2i) -> int:
	return clampi(pool_fill.get(anchor, 0) as int, 0, Characters.POSES - 1)


## The animal at every lake in the pose its pool_fill says -- one scene per
## LAKE, not per cell, drawn once the cell loop and the water are done so
## nothing paints over it and the risen water is under its feet. Drawn from
## the level's first frame: the animal lying in the dry basin is the
## scene's setup, not something that pops in with the first beat of water.
func _draw_pool_characters(visible: Rect2) -> void:
	if _character_poses.is_empty():
		return
	var slots := _character_poses.size()
	for anchor in pool_fill.keys():
		if not visible.has_point(character_rect(anchor, 0, slots).get_center()):
			continue
		var pose := character_pose_for(anchor)
		for slot in range(slots):
			var texture: Texture2D = _character_poses[slot][pose]
			if texture != null:
				draw_texture_rect(texture, character_rect(anchor, slot, slots), false)


## Every cell of the lake anchored at `anchor` -- the anchor itself first,
## then level_data.lake_cells' extras. A pool with no lake entry is a
## single cell, so the engine keeps working on data that predates lakes.
func lake_cells_of(anchor: Vector2i) -> Array:
	var cells := [anchor]
	if level_data != null:
		for extra in level_data.lake_cells.get(anchor, []):
			cells.append(extra)
	return cells


## Box-bar renderer for anything that fills up over a fixed number of
## beats -- `required` boxes above the cell, `filled` of them lit in
## `lit_color`, the rest dark. The Geyser branch in _draw_cell() is its one
## caller now that a pool shows its animal instead (_draw_pool_characters()).
func _draw_status_bar(coord: Vector2i, filled: int, required: int, lit_color: Color) -> void:
	_draw_status_bar_at(Hex.axial_to_pixel(coord), filled, required, lit_color)


## The same bar positioned by a pixel centre rather than a cell. `center`
## is treated as the centre of the cell the bar sits above.
func _draw_status_bar_at(center: Vector2, filled: int, required: int, lit_color: Color) -> void:
	if filled <= 0:
		return # bar hasn't "popped up" yet -- no connection landed here yet

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
	# The waterfall ledge spans the cell, so it draws larger than a centred
	# glyph and needs no ring to mark the cell out.
	_draw_icon(center, ICON_SOURCE, SOURCE_ICON_SCALE)

	var ring_color := Color(1.0, 1.0, 1.0, 0.9)

	if show_flow_preview:
		return

	var first_move := _first_move_direction(coord)
	var target_center := Hex.axial_to_pixel(coord + first_move)
	var dir_vec := (target_center - center).normalized()
	# Starts below the foam at the base of the falls rather than at the
	# centre, so the arrow does not cross the cascade.
	var arrow_start := center + dir_vec * (Hex.SIZE * 0.55)
	var arrow_end := center + dir_vec * (Hex.SIZE * 0.95)
	draw_line(arrow_start, arrow_end, ring_color, 3.0, true)

	# Arrowhead: two short strokes angled back from the tip.
	var back := -dir_vec * (Hex.SIZE * 0.22)
	var perp := Vector2(-dir_vec.y, dir_vec.x) * (Hex.SIZE * 0.14)
	draw_line(arrow_end, arrow_end + back + perp, ring_color, 3.0, true)
	draw_line(arrow_end, arrow_end + back - perp, ring_color, 3.0, true)


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


## Draws every arrow in _preview_arrows (computed once per redraw at the
## top of _draw(), see that cache's doc comment) in amber, fading slightly
## step-by-step (the segment right at the source is brightest, the
## 4th/final segment dimmest) so the chain reads as a directional trail
## rather than a wall of identical arrows. _predict_branch() appends a
## branch's segments in order, so a simple running index approximates this
## fade reasonably even across a Splitter's multiple branches.
func _draw_flow_preview() -> void:
	for i in range(_preview_arrows.size()):
		var seg: Dictionary = _preview_arrows[i]
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
	draw_line(arrow_start, arrow_end, color, 3.0, true)

	# Arrowhead: two short strokes angled back from the tip.
	var back := -dir_vec * (Hex.SIZE * 0.22)
	var perp := Vector2(-dir_vec.y, dir_vec.x) * (Hex.SIZE * 0.14)
	draw_line(arrow_end, arrow_end + back + perp, color, 3.0, true)
	draw_line(arrow_end, arrow_end + back - perp, color, 3.0, true)


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
	if start_coord == end_coord:
		# At minimum charge these coincide, and _draw_flow_arrow() then
		# normalizes a zero vector and draws nothing at all -- leaving the
		# first CATAPULT_CHARGE_MSEC_PER_TILE of every shot with a blast
		# preview but no visible aim line. Anchor it at the catapult
		# itself instead so there's always an arrow to read.
		start_coord = origin
	_draw_flow_arrow(start_coord, end_coord, 1.0)

	for cell in _catapult_blast_area(end_coord):
		if not in_playable_area(cell):
			continue
		var center := Hex.axial_to_pixel(cell)
		var points := PackedVector2Array()
		for i in range(6):
			points.append(Hex.hex_corner(center, i))
		draw_colored_polygon(points, Color(1.0, 0.4, 0.15, 0.35))


## Draws one water cell as a full-tile animated sprite. The destination is
## 2 x Hex.SIZE square, which is exactly the hex's own bounding box on both
## orientations, so the art lines up with the cell at every level's tile
## size (Hex.SIZE is solved per level -- see _fit_hex_layout()).
func _draw_water(coord: Vector2i, is_lead: bool) -> void:
	var center := Hex.axial_to_pixel(coord)

	# Body cells take a per-cell frame offset derived from the coordinate,
	# so a long stream churns instead of pulsing in lockstep. The lead is
	# left unstaggered -- there is only ever one per branch, and it should
	# read as the newest thing on the board.
	var flat := level_data.grid_style == "flat"
	var sheet: Texture2D
	var frame: int
	if is_lead:
		sheet = WATER_LEAD_FLAT if flat else WATER_LEAD_POINTY
		frame = _anim_frame(WATER_LEAD_FPS, WATER_FRAMES)
	else:
		sheet = WATER_BODY_FLAT if flat else WATER_BODY_POINTY
		frame = _anim_frame(WATER_FPS, WATER_FRAMES, _cell_stagger(coord, WATER_FRAMES))
	_draw_tile_art(sheet, center, Hex.SIZE * 2.0, WATER_FRAMES, frame)

	# A Diverter or Splitter under the water still has to be readable --
	# water lands ON those blocks (see _advance_water()), and a full-tile
	# sprite would otherwise bury the glyph that says what the block does.
	if placed_blocks.has(coord):
		var block: BlockData = block_catalog[placed_blocks[coord]]
		_draw_icon(center, block.glyph(_is_flat_grid()))
	# Same for a tunnel end: the mouth is wet whenever it is drinking and
	# the exit whenever it is flowing, which is most of a run, and the arch
	# is what says there is a tunnel here at all.
	var terrain: String = cell_terrain.get(coord, CellState.EMPTY)
	if terrain == CellState.TUNNEL_IN or terrain == CellState.TUNNEL_OUT:
		_draw_icon(center, _tile_visual(coord, _resolve_tile_state(coord))["icon"])


## Underground routes (LevelData.tunnel_pairs): for each pair, a faint
## dashed line between the two ends' centres with d - 1 stepping stones
## evenly spaced along it, d being the hex distance -- one stone per
## underground cell of travel, so the player can count the delay before
## the exit flows. A stone lights up water-blue while a drop is at that
## step (step = water_beat - entered, 1 .. d - 1; step 0 is the drop going
## in, drawn as a wet mouth, and step d is the drop on the exit).
##
## Culled per pair on the segment's bounding box, grown by a stone's
## radius; the cell loop's margin (_visible_draw_rect()) already covers
## the rest.
func _draw_tunnel_routes(visible: Rect2) -> void:
	if level_data.tunnel_pairs.is_empty():
		return
	for entrance in level_data.tunnel_pairs.keys():
		var exit_cell: Vector2i = level_data.tunnel_pairs[entrance]
		if not _tunnel_route_visible(entrance, exit_cell, visible):
			continue
		var from := Hex.axial_to_pixel(entrance)
		var to := Hex.axial_to_pixel(exit_cell)
		# The dashed line runs between the arch glyphs, not through them --
		# and stops short of the exit's first-move arrow when that arrow
		# points back along the route, so the one arrow on the line never
		# reads as the underground water running exit-to-entrance.
		var dir_vec := (to - from).normalized()
		var inset := Hex.SIZE * 0.55
		var exit_inset := inset
		var arrow_dir := _tunnel_exit_arrow_vector(exit_cell)
		if arrow_dir != Vector2.ZERO and arrow_dir.dot(-dir_vec) > 0.8:
			exit_inset = Hex.SIZE * (TUNNEL_ARROW_TO + 0.15)
		if from.distance_to(to) > inset + exit_inset:
			draw_dashed_line(from + dir_vec * inset, to - dir_vec * exit_inset,
				TUNNEL_ROUTE_COLOR, 3.0, 8.0, true, true)
		for stone in _tunnel_stones(entrance, exit_cell):
			_draw_tunnel_stone(stone["at"], stone["lit"], stone["dir"])


## The stepping stones that surface water would otherwise hide, drawn again
## on top of it once the water is down (_draw()). The route is drawn under
## the water so the dashed line never crosses a stream, but a stone is the
## thing the player counts -- and the one that lights up -- so a stone
## that overlaps a wet cell comes back over it, the same way _draw_water()
## puts a block's glyph back on top. `wet` is _draw()'s set of wet cells.
func _draw_tunnel_stones_over_water(visible: Rect2, wet: Dictionary) -> void:
	if level_data.tunnel_pairs.is_empty() or wet.is_empty():
		return
	# A stone overlaps a hex's water sprite when it is closer to the centre
	# than the hex's corner radius plus its own.
	var reach := Hex.SIZE + Hex.SIZE * TUNNEL_STONE_RADIUS
	for entrance in level_data.tunnel_pairs.keys():
		var exit_cell: Vector2i = level_data.tunnel_pairs[entrance]
		if not _tunnel_route_visible(entrance, exit_cell, visible):
			continue
		for stone in _tunnel_stones(entrance, exit_cell):
			var at: Vector2 = stone["at"]
			var near := Hex.pixel_to_axial(at)
			for offset in [Vector2i.ZERO] + Hex.NEIGHBOR_OFFSETS:
				var cell: Vector2i = near + offset
				if wet.has(cell) and Hex.axial_to_pixel(cell).distance_to(at) < reach:
					_draw_tunnel_stone(at, stone["lit"], stone["dir"])
					break


## True if the route between `entrance` and `exit_cell` can put a pixel
## inside `visible` -- its segment's bounding box, grown by a stone.
func _tunnel_route_visible(entrance: Vector2i, exit_cell: Vector2i, visible: Rect2) -> bool:
	var from := Hex.axial_to_pixel(entrance)
	var bounds := Rect2(from, Vector2.ZERO).expand(Hex.axial_to_pixel(exit_cell))
	return visible.intersects(bounds.grow(Hex.SIZE * TUNNEL_STONE_RADIUS * 2.0))


## One pair's stepping stones, entrance end first: d - 1 of them evenly
## spaced between the two centres, each {"at": Vector2, "lit": bool,
## "dir": Vector2}; lit while an in-flight drop is at that step (see
## _draw_tunnel_routes()), and "dir" the unit vector toward the exit that
## its chevron points along.
func _tunnel_stones(entrance: Vector2i, exit_cell: Vector2i) -> Array[Dictionary]:
	var from := Hex.axial_to_pixel(entrance)
	var to := Hex.axial_to_pixel(exit_cell)
	var toward_exit := (to - from).normalized()
	var d: int = _cube_distance(exit_cell - entrance)
	var lit := {}
	for transit in tunnel_transit:
		if transit["entrance"] == entrance:
			lit[water_beat - (transit["entered"] as int)] = true
	var stones: Array[Dictionary] = []
	for step in range(1, d):
		stones.append({"at": from.lerp(to, float(step) / float(d)), "lit": lit.has(step),
			"dir": toward_exit})
	return stones


## One stepping stone: an earthy disc rimmed in limestone with a chevron
## pointing `toward_exit`, or, lit, a water-blue disc rimmed in navy with a
## white chevron -- dark rim on pale froth, so a lit stone over a surface
## stream still reads.
func _draw_tunnel_stone(at: Vector2, lit: bool, toward_exit: Vector2) -> void:
	var radius := Hex.SIZE * TUNNEL_STONE_RADIUS
	if lit:
		draw_circle(at, radius, TUNNEL_STONE_LIT_COLOR, true, -1.0, true)
		draw_arc(at, radius, 0.0, TAU, 20, TUNNEL_STONE_LIT_OUTLINE, 3.0, true)
	else:
		draw_circle(at, radius, TUNNEL_STONE_COLOR, true, -1.0, true)
		draw_arc(at, radius, 0.0, TAU, 20, TUNNEL_STONE_OUTLINE, 2.0, true)
	if toward_exit == Vector2.ZERO:
		return
	var perp := Vector2(-toward_exit.y, toward_exit.x)
	var tip := at + toward_exit * (radius * 0.45)
	var tail := at - toward_exit * (radius * 0.25)
	var chevron := PackedVector2Array([tail + perp * (radius * 0.5), tip, tail - perp * (radius * 0.5)])
	draw_polyline(chevron, TUNNEL_STONE_LIT_CHEVRON if lit else TUNNEL_STONE_OUTLINE, 2.5, true)


## The unit vector of tunnel exit `exit_cell`'s pre-Start first-move arrow,
## or Vector2.ZERO when no arrow is drawn there: after Start, when the
## flow preview already reaches the exit (it draws that segment in amber),
## or when the spring is boxed in (_tunnel_exit_first_move()).
func _tunnel_exit_arrow_vector(exit_cell: Vector2i) -> Vector2:
	if not show_flow_preview or _preview_from_cells.has(exit_cell):
		return Vector2.ZERO
	var first_move := _tunnel_exit_first_move(exit_cell)
	if first_move == Vector2i.ZERO:
		return Vector2.ZERO
	return (Hex.axial_to_pixel(exit_cell + first_move) - Hex.axial_to_pixel(exit_cell)).normalized()


## Every tunnel exit's pre-Start first-move arrow -- the exit is a spring,
## so before Start it shows which way its water will fall, the way a
## dormant geyser does, resolved against the blocks on the board
## (_tunnel_exit_first_move()). Bolder than the geyser's and cased, and
## clear of the exit's glyph: TUNNEL_ARROW_FROM .. TUNNEL_ARROW_TO.
func _draw_tunnel_exit_arrows(visible: Rect2) -> void:
	if level_data.tunnel_pairs.is_empty():
		return
	var drawn := {}
	for exit_cell in level_data.tunnel_pairs.values():
		if drawn.has(exit_cell):
			continue # two entrances can share one exit
		drawn[exit_cell] = true
		var center := Hex.axial_to_pixel(exit_cell)
		if not visible.has_point(center):
			continue
		var dir_vec := _tunnel_exit_arrow_vector(exit_cell)
		if dir_vec == Vector2.ZERO:
			continue
		var arrow_start := center + dir_vec * (Hex.SIZE * TUNNEL_ARROW_FROM)
		var arrow_end := center + dir_vec * (Hex.SIZE * TUNNEL_ARROW_TO)
		var back := -dir_vec * (Hex.SIZE * 0.24)
		var perp := Vector2(-dir_vec.y, dir_vec.x) * (Hex.SIZE * 0.17)
		var shape := PackedVector2Array([arrow_end + back + perp, arrow_end, arrow_end + back - perp])
		draw_line(arrow_start, arrow_end, TUNNEL_ARROW_CASING, 8.0, true)
		draw_polyline(shape, TUNNEL_ARROW_CASING, 8.0, true)
		draw_circle(arrow_end, 4.0, TUNNEL_ARROW_CASING, true, -1.0, true)
		draw_line(arrow_start, arrow_end, TUNNEL_ARROW_COLOR, 4.0, true)
		draw_polyline(shape, TUNNEL_ARROW_COLOR, 4.0, true)


## True if this water cell is the front of its stream -- nothing wet in any
## of the cells it would flow into next. Branch-aware for free: a Splitter's
## two arms each end in their own lead. Presentation only; the simulation
## neither knows nor cares which cell this is.
func _is_lead_water(coord: Vector2i, wet: Dictionary) -> bool:
	if level_data.grid_style == "flat":
		return not (wet.has(coord + Hex.FLAT_DOWN)
			or wet.has(coord + Hex.FLAT_DOWN_LEFT)
			or wet.has(coord + Hex.FLAT_DOWN_RIGHT))
	return not (wet.has(coord + Hex.DOWN_LEFT) or wet.has(coord + Hex.DOWN_RIGHT))
