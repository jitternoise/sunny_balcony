class_name FFSim
extends Node

## Headless simulation core. Drives a real HexBoard through the real beat
## cycle with no UI, no timer and no display, so a level can be played
## programmatically -- by a solution verifier, a level generator, or a
## regression suite.
##
## The whole point is that this is NOT a re-implementation of the game's
## rules. It instantiates the shipped HexBoard.gd and calls the same four
## phase functions Level.gd calls, in the same order. Anything it reports
## is what the game itself does. The project's earlier verification work
## used a from-scratch Python port instead, which drifted from the engine
## at least once (Python's banker's round() vs GDScript's roundf(), which
## silently moved every corridor level's band centre by one column on odd
## rows -- see dev-progress.md 2026-08-17). Driving the engine directly
## makes that class of divergence structurally impossible.
##
## Usage:
##   var sim := FFSim.new()
##   add_child(sim)                     # needs to be in the tree
##   var r := sim.run("res://data/levels/level_001.tres", {
##       "placements": [{"coord": Vector2i(-1, -3), "block": "wall"}],
##   })
##   print(r.outcome, r.measures)

## Safety net for candidate levels that neither win nor lose. The
## generator's idle-run check uses 300; solution runs need far fewer.
const DEFAULT_MAX_MEASURES := 300

var _catalog: Dictionary = {}


func _init() -> void:
	_catalog = load_block_catalog()


## Mirrors Level.gd's _load_block_catalog() -- every BlockData in the
## catalog directory, keyed by its id.
static func load_block_catalog() -> Dictionary:
	var catalog := {}
	for f in DirAccess.get_files_at("res://data/blocks/"):
		if f.ends_with(".tres"):
			var block: BlockData = load("res://data/blocks/" + f)
			if block != null:
				catalog[block.id] = block
	return catalog


## Plays one level and reports what happened.
##
## `plan` keys, all optional:
##   placements  Array of {"coord": Vector2i, "block": String}, applied
##               before Start (which is when a real player plans).
##   digs        Array of Vector2i dug open after Start -- digging is a
##               during-the-run action and HexBoard.dig() refuses before
##               it (see its `started` guard).
##   dig_rate    Dig cells opened per measure. 0 (default) opens every
##               listed cell immediately on the first measure; a positive
##               value models the real "tap the river forward" pattern.
##   max_measures  Overrides DEFAULT_MAX_MEASURES.
##
## Returns a Dictionary:
##   outcome     "win" | "loss" | "timeout"
##   measures    measures elapsed when it ended
##   reason      HexBoard.LoseReason value, or "" on win/timeout
##   fires_remaining / fires_total
##   pools_full / pools_total
##   placements_rejected  placements HexBoard refused (bad footprint,
##                        empty inventory, on a source, ...) -- a
##                        non-empty list usually means the plan is stale
##                        rather than that the level is unwinnable.
func run(level_path: String, plan: Dictionary = {}) -> Dictionary:
	var data: LevelData = load(level_path)
	if data == null:
		return {"outcome": "error", "reason": "could not load " + level_path,
				"measures": 0, "placements_rejected": []}

	var board: HexBoard = HexBoard.new()
	add_child(board)
	board.setup(data, _catalog)

	var won := [false]
	var lost := [false]
	board.level_won.connect(func(): won[0] = true)
	board.level_lost.connect(func(): lost[0] = true)

	# Planning phase: placements land immediately pre-Start.
	var rejected: Array = []
	for p in plan.get("placements", []):
		if not board.place_block(p["coord"], p["block"]):
			rejected.append("%s at %s" % [p["block"], p["coord"]])

	board.started = true

	var digs: Array = plan.get("digs", []).duplicate()
	var dig_rate: int = plan.get("dig_rate", 0)
	var max_measures: int = plan.get("max_measures", DEFAULT_MAX_MEASURES)

	var measures := 0
	while measures < max_measures and not won[0] and not lost[0]:
		# Digging happens between measures: either the whole channel at
		# once (dig_rate 0) or dig_rate cells per measure.
		var to_dig := digs.size() if dig_rate <= 0 else mini(dig_rate, digs.size())
		for i in to_dig:
			var c: Vector2i = digs.pop_front()
			for _t in HexBoard.DIG_TAPS_REQUIRED:
				board.dig(c)

		# One measure is one pass through the four beat phases -- each
		# phase IS a beat (see Level.gd's BeatPhase enum and
		# _advance_beat(), which runs exactly one of these per sub-tick
		# cycle and wraps after STATUS).
		board.resolve_placement_phase()
		board.resolve_water_phase()
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		measures += 1

	var pools_full := 0
	for coord in data.pool_targets:
		if (board.pool_fill.get(coord, 0) as int) >= HexBoard.POOL_BEATS_REQUIRED:
			pools_full += 1

	var result := {
		"outcome": "win" if won[0] else ("loss" if lost[0] else "timeout"),
		"measures": measures,
		"reason": board.lose_reason,
		"fires_remaining": board.fires_remaining,
		"fires_total": data.fire_cells.size(),
		"pools_full": pools_full,
		"pools_total": data.pool_targets.size(),
		"placements_rejected": rejected,
	}

	# free(), not queue_free(): these tools run from a SceneTree script
	# where no frames are processed, so a queued free never happens and
	# thousands of boards pile up until the process is killed.
	remove_child(board)
	board.free()
	return result
