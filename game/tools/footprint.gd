extends SceneTree

## Prints, per level, the cells a grid reshape must NOT block: every cell the
## water visits on the bare run (b), under the documented solution (w, B for
## both), on the hydro-bonus route (h, the union over every activation delay
## that earns it), every cell a documented block really covers (x -- the
## Wall's second half after any mirroring), and the terrain -- a tunnel's
## entrance is I and its exit O (LevelData.tunnel_pairs).
##
##   godot --headless --path game --script res://tools/footprint.gd
##
## Reads ../level-solutions.md with the same line grammar as
## verify_solutions.gd. Rows are printed in offset columns -3..2 (odd rows
## indented half a cell), so the map reads like the board. A cell that is
## "." on every line can go into blocked_cells without changing a single
## replay, because natural fall only ever tries a cell it would then enter;
## everything else changes how the level plays. Used for the 2026-09-21
## silhouettes (see CLAUDE.md, "no two neighbours share a silhouette").
##
## Levels 13-17, 19, 20 and 22 are not listed: corridors and the flat grid
## were never reshaped.
const BLOCK_NAMES := {"wall": "wall", "splitter": "splitter",
	"divert-right": "divert_right", "diverter-right": "divert_right",
	"divert-left": "divert_left", "diverter-left": "divert_left",
	"catapult": "bomb_catapult", "bomb-catapult": "bomb_catapult"}
const LEVELS := [1,2,3,4,5,6,7,8,9,10,11,12,18,21,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50]

func _init() -> void:
	var catalog := FFSim.load_block_catalog()
	var sols := _parse_solutions()
	for lv in LEVELS:
		var data: LevelData = load("res://data/levels/level_%03d.tres" % lv)
		var bare := _trace(data, catalog, {})
		var plan: Dictionary = sols.get(lv, {})
		var sol := _trace(data, catalog, plan)
		var hydro := {}
		if not data.hydro_plant_cells.is_empty():
			for delay in range(0, 8):
				var h := _trace(data, catalog, plan, delay)
				if h["earned"]:
					for c in h["visited"]: hydro[c] = true
		var keep := {}
		for c in bare["visited"]: keep[c] = "b"
		for c in sol["visited"]: keep[c] = "w" if not keep.has(c) else "B"
		for c in hydro: if not keep.has(c): keep[c] = "h"
		var place := {}
		for c in sol["placed"]: place[c] = true
		var digs := {}
		for c in plan.get("digs", []): digs[c] = true
		print("== level %d  bare=%s@%d  sol=%s@%d  placements=%s" % [lv, bare["outcome"], bare["measures"], sol["outcome"], sol["measures"], str(plan.get("placements", []))])
		_print_map(data, keep, place, digs)
	quit()

