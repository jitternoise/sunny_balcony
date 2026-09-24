extends SceneTree

## Headless data smoke test. Loads every LevelData resource and every
## BlockData in the catalog, then checks each level's cells against its
## own declared playable area. Run with:
##   godot --headless --path game --script res://tools/smoke_test.gd
## Exits non-zero if anything fails, so it can gate a build.

## Deferred, known problems. Reported as KNOWN rather than counted as
## failures, so a genuine regression still stands out and the exit code
## stays meaningful. Remove an entry here the moment it's fixed -- a stale
## allowlist silently hides the thing it was meant to track.
##
## flat-grid off-board sources: levels 55, 56, 59, 60, 61 and 62 keep a
## water source at (-1,-4), one ring outside a radius-4 board, so its
## marker draws detached from the grid. Not fixed with the other 13
## because these are grid_style = "flat", where water falls straight down
## a column -- moving the source sideways moves the whole stream, and both
## candidate coordinates measurably change play. They also key
## source_flow_style off the same coordinate. See open-items.md.
const KNOWN_ISSUES := {
	"level_055.tres": "flat-grid off-board source",
	"level_056.tres": "flat-grid off-board source",
	"level_059.tres": "flat-grid off-board source",
	"level_060.tres": "flat-grid off-board source",
	"level_061.tres": "flat-grid off-board source",
	"level_062.tres": "flat-grid off-board source",
}


## Every folder of LevelData to check. data/sandbox/ holds levels that
## exist to try a mechanic before the owner places it in the campaign.
const LEVEL_DIRS: Array[String] = ["res://data/levels/", "res://data/sandbox/"]


func _init() -> void:
	var errors: Array[String] = []
	var known: Array[String] = []
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
			block_ids[b.id] = b

	# Levels: the campaign and tutorials, then the sandbox levels that are
	# not on the map yet (res://data/sandbox/, opened by tests/PlayLevel).
	# A sandbox file is named "sandbox/<file>" in every message.
	var files: Array[String] = []
	for dir in LEVEL_DIRS:
		var names := DirAccess.get_files_at(dir)
		names.sort()
		for n in names:
			files.append(n if dir == "res://data/levels/" else dir.trim_prefix("res://data/") + n)
	var seen_ids := {}
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var lv = load("res://data/" + (f if f.contains("/") else "levels/" + f))
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

		# Every pool is a four-cell lake: exactly three extra cells, each
		# playable, none a source, none shared with another lake, none
		# other terrain. A pool with fewer draws as a single hex and a
		# stray cell would either sit off the board or double as a fire.
		var claimed := {}
		for anchor in lv.pool_targets:
			claimed[anchor] = true
		for anchor in lv.pool_targets:
			var extras: Array = lv.lake_cells.get(anchor, [])
			if extras.size() != 3:
				errors.append("%s pool %s has %d lake cells, wants 3" % [f, anchor, extras.size()])
			for c in extras:
				if _hex_distance(c) > lv.grid_radius or lv.blocked_cells.has(c):
					errors.append("%s lake cell %s of pool %s is off the board" % [f, c, anchor])
				if lv.water_sources.has(c):
					errors.append("%s lake cell %s of pool %s is a water source" % [f, c, anchor])
				if lv.fire_cells.has(c) or lv.town_cells.has(c) or lv.geyser_cells.has(c) \
						or lv.dirt_cells.has(c) or lv.hydro_plant_cells.has(c):
					errors.append("%s lake cell %s of pool %s is other terrain" % [f, c, anchor])
				if claimed.has(c):
					errors.append("%s lake cell %s of pool %s is also part of another pool" % [f, c, anchor])
				claimed[c] = true
		for anchor in lv.lake_cells:
			if not lv.pool_targets.has(anchor):
				errors.append("%s lake_cells has an anchor %s that is not a pool" % [f, anchor])

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
				var msg := "%s water_source %s is outside grid_radius %d - marker renders off-board" % [f, c, radius]
				if KNOWN_ISSUES.has(f):
					known.append("%s  (%s)" % [msg, KNOWN_ISSUES[f]])
				else:
					errors.append(msg)

		for group in [["fire_cells", lv.fire_cells],
					  ["town_cells", lv.town_cells], ["geyser_cells", lv.geyser_cells],
					  ["dirt_cells", lv.dirt_cells], ["hydro_plant_cells", lv.hydro_plant_cells]]:
			for c in group[1]:
				if _hex_distance(c) > radius:
					errors.append("%s %s %s is outside grid_radius %d" % [f, group[0], c, radius])
		for c in lv.pool_targets:
			if _hex_distance(c) > radius:
				errors.append("%s pool_targets %s is outside grid_radius %d" % [f, c, radius])

		_check_tunnels(f, lv, block_ids, errors)

	print("\n=== smoke test: %d levels, %d block types ===" % [checked, block_ids.size()])
	if not known.is_empty():
		print("KNOWN - %d deferred issue(s), not counted as failures:" % known.size())
		for k in known:
			print("  " + k)
	if errors.is_empty():
		print("PASS - no new problems found")
		quit(0)
	else:
		print("FAIL - %d new problem(s):" % errors.size())
		for e in errors:
			print("  " + e)
		quit(1)


