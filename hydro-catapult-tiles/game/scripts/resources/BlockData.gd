extends Resource
class_name BlockData

## Defines one placeable block type. Create one .tres per block type under
## res://data/blocks/ -- add a new block by duplicating an existing .tres
## and changing its fields, no script changes needed.

enum TickBehavior {
	WALL,         # Fully blocks water; water backs up against it each tick.
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
@export var behavior: TickBehavior = TickBehavior.WALL
@export var color: Color = Color.WHITE # placeholder visual until real art exists