func _parse_solutions() -> Dictionary:
	var path := ProjectSettings.globalize_path("res://").path_join("../level-solutions.md").simplify_path()
	var line_re := RegEx.create_from_string("^- \\*\\*(?:Level )?(\\d+)\\.?[^*]*\\*\\*(?: \\([^)]*\\))? — (.+?) \\| win (\\d+)\\s*$")
	var placement_re := RegEx.create_from_string("([A-Za-z][A-Za-z-]*)\\s*\\((-?\\d+),\\s*(-?\\d+)\\)")
	var coord_re := RegEx.create_from_string("\\((-?\\d+),\\s*(-?\\d+)\\)")
	var out := {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var m := line_re.search(line)
		if m == null: continue
		var body := m.get_string(2)
		var dig_at := body.find("dig")
		var place_part := body if dig_at == -1 else body.substr(0, dig_at)
		var dig_part := "" if dig_at == -1 else body.substr(dig_at)
		var placements := []
		for p in placement_re.search_all(place_part):
			var name := p.get_string(1).to_lower()
			if not BLOCK_NAMES.has(name): continue
			placements.append({"coord": Vector2i(int(p.get_string(2)), int(p.get_string(3))), "block": BLOCK_NAMES[name]})
		var digs := []
		for c in coord_re.search_all(dig_part):
			digs.append(Vector2i(int(c.get_string(1)), int(c.get_string(2))))
		var plan := {}
		if not placements.is_empty(): plan["placements"] = placements
		if not digs.is_empty(): plan["digs"] = digs
		out[int(m.get_string(1))] = plan
	return out

func _trace(level_data: LevelData, catalog: Dictionary, plan: Dictionary, activate_delay: int = -1) -> Dictionary:
	var data: LevelData = level_data.duplicate(true)
	var board: HexBoard = HexBoard.new()
	root.add_child(board)
	board.setup(data, catalog)
	var won := [false]; var lost := [false]
	board.level_won.connect(func(): won[0] = true)
	board.level_lost.connect(func(): lost[0] = true)
	for p in plan.get("placements", []):
		board.place_block(p["coord"], p["block"])
	var placed := board.block_anchors.keys()
	for p in plan.get("placements", []):
		if not placed.has(p["coord"]): placed.append(p["coord"])
	board.started = true
	var digs: Array = plan.get("digs", []).duplicate()
	var visited := {}
	var measures := 0
	var activated := false
	var ready_since := -1
	var target: Vector2i = data.hydro_plant_cells[0] if not data.hydro_plant_cells.is_empty() else Vector2i.MAX
	while measures < (300 if activate_delay >= 0 else 60) and not won[0] and not lost[0]:
		for c in digs:
			for _t in HexBoard.DIG_TAPS_REQUIRED: board.dig(c)
		digs.clear()
		board.resolve_placement_phase()
		board.resolve_water_phase()
		for w in board.water_cells: visited[w["coord"]] = true
		if activate_delay >= 0 and not activated and target != Vector2i.MAX and board.hydro_ready_at(target):
			if ready_since < 0: ready_since = measures
			if measures - ready_since >= activate_delay:
				activated = board.try_activate_hydro(target)
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		measures += 1
	var outcome := "win" if won[0] else ("loss" if lost[0] else "timeout")
	var earned: bool = activated and won[0] and board.all_hydro_plants_running()
	board.queue_free()
	return {"visited": visited.keys(), "outcome": outcome, "measures": measures, "earned": earned, "placed": placed}

func _print_map(data: LevelData, keep: Dictionary, place: Dictionary, digs: Dictionary) -> void:
	var R: int = data.grid_radius
	var marks := {}
	for c in data.water_sources: marks[c] = "S"
	for c in data.fire_cells: marks[c] = "F"
	for c in data.town_cells: marks[c] = "T"
	for c in data.geyser_cells: marks[c] = "G"
	for c in data.hydro_plant_cells: marks[c] = "H"
	for c in data.dirt_cells: if not marks.has(c): marks[c] = "D"
	for c in data.pool_targets: marks[c] = "P"
	for a in data.lake_cells: for c in data.lake_cells[a]: if not marks.has(c): marks[c] = "L"
	for c in data.preset_blocks: if not marks.has(c): marks[c] = "X"
	for e in data.tunnel_pairs:
		marks[e] = "I"
		marks[data.tunnel_pairs[e]] = "O"
	for r in range(-R, R + 1):
		var cells := {}
		for q in range(-R, R + 1):
			var c := Vector2i(q, r)
			if maxi(absi(q), maxi(absi(r), absi(-q - r))) > R: continue
			if data.blocked_cells.has(c): continue
			var col: int = q + (r - (r & 1)) / 2
			var ch := "."
			if marks.has(c): ch = marks[c]
			elif place.has(c): ch = "x"
			elif digs.has(c): ch = "d"
			elif keep.has(c): ch = keep[c]
			cells[col] = ch
		if cells.is_empty(): continue
		var line := ""
		for col in range(-3, 3):
			line += (cells[col] if cells.has(col) else " ") + "   "
		print("  r=%+d %s|%s" % [r, "  " if (r & 1) else "", line.rstrip(" ")])

