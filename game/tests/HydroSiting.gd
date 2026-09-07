extends Node

## Searches every level for places a Hydro Plant could be added WITHOUT
## changing how the level plays. For each candidate centre cell it runs the
## level's documented solution three ways -- with no plant, with the plant
## inert, and with the plant switched on the moment water reaches it -- and
## keeps only sites where:
##   * the solution still wins on exactly the same measure, plant inert;
##   * water actually reaches the plant, so the bonus can be earned at all;
##   * switching the plant on still wins, so the bonus is not a trap.
## Run from game/:  godot --headless res://tests/HydroSiting.tscn

const CLEARANCE_ROWS := 2 # keep plants clear of a source's landing zone


func _ready() -> void:
	var sim := LevelSim.new()
	add_child(sim)
	var catalog := LevelSim.load_block_catalog()
	var solutions := LevelSim.parse_solutions()
	var max_radius := int(OS.get_environment("MAX_RADIUS")) if OS.get_environment("MAX_RADIUS") != "" else 8

	for n in range(1, LevelSelect.LEVEL_PATHS.size() + 1):
		if not solutions.has(n):
			continue
		var data: LevelData = load(LevelSelect.LEVEL_PATHS[n - 1])
		if data.grid_style == "flat":
			continue # plants are pointy-grid only, per their design notes
		if data.grid_radius > max_radius:
			continue
		var entry: Dictionary = solutions[n]
		var base := sim.simulate(data, catalog, entry["placements"])
		if not base["won"] or base["measures"] != entry["win"]:
			continue # this level's solution does not reproduce; leave it alone

		var hits: Array = []
		for center in _candidate_centers(data, catalog, entry["placements"]):
			var inert := sim.simulate(data, catalog, entry["placements"], center, false)
			if not inert["won"] or inert["measures"] != base["measures"]:
				continue
			if not inert["touched"]:
				continue # water never reaches it, so the bonus is unearnable
			# Try a range of activation timings -- switching the plant on
			# the instant it is ready is only one of the player's options.
			var best := {}
			var any_activated := false
			for delay in range(0, 8):
				var on := sim.simulate(data, catalog, entry["placements"], center, true, 300, delay)
				if not on["activated"]:
					continue
				any_activated = true
				if on["won"]:
					best = {"delay": delay, "measures": on["measures"]}
					break
			if not any_activated:
				continue
			hits.append({
				"center": center,
				"bonus_wins": not best.is_empty(),
				"bonus_measures": best.get("measures", -1),
				"delay": best.get("delay", -1),
			})
		if hits.is_empty():
			continue
		var safe: Array = []
		for h in hits:
			if h["bonus_wins"]:
				safe.append(h)
		print("level %d (r=%d, win %d): %d sites, %d safe with the plant on"
			% [n, data.grid_radius, base["measures"], hits.size(), safe.size()])
		for h in safe:
			print("    center %s -> win %d with plant running (activate %d measures after ready)"
				% [h["center"], h["bonus_measures"], h["delay"]])

	print("done")
	get_tree().quit()


## Every centre cell whose three cells are legal, empty, clear of the
## solution's own placements, and CLEARANCE_ROWS below every source.
func _candidate_centers(data: LevelData, catalog: Dictionary, placements: Array) -> Array:
	var probe := HexBoard.new()
	add_child(probe)
	probe.setup(data, catalog)
	var solution_cells := {}
	for p in placements:
		solution_cells[p["coord"]] = true
		solution_cells[p["coord"] + Vector2i(1, 0)] = true # a Wall is 2 wide
		solution_cells[p["coord"] + Vector2i(-1, 0)] = true
	var out: Array = []
	var radius: int = data.grid_radius
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var center := Vector2i(q, r)
			var ok := true
			for cell in [center + Vector2i(-1, 0), center, center + Vector2i(1, 0)]:
				if not probe.in_playable_area(cell) \
						or probe.cell_terrain.get(cell, HexBoard.CellState.EMPTY) != HexBoard.CellState.EMPTY \
						or data.water_sources.has(cell) \
						or data.preset_blocks.has(cell) \
						or solution_cells.has(cell):
					ok = false
					break
				for source in data.water_sources:
					if cell.y - source.y < CLEARANCE_ROWS:
						ok = false
						break
				if not ok:
					break
			if ok:
				out.append(center)
	probe.queue_free()
	remove_child(probe)
	return out
