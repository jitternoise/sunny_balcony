extends SceneTree

## Headless data smoke test. Loads every LevelData resource and every
## BlockData in the catalog, then checks each level's cells against its
## own declared playable area. Run with:
##   godot --headless --path game --script res://tools/smoke_test.gd
## Exits non-zero if anything fails, so it can gate a build.

func _init() -> void:
	var errors: Array[String] = []
	var checked := 0

	# Block catalog
	var block_ids := {}
	for f in DirAccess.get_files_at("res://data/blocks/"):
		if not f.ends_with(".tres"):
			continue
		var b = load("res://data/blocks/" + f)
		if b == null:
			errors.append("block %s failed to load" % f)
		else:
			block_ids[b.id] = true

	# Levels
	var files := DirAccess.get_files_at("res://data/levels/")
	files.sort()
	var seen_ids := {}
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var lv = load("res://data/levels/" + f)
		if lv == null:
			errors.append("%s failed to load" % f)
			continue
		checked += 1

		if seen_ids.has(lv.level_id):
			errors.append("%s duplicate level_id %d" % [f, lv.level_id])
		seen_ids[lv.level_id] = true

		if lv.water_sources.is_empty():
			errors.append("%s has no water_sources" % f)
		if lv.pool_targets.is_empty() and lv.fire_cells.is_empty():
			errors.append("%s has neither pools nor fires - unwinnable" % f)

		# Every preset block must exist in the catalog
		for coord in lv.preset_blocks:
			var bid: String = lv.preset_blocks[coord]
			if not block_ids.has(bid):
				errors.append("%s preset_blocks references unknown block '%s'" % [f, bid])
		for bid in lv.starting_inventory:
			if not block_ids.has(bid):
				errors.append("%s starting_inventory references unknown block '%s'" % [f, bid])

		# Terrain must sit inside the declared playable area
		var radius: int = lv.grid_radius
		# A source outside the playable area still simulates correctly (the
		# off-board diagonal is skipped and the fallback lands where an
		# on-rim source would), but _draw_source_marker() runs
		# unconditionally, so its marker and first preview arrow render
		# detached from the grid. Cosmetic, but wrong-looking.
		for c in lv.water_sources:
			if _hex_distance(c) > radius:
				errors.append("%s water_source %s is outside grid_radius %d - marker renders off-board" % [f, c, radius])

		for group in [["fire_cells", lv.fire_cells],
					  ["town_cells", lv.town_cells], ["geyser_cells", lv.geyser_cells],
					  ["dirt_cells", lv.dirt_cells], ["hydro_plant_cells", lv.hydro_plant_cells]]:
			for c in group[1]:
				if _hex_distance(c) > radius:
					errors.append("%s %s %s is outside grid_radius %d" % [f, group[0], c, radius])
		for c in lv.pool_targets:
			if _hex_distance(c) > radius:
				errors.append("%s pool_targets %s is outside grid_radius %d" % [f, c, radius])

	print("\n=== smoke test: %d levels, %d block types ===" % [checked, block_ids.size()])
	if errors.is_empty():
		print("PASS - no problems found")
		quit(0)
	else:
		print("FAIL - %d problem(s):" % errors.size())
		for e in errors:
			print("  " + e)
		quit(1)


## Axial distance from the origin (0,0) on a hex grid.
func _hex_distance(c: Vector2i) -> int:
	return int((abs(c.x) + abs(c.y) + abs(c.x + c.y)) / 2.0)
