extends SceneTree

## Asks, for a level with no remaining solution: what is the smallest
## change to its starting_inventory that makes it solvable again?
##
##   godot --headless --path game --script res://tools/probe_inventory.gd -- 6 64 66
##
## The 2-wide Wall left several levels unsolvable whose only tool is a
## wall -- there is no other block to search, so no solution edit can fix
## them and the level data itself has to change. Rather than guess which
## block to add, this tries each candidate addition and reports which ones
## actually work, with the winning placement and measure count.
##
## Nothing is written. The level resource is mutated in memory only, so the
## .tres on disk is untouched and this is safe to run at any time.

## Blocks worth offering. bomb_catapult is included deliberately: it blocks
## water exactly like a Wall but has no footprint_offsets, so it is a
## drop-in 1-cell replacement for the Wall as it used to behave.
const CANDIDATES := ["divert_right", "divert_left", "splitter", "bomb_catapult"]

const MAX_MEASURES := 120


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var levels := []
	for a in args:
		if a.is_valid_int():
			levels.append(int(a))
	if levels.is_empty():
		print("usage: -- <level numbers...>")
		quit(2)
		return

	var catalog := FFSim.load_block_catalog()

	for level in levels:
		var path := "res://data/levels/level_%03d.tres" % level
		var base: LevelData = load(path)
		if base == null:
			print("%3d  could not load" % level)
			continue

		print("\n=== level %d: %s ===" % [level, base.display_name])
		print("  current inventory: %s" % str(base.starting_inventory))

		var found := false
		for add in CANDIDATES:
			var result := _try_with_extra(base, catalog, add)
			if result.is_empty():
				print("  + %-14s no solution" % add)
			else:
				found = true
				print("  + %-14s SOLVED: %s | win %d" % [add, result["text"], result["measures"]])
		if not found:
			print("  nothing works with one extra block -- needs a layout change")

	quit(0)


## Copies the level, grants one extra block of `extra`, and searches every
## cell for a single placement of it (keeping the level's own wall out of
## it -- if a wall could solve this, solve_broken.gd would have found it).
func _try_with_extra(base: LevelData, catalog: Dictionary, extra: String) -> Dictionary:
	var data: LevelData = base.duplicate(true)
	var inv: Dictionary = data.starting_inventory.duplicate()
	inv[extra] = (inv.get(extra, 0) as int) + 1
	data.starting_inventory = inv

	var rad: int = data.grid_radius
	var best := {}

	for q in range(-rad, rad + 1):
		for r in range(-rad, rad + 1):
			var coord := Vector2i(q, r)
			var res := _run(data, catalog, [{"coord": coord, "block": extra}])
			if res.is_empty():
				continue
			if best.is_empty() or res["measures"] < best["measures"]:
				best = res
				best["text"] = "%s (%d, %d)" % [extra.replace("_", "-"), q, r]
	return best


## One run of one candidate plan. Returns {} unless it wins outright.
func _run(data: LevelData, catalog: Dictionary, placements: Array) -> Dictionary:
	var board := HexBoard.new()
	get_root().add_child(board)
	board.setup(data, catalog)

	var won := [false]
	var lost := [false]
	board.level_won.connect(func(): won[0] = true)
	board.level_lost.connect(func(): lost[0] = true)

	var ok := true
	for p in placements:
		if not board.place_block(p["coord"], p["block"]):
			ok = false
	board.started = true

	var measures := 0
	if ok:
		while measures < MAX_MEASURES and not won[0] and not lost[0]:
			board.resolve_placement_phase()
			board.resolve_water_phase()
			board.resolve_terrain_phase()
			board.resolve_status_phase()
			measures += 1

	get_root().remove_child(board)
	board.free()
	return {"measures": measures} if (ok and won[0]) else {}
