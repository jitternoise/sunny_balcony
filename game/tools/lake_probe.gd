extends Node

## Throwaway: sizes the "pool becomes a 4-hex lake" change before it is made.
## For every pool on every level, tries to grow it into the same rhombus
## shape the towns use (any rotation, anchor in any of the four cells) using
## only playable, terrain-free, source-free cells, and reports:
##   - pools that cannot grow at all
##   - pools whose only fits overlap the no-block water path (the lake
##     would then catch water the designer routed past that spot)
##   - levels that become winnable with NO block once the lake is there
## Runs headless; nothing here depends on viewport size.

## The town cluster from level 19/47, relative to one corner: a rhombus.
const RHOMBUS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 1)]

var _catalog: Dictionary


func _ready() -> void:
	_catalog = FFSim.load_block_catalog()
	var paths: Array[String] = LevelSelect.campaign_paths()
	var total_pools := 0
	var cannot_grow := 0
	var only_on_path := 0
	var trivial_after := 0
	var trivial_before := 0
	var bad_levels := []
	var trivial_levels := []
	for path in paths:
		var d: LevelData = load(path)
		var name := path.get_file().get_basename()
		var board := HexBoard.new()
		add_child(board)
		board.setup(d, _catalog)
		var natural := _natural_path(d)
		var was_trivial := _wins_bare(d)
		if was_trivial:
			trivial_before += 1

		var grown := d.duplicate(true)
		var new_pools := {}
		var level_bad := false
		for anchor in d.pool_targets:
			total_pools += 1
			var fits := _clusters(board, d, anchor)
			if fits.is_empty():
				cannot_grow += 1
				level_bad = true
				new_pools[anchor] = d.pool_targets[anchor]
				continue
			var best = null
			for c in fits:
				var clean := true
				for cell in c:
					if cell != anchor and natural.has(cell):
						clean = false
				if clean:
					best = c
					break
			if best == null:
				only_on_path += 1
				best = fits[0]
			for cell in best:
				new_pools[cell] = d.pool_targets[anchor]
		remove_child(board)
		board.free()
		if level_bad:
			bad_levels.append(name)

		# Approximate the lake with 4 independent pools -- strictly HARDER
		# than a shared-fill lake, so "trivial" here is a lower bound.
		grown.pool_targets = new_pools
		if not was_trivial and _wins_bare(grown):
			trivial_after += 1
			trivial_levels.append(name)

	print("pools: %d" % total_pools)
	print("cannot grow to 4 cells: %d  (levels: %s)" % [cannot_grow, ", ".join(bad_levels)])
	print("can only grow onto the natural water path: %d" % only_on_path)
	print("levels winnable with no block BEFORE: %d" % trivial_before)
	print("levels that become winnable with no block AFTER (lower bound): %d" % trivial_after)
	print("  %s" % ", ".join(trivial_levels))
	get_tree().quit()


func _clusters(board: HexBoard, d: LevelData, anchor: Vector2i) -> Array:
	var out := []
	var others := {}
	for c in d.pool_targets:
		if c != anchor:
			others[c] = true
	for rot in range(6):
		var shape := []
		for off in RHOMBUS:
			shape.append(_rotate(off, rot))
		for i in range(shape.size()):
			var origin: Vector2i = anchor - shape[i]
			var cells := []
			var ok := true
			for off in shape:
				var cell: Vector2i = origin + off
				if not board.in_playable_area(cell):
					ok = false
					break
				if cell != anchor and board.cell_terrain.get(cell, HexBoard.CellState.EMPTY) != HexBoard.CellState.EMPTY:
					ok = false
					break
				if d.water_sources.has(cell) or others.has(cell) or d.preset_blocks.has(cell):
					ok = false
					break
				cells.append(cell)
			if ok:
				var key: Array = cells.duplicate()
				key.sort()
				var dup := false
				for e in out:
					var k2: Array = e.duplicate()
					k2.sort()
					if k2 == key:
						dup = true
				if not dup:
					out.append(cells)
	return out


func _rotate(v: Vector2i, n: int) -> Vector2i:
	var q := v.x
	var r := v.y
	var s := -q - r
	for i in range(n):
		var nq := -r
		var nr := -s
		var ns := -q
		q = nq
		r = nr
		s = ns
	return Vector2i(q, r)


func _natural_path(d: LevelData) -> Dictionary:
	var probe := d.duplicate(true)
	probe.pool_targets = {Vector2i(999, 999): 4}
	var empty: Array[Vector2i] = []
	probe.fire_cells = empty
	probe.town_cells = empty.duplicate()
	var board := HexBoard.new()
	add_child(board)
	board.setup(probe, _catalog)
	board.started = true
	var seen := {}
	for m in range(120):
		if board.game_over:
			break
		board.resolve_placement_phase()
		board.resolve_water_phase()
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		for e in board.water_cells:
			seen[e["coord"]] = true
	remove_child(board)
	board.free()
	return seen


func _wins_bare(d: LevelData) -> bool:
	var board := HexBoard.new()
	add_child(board)
	board.setup(d.duplicate(true), _catalog)
	board.started = true
	var m := 0
	while m < 120 and not board.game_over:
		board.resolve_placement_phase()
		board.resolve_water_phase()
		board.resolve_terrain_phase()
		board.resolve_status_phase()
		m += 1
	var won: bool = board.game_over and board.lose_reason == ""
	remove_child(board)
	board.free()
	return won
