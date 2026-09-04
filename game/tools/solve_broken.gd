extends SceneTree

## Searches for replacement solutions on levels whose documented solution no
## longer wins, and prints them in level-solutions.md's own format.
##
##   godot --headless --path game --script res://tools/solve_broken.gd \
##         -- ../level-solutions.md [levels...]
##
## With no level numbers it re-solves the 27 levels the 2-wide Wall change
## broke. Give explicit numbers to work on a subset.
##
## Strategy: keep as much of the author's original solution as possible.
## Every non-wall placement and every dug cell stays exactly where it was --
## only the wall positions are re-searched, since the Wall's footprint is
## the only thing that changed. That keeps each level teaching the mechanic
## it was designed around instead of quietly turning into a different
## puzzle.
##
## If no wall position wins, it widens to a general search over everything
## the level's own inventory allows -- any block type, any cell, one then
## two placements -- because a level can hold blocks its documented
## solution never used (level 1 ships 2 Diverter-Rights and a Diverter-Left
## alongside its wall).
##
## Candidates are every cell of the playable area; HexBoard.place_block()
## rejects the illegal ones itself (on a source, on terrain, footprint
## doesn't fit), so legality is the engine's judgement, not a guess here.
## Among winning candidates, the one closest to the documented measure
## count wins -- a level's pacing was designed too, so a solution that
## still wins on the original beat is worth more than a faster one.

const DEFAULT_BROKEN := [1, 2, 6, 10, 11, 12, 17, 32, 33, 54, 64, 66, 67, 68,
	69, 81, 82, 83, 85, 86, 91, 92, 93, 94, 96, 97, 98]

const BLOCK_NAMES := {
	"wall": "wall", "splitter": "splitter",
	"divert-right": "divert_right", "diverter-right": "divert_right",
	"divert-left": "divert_left", "diverter-left": "divert_left",
	"catapult": "bomb_catapult", "bomb-catapult": "bomb_catapult",
}

## Printed names, so regenerated lines match the file's existing style.
const PRETTY := {
	"wall": "wall", "splitter": "splitter",
	"divert_right": "divert-right", "divert_left": "divert-left",
	"bomb_catapult": "catapult",
}

var _sim: FFSim
var _catalog: Dictionary


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <path-to-level-solutions.md> [level numbers...]")
		quit(2)
		return

	var path: String = args[0]
	if path.is_relative_path():
		path = ProjectSettings.globalize_path("res://").path_join(path).simplify_path()

	var targets: Array = []
	for i in range(1, args.size()):
		if args[i].is_valid_int():
			targets.append(int(args[i]))
	if targets.is_empty():
		targets = DEFAULT_BROKEN

	_sim = FFSim.new()
	get_root().add_child(_sim)
	_catalog = FFSim.load_block_catalog()

	var solutions := _parse_solutions(path)
	var solved := []
	var unsolved := []

	for level in targets:
		if not solutions.has(level):
			unsolved.append("%3d  no documented solution to work from" % level)
			continue
		var res := _solve(level, solutions[level])
		if res.is_empty():
			unsolved.append("%3d  no winning placement found" % level)
			print("  %3d  FAILED" % level)
		else:
			solved.append(res)
			print("  %3d  %s | win %d  (was: %s | win %d)" % [
				level, res["text"], res["measures"],
				solutions[level]["body"], solutions[level]["win"]])

	print("\n================ re-solve results ================")
	print("solved   : %d" % solved.size())
	print("unsolved : %d" % unsolved.size())
	if not unsolved.is_empty():
		print("\n--- UNSOLVED ---")
		for u in unsolved:
			print("  " + u)

	print("\n--- REPLACEMENT SOLUTION LINES ---")
	for s in solved:
		print("%d|%s|%d" % [s["level"], s["text"], s["measures"]])

	quit(0)


func _parse_solutions(path: String) -> Dictionary:
	var out := {}
	var line_re := RegEx.create_from_string(
		"^- \\*\\*(?:Level )?(\\d+)\\.?[^*]*\\*\\*(?: \\([^)]*\\))? — (.+?) \\| win (\\d+)\\s*$")
	var placement_re := RegEx.create_from_string("([A-Za-z][A-Za-z-]*)\\s*\\((-?\\d+),\\s*(-?\\d+)\\)")
	var coord_re := RegEx.create_from_string("\\((-?\\d+),\\s*(-?\\d+)\\)")

	for line in FileAccess.get_file_as_string(path).split("\n"):
		var m := line_re.search(line)
		if m == null:
			continue
		var body := m.get_string(2)
		var dig_at := body.find("dig")
		var place_part := body if dig_at == -1 else body.substr(0, dig_at)
		var dig_part := "" if dig_at == -1 else body.substr(dig_at)

		var placements := []
		for p in placement_re.search_all(place_part):
			var n := p.get_string(1).to_lower()
			if BLOCK_NAMES.has(n):
				placements.append({
					"coord": Vector2i(int(p.get_string(2)), int(p.get_string(3))),
					"block": BLOCK_NAMES[n],
				})
		var digs := []
		for c in coord_re.search_all(dig_part):
			digs.append(Vector2i(int(c.get_string(1)), int(c.get_string(2))))

		out[int(m.get_string(1))] = {
			"body": body, "win": int(m.get_string(3)),
			"placements": placements, "digs": digs,
		}
	return out