## Underground tunnels (LevelData.tunnel_pairs): both ends playable, on
## plain ground -- not a source, fire, lake, town, geyser, dirt, hydro
## plant cell or preset block (any cell of its footprint) -- the two ends
## of a pair different, and no cell both an entrance and an exit. Two
## entrances sharing one exit is allowed. Static so tests/VerifyTunnels
## can hand it a bad LevelData in memory without running the whole scan.
static func _check_tunnels(f: String, lv, block_ids: Dictionary, errors: Array[String]) -> void:
	if lv.tunnel_pairs.is_empty():
		return
	var taken := {}
	for c in lv.water_sources: taken[c] = "a water source"
	for c in lv.fire_cells: taken[c] = "a fire"
	for c in lv.town_cells: taken[c] = "a town"
	for c in lv.geyser_cells: taken[c] = "a geyser"
	for c in lv.dirt_cells: taken[c] = "dirt"
	for anchor in lv.pool_targets:
		taken[anchor] = "a lake"
		for c in lv.lake_cells.get(anchor, []): taken[c] = "a lake"
	for center in lv.hydro_plant_cells:
		for dq in [-1, 0, 1]: taken[center + Vector2i(dq, 0)] = "a hydro plant"
	for anchor in lv.preset_blocks:
		taken[anchor] = "a preset block"
		var block = block_ids.get(lv.preset_blocks[anchor], null)
		if block != null:
			for offset in block.footprint_offsets: taken[anchor + offset] = "a preset block"
	var exits := {}
	for entrance in lv.tunnel_pairs:
		exits[lv.tunnel_pairs[entrance]] = true
	for entrance in lv.tunnel_pairs:
		var exit_cell = lv.tunnel_pairs[entrance]
		if typeof(entrance) != TYPE_VECTOR2I or typeof(exit_cell) != TYPE_VECTOR2I:
			errors.append("%s tunnel_pairs entry %s -> %s is not Vector2i -> Vector2i" % [f, entrance, exit_cell])
			continue
		if entrance == exit_cell:
			errors.append("%s tunnel at %s enters and exits on the same cell" % [f, entrance])
		if exits.has(entrance):
			errors.append("%s tunnel cell %s is both an entrance and an exit" % [f, entrance])
		for end in [["entrance", entrance], ["exit", exit_cell]]:
			var c: Vector2i = end[1]
			if not _in_playable_area(lv, c):
				errors.append("%s tunnel %s %s is outside the playable area" % [f, end[0], c])
			if taken.has(c):
				errors.append("%s tunnel %s %s is on %s" % [f, end[0], c, taken[c]])


## HexBoard.in_playable_area() without a board: radius, blocked_cells and
## the corridor band.
static func _in_playable_area(lv, c: Vector2i) -> bool:
	if lv.blocked_cells.has(c) or _hex_distance(c) > lv.grid_radius:
		return false
	if lv.corridor_half_width > 0:
		var band_center := int(roundf(-c.y / 2.0))
		if absi(c.x - band_center) > lv.corridor_half_width:
			return false
	return true


## Axial distance from the origin (0,0) on a hex grid.
static func _hex_distance(c: Vector2i) -> int:
	return int((abs(c.x) + abs(c.y) + abs(c.x + c.y)) / 2.0)
