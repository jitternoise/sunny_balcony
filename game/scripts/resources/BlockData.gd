extends Resource
class_name BlockData

## Defines one placeable block type. Create one .tres per block type under
## res://data/blocks/ -- add a new block by duplicating an existing .tres
## and changing its fields, no script changes needed.

enum TickBehavior {
	WALL,         # Fully blocks water; water backs up against it each tick.
	              # The shipped Wall is 2 tiles wide -- see footprint_offsets
	              # below and wall.tres.
	DIVERT_LEFT,  # Redirects water to the down-left neighbor.
	DIVERT_RIGHT, # Redirects water to the down-right neighbor.
	SPLIT,        # Sends water to both down neighbors at once.
	ABSORB,       # Reserved for future block-based pool targets.
	# Bomb Catapult: for WATER purposes behaves exactly like WALL (fully
	# blocks, water backs up against it) -- see HexBoard._resolve_block_targets().
	# Its actual gameplay (clearing a 7-cell cluster of dirt on a
	# press-and-hold-to-aim, release-to-fire player tap) is handled entirely
	# outside the tick simulation -- see HexBoard.fire_catapult() and
	# Level.gd's press/drag/release aiming state machine. A separate enum
	# value (rather than just reusing WALL) exists so place_block()/Level.gd
	# can tell "this is a catapult, route taps to the aim-and-fire handler
	# instead of pickup" apart from an ordinary Wall block.
	CATAPULT,
}

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D

## The same glyph redrawn for a "flat" grid, or null when one orientation's
## art serves both. Only blocks whose glyph states a DIRECTION need it: a
## Diverter's exit bearing is 30 degrees off vertical on a pointy grid and
## 30 degrees off HORIZONTAL on a flat one (see Hex.axial_to_pixel() and
## HexBoard._block_target_offsets()), so one arrow cannot be right on both.
## A centred, direction-free glyph -- the Wall's boulder, the Catapult --
## leaves this unset and is drawn from `icon` on every level.
##
## Read through glyph() rather than directly, so an unset one falls back.
@export var icon_flat: Texture2D
@export var behavior: TickBehavior = TickBehavior.WALL
@export var color: Color = Color.WHITE # placeholder visual until real art exists

## Extra cells this block occupies beyond the one the player taps, as axial
## offsets from that anchor cell. Empty (the default) means an ordinary
## single-cell block -- exactly how every block behaved before this field
## existed, so Diverters, the Splitter and the Bomb Catapult are untouched.
## The shipped Wall sets [Vector2i(1, 0)], making it 2 tiles wide: it covers
## the tapped cell plus its right-hand neighbour, for one inventory slot.
##
## Every occupied cell gets its own placed_blocks entry, so the water
## simulation, _resolve_block_targets() and _is_wall() each treat a half
## exactly like the whole block with no special-casing -- only placement,
## pickup and the preset guard need to know about the grouping, which they
## do via HexBoard.block_footprint()/block_anchor_at()/block_anchors.
##
## HexBoard.place_block() retries a MIRRORED footprint (each offset's x
## negated) when the preferred one doesn't fit, so a 2-wide block can still
## be placed hard against the right-hand wall of a corridor.
##
## Note this is only sensible on a block whose behaviour is the same from
## every cell it covers -- WALL and CATAPULT qualify. Giving a DIVERT or
## SPLIT block a footprint would make each half redirect water separately,
## which is almost certainly not what you want.
@export var footprint_offsets: Array[Vector2i] = []


## This block's glyph for the grid it is being drawn on. Every draw site
## goes through here: HexBoard's placed, ghosted and preset blocks, and the
## inventory bar's HexTileIcon.
func glyph(flat: bool) -> Texture2D:
	if flat and icon_flat != null:
		return icon_flat
	return icon