## Every cell inside the level's playable area, asked of the engine itself.
func _playable_cells(data: LevelData) -> Array:
	var board := HexBoard.new()
	get_root().add_child(board)
	board.setup(data, _catalog)
	var cells := []
	var rad: int = data.grid_radius
	for q in range(-rad, rad + 1):
		for r in range(-rad, rad + 1):
			var c := Vector2i(q, r)
			if board.in_playable_area(c):
				cells.append(c)
	get_root().remove_child(board)
	board.free()
	return cells


func _solve(level: int, sol: Dictionary) -> Dictionary:
	var level_path := "res://data/levels/level_%03d.tres" % level
	var data: LevelData = load(level_path)
	if data == null:
		return {}

	var placements: Array = sol["placements"]
	var wall_slots := []
	for i in placements.size():
		if placements[i]["block"] == "wall":
			wall_slots.append(i)
	if wall_slots.is_empty():
		return {}

	var cells := _playable_cells(data)
	var cap: int = mini(200, maxi(60, sol["win"] * 3 + 20))
	var best := {}

	# One wall: try every cell. Two walls: hold each documented position in
	# turn and search the other, then fall back to the full cross product.
	var candidate_sets: Array = []
	if wall_slots.size() == 1:
		for c in cells:
			candidate_sets.append([c])
	else:
		for keep in wall_slots.size():
			for c in cells:
				var combo := []
				for i in wall_slots.size():
					combo.append(placements[wall_slots[i]]["coord"] if i == keep else c)
				candidate_sets.append(combo)
		for a in cells:
			for b in cells:
				if a != b:
					candidate_sets.append([a, b])

	for combo in candidate_sets:
		var trial := []
		for i in placements.size():
			var slot := wall_slots.find(i)
			trial.append({
				"coord": combo[slot] if slot != -1 else placements[i]["coord"],
				"block": placements[i]["block"],
			})
		var plan := {"placements": trial, "max_measures": cap}
		if not sol["digs"].is_empty():
			plan["digs"] = sol["digs"]
		var r: Dictionary = _sim.run(level_path, plan)
		if r["outcome"] != "win" or r["placements_rejected"].size() > 0:
			continue
		# Closest to the documented pacing wins; ties break toward fewer measures.
		var delta: int = absi(r["measures"] - sol["win"])
		if best.is_empty() or delta < best["delta"] or (delta == best["delta"] and r["measures"] < best["measures"]):
			best = {"delta": delta, "measures": r["measures"], "trial": trial}

	# Widen: the documented solution may simply no longer be achievable with
	# a wall at all. Search everything the level's inventory permits, at one
	# placement then two, keeping the documented digs.
	if best.is_empty():
		best = _general_search(level_path, data, sol, cells, cap)

	if best.is_empty():
		return {}

	var parts := []
	for p in best["trial"]:
		parts.append("%s (%d, %d)" % [PRETTY[p["block"]], p["coord"].x, p["coord"].y])
	var text: String = " + ".join(parts)
	if not sol["digs"].is_empty():
		var dparts := []
		for d in sol["digs"]:
			dparts.append("(%d, %d)" % [d.x, d.y])
		text += " + dig %d cells: [%s]" % [sol["digs"].size(), ", ".join(dparts)]

	return {"level": level, "text": text, "measures": best["measures"]}


## What this level lets the player place: the per-type starting inventory,
## or the whole catalog when a Jamboree budget is set (see
## LevelData.total_block_budget).
func _available_blocks(data: LevelData) -> Array:
	if data.total_block_budget > 0:
		return _catalog.keys()
	var ids := []
	for bid in data.starting_inventory:
		if (data.starting_inventory[bid] as int) > 0:
			ids.append(bid)
	return ids


## Brute-force search over the level's own inventory, one placement then
## two. Deliberately capped at two: beyond that the search explodes and a
## three-block solution is not really the same puzzle any more.
func _general_search(level_path: String, data: LevelData, sol: Dictionary,
		cells: Array, cap: int) -> Dictionary:
	var blocks := _available_blocks(data)
	if blocks.is_empty():
		return {}

	var singles := []
	for b in blocks:
		for c in cells:
			singles.append({"coord": c, "block": b})

	var best := {}
	for one in singles:
		best = _try(level_path, [one], sol, cap, best)
	if not best.is_empty():
		return best

	for i in singles.size():
		for j in range(i + 1, singles.size()):
			if singles[i]["coord"] == singles[j]["coord"]:
				continue
			best = _try(level_path, [singles[i], singles[j]], sol, cap, best)
	return best


## Runs one candidate placement list and keeps it if it wins and is closer
## to the documented pacing than whatever is best so far.
func _try(level_path: String, trial: Array, sol: Dictionary, cap: int,
		best: Dictionary) -> Dictionary:
	var plan := {"placements": trial, "max_measures": cap}
	if not sol["digs"].is_empty():
		plan["digs"] = sol["digs"]
	var r: Dictionary = _sim.run(level_path, plan)
	if r["outcome"] != "win" or r["placements_rejected"].size() > 0:
		return best
	var delta: int = absi(r["measures"] - sol["win"])
	if best.is_empty() or delta < best["delta"] or (delta == best["delta"] and r["measures"] < best["measures"]):
		return {"delta": delta, "measures": r["measures"], "trial": trial}
	return best
