extends Node

## Headless check that a solid target blocks a redirected stream. From game/:
##   godot --headless res://tests/VerifyWaterBlocking.tscn
##
## Natural fall and forced block redirects used to disagree about what counts
## as solid. Natural fall asks _is_wall(); the two redirect loops only checked
## undug dirt and an inactive Hydro Plant, and _try_enter() has no wall check
## of its own -- so a Wall sitting on a Diverter's target was not solid to the
## diverted stream. The water was moved ONTO the wall cell, where the wall's
## own empty target list then held it forever: a puddle drawn inside a solid
## block that never moved again. wall.tres documents a Wall as "fully blocks
## water; water backs up against it each tick", and plugging a diverter's
## mouth with one is the obvious thing for a player to try.
##
## Both loops now use _is_wall(), the same test natural fall uses. These
## checks drive _advance_water() directly, one water step at a time, because
## that is where the disagreement lived.

var _failures := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _open(path: String) -> Node:
	GameState.pending_level_path = path
	var level: Node = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	for i in range(4):
		await get_tree().process_frame
	return level


## One water step from `from`, returning the coordinates it ends up at.
func _step(board: HexBoard, from: Vector2i, dir: Vector2i) -> Array:
	var next_water: Array[Dictionary] = []
	board._advance_water({"coord": from, "next_dir": dir}, next_water)
	var out := []
	for e in next_water:
		out.append(e["coord"])
	return out


func _ready() -> void:
	GameState.current_slot = 0
	GameState.debug_unlock_all = true

	# --- pointy grid ---
	var level := await _open("res://data/levels/level_001.tres")
	var board: HexBoard = level.get_node("Board")
	var d := Vector2i(0, 0)

	print("Pointy grid: a Diverter with an open target")
	board.placed_blocks.clear()
	board.placed_blocks[d] = "divert_left"
	var targets: Array = board._resolve_block_targets(d)
	_check(targets.size() == 1, "the diverter has one target (precondition)")
	_check(_step(board, d, Hex.DOWN_LEFT) == [targets[0]],
		"water diverts onto it as normal")

	print("Pointy grid: a Wall on the Diverter's only target")
	board.placed_blocks[targets[0]] = "wall"
	_check(board._is_wall(targets[0]), "the target reads as solid (precondition)")
	var landed := _step(board, d, Hex.DOWN_LEFT)
	_check(landed == [d], "water backs up on the diverter instead of entering the wall")
	_check(not landed.has(targets[0]), "and never lands on the wall cell")

	print("Pointy grid: the backed-up water stays put, it is not lost")
	var here := landed
	for i in range(4):
		here = _step(board, here[0], Hex.DOWN_LEFT)
	_check(here == [d], "still backed up four steps later, still one drop")

	print("Pointy grid: a Splitter with one of two targets walled")
	board.placed_blocks.clear()
	board.placed_blocks[d] = "splitter"
	targets = board._resolve_block_targets(d)
	_check(targets.size() == 2, "the splitter has two targets (precondition)")
	board.placed_blocks[targets[0]] = "wall"
	landed = _step(board, d, Hex.DOWN_LEFT)
	_check(landed == [targets[1]], "the stream goes to the open target only")

	print("Pointy grid: a Splitter with both targets walled")
	board.placed_blocks[targets[1]] = "wall"
	_check(_step(board, d, Hex.DOWN_LEFT) == [d], "water backs up on the splitter")

	# The narrow-vs-wide question this fix turns on. _is_wall() also counts
	# an ACTIVATED GEYSER as solid, which is right for natural fall but
	# wrong for a redirect: level 63 feeds its Hydro Plant with a stream
	# routed through its geyser's cell, and using the whole of _is_wall()
	# here makes that plant unreachable. Pinned so nobody "simplifies" the
	# condition back to _is_wall() -- VerifyHydroBonus catches it too, but
	# only by way of a level that fails for a non-obvious reason.
	print("Pointy grid: an ACTIVATED geyser is still enterable by a redirect")
	board.placed_blocks.clear()
	board.placed_blocks[d] = "divert_left"
	targets = board._resolve_block_targets(d)
	board.active_geysers.append(targets[0])
	_check(board._is_wall(targets[0]),
		"the geyser cell reads as solid to natural fall (precondition)")
	_check(_step(board, d, Hex.DOWN_LEFT) == [targets[0]],
		"but a redirected stream still enters it")
	board.active_geysers.clear()

	level.queue_free()
	remove_child(level)
	await get_tree().process_frame

	# --- flat grid (level 20 is grid_style = "flat") ---
	print("Flat grid: the same rule applies")
	level = await _open("res://data/levels/level_020.tres")
	board = level.get_node("Board")
	_check(board.level_data.grid_style == "flat", "level 20 is a flat grid (precondition)")
	var f := Vector2i(0, 0)
	board.placed_blocks.clear()
	board.placed_blocks[f] = "divert_left"
	targets = board._resolve_block_targets(f)
	_check(_step(board, f, Hex.FLAT_DOWN_LEFT) == [targets[0]],
		"water diverts onto an open target")
	board.placed_blocks[targets[0]] = "wall"
	_check(_step(board, f, Hex.FLAT_DOWN_LEFT) == [f],
		"and backs up when that target is walled")

	level.queue_free()
	remove_child(level)
	await get_tree().process_frame

	if _failures == 0:
		print("WATER BLOCKING PASS")
	else:
		printerr("WATER BLOCKING FAIL: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
