extends SceneTree

## Measures how FORGIVING each level is: how many different placements win,
## not merely whether the one documented solution still does.
##
##   godot --headless --path game --script res://tools/solution_space.gd \
##         -- ../level-solutions.md [levels...]
##
## The design intent is that a level ships more tiles than it strictly
## needs, so several placements solve it and the player is not hunting one
## exact combinatorial answer. That makes "does the documented solution
## win?" the wrong health check -- a level with exactly one winning
## placement passes that check while being precisely the puzzle the design
## was trying to avoid. This counts the winning placements instead.
##
## Depth-1 levels are searched exhaustively: every block type in every
## cell. Depth-2 levels are measured for LOCAL breadth instead -- hold one
## documented placement, move the other, and count the wins, both ways
## round. An exhaustive pair search is millions of runs; local breadth is
## a few hundred and answers the question that matters anyway, which is
## how much freedom the player has around a known answer. The two numbers
## are not directly comparable across depths, so the depth is printed.
## Digs are replayed as documented -- they are the level's channel, not a
## choice.
##
## Health bands, reported per level:
##   BROKEN    0 winning placements -- unsolvable as shipped
##   KNIFE     1 -- exactly one answer, the failure mode described above
##   TIGHT     2-3
##   OK        4+

const BLOCK_NAMES := {
	"wall": "wall", "splitter": "splitter",
	"divert-right": "divert_right", "diverter-right": "divert_right",
	"divert-left": "divert_left", "diverter-left": "divert_left",
	"catapult": "bomb_catapult", "bomb-catapult": "bomb_catapult",
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <path-to-level-solutions.md> [levels...]")
		quit(2)
		return

	var path: String = args[0]
	if path.is_relative_path():
		path = ProjectSettings.globalize_path("res://").path_join(path).simplify_path()

	var only := []
	for i in range(1, args.size()):
		if args[i].is_valid_int():
			only.append(int(args[i]))

	var sim := FFSim.new()
	get_root().add_child(sim)
	var catalog := FFSim.load_block_catalog()
	var sols := _parse(path)

	var bands := {"BROKEN": [], "KNIFE": [], "TIGHT": [], "OK": []}

	for level in range(1, 101):
		if not only.is_empty() and not only.has(level):
			continue
		if not sols.has(level):
			continue
		var sol: Dictionary = sols[level]
		var depth: int = sol["placements"].size()
		if depth == 0 or depth > 2:
			continue # pure-dig or deep solutions: not a placement puzzle

		var level_path := "res://data/levels/level_%03d.tres" % level
		var data: LevelData = load(level_path)
		if data == null:
			continue

		var cells := _playable(data, catalog)
		var blocks := _available(data, catalog)
		var cap: int = mini(200, maxi(60, sol["win"] * 3 + 20))

		var wins := 0
		var examples := []
		if depth == 1:
			for b in blocks:
				for c in cells:
					if _wins(sim, level_path, [{"coord": c, "block": b}], sol, cap):
						wins += 1
						if examples.size() < 3:
							examples.append("%s (%d, %d)" % [b, c.x, c.y])
		else:
			# Local breadth: hold one documented placement, move the other.
			for moved in 2:
				var fixed: Dictionary = sol["placements"][1 - moved]
				for b in blocks:
					for c in cells:
						if c == fixed["coord"]:
							continue
						var trial := []
						trial.resize(2)
						trial[1 - moved] = fixed
						trial[moved] = {"coord": c, "block": b}
						if _wins(sim, level_path, trial, sol, cap):
							wins += 1
							if examples.size() < 3:
								examples.append("%s (%d, %d)" % [b, c.x, c.y])

		var band := "BROKEN" if wins == 0 else ("KNIFE" if wins == 1 else ("TIGHT" if wins <= 3 else "OK"))
		bands[band].append(level)
		print("%3d  %-6s %4d winning placement(s)  depth %d  %s" % [
			level, band, wins, depth, ", ".join(examples)])

	print("\n================ solution-space health ================")
	for b in ["BROKEN", "KNIFE", "TIGHT", "OK"]:
		print("%-7s %3d  %s" % [b, bands[b].size(), str(bands[b])])
	quit(0)


func _wins(sim: FFSim, level_path: String, trial: Array, sol: Dictionary, cap: int) -> bool:
	var plan := {"placements": trial, "max_measures": cap}
	if not sol["digs"].is_empty():
		plan["digs"] = sol["digs"]
	var r: Dictionary = sim.run(level_path, plan)
	return r["outcome"] == "win" and r["placements_rejected"].is_empty()


func _playable(data: LevelData, catalog: Dictionary) -> Array:
	var board := HexBoard.new()
	get_root().add_child(board)
	board.setup(data, catalog)
	var cells := []
	var rad: int = data.grid_radius
	for q in range(-rad, rad + 1):
		for r in range(-rad, rad + 1):
			if board.in_playable_area(Vector2i(q, r)):
				cells.append(Vector2i(q, r))
	get_root().remove_child(board)
	board.free()
	return cells


func _available(data: LevelData, catalog: Dictionary) -> Array:
	if data.total_block_budget > 0:
		return catalog.keys()
	var ids := []
	for bid in data.starting_inventory:
		if (data.starting_inventory[bid] as int) > 0:
			ids.append(bid)
	return ids


func _parse(path: String) -> Dictionary:
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
				placements.append({"coord": Vector2i(int(p.get_string(2)), int(p.get_string(3))),
					"block": BLOCK_NAMES[n]})
		var digs := []
		for c in coord_re.search_all(dig_part):
			digs.append(Vector2i(int(c.get_string(1)), int(c.get_string(2))))
		out[int(m.get_string(1))] = {"body": body, "win": int(m.get_string(3)),
			"placements": placements, "digs": digs}
	return out
